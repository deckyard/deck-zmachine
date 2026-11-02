# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - the machine state and the primitives every other topic builds on.
# Spliced into zmachine.j via include - not a standalone module.

/** The `kind` of every `Error` this deck throws. */
export def const ERROR_KIND as string init "zmachine";

/** The interpreter number written to the header (6, IBM PC). */
def const INTERPRETER_NUMBER as int init 6;

/** Instructions one `run` may execute before it gives up on a looping game. */
def const DEFAULT_LIMIT as int init 50000000;

/** Words of stack the machine may use: locals and evaluation stack together. */
def const STACK_LIMIT as int init 65535;

/** Ints per call frame in `Machine.frames`. */
def const FRAME_SIZE as int init 5;

/** `save_undo` states kept; the oldest is dropped beyond this. */
def const UNDO_DEPTH as int init 8;

# What the machine is waiting for. The public view is the `Wait` enum; inside,
# an int is cheaper to test after every instruction.
def const WAIT_NONE as int init 0;
def const WAIT_LINE as int init 1;
def const WAIT_KEY as int init 2;
def const WAIT_SAVE as int init 3;
def const WAIT_RESTORE as int init 4;
def const WAIT_QUIT as int init 5;

/**
 * What a machine needs before it can go on.
 *
 * `Line` and `Key` are answered with `send`, `Save` with `saveData` and then
 * `resume`, `Restore` with `restore` (or `resume` to refuse). `Quit` is final.
 */
export def enum Wait {
    Line,
    Key,
    Save,
    Restore,
    Quit
};

/**
 * The identity of a story file, from its header.
 * @field version {int} Z-machine version, 3, 4, 5, 7 or 8
 * @field release {int} release number
 * @field serial {string} serial code, six characters, usually the compile date
 * @field checksum {int} header checksum
 */
export def struct Info {
    version as int,
    release as int,
    serial as string,
    checksum as int
};

/**
 * A `save_undo` state: what `restore_undo` puts back.
 * @field dynamic {bytes} dynamic memory
 * @field stack {list of int} the used part of the stack
 * @field frames {list of int} the used part of the frame list
 * @field pc {int} address of the store byte of the `save_undo`
 */
export def struct Snap {
    dynamic as bytes,
    stack as list of int,
    frames as list of int,
    pc as int
};

/**
 * A running story. Treat it as opaque: build it with `load` or `open`, drive it
 * with `run`, `send`, `resume` and `restore`, read it with the other exports.
 * Every function returns a new `Machine`; keep the one you get back.
 * @field mem {bytes} story memory; the dynamic part changes as the game runs
 * @field story {bytes} the story file as loaded, for `restart`, `verify` and saves
 * @field version {int} Z-machine version
 * @field pc {int} program counter
 * @field stack {list of int} locals and evaluation stack of every frame
 * @field sp {int} next free stack slot
 * @field bp {int} first local of the current frame
 * @field frames {list of int} five ints per frame: return pc, store variable (-1 to discard), argument count, local count, base
 * @field fp {int} ints of `frames` in use
 * @field ops {list of int} operands of the current instruction
 * @field nops {int} how many of `ops` the current instruction has
 * @field globals {int} address of the global variables
 * @field objects {int} address of the object table
 * @field abbrevs {int} address of the abbreviations table
 * @field dict {int} address of the standard dictionary
 * @field staticBase {int} first byte of static memory
 * @field packShift {int} packed address multiplier as a shift
 * @field routineOffset {int} byte offset added to packed routine addresses (version 7)
 * @field stringOffset {int} byte offset added to packed string addresses (version 7)
 * @field alphabet {list of int} the 78 ZSCII codes of alphabets A0, A1 and A2
 * @field zscii {list of string} ZSCII code to text, 0 to 1023
 * @field waitOn {int} what the machine waits for, one of the `WAIT_` constants
 * @field readText {int} text buffer of the pending read
 * @field readParse {int} parse buffer of the pending read
 * @field readStore {int} store variable of the pending read, -1 for none
 * @field resultPc {int} address of the store or branch byte of a pending save or restore
 * @field out {list of string} lower window text since the last run began
 * @field screen {bool} output stream 1 is selected
 * @field transcript {bool} output stream 2 is selected
 * @field tables {list of int} output stream 3 tables, innermost last
 * @field window {int} the selected window, 0 lower, 1 upper
 * @field upper {list of string} upper window rows, `width` characters each
 * @field row {int} upper window cursor row, from 0
 * @field col {int} upper window cursor column, from 0
 * @field width {int} screen width in characters
 * @field height {int} screen height in lines, 255 for endless
 * @field font {int} the current font
 * @field rng {int} random generator state
 * @field rngMode {int} 0 random, 1 seeded, 2 counting
 * @field rngCount {int} the next value in counting mode
 * @field rngTop {int} the cycle length in counting mode
 * @field undos {list of Snap} `save_undo` states, newest last
 * @field saved {bytes} the Quetzal file of a pending save
 * @field limit {int} instructions one run may execute
 */
