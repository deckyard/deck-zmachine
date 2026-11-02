# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - decoding and executing instructions.
# Spliced into zmachine.j via include - not a standalone module.
#
# Every handler takes the machine and returns it, always as `$m = f($m, ...)`
# with no other argument naming `$m`: that form moves the machine into the
# call instead of copying its memory (see CLAUDE.md).

/**
 * Run the story until it needs something: a line, a key, a save or restore
 * decision, or until it quits. Call it once after `load` to start the game.
 * @param m {Machine} the machine
 * @return {Machine} the machine, now waiting (see `waiting`)
 * @throws {Error} when the machine is already waiting, or on an illegal instruction
 * @example
 *   def m as zmachine.Machine init zmachine.run(zmachine.open("story.z5"));
 *   io.printf("%s", zmachine.output($m));
 */
export func run(m as Machine) {
    if ($m.waitOn == WAIT_QUIT) {
        fail("the story has ended");
    }
    if ($m.waitOn != WAIT_NONE) {
        fail("the story is waiting for " + waitName($m.waitOn) + ", not for run");
    }
    $m.out = [];
    $m = execute($m);
    return $m;
}

/**
 * What the machine waits for.
 * @param m {Machine} the machine
 * @return {Wait} `Line`, `Key`, `Save`, `Restore` or `Quit`
 * @throws {Error} on a machine that has not been run yet
 */
export func waiting(m as Machine) {
    match ($m.waitOn) {
        when WAIT_LINE { return Wait.Line; }
        when WAIT_KEY { return Wait.Key; }
        when WAIT_SAVE { return Wait.Save; }
        when WAIT_RESTORE { return Wait.Restore; }
        when WAIT_QUIT { return Wait.Quit; }
    }
    fail("the story has not been run");
}

/**
 * Answer a `Line` or `Key` wait, then run until the next one. A line is
 * lower-cased and cut to the game's buffer; a key is the first character of
 * `text`, or Return for "".
 * @param m {Machine} the machine
 * @param text {string} the line typed, or the key pressed
 * @return {Machine} the machine, waiting again
 * @throws {Error} when the machine is not waiting for a line or a key
 * @example
 *   $m = zmachine.send($m, "take lamp");
 */
export func send(m as Machine, text as string) {
    if ($m.waitOn == WAIT_LINE) {
        $m = fillText($m, $text);
        def text2 as int init $m.readText;
        def parse as int init $m.readParse;
        if ($parse != 0) {
            $m = tokenise($m, $text2, $parse, 0, false);
        }
        def sv as int init $m.readStore;
        if ($sv >= 0) {
            $m = store($m, $sv, 13);
        }
    } elseif ($m.waitOn == WAIT_KEY) {
        def key as int init 13;
        if ($text != "") {
            $key = charToZscii($m, strings.chars($text)[0]);
        }
        def sv as int init $m.readStore;
        $m = store($m, $sv, $key);
    } else {
        fail("the story is waiting for " + waitName($m.waitOn) + ", not for input");
    }
    $m.waitOn = WAIT_NONE;
    $m.out = [];
    $m = execute($m);
    return $m;
}

/**
 * Name a wait state for a message.
 * @param w {int} a `WAIT_` constant
 * @return {string} a few words
 */
func waitName(w as int) {
    match ($w) {
        when WAIT_LINE { return "a line"; }
        when WAIT_KEY { return "a key"; }
        when WAIT_SAVE { return "a save"; }
        when WAIT_RESTORE { return "a restore"; }
        when WAIT_QUIT { return "nothing, it has ended"; }
    }
    return "run";
}

/**
 * Execute instructions until the machine waits.
 * @param m {Machine} the machine
 * @return {Machine} the waiting machine
 * @throws {Error} when the instruction limit runs out
 */
func execute(m as Machine) {
    def n as int init 0;
    def limit as int init $m.limit;
    while ($m.waitOn == WAIT_NONE) {
        $m = step($m);
        $n = $n + 1;
        if ($n > $limit) {
            failAt($m, "no input request after " + convert.toString($limit) + " instructions");
        }
    }
    return $m;
}

/**
 * Decode and execute one instruction.
 * @param m {Machine} the machine
 * @return {Machine} the machine after it
 * @throws {Error} on an illegal instruction
 */
