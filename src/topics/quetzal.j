# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - saving and restoring: Quetzal files and undo.
# Spliced into zmachine.j via include - not a standalone module.

/**
 * The save file of a pending `Save` wait, in Quetzal format (`.qzl`), which
 * other interpreters read too. Store it, then call `resume`.
 * @param m {Machine} the machine
 * @return {bytes} the Quetzal file
 * @throws {Error} when the machine is not waiting for a save
 * @example
 *   fs.writeBytes("game.qzl", zmachine.saveData($m));
 *   $m = zmachine.resume($m, true);
 */
export func saveData(m as Machine) {
    if ($m.waitOn != WAIT_SAVE) {
        fail("the story is waiting for " + waitName($m.waitOn) + ", not for a save");
    }
    return $m.saved;
}

/**
 * Answer a `Save` wait (did storing the file work?) or turn down a `Restore`
 * wait, then run until the next wait. The game reports the outcome itself.
 * @param m {Machine} the machine
 * @param ok {bool} for a save, true when the file was stored; ignored for a restore
 * @return {Machine} the machine, waiting again
 * @throws {Error} when the machine is not waiting for a save or a restore
 */
export func resume(m as Machine, ok as bool) {
    def done as bool init $ok;
    if ($m.waitOn == WAIT_RESTORE) {
        $done = false;
    } elseif ($m.waitOn != WAIT_SAVE) {
        fail("the story is waiting for " + waitName($m.waitOn) + ", not for resume");
    }
    $m.waitOn = WAIT_NONE;
    $m.saved = binary.make(0);
    $m.out = [];
    $m = answerSave($m, $done, 1);
    $m = execute($m);
    return $m;
}

/**
 * Answer a `Restore` wait with a Quetzal file, then run on from the point it
 * was saved at.
 * @param m {Machine} the machine
 * @param data {bytes} the Quetzal file
 * @return {Machine} the restored machine, waiting again
 * @throws {Error} when the machine is not waiting for a restore, or the file is not a save of this story; the machine passed in is unchanged, so `resume(m, false)` still turns the restore down
 */
export func restore(m as Machine, data as bytes) {
    if ($m.waitOn != WAIT_RESTORE) {
        fail("the story is waiting for " + waitName($m.waitOn) + ", not for a restore");
    }
    $m = readQuetzal($m, $data);
    $m.waitOn = WAIT_NONE;
    $m.out = [];
    $m = answerSave($m, true, 2);
    $m = execute($m);
    return $m;
}

/**
 * Finish a `save` or `restore` instruction at its store or branch byte.
 * @param m {Machine} the machine
 * @param ok {bool} whether it worked
 * @param value {int} what a version 4+ store gets on success: 1 after a save, 2 after a restore
 * @return {Machine} the machine past the instruction
 */
func answerSave(m as Machine, ok as bool, value as int) {
    $m.pc = $m.resultPc;
    if ($m.version <= 3) {
        $m = branch($m, $ok);
        return $m;
    }
    def x as int init 0;
    if ($ok) {
        $x = $value;
    }
    $m = result($m, $x);
    return $m;
}

/**
 * Stop at a `save` instruction with the Quetzal file ready.
 * @param m {Machine} the machine, its program counter on the store or branch byte
 * @return {Machine} the machine waiting for a save
 */
func pauseForSave(m as Machine) {
    $m.resultPc = $m.pc;
    $m.saved = writeQuetzal($m);
    $m.waitOn = WAIT_SAVE;
    return $m;
}

/**
 * Append a big-endian number.
 * @param out {bytes} the buffer
 * @param v {int} the value
 * @param size {int} bytes, 1 to 4
 * @return {bytes} the buffer with the number appended
 */
func putBE(out as bytes, v as int, size as int) {
    for (def i in 0..$size) {
        $out[] = ($v >> (8 * ($size - 1 - $i))) & 0xff;
    }
    return $out;
}

/**
 * Wrap a body in an IFF chunk, padded to an even length.
 * @param id {string} the four-letter chunk id
 * @param body {bytes} the chunk data
 * @return {bytes} the chunk
 */
func chunk(id as string, body as bytes) {
    def out as bytes init convert.bytesFromString($id, "utf-8");
    $out = putBE($out, len($body), 4);
    def parts as list of bytes init [$out, $body];
    if (len($body) % 2 == 1) {
        $parts[] = binary.make(1);
    }
    return binary.join($parts);
}

/**
 * The machine as a Quetzal file, with the program counter at `resultPc`.
 * @param m {Machine} the machine
 * @return {bytes} the file
 */