export def struct Machine {
    mem as bytes,
    story as bytes,
    version as int,
    pc as int,
    stack as list of int,
    sp as int,
    bp as int,
    frames as list of int,
    fp as int,
    ops as list of int,
    nops as int,
    globals as int,
    objects as int,
    abbrevs as int,
    dict as int,
    staticBase as int,
    packShift as int,
    routineOffset as int,
    stringOffset as int,
    alphabet as list of int,
    zscii as list of string,
    waitOn as int,
    readText as int,
    readParse as int,
    readStore as int,
    resultPc as int,
    out as list of string,
    screen as bool,
    transcript as bool,
    tables as list of int,
    window as int,
    upper as list of string,
    row as int,
    col as int,
    width as int,
    height as int,
    font as int,
    rng as int,
    rngMode as int,
    rngCount as int,
    rngTop as int,
    undos as list of Snap,
    saved as bytes,
    limit as int
};

/**
 * Raise a deck error.
 * @param message {string} what went wrong
 * @throws {Error} always, with `kind` `"zmachine"`
 */
func fail(message as string) {
    throw Error{kind: ERROR_KIND, message: "zmachine: " + $message};
}

/**
 * Raise a deck error that names the instruction it happened at.
 * @param m {Machine} the machine
 * @param message {string} what went wrong
 * @throws {Error} always, with `kind` `"zmachine"`
 */
func failAt(m as Machine, message as string) {
    fail($message + " (pc " + hex($m.pc) + ")");
}

/**
 * Format an address for a message.
 * @param n {int} the value
 * @return {string} `$` and lower case hex digits
 */
func hex(n as int) {
    return "$" + convert.toString($n, 16);
}

/**
 * Read a big-endian word.
 * @param mem {bytes} memory
 * @param a {int} byte address
 * @return {int} 0 to 65535
 */
func word(mem as bytes, a as int) {
    return ($mem[$a] << 8) | $mem[$a + 1];
}

/**
 * Interpret a word as a signed number.
 * @param v {int} 0 to 65535
 * @return {int} -32768 to 32767
 */
func signed(v as int) {
    if ($v >= 32768) {
        return $v - 65536;
    }
    return $v;
}

/**
 * Write a big-endian word into dynamic memory.
 * @param m {Machine} the machine
 * @param a {int} byte address
 * @param v {int} the value; reduced to 16 bits
 * @return {Machine} the machine with the word written
 * @throws {Error} when the address is outside dynamic memory
 */
func storeWord(m as Machine, a as int, v as int) {
    if ($a < 0 or $a + 1 >= $m.staticBase) {
        failAt($m, "write to " + hex($a) + " outside dynamic memory");
    }
    $m.mem[$a] = ($v >> 8) & 0xff;
    $m.mem[$a + 1] = $v & 0xff;
    return $m;
}

/**
 * Write a byte into dynamic memory.
 * @param m {Machine} the machine
 * @param a {int} byte address
 * @param v {int} the value; reduced to 8 bits
 * @return {Machine} the machine with the byte written
 * @throws {Error} when the address is outside dynamic memory
 */
func storeByte(m as Machine, a as int, v as int) {
    if ($a < 0 or $a >= $m.staticBase) {
        failAt($m, "write to " + hex($a) + " outside dynamic memory");
    }
    $m.mem[$a] = $v & 0xff;
    return $m;
}

