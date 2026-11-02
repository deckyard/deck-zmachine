# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - white-box tests for the core topic, and the helpers every other
# overlay uses. Spliced into zmachine_test.j via include - run with:
#   jennifer test src/zmachine_test.j

def const LANTERN3 as string init "testdata/lantern.z3";
def const LANTERN5 as string init "testdata/lantern.z5";
def const LANTERN8 as string init "testdata/lantern.z8";

# Lantern's objects: Inform numbers its four class objects first.
def const HALL as int init 5;
def const GARDEN as int init 6;
def const PLAYER as int init 7;
def const LAMP as int init 8;

/**
 * Start a story with repeatable random numbers.
 * @param path {string} the story file
 * @return {Machine} the machine at its first wait
 */
func started(path as string) {
    return run(seed(open($path), 1));
}

/**
 * Play a list of commands.
 * @param m {Machine} the machine, waiting for a line
 * @param lines {list of string} the commands
 * @return {Machine} the machine after the last one
 */
func play(m as Machine, lines as list of string) {
    for (def line in $lines) {
        $m = send($m, $line);
    }
    return $m;
}

func writeToStaticMemory() {
    def m as Machine init open(LANTERN3);
    storeWord($m, $m.staticBase, 1);
}

func popEmptyStack() {
    def m as Machine init open(LANTERN3);
    drop($m);
}

func readMissingLocal() {
    def m as Machine init open(LANTERN3);
    peekVar($m, 3);
}

func testSignedWords() {
    testing.assertEqual(signed(0), 0);
    testing.assertEqual(signed(32767), 32767);
    testing.assertEqual(signed(32768), -32768);
    testing.assertEqual(signed(65535), -1);
}

func testWordsAreBigEndian() {
    def m as Machine init open(LANTERN3);
    $m = storeWord($m, 0x40, 0x1234);
    testing.assertEqual($m.mem[0x40], 0x12);
    testing.assertEqual($m.mem[0x41], 0x34);
    testing.assertEqual(word($m.mem, 0x40), 0x1234);
    $m = storeByte($m, 0x40, 0x1ff);
    testing.assertEqual($m.mem[0x40], 0xff);
}

func testWritesStayInDynamicMemory() {
    testing.assertThrows("writeToStaticMemory", ERROR_KIND);
}

func testStackAndVariables() {
    def m as Machine init open(LANTERN3);
    $m = push($m, 7);
    $m = push($m, 70000);
    testing.assertEqual(peekVar($m, 0), 70000 & 0xffff);
    $m = pokeVar($m, 0, 9);
    testing.assertEqual(peekVar($m, 0), 9);
    $m = drop($m);
    testing.assertEqual(peekVar($m, 0), 7);
    $m = store($m, 0, 8);
    testing.assertEqual($m.sp, 2);
    $m = store($m, 16, 0xbeef);
    testing.assertEqual(peekVar($m, 16), 0xbeef);
    testing.assertEqual(word($m.mem, $m.globals), 0xbeef);
}

func testStackErrorsAreDeckErrors() {
    testing.assertThrows("popEmptyStack", ERROR_KIND);
    testing.assertThrows("readMissingLocal", ERROR_KIND);
}

func testPackedAddressesFollowTheVersion() {
    testing.assertEqual(routineAddress(open(LANTERN3), 0x100), 0x200);
    testing.assertEqual(routineAddress(open(LANTERN5), 0x100), 0x400);
    testing.assertEqual(stringAddress(open(LANTERN8), 0x100), 0x800);
    def m7 as Machine init open("testdata/czech/czech.z7");
    testing.assertEqual(routineAddress($m7, 0x100), 0x400 + 8 * word($m7.story, 0x28));
    testing.assertEqual(stringAddress($m7, 0x100), 0x400 + 8 * word($m7.story, 0x2a));
}

func testFailNamesTheDeck() {
    try {
        fail("boom");
    } catch (e) {
        testing.assertEqual($e.kind, "zmachine");
        testing.assertEqual($e.message, "zmachine: boom");
    }
    testing.assertEqual(hex(255), "$ff");
}