func writeQuetzal(m as Machine) {
    def head as bytes;
    for (def i in [2, 3, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x1c, 0x1d]) {
        $head[] = $m.story[$i];
    }
    $head = putBE($head, $m.resultPc, 3);
    def body as list of bytes init [
        convert.bytesFromString("IFZS", "utf-8"),
        chunk("IFhd", $head),
        chunk("CMem", compressMemory($m)),
        chunk("Stks", writeStacks($m))
    ];
    def form as bytes init binary.join($body);
    def out as bytes init convert.bytesFromString("FORM", "utf-8");
    $out = putBE($out, len($form), 4);
    return binary.join([$out, $form]);
}

/**
 * Dynamic memory as a CMem body: XOR with the story, runs of zeros as a zero
 * byte and a count.
 * @param m {Machine} the machine
 * @return {bytes} the compressed memory
 */
func compressMemory(m as Machine) {
    def out as bytes;
    def zeros as int init 0;
    for (def i in 0..$m.staticBase) {
        def x as int init $m.mem[$i] ^ $m.story[$i];
        if ($x == 0) {
            $zeros = $zeros + 1;
            continue;
        }
        while ($zeros > 0) {
            def n as int init math.min($zeros, 256);
            $out[] = 0;
            $out[] = $n - 1;
            $zeros = $zeros - $n;
        }
        $out[] = $x;
    }
    return $out;
}

/**
 * The call stack as a Stks body: one record per frame, oldest first, starting
 * with the dummy frame that holds the main routine's evaluation stack.
 * @param m {Machine} the machine
 * @return {bytes} the stacks
 */
func writeStacks(m as Machine) {
    def out as bytes;
    def nframes as int init $m.fp // FRAME_SIZE;
    for (def k in 0..$nframes) {
        def f as int init $k * FRAME_SIZE;
        def sv as int init $m.frames[$f + 1];
        def args as int init $m.frames[$f + 2];
        def nloc as int init $m.frames[$f + 3];
        def base as int init $m.frames[$f + 4];
        def top as int init $m.sp;
        if ($k + 1 < $nframes) {
            $top = $m.frames[$f + FRAME_SIZE + 4];
        }
        def flags as int init $nloc;
        def var as int init $sv;
        if ($sv < 0) {
            $flags = $flags | 0x10;
            $var = 0;
        }
        if ($k == 0) {
            # the dummy frame is zero but for its stack; frotz insists
            $flags = 0;
            $args = 0;
        }
        $out = putBE($out, $m.frames[$f], 3);
        $out[] = $flags;
        $out[] = $var;
        $out[] = (1 << $args) - 1;
        $out = putBE($out, $top - $base - $nloc, 2);
        for (def i in $base..$top) {
            $out = putBE($out, $m.stack[$i], 2);
        }
    }
    return $out;
}

/**
 * Read a big-endian number.
 * @param data {bytes} the buffer
 * @param at {int} the offset
 * @param size {int} bytes, 1 to 4
 * @return {int} the number
 */
func getBE(data as bytes, at as int, size as int) {
    def v as int init 0;
    for (def i in 0..$size) {
        $v = ($v << 8) | $data[$at + $i];
    }
    return $v;
}

/**
 * Load a Quetzal file into the machine.
 * @param m {Machine} the machine
 * @param data {bytes} the file
 * @return {Machine} the machine in the saved state, its program counter in `resultPc`
 * @throws {Error} when the file is not a Quetzal save of this story
 */
func readQuetzal(m as Machine, data as bytes) {
    def n as int init len($data);
    if ($n < 12 or convert.stringFromBytes($data[0..4], "utf-8") != "FORM" or
        convert.stringFromBytes($data[8..12], "utf-8") != "IFZS") {
        fail("not a Quetzal save file");
    }
    def end as int init math.min($n, 8 + getBE($data, 4, 4));
    def at as int init 12;
    def head as bytes;
    def mem as bytes;
    def stacks as bytes;
    def haveMem as bool init false;
    def compressed as bool init true;
    while ($at + 8 <= $end) {
        def id as string init convert.stringFromBytes($data[$at..$at + 4], "utf-8");
        def size as int init getBE($data, $at + 4, 4);
        if ($at + 8 + $size > $end) {
            fail("the save file is truncated in its " + $id + " chunk");
        }
        def body as bytes init $data[$at + 8..$at + 8 + $size];
        if ($id == "IFhd") {
            $head = $body;
        } elseif ($id == "CMem" or $id == "UMem") {
            $mem = $body;
            $haveMem = true;
            $compressed = $id == "CMem";
        } elseif ($id == "Stks") {
            $stacks = $body;
        }
        $at = $at + 8 + $size + $size % 2;
    }
    if (len($head) < 13 or not $haveMem or len($stacks) == 0) {
        fail("the save file lacks an IFhd, CMem or Stks chunk");
    }
    def i as int init 0;
    for (def a in [2, 3, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x1c, 0x1d]) {
        if ($head[$i] != $m.story[$a]) {
            fail("the save file is from another story or release");
        }
        $i = $i + 1;
    }
    def keep as int init $m.mem[0x11] & 3;
    $m.mem = expandMemory($m, $mem, $compressed);
    $m.mem[0x11] = ($m.mem[0x11] & 0xfc) | $keep;
    $m = writeHeader($m);
    $m = readStacks($m, $stacks);
    $m.resultPc = getBE($head, 10, 3);
    $m.tables = [];
    $m.window = 0;
    return $m;
}