/**
 * Push a word onto the evaluation stack.
 * @param m {Machine} the machine
 * @param v {int} the value; reduced to 16 bits
 * @return {Machine} the machine with the value pushed
 * @throws {Error} when the stack is full
 */
func push(m as Machine, v as int) {
    if ($m.sp >= len($m.stack)) {
        if ($m.sp >= STACK_LIMIT) {
            failAt($m, "stack overflow");
        }
        $m.stack[] = $v & 0xffff;
    } else {
        $m.stack[$m.sp] = $v & 0xffff;
    }
    $m.sp = $m.sp + 1;
    return $m;
}

/**
 * The lowest stack slot the current frame may pop: below it are its locals.
 * @param m {Machine} the machine
 * @return {int} a stack index
 */
func stackFloor(m as Machine) {
    return $m.bp + $m.frames[$m.fp - 2];
}

/**
 * Read a variable without popping: variable 0 is the top of the stack, read
 * in place, as the indirect-variable opcodes require.
 * @param m {Machine} the machine
 * @param v {int} the variable, 0 to 255
 * @return {int} its value
 * @throws {Error} on an empty stack or a missing local
 */
func peekVar(m as Machine, v as int) {
    if ($v == 0) {
        if ($m.sp <= stackFloor($m)) {
            failAt($m, "stack underflow");
        }
        return $m.stack[$m.sp - 1];
    }
    if ($v < 16) {
        if ($v > $m.frames[$m.fp - 2]) {
            failAt($m, "local " + convert.toString($v) + " does not exist");
        }
        return $m.stack[$m.bp + $v - 1];
    }
    return word($m.mem, $m.globals + 2 * ($v - 16));
}

/**
 * Write a variable in place: variable 0 replaces the top of the stack.
 * @param m {Machine} the machine
 * @param v {int} the variable, 0 to 255
 * @param x {int} the value; reduced to 16 bits
 * @return {Machine} the machine with the variable written
 * @throws {Error} on an empty stack or a missing local
 */
func pokeVar(m as Machine, v as int, x as int) {
    if ($v == 0) {
        if ($m.sp <= stackFloor($m)) {
            failAt($m, "stack underflow");
        }
        $m.stack[$m.sp - 1] = $x & 0xffff;
        return $m;
    }
    if ($v < 16) {
        if ($v > $m.frames[$m.fp - 2]) {
            failAt($m, "local " + convert.toString($v) + " does not exist");
        }
        $m.stack[$m.bp + $v - 1] = $x & 0xffff;
        return $m;
    }
    def a as int init $m.globals + 2 * ($v - 16);
    $m.mem[$a] = ($x >> 8) & 0xff;
    $m.mem[$a + 1] = $x & 0xff;
    return $m;
}

/**
 * Store an instruction's result: variable 0 pushes.
 * @param m {Machine} the machine
 * @param v {int} the store variable, 0 to 255
 * @param x {int} the value; reduced to 16 bits
 * @return {Machine} the machine with the result stored
 */
func store(m as Machine, v as int, x as int) {
    if ($v == 0) {
        $m = push($m, $x);
        return $m;
    }
    $m = pokeVar($m, $v, $x);
    return $m;
}

/**
 * Pop the evaluation stack.
 * @param m {Machine} the machine
 * @return {Machine} the machine with the value removed; read it first with `peekVar(m, 0)`
 * @throws {Error} on an empty stack
 */
func drop(m as Machine) {
    if ($m.sp <= stackFloor($m)) {
        failAt($m, "stack underflow");
    }
    $m.sp = $m.sp - 1;
    return $m;
}

/**
 * Unpack a packed routine address.
 * @param m {Machine} the machine
 * @param p {int} the packed address
 * @return {int} the byte address
 */
func routineAddress(m as Machine, p as int) {
    return ($p << $m.packShift) + $m.routineOffset;
}

/**
 * Unpack a packed string address.
 * @param m {Machine} the machine
 * @param p {int} the packed address
 * @return {int} the byte address
 */
func stringAddress(m as Machine, p as int) {
    return ($p << $m.packShift) + $m.stringOffset;
}
