# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - loading a story, the header and the host settings.
# Spliced into zmachine.j via include - not a standalone module.

/**
 * Load a story file. The machine is ready but not started: `run` starts it.
 * @param story {bytes} the story file (`.z3`, `.z4`, `.z5`, `.z7`, `.z8`, or a `.dat`)
 * @return {Machine} a fresh machine, 80 columns wide
 * @throws {Error} when the file is not a story of version 3, 4, 5, 7 or 8
 * @example
 *   def m as zmachine.Machine init zmachine.load(fs.readBytes("zork1.z3"));
 */
export func load(story as bytes) {
    if (len($story) < 64) {
        fail("not a story file: " + convert.toString(len($story)) +
            " bytes is shorter than the header");
    }
    def v as int init $story[0];
    if ($v != 3 and $v != 4 and $v != 5 and $v != 7 and $v != 8) {
        fail("version " + convert.toString($v) + " stories are not supported (3, 4, 5, 7 and 8 are)");
    }
    def staticBase as int init word($story, 0x0e);
    if ($staticBase < 64 or $staticBase > len($story)) {
        fail("not a story file: static memory starts at " + hex($staticBase));
    }
    def shift as int init 2;
    if ($v <= 3) {
        $shift = 1;
    } elseif ($v == 8) {
        $shift = 3;
    }
    def m as Machine init Machine{
        mem: $story,
        story: $story,
        version: $v,
        pc: 0,
        stack: [],
        sp: 0,
        bp: 0,
        frames: [],
        fp: 0,
        ops: [0, 0, 0, 0, 0, 0, 0, 0],
        nops: 0,
        globals: word($story, 0x0c),
        objects: word($story, 0x0a),
        abbrevs: word($story, 0x18),
        dict: word($story, 0x08),
        staticBase: $staticBase,
        packShift: $shift,
        routineOffset: 0,
        stringOffset: 0,
        alphabet: alphabetOf($story, $v),
        zscii: zsciiTable($story, $v),
        waitOn: WAIT_NONE,
        readText: 0,
        readParse: 0,
        readStore: -1,
        resultPc: 0,
        out: [],
        screen: true,
        transcript: false,
        tables: [],
        window: 0,
        upper: [],
        row: 0,
        col: 0,
        width: 80,
        height: 255,
        font: 1,
        rng: 0,
        rngMode: 0,
        rngCount: 1,
        rngTop: 1,
        undos: [],
        saved: binary.make(0),
        limit: DEFAULT_LIMIT
    };
    if ($v == 7) {
        $m.routineOffset = 8 * word($story, 0x28);
        $m.stringOffset = 8 * word($story, 0x2a);
    }
    $m = reset($m);
    return $m;
}

/**
 * Load a story file from disk.
 * @param path {string} the file
 * @return {Machine} a fresh machine
 * @throws {Error} when the file is missing or is not a supported story
 */
export func open(path as string) {
    if (not fs.isFile($path)) {
        fail("no story file at " + $path);
    }
    return load(fs.readBytes($path));
}

/**
 * The story's identity, for naming save files or telling releases apart.
 * @param m {Machine} the machine
 * @return {Info} version, release, serial and checksum
 */
export func info(m as Machine) {
    def serial as list of string init [];
    for (def i in 0..6) {
        def c as int init $m.story[0x12 + $i];
        if ($c >= 32 and $c < 127) {
            $serial[] = convert.fromCodepoint($c);
        }
    }
    return Info{
        version: $m.version,
        release: word($m.story, 0x02),
        serial: strings.join($serial, ""),
        checksum: word($m.story, 0x1c)
    };
}

/**
 * Set the screen size the game sees. Games read it when they start, so set
 * it before the first `run`.
 * @param m {Machine} the machine
 * @param columns {int} characters per line, 20 to 255
 * @param rows {int} lines, 1 to 255; 255 means the screen never fills
 * @return {Machine} the machine with the new size
 * @throws {Error} when a size is out of range
 */