/**
 * Rebuild memory from a CMem or UMem body.
 * @param m {Machine} the machine
 * @param body {bytes} the chunk body
 * @param compressed {bool} true for CMem
 * @return {bytes} the whole memory
 * @throws {Error} when the body does not fit dynamic memory
 */
func expandMemory(m as Machine, body as bytes, compressed as bool) {
    def mem as bytes init $m.story;
    def size as int init $m.staticBase;
    if (not $compressed) {
        if (len($body) != $size) {
            fail("the save file's memory is the wrong size");
        }
        for (def i in 0..$size) {
            $mem[$i] = $body[$i];
        }
        return $mem;
    }
    def a as int init 0;
    def i as int init 0;
    def n as int init len($body);
    while ($i < $n) {
        def x as int init $body[$i];
        $i = $i + 1;
        if ($x == 0) {
            if ($i >= $n) {
                fail("the save file's memory ends inside a run");
            }
            $a = $a + $body[$i] + 1;
            $i = $i + 1;
            continue;
        }
        if ($a >= $size) {
            fail("the save file's memory is larger than the story's");
        }
        $mem[$a] = $m.story[$a] ^ $x;
        $a = $a + 1;
    }
    if ($a > $size) {
        fail("the save file's memory is larger than the story's");
    }
    return $mem;
}

/**
 * Rebuild the stack and frames from a Stks body.
 * @param m {Machine} the machine
 * @param body {bytes} the chunk body
 * @return {Machine} the machine with its stacks replaced
 * @throws {Error} when the body is malformed
 */
func readStacks(m as Machine, body as bytes) {
    def stack as list of int init [];
    def frames as list of int init [];
    def at as int init 0;
    def n as int init len($body);
    while ($at < $n) {
        if ($at + 8 > $n) {
            fail("the save file's stacks are truncated");
        }
        def pc as int init getBE($body, $at, 3);
        def flags as int init $body[$at + 3];
        def nloc as int init $flags & 15;
        def sv as int init $body[$at + 4];
        if ($flags & 0x10 != 0) {
            $sv = -1;
        }
        def args as int init 0;
        def mask as int init $body[$at + 5];
        while ($mask & 1 == 1) {
            $args = $args + 1;
            $mask = $mask >> 1;
        }
        def evals as int init getBE($body, $at + 6, 2);
        $at = $at + 8;
        if ($at + 2 * ($nloc + $evals) > $n) {
            fail("the save file's stacks are truncated");
        }
        for (def x in [$pc, $sv, $args, $nloc, len($stack)]) {
            $frames[] = $x;
        }
        for (def i in 0..$nloc + $evals) {
            $stack[] = getBE($body, $at, 2);
            $at = $at + 2;
        }
    }
    if (len($frames) == 0 or $frames[3] != 0) {
        fail("the save file's stacks do not start with the main routine");
    }
    $m.stack = $stack;
    $m.sp = len($stack);
    $m.frames = $frames;
    $m.fp = len($frames);
    $m.bp = $frames[len($frames) - 1];
    return $m;
}

/**
 * The `save_undo` opcode: remember the state, store 1.
 * @param m {Machine} the machine, its program counter on the store byte
 * @return {Machine} the machine past the instruction
 */
func saveUndo(m as Machine) {
    def snap as Snap init Snap{
        dynamic: $m.mem[..$m.staticBase],
        stack: $m.stack[..$m.sp],
        frames: $m.frames[..$m.fp],
        pc: $m.pc
    };
    if (len($m.undos) >= UNDO_DEPTH) {
        $m.undos = $m.undos[1..];
    }
    $m.undos[] = $snap;
    $m = result($m, 1);
    return $m;
}

/**
 * The `restore_undo` opcode: go back to the last `save_undo`, which then
 * stores 2. Stores 0 when there is nothing to undo.
 * @param m {Machine} the machine
 * @return {Machine} the machine in the remembered state
 */
func restoreUndo(m as Machine) {
    def n as int init len($m.undos);
    if ($n == 0) {
        $m = result($m, 0);
        return $m;
    }
    def snap as Snap init $m.undos[$n - 1];
    $m.undos = $m.undos[..$n - 1];
    $m.mem = binary.join([$snap.dynamic, $m.mem[$m.staticBase..]]);
    $m.stack = $snap.stack;
    $m.sp = len($snap.stack);
    $m.frames = $snap.frames;
    $m.fp = len($snap.frames);
    $m.bp = $m.frames[$m.fp - 1];
    $m.pc = $snap.pc;
    $m = result($m, 2);
    return $m;
}