func step(m as Machine) {
    def pc as int init $m.pc;
    def b as int init $m.mem[$pc];
    $pc = $pc + 1;
    def form as int init 2;
    def num as int init $b & 31;
    # two bits per operand, first operand highest; 3 ends the list
    def types as int init 0xffff;
    if ($b < 0x80) {
        $types = 0x0fff | (0x4000 << (($b >> 6) & 1)) | (0x1000 << (($b >> 5) & 1));
    } elseif ($b < 0xc0) {
        if ($b == 0xbe and $m.version >= 5) {
            $form = 4;
            $num = $m.mem[$pc];
            $types = ($m.mem[$pc + 1] << 8) | 0xff;
            $pc = $pc + 2;
        } else {
            def t as int init ($b >> 4) & 3;
            $num = $b & 15;
            if ($t == 3) {
                $form = 0;
            } else {
                $form = 1;
                $types = ($t << 14) | 0x3fff;
            }
        }
    } else {
        if ($b & 0x20 != 0) {
            $form = 3;
        }
        $types = ($m.mem[$pc] << 8) | 0xff;
        $pc = $pc + 1;
        if ($form == 3 and ($num == 12 or $num == 26)) {
            $types = ($types & 0xff00) | $m.mem[$pc];
            $pc = $pc + 1;
        }
    }
    def n as int init 0;
    def shift as int init 14;
    while ($shift >= 0) {
        def t as int init ($types >> $shift) & 3;
        if ($t == 3) {
            break;
        }
        def v as int init 0;
        if ($t == 0) {
            $v = ($m.mem[$pc] << 8) | $m.mem[$pc + 1];
            $pc = $pc + 2;
        } elseif ($t == 1) {
            $v = $m.mem[$pc];
            $pc = $pc + 1;
        } else {
            def x as int init $m.mem[$pc];
            $pc = $pc + 1;
            if ($x == 0) {
                if ($m.sp <= $m.bp + $m.frames[$m.fp - 2]) {
                    $m.pc = $pc;
                    failAt($m, "stack underflow");
                }
                $m.sp = $m.sp - 1;
                $v = $m.stack[$m.sp];
            } elseif ($x < 16) {
                if ($x > $m.frames[$m.fp - 2]) {
                    $m.pc = $pc;
                    failAt($m, "local " + convert.toString($x) + " does not exist");
                }
                $v = $m.stack[$m.bp + $x - 1];
            } else {
                def g as int init $m.globals + 2 * $x - 32;
                $v = ($m.mem[$g] << 8) | $m.mem[$g + 1];
            }
        }
        $m.ops[$n] = $v;
        $n = $n + 1;
        $shift = $shift - 2;
    }
    $m.nops = $n;
    $m.pc = $pc;
    if ($form == 2) {
        $m = op2($m, $num);
    } elseif ($form == 3) {
        $m = opVar($m, $num);
    } elseif ($form == 1) {
        $m = op1($m, $num);
    } elseif ($form == 0) {
        $m = op0($m, $num);
    } else {
        $m = opExt($m, $num);
    }
    return $m;
}

/**
 * Store a result in the variable named by the byte at the program counter.
 * @param m {Machine} the machine
 * @param x {int} the value
 * @return {Machine} the machine with the result stored
 */
func result(m as Machine, x as int) {
    def v as int init $m.mem[$m.pc];
    $m.pc = $m.pc + 1;
    $m = store($m, $v, $x);
    return $m;
}

/**
 * Read the branch data at the program counter and take the branch when
 * `cond` matches its sense.
 * @param m {Machine} the machine
 * @param cond {bool} the instruction's outcome
 * @return {Machine} the machine after the branch
 */
func branch(m as Machine, cond as bool) {
    def b as int init $m.mem[$m.pc];
    def off as int init $b & 63;
    if ($b & 0x40 != 0) {
        $m.pc = $m.pc + 1;
    } else {
        $off = ($off << 8) | $m.mem[$m.pc + 1];
        if ($off >= 8192) {
            $off = $off - 16384;
        }
        $m.pc = $m.pc + 2;
    }
    if (($b & 0x80 != 0) != $cond) {
        return $m;
    }
    if ($off == 0 or $off == 1) {
        $m = ret($m, $off);
        return $m;
    }
    $m.pc = $m.pc + $off - 2;
    return $m;
}

