# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - Z-characters, ZSCII, the dictionary and the tokeniser.
# Spliced into zmachine.j via include - not a standalone module.

/** ZSCII 155 to 223 when the story has no Unicode table (Standard 1.1, 3.8.5.3). */
def const EXTRA_CHARS as string init "äöüÄÖÜß»«ëïÿËÏáéíóúýÁÉÍÓÚÝàèìòùÀÈÌÒÙâêîôûÂÊÎÔÛåÅøØãñõÃÑÕæÆçÇþðÞÐ£œŒ¡¿";

/** Alphabet A2 from z-character 8 on; 6 is the ZSCII escape and 7 a newline. */
def const A2_TAIL as string init "0123456789.,!?_#'\"/\\-:()";

/**
 * The default alphabet table as ZSCII codes: A0, A1, A2, 26 each.
 * @return {list of int} 78 codes
 */
func defaultAlphabet() {
    def out as list of int init [];
    for (def i in 0..26) {
        $out[] = 97 + $i;
    }
    for (def i in 0..26) {
        $out[] = 65 + $i;
    }
    $out[] = 0;
    $out[] = 13;
    for (def c in strings.chars(A2_TAIL)) {
        $out[] = convert.toCodepoint($c);
    }
    return $out;
}

/**
 * The alphabet table a story uses: its own (header $34, version 5 and later)
 * or the default.
 * @param mem {bytes} story memory
 * @param version {int} Z-machine version
 * @return {list of int} 78 ZSCII codes
 */
func alphabetOf(mem as bytes, version as int) {
    def table as int init 0;
    if ($version >= 5) {
        $table = word($mem, 0x34);
    }
    if ($table == 0) {
        return defaultAlphabet();
    }
    def out as list of int init [];
    for (def i in 0..78) {
        $out[] = $mem[$table + $i];
    }
    $out[52] = 0;
    $out[53] = 13;
    return $out;
}

/**
 * ZSCII code to text: ASCII, the extra characters (from the story's Unicode
 * table when it has one) and newline. Codes with no character map to "".
 * @param mem {bytes} story memory
 * @param version {int} Z-machine version
 * @return {list of string} 1024 entries
 */
func zsciiTable(mem as bytes, version as int) {
    def out as list of string init [];
    for (def i in 0..1024) {
        $out[] = "";
    }
    $out[13] = "\n";
    for (def c in 32..127) {
        $out[$c] = convert.fromCodepoint($c);
    }
    def extra as list of string init strings.chars(EXTRA_CHARS);
    def custom as int init unicodeTable($mem, $version);
    if ($custom != 0) {
        $extra = [];
        for (def i in 0..$mem[$custom]) {
            $extra[] = convert.fromCodepoint(word($mem, $custom + 1 + 2 * $i));
        }
    }
    for (def i in 0..len($extra)) {
        if (155 + $i < 252) {
            $out[155 + $i] = $extra[$i];
        }
    }
    return $out;
}

/**
 * Address of the story's Unicode translation table, from header extension
 * word 3.
 * @param mem {bytes} story memory
 * @param version {int} Z-machine version
 * @return {int} the address, 0 for none
 */
func unicodeTable(mem as bytes, version as int) {
    if ($version < 5) {
        return 0;
    }
    def ext as int init word($mem, 0x36);
    if ($ext == 0 or $ext + 7 >= len($mem) or word($mem, $ext) < 3) {
        return 0;
    }
    return word($mem, $ext + 6);
}

/**
 * Decode a Z-string to ZSCII codes.
 * @param m {Machine} the machine
 * @param addr {int} byte address of the first word
 * @param nested {bool} true inside an abbreviation, which may not use another
 * @return {list of int} ZSCII codes
 * @throws {Error} on an abbreviation inside an abbreviation, or a string past the end of memory
 */
func decode(m as Machine, addr as int, nested as bool) {
    def out as list of int init [];
    def zs as list of int init [];
    def a as int init $addr;
    def size as int init len($m.mem);
    while (true) {
        if ($a + 1 >= $size) {
            fail("string at " + hex($addr) + " runs past the end of memory");
        }
        def w as int init ($m.mem[$a] << 8) | $m.mem[$a + 1];
        $zs[] = ($w >> 10) & 31;
        $zs[] = ($w >> 5) & 31;
        $zs[] = $w & 31;
        $a = $a + 2;
        if ($w >= 0x8000) {
            break;
        }
    }
    def shift as int init 0;
    def i as int init 0;
    def n as int init len($zs);
    while ($i < $n) {
        def z as int init $zs[$i];
        $i = $i + 1;
        if ($z == 0) {
            $out[] = 32;
            $shift = 0;
        } elseif ($z <= 3) {
            if ($nested) {
                fail("abbreviation inside an abbreviation in the string at " + hex($addr));
            }
            if ($i >= $n) {
                break;
            }
            def index as int init 32 * ($z - 1) + $zs[$i];
            $i = $i + 1;
            def entry as int init word($m.mem, $m.abbrevs + 2 * $index);
            for (def c in decode($m, 2 * $entry, true)) {
                $out[] = $c;
            }
            $shift = 0;
        } elseif ($z == 4) {
            $shift = 1;
        } elseif ($z == 5) {
            $shift = 2;
        } elseif ($shift == 2 and $z == 6) {
            if ($i + 1 < $n) {
                $out[] = ($zs[$i] << 5) | $zs[$i + 1];
            }
            $i = $i + 2;
            $shift = 0;
        } else {
            $out[] = $m.alphabet[26 * $shift + $z - 6];
            $shift = 0;
        }
    }
    return $out;
}

