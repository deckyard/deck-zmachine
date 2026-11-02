# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - white-box tests for the core topic, and the helpers every other
# overlay uses. Spliced into zmachine_test.j via include - run with:
#   jennifer test src/zmachine_test.j

include "fixtures/lantern_test.j";

# Lantern, the deck's own test game, comes from fixtures/lantern_test.j, so the
# overlays run where jvc runs them: from a copy of src/ with no testdata/. The
# conformance suites are too big for that and run only beside testdata/.
def const LANTERN3 as string init "lantern.z3";
def const LANTERN5 as string init "lantern.z5";
def const LANTERN8 as string init "lantern.z8";

# Lantern's objects: Inform numbers its four class objects first.
def const HALL as int init 5;
def const GARDEN as int init 6;
def const PLAYER as int init 7;
def const LAMP as int init 8;

/**
 * True beside testdata/, false in a copy of src/ alone.
 * @return {bool} whether the conformance suites can run
 */
func haveTestdata() {
    return fs.isDir("testdata/czech");
}

/**
 * One of Lantern's builds, from the embedded copy.
 * @param name {string} `LANTERN3`, `LANTERN5` or `LANTERN8`
 * @return {bytes} the story file
 */
func storyBytes(name as string) {
    def lines as list of string init LANTERN_Z5_BASE64;
    if ($name == LANTERN3) {
        $lines = LANTERN_Z3_BASE64;
    } elseif ($name == LANTERN8) {
        $lines = LANTERN_Z8_BASE64;
    }
    return encoding.fromText(strings.join($lines, ""), "base64");
}

/**
 * Load one of Lantern's builds.
 * @param name {string} `LANTERN3`, `LANTERN5` or `LANTERN8`
 * @return {Machine} a fresh machine
 */
func story(name as string) {
    return load(storyBytes($name));
}

/**
 * Start one of Lantern's builds with repeatable random numbers.
 * @param name {string} `LANTERN3`, `LANTERN5` or `LANTERN8`
 * @return {Machine} the machine at its first wait
 */
func started(name as string) {
    return run(seed(story($name), 1));
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
    def m as Machine init story(LANTERN3);
    storeWord($m, $m.staticBase, 1);
}

func popEmptyStack() {
    def m as Machine init story(LANTERN3);
    drop($m);
}

func readMissingLocal() {
    def m as Machine init story(LANTERN3);
    peekVar($m, 3);
}

func testSignedWords() {
    testing.assertEqual(signed(0), 0);
    testing.assertEqual(signed(32767), 32767);
    testing.assertEqual(signed(32768), -32768);
    testing.assertEqual(signed(65535), -1);
}

func testWordsAreBigEndian() {
    def m as Machine init story(LANTERN3);
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
    def m as Machine init story(LANTERN3);
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
    testing.assertEqual(routineAddress(story(LANTERN3), 0x100), 0x200);
    testing.assertEqual(routineAddress(story(LANTERN5), 0x100), 0x400);
    testing.assertEqual(stringAddress(story(LANTERN8), 0x100), 0x800);
    if (not haveTestdata()) {
        return;
    }
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

func testTheEmbeddedLanternIsTheOneInTestdata() {
    if (not haveTestdata()) {
        return;
    }
    for (def name in [LANTERN3, LANTERN5, LANTERN8]) {
        testing.assertEqual(storyBytes($name), fs.readBytes("testdata/" + $name));
        testing.assertEqual(open("testdata/" + $name).story, storyBytes($name));
    }
}
