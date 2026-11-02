# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - white-box tests for the exec topic. The conformance suites in
# testdata/ cover the opcodes; the tests here cover the host side.
# Spliced into zmachine_test.j via include - run with:
#   jennifer test src/zmachine_test.j

func runTwice() {
    run(started(LANTERN5));
}

func runAfterQuit() {
    run(play(started(LANTERN5), ["quit"]));
}

func sendBeforeRun() {
    send(story(LANTERN5), "look");
}

func waitingBeforeRun() {
    waiting(story(LANTERN5));
}

func returnFromMain() {
    ret(story(LANTERN5), 0);
}

func divideByZero() {
    divide(story(LANTERN5), 1, 0, false);
}

func illegalOpcode() {
    def m as Machine init story(LANTERN5);
    # 0OP opcode 14 is the EXT prefix 0xbe; 0xbf's short-form twin is 0xb0+14
    $m.mem[$m.pc] = 0xbe;
    $m.mem[$m.pc + 1] = 0x20;
    $m.mem[$m.pc + 2] = 0xff;
    step($m);
}

func testCzechPassesInEveryVersion() {
    if (not haveTestdata()) {
        return;
    }
    for (def v in ["3", "4", "5", "7", "8"]) {
        def m as Machine init run(open("testdata/czech/czech.z" + $v));
        def out as string init output($m);
        testing.assertTrue(strings.contains($out, "Failed: 0,"));
        testing.assertTrue(strings.contains($out, "Didn't crash: hooray!"));
        testing.assertEqual(waiting($m), Wait.Quit);
    }
}

func testPraxixPasses() {
    if (not haveTestdata()) {
        return;
    }
    def m as Machine init send(run(open("testdata/praxix/praxix.z5")), "all");
    testing.assertTrue(strings.contains(output($m), "All tests passed."));
}

func testWaitingNamesWhatTheGameNeeds() {
    def m as Machine init started(LANTERN5);
    testing.assertEqual(waiting($m), Wait.Line);
    $m = send($m, "key");
    testing.assertEqual(waiting($m), Wait.Key);
    $m = send($m, "q");
    testing.assertEqual(output($m), "you pressed 113.\n\n>");
    $m = send($m, "save");
    testing.assertEqual(waiting($m), Wait.Save);
    $m = resume($m, true);
    $m = send($m, "restore");
    testing.assertEqual(waiting($m), Wait.Restore);
    $m = resume($m, false);
    $m = send($m, "quit");
    testing.assertEqual(waiting($m), Wait.Quit);
    testing.assertEqual(output($m), "Bye.\n");
}

func testAnEmptyKeyIsReturn() {
    def m as Machine init send(play(started(LANTERN5), ["key"]), "");
    testing.assertEqual(output($m), "you pressed 13.\n\n>");
}

func testHostMistakesThrow() {
    testing.assertThrows("runTwice", ERROR_KIND);
    testing.assertThrows("runAfterQuit", ERROR_KIND);
    testing.assertThrows("sendBeforeRun", ERROR_KIND);
    testing.assertThrows("waitingBeforeRun", ERROR_KIND);
}

func testStoryErrorsThrow() {
    testing.assertThrows("returnFromMain", ERROR_KIND);
    testing.assertThrows("divideByZero", ERROR_KIND);
    testing.assertThrows("illegalOpcode", ERROR_KIND);
}

func testDivisionRoundsTowardZero() {
    def m as Machine init story(LANTERN5);
    testing.assertEqual(divide($m, -7, 2, false), -3);
    testing.assertEqual(divide($m, -7, 2, true), -1);
    testing.assertEqual(divide($m, 7, -2, false), -3);
    testing.assertEqual(divide($m, 7, -2, true), 1);
    testing.assertEqual(divide($m, -7, -2, false), 3);
}

func testAnOldMachineIsAnUndo() {
    def before as Machine init started(LANTERN3);
    def after as Machine init send($before, "take lamp");
    testing.assertEqual(link($after, LAMP, 0), PLAYER);
    testing.assertEqual(link($before, LAMP, 0), HALL);
    $after = send($before, "n");
    testing.assertEqual(
        output($after),
        "Garden\nAn overgrown garden. The hall is to the south.\n\n>");
}

func testTheGameRunsTheSameInEveryVersion() {
    def lines as list of string init [
        "take lamp",
        "n",
        "drop lamp",
        "i",
        "random",
        "euro",
        "stream"
    ];
    def m3 as Machine init play(started(LANTERN3), $lines);
    def m5 as Machine init play(started(LANTERN5), $lines);
    def m8 as Machine init play(started(LANTERN8), $lines);
    testing.assertEqual(output($m5), output($m8));
    testing.assertEqual(output($m3), "Captured 6 characters.\n\n>");
    $m3 = send($m3, "euro");
    testing.assertEqual(output($m3), "Accents: äÉ\n\n>");
    $m5 = send($m5, "euro");
    testing.assertEqual(output($m5), "Accents: äÉ, euro: €\n\n>");
    $m5 = send($m5, "random");
    testing.assertEqual(output($m5), "Dice: 1 2 3 4 5\n\n>");
}

func testUnknownWords() {
    def m as Machine init play(started(LANTERN5), ["xyzzy"]);
    testing.assertEqual(output($m), "I don't know that word.\n\n>");
    $m = send($m, "TAKE LAMP");
    testing.assertEqual(output($m), "Taken.\n\n>");
}
