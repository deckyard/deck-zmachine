# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - white-box tests for the text topic.
# Spliced into zmachine_test.j via include - run with:
#   jennifer test src/zmachine_test.j

/**
 * ZSCII codes of an ASCII string.
 * @param s {string} the text
 * @return {list of int} its codes
 */
func codesOf(s as string) {
    def out as list of int init [];
    for (def ch in strings.chars($s)) {
        $out[] = convert.toCodepoint($ch);
    }
    return $out;
}

func testTheDefaultAlphabet() {
    def a as list of int init defaultAlphabet();
    testing.assertEqual(len($a), 78);
    testing.assertEqual($a[0], 97);
    testing.assertEqual($a[26], 65);
    testing.assertEqual($a[53], 13);
    testing.assertEqual($a[54], 48);
    testing.assertEqual($a[77], 41);
}

func testTheExtraCharacters() {
    def m as Machine init story(LANTERN5);
    testing.assertEqual(len(strings.chars(EXTRA_CHARS)), 69);
    testing.assertEqual($m.zscii[155], "ä");
    testing.assertEqual($m.zscii[176], "É");
    testing.assertEqual($m.zscii[223], "¿");
    testing.assertEqual($m.zscii[13], "\n");
    testing.assertEqual($m.zscii[1], "");
    testing.assertEqual(toText($m, [72, 105, 13, 155, 1]), "Hi\nä?");
}

func testInputCharactersToZscii() {
    def m as Machine init story(LANTERN5);
    testing.assertEqual(charToZscii($m, "a"), 97);
    testing.assertEqual(charToZscii($m, "\n"), 13);
    testing.assertEqual(charToZscii($m, "ß"), 161);
    testing.assertEqual(charToZscii($m, "€"), 63);
}

func testEncodedWordsAreFoundInTheDictionary() {
    for (def path in [LANTERN3, LANTERN5]) {
        def m as Machine init story($path);
        testing.assertTrue(lookup($m, $m.dict, encodeWord($m, codesOf("lamp"))) != 0);
        testing.assertTrue(lookup($m, $m.dict, encodeWord($m, codesOf("n"))) != 0);
        testing.assertEqual(lookup($m, $m.dict, encodeWord($m, codesOf("xyzzy"))), 0);
    }
}

func testWordsAreCutToTheVersionsLength() {
    def m3 as Machine init story(LANTERN3);
    def m5 as Machine init story(LANTERN5);
    testing.assertEqual(len(encodeWord($m3, codesOf("inventory"))), 4);
    testing.assertEqual(len(encodeWord($m5, codesOf("inventory"))), 6);
    # version 3 compares six letters only
    testing.assertEqual(encodeWord($m3, codesOf("invent")), encodeWord($m3, codesOf("inventory")));
    testing.assertTrue(lookup($m3, $m3.dict, encodeWord($m3, codesOf("inventxyz"))) != 0);
    testing.assertEqual(lookup($m5, $m5.dict, encodeWord($m5, codesOf("inventxyz"))), 0);
}

func testCharactersOutsideTheAlphabetsAreEscaped() {
    def m as Machine init story(LANTERN5);
    def enc as list of int init encodeWord($m, [155]);
    # 5 (shift to A2), 6 (escape), then 155 in two halves
    testing.assertEqual((($enc[0] << 8) | $enc[1]) >> 5, (5 << 5) | 6);
    testing.assertEqual((($enc[0] << 8) | $enc[1]) & 31, 155 >> 5);
}

func testDecodeReadsTheObjectNames() {
    def m as Machine init story(LANTERN3);
    testing.assertEqual(toText($m, shortName($m, LAMP)), "brass lamp");
    def t as int init propTable($m, LAMP);
    testing.assertEqual(skipString($m, $t + 1), $t + 1 + 2 * $m.mem[$t]);
}

func testTokeniseWritesTheParseBuffer() {
    def m as Machine init started(LANTERN5);
    $m = fillText($m, "Take  LAMP,now");
    def text as int init $m.readText;
    testing.assertEqual($m.mem[$text + 1], 14);
    testing.assertEqual($m.mem[$text + 2], 116);
    def parse as int init $m.readParse;
    $m = tokenise($m, $text, $parse, 0, false);
    # Inform's dictionary separates on "," as well as on spaces
    testing.assertEqual($m.mem[$parse + 1], 4);
    testing.assertTrue(word($m.mem, $parse + 2) != 0);
    testing.assertEqual($m.mem[$parse + 4], 4);
    testing.assertEqual($m.mem[$parse + 5], 2);
    testing.assertTrue(word($m.mem, $parse + 6) != 0);
    testing.assertEqual($m.mem[$parse + 9], 8);
    testing.assertEqual($m.mem[$parse + 13], 12);
    testing.assertEqual(word($m.mem, $parse + 14), 0);
    testing.assertEqual($m.mem[$parse + 16], 3);
}

func testTokeniseCanKeepUnknownWords() {
    def m as Machine init started(LANTERN5);
    $m = fillText($m, "lamp zzz");
    def parse as int init $m.readParse;
    $m = storeWord($m, $parse + 6, 0x1234);
    $m = tokenise($m, $m.readText, $parse, 0, true);
    testing.assertEqual($m.mem[$parse + 1], 2);
    testing.assertEqual(word($m.mem, $parse + 6), 0x1234);
}

func testVersion3TextIsZeroTerminated() {
    def m as Machine init started(LANTERN3);
    $m = fillText($m, "look");
    def text as int init $m.readText;
    testing.assertEqual($m.mem[$text + 1], 108);
    testing.assertEqual($m.mem[$text + 5], 0);
    testing.assertEqual(bufferChars($m, $text), codesOf("look"));
}

func testLongInputIsCutToTheBuffer() {
    def m as Machine init started(LANTERN5);
    $m = fillText($m, strings.repeat("a", 200));
    testing.assertEqual($m.mem[$m.readText + 1], 80);
}
