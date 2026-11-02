# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - white-box tests for the screen topic.
# Spliced into zmachine_test.j via include - run with:
#   jennifer test src/zmachine_test.j

func nestTooManyStreams() {
    def m as Machine init open(LANTERN5);
    for (def i in 0..17) {
        $m = selectStream($m, 3, 0x40);
    }
}

func testOutputIsTheLowerWindowSinceTheLastRun() {
    def m as Machine init started(LANTERN5);
    testing.assertTrue(strings.startsWith(output($m), "Lantern\nA test game"));
    $m = send($m, "take lamp");
    testing.assertEqual(output($m), "Taken.\n\n>");
}

func testTheVersion3StatusLine() {
    def m as Machine init play(started(LANTERN3), ["take lamp", "n"]);
    def rows as list of string init upperWindow($m);
    testing.assertEqual(len($rows), 1);
    testing.assertEqual(len($rows[0]), 80);
    testing.assertTrue(strings.startsWith($rows[0], " Garden "));
    testing.assertTrue(strings.endsWith($rows[0], "Score: 5  Moves: 2 "));
}

func testTheVersion3TimeStatusLine() {
    def m as Machine init started(LANTERN3);
    $m.mem[1] = $m.mem[1] | 2;
    $m = storeWord($m, $m.globals + 2, 13);
    $m = storeWord($m, $m.globals + 4, 5);
    testing.assertTrue(strings.endsWith(statusLine($m), "Time: 1:05 PM "));
    $m = storeWord($m, $m.globals + 2, 0);
    testing.assertTrue(strings.endsWith(statusLine($m), "Time: 12:05 AM "));
}

func testALongPlaceNameIsCut() {
    def m as Machine init setScreen(started(LANTERN3), 30, 24);
    def line as string init statusLine($m);
    testing.assertEqual(len($line), 30);
    testing.assertTrue(strings.endsWith($line, "Score: 0  Moves: 0 "));
}

func testTheGameDrawsTheUpperWindowFromVersion4() {
    def m as Machine init play(started(LANTERN5), ["n"]);
    def rows as list of string init upperWindow($m);
    testing.assertEqual(len($rows), 1);
    testing.assertTrue(strings.startsWith($rows[0], " Garden            Turns: 1 "));
    testing.assertEqual(output($m), "Garden\nAn overgrown garden. The hall is to the south.\n\n>");
}

func testSplitAndErase() {
    def m as Machine init open(LANTERN5);
    $m = split($m, 2);
    $m.window = 1;
    $m = emit($m, [65, 13, 66, 67]);
    testing.assertEqual($m.upper[0][..2], "A ");
    testing.assertEqual($m.upper[1][..3], "BC ");
    testing.assertEqual($m.col, 2);
    $m.col = 1;
    $m = eraseLine($m);
    testing.assertEqual($m.upper[1], "B" + strings.repeat(" ", 79));
    $m = split($m, 3);
    testing.assertEqual(len($m.upper), 3);
    testing.assertEqual($m.upper[0][..1], "A");
    $m = eraseWindow($m, 1);
    testing.assertEqual($m.upper[0], blankRow($m));
    $m = eraseWindow($m, -1);
    testing.assertEqual(len($m.upper), 0);
    testing.assertEqual($m.window, 0);
}

func testTextOffTheUpperWindowIsDropped() {
    def m as Machine init split(open(LANTERN5), 1);
    $m.window = 1;
    $m.col = 79;
    $m = emit($m, [65, 66, 13, 67]);
    testing.assertEqual($m.upper[0][79..], "A");
    testing.assertEqual(len($m.out), 0);
}

func testStream3CapturesOutput() {
    def m as Machine init open(LANTERN5);
    $m = selectStream($m, 3, 0x40);
    $m = emit($m, [104, 0, 105]);
    $m = emitText($m, "!");
    $m = selectStream($m, -3, 0);
    testing.assertEqual(word($m.mem, 0x40), 3);
    testing.assertEqual($m.mem[0x42], 104);
    testing.assertEqual($m.mem[0x44], 33);
    testing.assertEqual(len($m.out), 0);
    testing.assertThrows("nestTooManyStreams", ERROR_KIND);
}

func testStreamsOneAndTwo() {
    def m as Machine init open(LANTERN5);
    $m = selectStream($m, -1, 0);
    $m = emitText($m, "gone");
    testing.assertEqual(len($m.out), 0);
    $m = selectStream($m, 1, 0);
    $m = selectStream($m, 2, 0);
    testing.assertEqual($m.mem[0x11] & 1, 1);
    $m = selectStream($m, -2, 0);
    testing.assertEqual($m.mem[0x11] & 1, 0);
    $m = emitText($m, "back");
    testing.assertEqual(output($m), "back");
}

func testTheGameUsesStream3() {
    def m as Machine init play(started(LANTERN5), ["stream"]);
    testing.assertEqual(output($m), "Captured 6 characters.\n\n>");
}