/**
 * Address just past a Z-string.
 * @param m {Machine} the machine
 * @param addr {int} byte address of the first word
 * @return {int} the address after its last word
 */
func skipString(m as Machine, addr as int) {
    def a as int init $addr;
    while ($a + 1 < len($m.mem) and $m.mem[$a] < 0x80) {
        $a = $a + 2;
    }
    return $a + 2;
}

/**
 * ZSCII codes to text.
 * @param m {Machine} the machine
 * @param codes {list of int} ZSCII codes
 * @return {string} the text; codes with no character become "?"
 */
func toText(m as Machine, codes as list of int) {
    def parts as list of string init [];
    for (def c in $codes) {
        if ($c >= 0 and $c < 1024 and $m.zscii[$c] != "") {
            $parts[] = $m.zscii[$c];
        } elseif ($c != 0) {
            $parts[] = "?";
        }
    }
    return strings.join($parts, "");
}

/**
 * One character of input to ZSCII.
 * @param m {Machine} the machine
 * @param ch {string} one character
 * @return {int} the ZSCII code; 63 ("?") for a character ZSCII lacks
 */
func charToZscii(m as Machine, ch as string) {
    def cp as int init convert.toCodepoint($ch);
    if ($cp >= 32 and $cp < 127) {
        return $cp;
    }
    if ($cp == 10 or $cp == 13) {
        return 13;
    }
    if ($cp == 8 or $cp == 127) {
        return 8;
    }
    if ($cp == 27) {
        return 27;
    }
    for (def i in 155..252) {
        if ($m.zscii[$i] == $ch) {
            return $i;
        }
    }
    return 63;
}

/**
 * Encode ZSCII codes as a dictionary word: 6 Z-characters in 4 bytes up to
 * version 3, 9 in 6 bytes after.
 * @param m {Machine} the machine
 * @param codes {list of int} the word, lower case
 * @return {list of int} the encoded bytes
 */
func encodeWord(m as Machine, codes as list of int) {
    def size as int init 9;
    if ($m.version <= 3) {
        $size = 6;
    }
    def zs as list of int init [];
    for (def c in $codes) {
        if (len($zs) >= $size) {
            break;
        }
        def at as int init -1;
        for (def i in 0..78) {
            if ($m.alphabet[$i] == $c and ($i < 52 or $i >= 54)) {
                $at = $i;
                break;
            }
        }
        if ($at >= 0 and $at < 26) {
            $zs[] = $at + 6;
        } elseif ($at >= 26) {
            $zs[] = 4 + $at // 26 - 1;
            $zs[] = $at % 26 + 6;
        } else {
            $zs[] = 5;
            $zs[] = 6;
            $zs[] = ($c >> 5) & 31;
            $zs[] = $c & 31;
        }
    }
    while (len($zs) < $size) {
        $zs[] = 5;
    }
    def out as list of int init [];
    for (def i in 0..$size // 3) {
        def w as int init ($zs[3 * $i] << 10) | ($zs[3 * $i + 1] << 5) | $zs[3 * $i + 2];
        if ($i == $size // 3 - 1) {
            $w = $w | 0x8000;
        }
        $out[] = $w >> 8;
        $out[] = $w & 0xff;
    }
    return $out;
}

/**
 * Look a word up in a dictionary.
 * @param m {Machine} the machine
 * @param dict {int} address of the dictionary
 * @param key {list of int} the word as `encodeWord` gives it
 * @return {int} address of the entry, 0 when the word is not there
 */