/**
 * Call the routine in `ops[0]` with the rest of `ops` as arguments.
 * @param m {Machine} the machine
 * @param sv {int} the store variable for the result, -1 to discard it
 * @return {Machine} the machine at the routine's first instruction
 * @throws {Error} on a routine with more than 15 locals
 */
func call(m as Machine, sv as int) {
    def packed as int init $m.ops[0];
    if ($packed == 0) {
        if ($sv >= 0) {
            $m = store($m, $sv, 0);
        }
        return $m;
    }
    def a as int init routineAddress($m, $packed);
    if ($a >= len($m.mem)) {
        failAt($m, "call to " + hex($a) + " beyond the end of memory");
    }
    def nloc as int init $m.mem[$a];
    if ($nloc > 15) {
        failAt($m, "routine at " + hex($a) + " has " + convert.toString($nloc) + " locals");
    }
    def args as int init $m.nops - 1;
    def f as int init $m.fp;
    for (def x in [$m.pc, $sv, $args, $nloc, $m.sp]) {
        if ($f < len($m.frames)) {
            $m.frames[$f] = $x;
        } else {
            $m.frames[] = $x;
        }
        $f = $f + 1;
    }
    $m.fp = $f;
    $m.bp = $m.sp;
    def body as int init $a + 1;
    for (def i in 0..$nloc) {
        def v as int init 0;
        if ($m.version <= 4) {
            $v = word($m.mem, $a + 1 + 2 * $i);
        }
        if ($i < $args) {
            $v = $m.ops[$i + 1];
        }
        $m = push($m, $v);
    }
    if ($m.version <= 4) {
        $body = $body + 2 * $nloc;
    }
    $m.pc = $body;
    return $m;
}

/**
 * Return from the current routine.
 * @param m {Machine} the machine
 * @param x {int} the return value
 * @return {Machine} the machine back in the caller
 * @throws {Error} when there is no routine to return from
 */
func ret(m as Machine, x as int) {
    if ($m.fp <= FRAME_SIZE) {
        failAt($m, "return from the main routine");
    }
    def f as int init $m.fp - FRAME_SIZE;
    def sv as int init $m.frames[$f + 1];
    $m.pc = $m.frames[$f];
    $m.sp = $m.frames[$f + 4];
    $m.fp = $f;
    $m.bp = $m.frames[$f - 1];
    if ($sv >= 0) {
        $m = store($m, $sv, $x);
    }
    return $m;
}

/**
 * Signed division and remainder, both rounded toward zero as the Z-machine
 * requires; Jennifer's `//` and `%` round toward minus infinity.
 * @param m {Machine} the machine
 * @param a {int} the dividend, signed
 * @param b {int} the divisor, signed
 * @param modulo {bool} true for the remainder
 * @return {int} the quotient or remainder
 * @throws {Error} on division by zero
 */
func divide(m as Machine, a as int, b as int, modulo as bool) {
    if ($b == 0) {
        failAt($m, "division by zero");
    }
    def q as int init math.abs($a) // math.abs($b);
    if (($a < 0) != ($b < 0)) {
        $q = -$q;
    }
    if ($modulo) {
        return $a - $b * $q;
    }
    return $q;
}

/**
 * Execute a 2OP instruction.
 * @param m {Machine} the machine
 * @param num {int} the opcode number
 * @return {Machine} the machine after it
 */
