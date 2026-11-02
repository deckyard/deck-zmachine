# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - white-box tests for the story topic.
# Spliced into zmachine_test.j via include - run with:
#   jennifer test src/zmachine_test.j

func loadTooShort() {
    load(binary.make(63));
}

func loadVersion6() {
    def b as bytes init fs.readBytes(LANTERN5);
    $b[0] = 6;
    load($b);
}

func loadBadStaticBase() {
    def b as bytes init fs.readBytes(LANTERN5);
    $b[0x0e] = 0xff;
    load($b);
}

func openMissing() {
    open("testdata/no-such-story.z5");
}

func screenTooNarrow() {
    setScreen(open(LANTERN5), 19, 24);
}

func screenTooTall() {
    setScreen(open(LANTERN5), 80, 256);
}

func seedZero() {
    seed(open(LANTERN5), 0);
}

func limitZero() {
    setLimit(open(LANTERN5), 0);
}

func runOutOfInstructions() {
    run(setLimit(open(LANTERN5), 100));
}

func testLoadRejectsWhatItCannotPlay() {
    testing.assertThrows("loadTooShort", ERROR_KIND);
    testing.assertThrows("loadVersion6", ERROR_KIND);
    testing.assertThrows("loadBadStaticBase", ERROR_KIND);
    testing.assertThrows("openMissing", ERROR_KIND);
}

func testLoadReadsTheHeader() {
    def m as Machine init open(LANTERN5);
    testing.assertEqual($m.version, 5);
    testing.assertEqual($m.pc, word($m.story, 0x06));
    testing.assertEqual($m.staticBase, word($m.story, 0x0e));
    testing.assertEqual($m.packShift, 2);
    testing.assertEqual($m.fp, FRAME_SIZE);
    testing.assertEqual(open(LANTERN8).packShift, 3);
    def m2 as Machine init load(fs.readBytes(LANTERN3));
    testing.assertEqual($m2.packShift, 1);
}

func testInfo() {
    def i as Info init info(open(LANTERN3));
    testing.assertEqual($i.version, 3);
    testing.assertEqual($i.release, 1);
    testing.assertEqual(len($i.serial), 6);
    testing.assertEqual($i.checksum, word(fs.readBytes(LANTERN3), 0x1c));
}

func testTheInterpreterHeader() {
    def m as Machine init open(LANTERN5);
    testing.assertEqual($m.mem[0x1e], INTERPRETER_NUMBER);
    testing.assertEqual($m.mem[0x20], 255);
    testing.assertEqual($m.mem[0x21], 80);
    testing.assertEqual($m.mem[0x32], 1);
    testing.assertEqual($m.mem[0x33], 1);
    testing.assertEqual($m.mem[1] & 0x1c, 0x1c);
    def m3 as Machine init open(LANTERN3);
    testing.assertEqual($m3.mem[1] & 0x30, 0x20);
}

func testSetScreen() {
    def m as Machine init setScreen(open(LANTERN5), 40, 20);
    testing.assertEqual($m.mem[0x21], 40);
    testing.assertEqual($m.mem[0x20], 20);
    testing.assertEqual($m.mem[0x23], 40);
    $m = setScreen(play(started(LANTERN5), ["look"]), 60, 24);
    testing.assertEqual(len($m.upper[0]), 60);
    testing.assertThrows("screenTooNarrow", ERROR_KIND);
    testing.assertThrows("screenTooTall", ERROR_KIND);
}

/**
 * Roll `random` twenty times, each result pushed on the stack.
 * @param m {Machine} the machine
 * @param range {int} the operand
 * @return {list of int} the rolls
 */
func rolls(m as Machine, range as int) {
    $m.mem[0x40] = 0;
    def out as list of int init [];
    for (def i in 0..20) {
        $m.pc = 0x40;
        $m = random($m, $range);
        $out[] = peekVar($m, 0);
    }
    return $out;
}

func testSeedMakesRandomNumbersRepeatable() {
    def a as list of int init rolls(seed(open(LANTERN5), 99), 6);
    testing.assertEqual(rolls(seed(open(LANTERN5), 99), 6), $a);
    testing.assertTrue(rolls(seed(open(LANTERN5), 98), 6) != $a);
    for (def x in $a) {
        testing.assertTrue($x >= 1 and $x <= 6);
    }
    def unseeded as list of int init rolls(open(LANTERN5), 6);
    for (def x in $unseeded) {
        testing.assertTrue($x >= 1 and $x <= 6);
    }
    testing.assertThrows("seedZero", ERROR_KIND);
}

func testTheGameCanSeedItself() {
    def m as Machine init open(LANTERN5);
    $m.mem[0x40] = 0;
    $m.pc = 0x40;
    $m = random($m, -3);
    testing.assertEqual($m.rngMode, 2);
    testing.assertEqual(
        rolls($m, 10),
        [1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2]);
    $m.pc = 0x40;
    $m = random($m, -5000);
    testing.assertEqual($m.rngMode, 1);
    testing.assertEqual(rolls($m, 6), rolls(seed(open(LANTERN5), 5000), 6));
    $m.pc = 0x40;
    $m = random($m, 0);
    testing.assertEqual($m.rngMode, 1);
}

func testTheInstructionLimit() {
    testing.assertThrows("runOutOfInstructions", ERROR_KIND);
    testing.assertThrows("limitZero", ERROR_KIND);
    testing.assertEqual(setLimit(open(LANTERN5), 7).limit, 7);
}

func testRestartKeepsTheTranscriptBit() {
    def m as Machine init play(started(LANTERN5), ["take lamp"]);
    $m.mem[0x11] = $m.mem[0x11] | 1;
    $m = restart($m);
    testing.assertEqual($m.mem[0x11] & 1, 1);
    testing.assertEqual(link($m, LAMP, 0), HALL);
    testing.assertEqual($m.pc, word($m.story, 0x06));
    testing.assertEqual($m.sp, 0);
}
