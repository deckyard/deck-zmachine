# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - white-box tests for the quetzal topic.
# Spliced into zmachine_test.j via include - run with:
#   jennifer test src/zmachine_test.j

/**
 * Play Lantern into the garden with the lamp, save there, and return the
 * save file.
 * @param path {string} the story file
 * @return {bytes} the Quetzal file
 */
func gardenSave(path as string) {
    def m as Machine init play(started($path), ["take lamp", "n", "save"]);
    return saveData($m);
}

/**
 * Lantern in the hall, waiting for the file of a restore.
 * @param path {string} the story file
 * @return {Machine} the machine
 */
func restoring(path as string) {
    return play(started($path), ["restore"]);
}

func saveDataWhileReading() {
    saveData(started(LANTERN5));
}

func resumeWhileReading() {
    resume(started(LANTERN5), true);
}

func restoreWhileReading() {
    restore(started(LANTERN5), gardenSave(LANTERN5));
}

func restoreGarbage() {
    restore(restoring(LANTERN5), convert.bytesFromString("FORM....IFZS", "utf-8"));
}

func restoreOtherStory() {
    restore(restoring(LANTERN5), gardenSave(LANTERN8));
}

func restoreTruncated() {
    def data as bytes init gardenSave(LANTERN5);
    restore(restoring(LANTERN5), $data[..len($data) - 20]);
}

func testSaveWritesAQuetzalFile() {
    def data as bytes init gardenSave(LANTERN5);
    testing.assertEqual(convert.stringFromBytes($data[0..4], "utf-8"), "FORM");
    testing.assertEqual(getBE($data, 4, 4), len($data) - 8);
    testing.assertEqual(convert.stringFromBytes($data[8..16], "utf-8"), "IFZSIFhd");
    testing.assertTrue(binary.contains($data, convert.bytesFromString("CMem", "utf-8")));
    testing.assertTrue(binary.contains($data, convert.bytesFromString("Stks", "utf-8")));
}

func testTheDummyFrameIsZero() {
    def m as Machine init play(started(LANTERN5), ["save"]);
    def stacks as bytes init writeStacks($m);
    for (def i in 0..6) {
        testing.assertEqual($stacks[$i], 0);
    }
}

func testResumeTellsTheGameHowTheSaveWent() {
    for (def path in [LANTERN3, LANTERN5]) {
        def m as Machine init play(started($path), ["save"]);
        testing.assertEqual(output(resume($m, true)), "Saved.\n\n>");
        testing.assertEqual(output(resume($m, false)), "Save failed.\n\n>");
    }
}

func testRestoreReturnsToTheSavedState() {
    for (def path in [LANTERN3, LANTERN5, LANTERN8]) {
        def m as Machine init restore(restoring($path), gardenSave($path));
        # the game goes on from its save instruction, which now succeeded
        testing.assertEqual(output($m), "Saved.\n\n>");
        $m = send($m, "look");
        testing.assertEqual(
            output($m),
            "Garden\nAn overgrown garden. The hall is to the south.\n\n>");
        $m = send($m, "i");
        testing.assertEqual(output($m), "You are carrying:\n  brass lamp\n\n>");
    }
}

func testARefusedRestoreFails() {
    def m as Machine init resume(restoring(LANTERN5), true);
    testing.assertEqual(output($m), "Restore failed.\n\n>");
}

func testABadSaveFileThrowsAndLeavesTheMachineWaiting() {
    testing.assertThrows("restoreGarbage", ERROR_KIND);
    testing.assertThrows("restoreOtherStory", ERROR_KIND);
    testing.assertThrows("restoreTruncated", ERROR_KIND);
    def m as Machine init restoring(LANTERN5);
    try {
        restore($m, binary.make(4));
    } catch (e) {
        testing.assertEqual($e.kind, ERROR_KIND);
    }
    testing.assertEqual(waiting($m), Wait.Restore);
}

func testHostMistakesAroundSaving() {
    testing.assertThrows("saveDataWhileReading", ERROR_KIND);
    testing.assertThrows("resumeWhileReading", ERROR_KIND);
    testing.assertThrows("restoreWhileReading", ERROR_KIND);
}

func testMemoryCompressionRoundTrips() {
    def m as Machine init play(started(LANTERN5), ["take lamp", "n"]);
    def packed as bytes init compressMemory($m);
    testing.assertTrue(len($packed) < $m.staticBase);
    testing.assertEqual(expandMemory($m, $packed, true), $m.mem);
    testing.assertEqual(expandMemory($m, $m.mem[..$m.staticBase], false), $m.mem);
    # a fresh machine differs from the story only in the header the interpreter writes
    def fresh as bytes init compressMemory(story(LANTERN5));
    testing.assertTrue(len($fresh) > 0 and len($fresh) < 64);
}

func testUndo() {
    def m as Machine init play(started(LANTERN5), ["take lamp", "n"]);
    $m = send($m, "undo");
    testing.assertEqual(output($m), "Undone.\n\n>");
    $m = send($m, "look");
    testing.assertTrue(strings.startsWith(output($m), "Hall\n"));
    $m = send($m, "undo");
    $m = send($m, "undo");
    $m = send($m, "i");
    testing.assertEqual(output($m), "You are empty-handed.\n\n>");
}

func testUndoKeepsALimitedHistory() {
    def lines as list of string init [];
    for (def i in 0..UNDO_DEPTH + 3) {
        $lines[] = "look";
    }
    def m as Machine init play(started(LANTERN5), $lines);
    testing.assertEqual(len($m.undos), UNDO_DEPTH);
    for (def i in 0..UNDO_DEPTH) {
        $m = send($m, "undo");
    }
    $m = send($m, "undo");
    testing.assertEqual(output($m), "Nothing to undo.\n\n>");
}