func lookup(m as Machine, dict as int, key as list of int) {
    def seps as int init $m.mem[$dict];
    def entryLen as int init $m.mem[$dict + 1 + $seps];
    def count as int init signed(word($m.mem, $dict + 2 + $seps));
    def first as int init $dict + 4 + $seps;
    def size as int init len($key);
    if ($count < 0) {
        for (def i in 0..-$count) {
            def e as int init $first + $i * $entryLen;
            if (compareEntry($m.mem, $e, $key, $size) == 0) {
                return $e;
            }
        }
        return 0;
    }
    def lo as int init 0;
    def hi as int init $count - 1;
    while ($lo <= $hi) {
        def mid as int init ($lo + $hi) // 2;
        def e as int init $first + $mid * $entryLen;
        def c as int init compareEntry($m.mem, $e, $key, $size);
        if ($c == 0) {
            return $e;
        }
        if ($c < 0) {
            $lo = $mid + 1;
        } else {
            $hi = $mid - 1;
        }
    }
    return 0;
}

/**
 * Compare a dictionary entry with an encoded word, byte by byte.
 * @param mem {bytes} story memory
 * @param e {int} address of the entry
 * @param key {list of int} the encoded word
 * @param size {int} bytes to compare
 * @return {int} negative, 0 or positive, as the entry sorts before, with or after the word
 */
func compareEntry(mem as bytes, e as int, key as list of int, size as int) {
    for (def i in 0..$size) {
        def d as int init $mem[$e + $i] -$key[$i];
        if ($d != 0) {
            return $d;
        }
    }
    return 0;
}

/**
 * The characters in a text buffer, with the offset of the first.
 * @param m {Machine} the machine
 * @param text {int} address of the text buffer
 * @return {list of int} the ZSCII codes
 */
func bufferChars(m as Machine, text as int) {
    def out as list of int init [];
    if ($m.version >= 5) {
        def n as int init $m.mem[$text + 1];
        for (def i in 0..$n) {
            $out[] = $m.mem[$text + 2 + $i];
        }
        return $out;
    }
    def a as int init $text + 1;
    while ($a < len($m.mem) and $m.mem[$a] != 0) {
        $out[] = $m.mem[$a];
        $a = $a + 1;
    }
    return $out;
}

/**
 * Split a text buffer into words and write the parse buffer (`tokenise`).
 * @param m {Machine} the machine
 * @param text {int} address of the text buffer
 * @param parse {int} address of the parse buffer
 * @param dict {int} address of the dictionary, 0 for the standard one
 * @param keep {bool} leave the entries of unknown words untouched
 * @return {Machine} the machine with the parse buffer written
 */
func tokenise(m as Machine, text as int, parse as int, dict as int, keep as bool) {
    def d as int init $dict;
    if ($d == 0) {
        $d = $m.dict;
    }
    def seps as list of int init [];
    for (def i in 0..$m.mem[$d]) {
        $seps[] = $m.mem[$d + 1 + $i];
    }
    def chars as list of int init bufferChars($m, $text);
    def start as int init 1;
    if ($m.version >= 5) {
        $start = 2;
    }
    def max as int init $m.mem[$parse];
    def found as int init 0;
    def i as int init 0;
    def n as int init len($chars);
    while ($i < $n and $found < $max) {
        def c as int init $chars[$i];
        if ($c == 32) {
            $i = $i + 1;
            continue;
        }
        def end as int init $i + 1;
        if (not lists.contains($seps, $c)) {
            while ($end < $n and $chars[$end] != 32 and not lists.contains($seps, $chars[$end])) {
                $end = $end + 1;
            }
        }
        def entry as int init lookup($m, $d, encodeWord($m, $chars[$i..$end]));
        def slot as int init $parse + 2 + 4 * $found;
        if ($entry != 0 or not $keep) {
            $m = storeWord($m, $slot, $entry);
            $m = storeByte($m, $slot + 2, $end - $i);
            $m = storeByte($m, $slot + 3, $i + $start);
        }
        $found = $found + 1;
        $i = $end;
    }
    $m = storeByte($m, $parse + 1, $found);
    return $m;
}

/**
 * Write a line of input into the pending read's text buffer, lower case and
 * cut to the buffer's size.
 * @param m {Machine} the machine
 * @param line {string} the input
 * @return {Machine} the machine with the text buffer filled
 */
func fillText(m as Machine, line as string) {
    def text as int init $m.readText;
    def max as int init $m.mem[$text];
    def at as int init $text + 1;
    def have as int init 0;
    if ($m.version >= 5) {
        $at = $text + 2;
        $have = $m.mem[$text + 1];
        if ($have > $max) {
            $have = 0;
        }
    } else {
        $max = $max - 1;
    }
    def n as int init $have;
    for (def ch in strings.chars(strings.lower($line))) {
        if ($n >= $max) {
            break;
        }
        def z as int init charToZscii($m, $ch);
        if ($z == 13 or $z == 8 or $z == 27) {
            continue;
        }
        $m = storeByte($m, $at + $n, $z);
        $n = $n + 1;
    }
    if ($m.version >= 5) {
        $m = storeByte($m, $text + 1, $n);
    } else {
        $m = storeByte($m, $at + $n, 0);
    }
    return $m;
}