export func setScreen(m as Machine, columns as int, rows as int) {
    if ($columns < 20 or $columns > 255 or $rows < 1 or $rows > 255) {
        fail("screen size " + convert.toString($columns) + "x" + convert.toString($rows) +
            " is out of range");
    }
    $m.width = $columns;
    $m.height = $rows;
    def n as int init len($m.upper);
    $m.upper = [];
    $m = split($m, $n);
    $m = writeHeader($m);
    return $m;
}

/**
 * Make the game's random numbers repeatable: the same seed and the same input
 * give the same game. A game that seeds itself overrides it.
 * @param m {Machine} the machine
 * @param n {int} the seed, 1 or more
 * @return {Machine} the machine in seeded mode
 * @throws {Error} when `n` is less than 1
 */
export func seed(m as Machine, n as int) {
    if ($n < 1) {
        fail("the seed must be 1 or more");
    }
    $m.rngMode = 1;
    $m.rng = $n % 2147483648;
    return $m;
}

/**
 * Set how many instructions one `run`, `send`, `resume` or `restore` may
 * execute before it throws. Guards a host against a game stuck in a loop.
 * @param m {Machine} the machine
 * @param steps {int} the instruction budget, 1 or more; the default is 50 million
 * @return {Machine} the machine with the new limit
 * @throws {Error} when `steps` is less than 1
 */
export func setLimit(m as Machine, steps as int) {
    if ($steps < 1) {
        fail("the instruction limit must be 1 or more");
    }
    $m.limit = $steps;
    return $m;
}

/**
 * Write the header fields the interpreter owns: capabilities, screen size,
 * interpreter number and Standard revision.
 * @param m {Machine} the machine
 * @return {Machine} the machine with its header written
 */
func writeHeader(m as Machine) {
    def flags1 as int init $m.mem[1];
    if ($m.version <= 3) {
        # status line available, screen splitting available, fixed-pitch default
        $flags1 = ($flags1 & 0x8f) | 0x20;
    } else {
        # bold, italic and fixed-space; no colours, pictures, sound or timed input
        $flags1 = ($flags1 & 0x40) | 0x1c;
    }
    $m.mem[1] = $flags1;
    def flags2 as int init word($m.mem, 0x10);
    # keep transcripting, fixed pitch, redraw and undo; refuse pictures, mouse, colours, sound, menus
    $flags2 = $flags2 & 0xfe17;
    $m.mem[0x10] = $flags2 >> 8;
    $m.mem[0x11] = $flags2 & 0xff;
    $m.mem[0x1e] = INTERPRETER_NUMBER;
    $m.mem[0x1f] = 74;
    $m.mem[0x20] = $m.height;
    $m.mem[0x21] = $m.width;
    if ($m.version >= 5) {
        $m.mem[0x22] = 0;
        $m.mem[0x23] = $m.width;
        $m.mem[0x24] = 0;
        $m.mem[0x25] = $m.height;
        $m.mem[0x26] = 1;
        $m.mem[0x27] = 1;
        # default colours: "default" on "default"
        $m.mem[0x2c] = 1;
        $m.mem[0x2d] = 1;
    }
    $m.mem[0x32] = 1;
    $m.mem[0x33] = 1;
    return $m;
}

/**
 * Put the machine in its starting state: memory as loaded, an empty stack,
 * the program counter at the start. Keeps the transcript and fixed-pitch bits.
 * @param m {Machine} the machine
 * @return {Machine} the machine ready to run from the start
 */
func reset(m as Machine) {
    def keep as int init $m.mem[0x11] & 3;
    $m.mem = $m.story;
    $m.mem[0x11] = ($m.mem[0x11] & 0xfc) | $keep;
    $m = writeHeader($m);
    $m.stack = [];
    $m.sp = 0;
    $m.bp = 0;
    $m.frames = [0, -1, 0, 0, 0];
    $m.fp = FRAME_SIZE;
    $m.pc = word($m.mem, 0x06);
    $m.tables = [];
    $m.window = 0;
    $m.upper = [];
    $m.row = 0;
    $m.col = 0;
    return $m;
}

/**
 * The `restart` opcode.
 * @param m {Machine} the machine
 * @return {Machine} the machine back at the start of the story
 */
func restart(m as Machine) {
    $m = reset($m);
    return $m;
}