func op2(m as Machine, num as int) {
    def a as int init $m.ops[0];
    def b as int init $m.ops[1];
    match ($num) {
        when 1 {
            def hit as bool init false;
            for (def i in 1..$m.nops) {
                if ($m.ops[$i] == $a) {
                    $hit = true;
                    break;
                }
            }
            $m = branch($m, $hit);
        }
        when 2 { $m = branch($m, signed($a) < signed($b)); }
        when 3 { $m = branch($m, signed($a) > signed($b)); }
        when 4 {
            def x as int init signed(peekVar($m, $a)) - 1;
            $m = pokeVar($m, $a, $x);
            $m = branch($m, signed($x & 0xffff) < signed($b));
        }
        when 5 {
            def x as int init signed(peekVar($m, $a)) + 1;
            $m = pokeVar($m, $a, $x);
            $m = branch($m, signed($x & 0xffff) > signed($b));
        }
        when 6 { $m = branch($m, link($m, $a, 0) == $b); }
        when 7 { $m = branch($m, $a & $b == $b); }
        when 8 { $m = result($m, $a | $b); }
        when 9 { $m = result($m, $a & $b); }
        when 10 { $m = branch($m, hasAttr($m, $a, $b)); }
        when 11 { $m = setAttr($m, $a, $b, true); }
        when 12 { $m = setAttr($m, $a, $b, false); }
        when 13 { $m = pokeVar($m, $a, $b); }
        when 14 { $m = insertObject($m, $a, $b); }
        when 15 { $m = result($m, word($m.mem, ($a + 2 * $b) & 0xffff)); }
        when 16 { $m = result($m, $m.mem[($a + $b) & 0xffff]); }
        when 17 { $m = result($m, getProp($m, $a, $b)); }
        when 18 { $m = result($m, propAddress($m, $a, $b)); }
        when 19 { $m = result($m, nextProp($m, $a, $b)); }
        when 20 { $m = result($m, $a + $b); }
        when 21 { $m = result($m, $a - $b); }
        when 22 { $m = result($m, signed($a) * signed($b)); }
        when 23 { $m = result($m, divide($m, signed($a), signed($b), false)); }
        when 24 { $m = result($m, divide($m, signed($a), signed($b), true)); }
        when 25 {
            def sv as int init $m.mem[$m.pc];
            $m.pc = $m.pc + 1;
            $m = call($m, $sv);
        }
        when 26 { $m = call($m, -1); }
        when 27 {
            # set_colour: no colours
        }
        when 28 { $m = throwTo($m, $a, $b); }
        else { failAt($m, "illegal 2OP opcode " + convert.toString($num)); }
    }
    return $m;
}

/**
 * Return from the frame a `catch` named (`throw`).
 * @param m {Machine} the machine
 * @param x {int} the value to return
 * @param frame {int} the frame `catch` stored
 * @return {Machine} the machine back in that frame's caller
 * @throws {Error} when the frame is gone
 */
func throwTo(m as Machine, x as int, frame as int) {
    def f as int init $frame * FRAME_SIZE;
    if ($f > $m.fp or $f <= FRAME_SIZE) {
        failAt($m, "throw to frame " + convert.toString($frame) + ", which is not on the stack");
    }
    $m.fp = $f;
    $m.bp = $m.frames[$f - 1];
    $m = ret($m, $x);
    return $m;
}

/**
 * Execute a 1OP instruction.
 * @param m {Machine} the machine
 * @param num {int} the opcode number
 * @return {Machine} the machine after it
 */
func op1(m as Machine, num as int) {
    def a as int init $m.ops[0];
    match ($num) {
        when 0 { $m = branch($m, $a == 0); }
        when 1 {
            def x as int init link($m, $a, 1);
            $m = result($m, $x);
            $m = branch($m, $x != 0);
        }
        when 2 {
            def x as int init link($m, $a, 2);
            $m = result($m, $x);
            $m = branch($m, $x != 0);
        }
        when 3 { $m = result($m, link($m, $a, 0)); }
        when 4 { $m = result($m, propLength($m, $a)); }
        when 5 {
            def x as int init peekVar($m, $a) + 1;
            $m = pokeVar($m, $a, $x);
        }
        when 6 {
            def x as int init peekVar($m, $a) - 1;
            $m = pokeVar($m, $a, $x);
        }
        when 7 { $m = emit($m, decode($m, $a, false)); }
        when 8 {
            def sv as int init $m.mem[$m.pc];
            $m.pc = $m.pc + 1;
            $m = call($m, $sv);
        }
        when 9 { $m = detach($m, $a); }
        when 10 { $m = emit($m, shortName($m, $a)); }
        when 11 { $m = ret($m, $a); }
        when 12 { $m.pc = $m.pc + signed($a) - 2; }
        when 13 { $m = emit($m, decode($m, stringAddress($m, $a), false)); }
        when 14 { $m = result($m, peekVar($m, $a)); }
        when 15 {
            if ($m.version <= 4) {
                $m = result($m, ~ $a);
            } else {
                $m = call($m, -1);
            }
        }
    }
    return $m;
}

