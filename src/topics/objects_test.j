# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - white-box tests for the objects topic.
# Spliced into zmachine_test.j via include - run with:
#   jennifer test src/zmachine_test.j

func putMissingProperty() {
    def m as Machine init open(LANTERN3);
    putProp($m, HALL, 1, 5);
}

func badAttribute() {
    def m as Machine init open(LANTERN3);
    hasAttr($m, HALL, 32);
}

func objectZero() {
    def m as Machine init open(LANTERN3);
    objectAddress($m, 0);
}

func testTheTree() {
    for (def path in [LANTERN3, LANTERN5]) {
        def m as Machine init open($path);
        testing.assertEqual(toText($m, shortName($m, HALL)), "Hall");
        testing.assertEqual(link($m, LAMP, 0), HALL);
        testing.assertEqual(link($m, HALL, 2), PLAYER);
        testing.assertEqual(link($m, PLAYER, 1), LAMP);
        testing.assertEqual(link($m, LAMP, 1), 0);
        testing.assertEqual(link($m, 0, 0), 0);
    }
}

func testInsertAndDetach() {
    for (def path in [LANTERN3, LANTERN5]) {
        def m as Machine init open($path);
        $m = insertObject($m, LAMP, PLAYER);
        testing.assertEqual(link($m, LAMP, 0), PLAYER);
        testing.assertEqual(link($m, PLAYER, 2), LAMP);
        testing.assertEqual(link($m, LAMP, 1), 0);
        testing.assertEqual(link($m, HALL, 2), PLAYER);
        testing.assertEqual(link($m, PLAYER, 1), 0);
        $m = detach($m, PLAYER);
        testing.assertEqual(link($m, HALL, 2), 0);
        testing.assertEqual(link($m, PLAYER, 0), 0);
        # the lamp went with the player
        testing.assertEqual(link($m, LAMP, 0), PLAYER);
    }
}

func testDetachFromTheMiddleOfASiblingList() {
    def m as Machine init open(LANTERN3);
    $m = insertObject($m, GARDEN, HALL);
    # HALL's children: GARDEN, PLAYER, LAMP
    $m = detach($m, PLAYER);
    testing.assertEqual(link($m, GARDEN, 1), LAMP);
    testing.assertEqual(link($m, PLAYER, 0), 0);
}

func testAttributes() {
    for (def path in [LANTERN3, LANTERN5]) {
        def m as Machine init open($path);
        testing.assertTrue(not hasAttr($m, LAMP, 0));
        $m = setAttr($m, LAMP, 0, true);
        $m = setAttr($m, LAMP, 31, true);
        testing.assertTrue(hasAttr($m, LAMP, 0));
        testing.assertTrue(hasAttr($m, LAMP, 31));
        testing.assertEqual($m.mem[objectAddress($m, LAMP)] & 0x80, 0x80);
        $m = setAttr($m, LAMP, 0, false);
        testing.assertTrue(not hasAttr($m, LAMP, 0));
        testing.assertTrue(not hasAttr($m, 0, 0));
    }
    def m5 as Machine init open(LANTERN5);
    $m5 = setAttr($m5, LAMP, 47, true);
    testing.assertTrue(hasAttr($m5, LAMP, 47));
    testing.assertThrows("badAttribute", ERROR_KIND);
    testing.assertThrows("objectZero", ERROR_KIND);
}

func testProperties() {
    for (def path in [LANTERN3, LANTERN5]) {
        def m as Machine init open($path);
        # the name property holds two dictionary words
        def first as int init nextProp($m, LAMP, 0);
        testing.assertTrue($first != 0);
        def data as int init propAddress($m, LAMP, $first);
        testing.assertTrue($data != 0);
        testing.assertEqual(propLength($m, $data), 4);
        testing.assertEqual(getProp($m, LAMP, $first), word($m.mem, $data));
        testing.assertEqual(nextProp($m, LAMP, $first), 0);
        testing.assertEqual(propAddress($m, HALL, $first), 0);
        testing.assertEqual(propLength($m, 0), 0);
        $m = putProp($m, LAMP, $first, 0x1234);
        testing.assertEqual(getProp($m, LAMP, $first), 0x1234);
    }
}

func testMissingPropertiesUseTheDefaults() {
    def m as Machine init open(LANTERN3);
    $m = storeWord($m, $m.objects + 2 * 9, 77);
    testing.assertEqual(getProp($m, HALL, 10), 77);
    testing.assertThrows("putMissingProperty", ERROR_KIND);
}