/**
 * Execute a 0OP instruction.
 * @param m {Machine} the machine
 * @param num {int} the opcode number
 * @return {Machine} the machine after it
 */
func op0(m as Machine, num as int) {
    match ($num) {
        when 0 { $m = ret($m, 1); }
        when 1 { $m = ret($m, 0); }
        when 2 {
            def at as int init $m.pc;
            $m.pc = skipString($m, $at);
            $m = emit($m, decode($m, $at, false));
        }
        when 3 {
            def at as int init $m.pc;
            $m.pc = skipString($m, $at);
            $m = emit($m, decode($m, $at, false));
            $m = emit($m, [13]);
            $m = ret($m, 1);
        }
        when 4 {
            # nop
        }
        when 5 { if ($m.version >= 5) {
            failAt($m, "illegal 0OP opcode 5");
        }
        $m = pauseForSave($m); }
        when 6 {
            if ($m.version >= 5) {
                failAt($m, "illegal 0OP opcode 6");
            }
            $m.resultPc = $m.pc;
            $m.waitOn = WAIT_RESTORE;
        }
        when 7 { $m = restart($m); }
        when 8 {
            def x as int init peekVar($m, 0);
            $m = drop($m);
            $m = ret($m, $x);
        }
        when 9 {
            if ($m.version >= 5) {
                $m = result($m, $m.fp // FRAME_SIZE);
            } else {
                $m = drop($m);
            }
        }
        when 10 { $m.waitOn = WAIT_QUIT; }
        when 11 { $m = emit($m, [13]); }
        when 12 {
            # show_status: the status line is drawn when it is asked for
        }
        when 13 { $m = branch($m, verify($m)); }
        when 15 { $m = branch($m, true); }
        else { failAt($m, "illegal 0OP opcode " + convert.toString($num)); }
    }
    return $m;
}

/**
 * Execute a VAR instruction.
 * @param m {Machine} the machine
 * @param num {int} the opcode number
 * @return {Machine} the machine after it
 */
func opVar(m as Machine, num as int) {
    def a as int init $m.ops[0];
    def b as int init $m.ops[1];
    def c as int init $m.ops[2];
    match ($num) {
        when 0 {
            def sv as int init $m.mem[$m.pc];
            $m.pc = $m.pc + 1;
            $m = call($m, $sv);
        }
        when 1 { $m = storeWord($m, ($a + 2 * $b) & 0xffff, $c); }
        when 2 { $m = storeByte($m, ($a + $b) & 0xffff, $c); }
        when 3 { $m = putProp($m, $a, $b, $c); }
        when 4 {
            $m.readText = $a;
            $m.readParse = 0;
            if ($m.nops > 1) {
                $m.readParse = $b;
            }
            $m.readStore = -1;
            if ($m.version >= 5) {
                $m.readStore = $m.mem[$m.pc];
                $m.pc = $m.pc + 1;
            }
            $m.waitOn = WAIT_LINE;
        }
        when 5 { $m = emit($m, [$a]); }
        when 6 { $m = emitText($m, convert.toString(signed($a))); }
        when 7 { $m = random($m, signed($a)); }
        when 8 { $m = push($m, $a); }
        when 9 {
            def x as int init peekVar($m, 0);
            $m = drop($m);
            $m = pokeVar($m, $a, $x);
        }
        when 10 { $m = split($m, $a); }
        when 11 { $m.window = $a;
        if ($a == 1) {
            $m.row = 0;
            $m.col = 0;
        }
        }
        when 12 {
            def sv as int init $m.mem[$m.pc];
            $m.pc = $m.pc + 1;
            $m = call($m, $sv);
        }
        when 13 { $m = eraseWindow($m, signed($a)); }
        when 14 {
            if ($a == 1) {
                $m = eraseLine($m);
            }
        }
        when 15 {
            if ($m.window == 1 and signed($a) > 0) {
                $m.row = $a - 1;
                $m.col = math.max(0, signed($b) - 1);
            }
        }
        when 16 {
            $m = storeWord($m, $a, $m.row + 1);
            $m = storeWord($m, $a + 2, $m.col + 1);
        }
        when 17, 18, 20, 21 {
            # text style, buffering, input stream and sound: nothing to do
        }
        when 19 { $m = selectStream($m, signed($a), $b); }
        when 22 {
            $m.readStore = $m.mem[$m.pc];
            $m.pc = $m.pc + 1;
            $m.waitOn = WAIT_KEY;
        }
        when 23 {
            def form as int init 0x82;
            if ($m.nops > 3) {
                $form = $m.ops[3];
            }
            def found as int init scanTable($m, $a, $b, $c, $form);
            $m = result($m, $found);
            $m = branch($m, $found != 0);
        }
        when 24 { $m = result($m, ~ $a); }
        when 25, 26 { $m = call($m, -1); }
        when 27 {
            def dict as int init 0;
            def keep as bool init false;
            if ($m.nops > 2) {
                $dict = $c;
            }
            if ($m.nops > 3) {
                $keep = $m.ops[3] != 0;
            }
            $m = tokenise($m, $a, $b, $dict, $keep);
        }
        when 28 {
            def codes as list of int init [];
            for (def i in 0..$b) {
                $codes[] = $m.mem[$a + $c + $i];
            }
            def coded as int init $m.ops[3];
            def encoded as list of int init encodeWord($m, $codes);
            for (def i in 0..len($encoded)) {
                $m = storeByte($m, $coded + $i, $encoded[$i]);
            }
        }
        when 29 { $m = copyTable($m, $a, $b, signed($c)); }
        when 30 { $m = printTable($m); }
        when 31 { $m = branch($m, $a <= $m.frames[$m.fp - 3]); }
    }
    return $m;
}

/**
 * Execute an EXT instruction (version 5 and later).
 * @param m {Machine} the machine
 * @param num {int} the opcode number
 * @return {Machine} the machine after it
 */
func opExt(m as Machine, num as int) {
    def a as int init $m.ops[0];
    def b as int init $m.ops[1];
    match ($num) {
        when 0 {
            if ($m.nops > 0) {
                # saving a table to an auxiliary file is not supported
                $m = result($m, 0);
            } else {
                $m = pauseForSave($m);
            }
        }
        when 1 {
            if ($m.nops > 0) {
                $m = result($m, 0);
            } else {
                $m.resultPc = $m.pc;
                $m.waitOn = WAIT_RESTORE;
            }
        }
        when 2 {
            def places as int init signed($b);
            if ($places >= 0) {
                $m = result($m, $a << $places);
            } else {
                $m = result($m, $a >> -$places);
            }
        }
        when 3 {
            def places as int init signed($b);
            if ($places >= 0) {
                $m = result($m, $a << $places);
            } else {
                $m = result($m, signed($a) >> -$places);
            }
        }
        when 4 {
            def was as int init $m.font;
            if ($a == 0) {
                $m = result($m, $was);
            } elseif ($a == 1 or $a == 4) {
                $m.font = $a;
                $m = result($m, $was);
            } else {
                $m = result($m, 0);
            }
        }
        when 9 { $m = saveUndo($m); }
        when 10 { $m = restoreUndo($m); }
        when 11 { $m = emitText($m, convert.fromCodepoint($a)); }
        when 12 {
            def can as int init 0;
            if ($a >= 32 and $a != 127) {
                $can = 1;
                if (charToZscii($m, convert.fromCodepoint($a)) != 63 or $a == 63) {
                    $can = 3;
                }
            }
            $m = result($m, $can);
        }
        when 13 {
            # set_true_colour: no colours
        }
        else { failAt($m, "EXT opcode " + convert.toString($num) + " is not supported"); }
    }
    return $m;
}

/**
 * The `random` opcode: a number from 1 to `range`, or a reseed for 0 and
 * negative ranges.
 * @param m {Machine} the machine
 * @param range {int} the signed operand
 * @return {Machine} the machine with the result stored
 */
func random(m as Machine, range as int) {
    if ($range > 0) {
        def x as int init 0;
        if ($m.rngMode == 2) {
            $x = ($m.rngCount - 1) % $range + 1;
            $m.rngCount = $m.rngCount % $m.rngTop + 1;
        } elseif ($m.rngMode == 1) {
            $m.rng = ($m.rng * 1103515245 + 12345) % 2147483648;
            $x = ($m.rng >> 8) % $range + 1;
        } else {
            $x = math.randInt(1, $range);
        }
        $m = result($m, $x);
        return $m;
    }
    if ($range < 0 and -$range < 1000) {
        $m.rngMode = 2;
        $m.rngTop = -$range;
        $m.rngCount = 1;
    } elseif ($range < 0) {
        $m.rngMode = 1;
        $m.rng = -$range;
    } elseif ($m.rngMode != 0) {
        $m.rngMode = 1;
        $m.rng = ($m.rng * 69069 + 1) % 2147483648;
    }
    $m = result($m, 0);
    return $m;
}

/**
 * Search a table for a byte or word (`scan_table`).
 * @param m {Machine} the machine
 * @param x {int} the value to find
 * @param table {int} address of the table
 * @param count {int} entries to search
 * @param form {int} bit 7 for words, bits 0 to 6 the entry size
 * @return {int} address of the first match, 0 for none
 */
func scanTable(m as Machine, x as int, table as int, count as int, form as int) {
    def size as int init $form & 0x7f;
    def words as bool init $form & 0x80 != 0;
    for (def i in 0..$count) {
        def a as int init $table + $i * $size;
        def v as int init $m.mem[$a];
        if ($words) {
            $v = word($m.mem, $a);
        }
        if ($v == $x) {
            return $a;
        }
    }
    return 0;
}

/**
 * Copy, or zero, a block of memory (`copy_table`).
 * @param m {Machine} the machine
 * @param first {int} the source
 * @param second {int} the destination, 0 to zero the source
 * @param size {int} bytes; negative forces a forward copy even over an overlap
 * @return {Machine} the machine with the block copied
 */
func copyTable(m as Machine, first as int, second as int, size as int) {
    def n as int init math.abs($size);
    if ($second == 0) {
        for (def i in 0..$n) {
            $m = storeByte($m, $first + $i, 0);
        }
        return $m;
    }
    if ($size < 0) {
        for (def i in 0..$n) {
            def x as int init $m.mem[$first + $i];
            $m = storeByte($m, $second + $i, $x);
        }
        return $m;
    }
    def src as bytes init $m.mem[$first..$first + $n];
    for (def i in 0..$n) {
        def x as int init $src[$i];
        $m = storeByte($m, $second + $i, $x);
    }
    return $m;
}

/**
 * Print a rectangle of ZSCII text (`print_table`): in the upper window each
 * row starts below the last at the same column, in the lower window on a new
 * line.
 * @param m {Machine} the machine
 * @return {Machine} the machine with the table printed
 */
func printTable(m as Machine) {
    def text as int init $m.ops[0];
    def width as int init $m.ops[1];
    def height as int init 1;
    def skip as int init 0;
    if ($m.nops > 2) {
        $height = $m.ops[2];
    }
    if ($m.nops > 3) {
        $skip = $m.ops[3];
    }
    def row as int init $m.row;
    def col as int init $m.col;
    for (def r in 0..$height) {
        def codes as list of int init [];
        def at as int init $text + $r * ($width + $skip);
        for (def i in 0..$width) {
            $codes[] = $m.mem[$at + $i];
        }
        if ($m.window == 1) {
            $m.row = $row + $r;
            $m.col = $col;
        } elseif ($r > 0) {
            $m = emit($m, [13]);
        }
        $m = emit($m, $codes);
    }
    return $m;
}

/**
 * Check the story against its header checksum (`verify`).
 * @param m {Machine} the machine
 * @return {bool} true when the bytes from $40 to the stated length add up
 */
func verify(m as Machine) {
    def size as int init fileLength($m.story);
    def sum as int init 0;
    for (def i in 0x40..math.min($size, len($m.story))) {
        $sum = $sum + $m.story[$i];
    }
    return $sum % 65536 == word($m.story, 0x1c);
}

/**
 * The story length the header states.
 * @param story {bytes} the story file
 * @return {int} bytes; the actual length when the header leaves it 0
 */
func fileLength(story as bytes) {
    def v as int init $story[0];
    def scale as int init 8;
    if ($v <= 3) {
        $scale = 2;
    } elseif ($v <= 5) {
        $scale = 4;
    }
    def n as int init word($story, 0x1a) * $scale;
    if ($n == 0) {
        return len($story);
    }
    return $n;
}
