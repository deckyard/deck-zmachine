# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

# zmachine - output streams, the two windows and the status line.
# Spliced into zmachine.j via include - not a standalone module.

/**
 * Text the lower window received since the last `run`, `send`, `resume` or
 * `restore` began. Input is not echoed into it.
 * @param m {Machine} the machine
 * @return {string} the text, with "\n" line breaks
 * @example
 *   $m = zmachine.send($m, "open mailbox");
 *   io.printf("%s", zmachine.output($m));
 */
export func output(m as Machine) {
    return strings.join($m.out, "");
}

/**
 * The upper window, row by row, each `width` characters wide. Up to version
 * 3 the first row is the status line.
 * @param m {Machine} the machine
 * @return {list of string} the rows; empty when the window is closed
 */
export func upperWindow(m as Machine) {
    if ($m.version > 3) {
        return $m.upper;
    }
    def rows as list of string init [statusLine($m)];
    for (def r in $m.upper) {
        $rows[] = $r;
    }
    return $rows;
}

/**
 * The version 3 status line: the location on the left, the score and moves
 * (or the time) on the right.
 * @param m {Machine} the machine
 * @return {string} `width` characters
 */
func statusLine(m as Machine) {
    def g as int init $m.globals;
    def place as string init toText($m, shortName($m, word($m.mem, $g)));
    def a as int init signed(word($m.mem, $g + 2));
    def b as int init word($m.mem, $g + 4);
    def right as string init "Score: " + convert.toString($a) + "  Moves: " +
        convert.toString($b);
    if ($m.mem[1] & 2 != 0) {
        def hour as int init $a % 12;
        if ($hour == 0) {
            $hour = 12;
        }
        def half as string init "AM";
        if ($a >= 12) {
            $half = "PM";
        }
        def mins as string init convert.toString($b);
        if ($b < 10) {
            $mins = "0" + $mins;
        }
        $right = "Time: " + convert.toString($hour) + ":" + $mins + " " + $half;
    }
    def left as string init " " + $place;
    def room as int init $m.width - len($right) - 1;
    if (len($left) > $room - 1) {
        $left = $left[..math.max(0, $room - 1)];
    }
    def line as string init $left + strings.repeat(" ", $room - len($left)) + $right + " ";
    if (len($line) > $m.width) {
        return $line[..$m.width];
    }
    return $line;
}

/**
 * A blank upper window row.
 * @param m {Machine} the machine
 * @return {string} `width` spaces
 */
func blankRow(m as Machine) {
    return strings.repeat(" ", $m.width);
}

/**
 * Send ZSCII codes to the selected output: the innermost stream 3 table when
 * one is open, else the selected window.
 * @param m {Machine} the machine
 * @param codes {list of int} ZSCII codes
 * @return {Machine} the machine with the text written
 */
func emit(m as Machine, codes as list of int) {
    def nt as int init len($m.tables);
    if ($nt > 0) {
        def t as int init $m.tables[$nt - 1];
        def n as int init word($m.mem, $t);
        for (def c in $codes) {
            if ($c == 0) {
                # ZSCII 0 is "no character"
                continue;
            }
            $m = storeByte($m, $t + 2 + $n, $c);
            $n = $n + 1;
        }
        $m = storeWord($m, $t, $n);
        return $m;
    }
    if (not $m.screen) {
        return $m;
    }
    if ($m.window == 0) {
        $m.out[] = toText($m, $codes);
        return $m;
    }
    for (def c in $codes) {
        if ($c == 13) {
            $m.row = $m.row + 1;
            $m.col = 0;
            continue;
        }
        if ($m.row < len($m.upper) and $m.col < $m.width) {
            def r as string init $m.upper[$m.row];
            def ch as string init toText($m, [$c]);
            $m.upper[$m.row] = $r[..$m.col] + $ch + $r[$m.col + 1..];
        }
        $m.col = $m.col + 1;
    }
    return $m;
}

/**
 * Send text that is already a string (numbers, Unicode) to the output.
 * @param m {Machine} the machine
 * @param text {string} the text
 * @return {Machine} the machine with the text written
 */
func emitText(m as Machine, text as string) {
    def codes as list of int init [];
    for (def ch in strings.chars($text)) {
        $codes[] = charToZscii($m, $ch);
    }
    if (len($m.tables) == 0 and $m.screen and $m.window == 0) {
        $m.out[] = $text;
        return $m;
    }
    $m = emit($m, $codes);
    return $m;
}

/**
 * Set the upper window's height (`split_window`).
 * @param m {Machine} the machine
 * @param rows {int} lines, 0 closes it
 * @return {Machine} the machine with the window resized
 */
func split(m as Machine, rows as int) {
    def n as int init math.max(0, $rows);
    def out as list of string init [];
    for (def i in 0..$n) {
        if ($i < len($m.upper)) {
            $out[] = $m.upper[$i];
        } else {
            $out[] = blankRow($m);
        }
    }
    $m.upper = $out;
    if ($m.row >= $n) {
        $m.row = 0;
        $m.col = 0;
    }
    if ($n == 0) {
        $m.window = 0;
    }
    return $m;
}

/**
 * Clear a window (`erase_window`): -1 also closes the upper window, -2 keeps
 * it; the lower window has nothing to clear, its text is already out.
 * @param m {Machine} the machine
 * @param w {int} the window, 0, 1, -1 or -2
 * @return {Machine} the machine with the window cleared
 */
func eraseWindow(m as Machine, w as int) {
    if ($w == -1) {
        $m.upper = [];
        $m.window = 0;
    }
    if ($w == 1 or $w == -2) {
        for (def i in 0..len($m.upper)) {
            $m.upper[$i] = blankRow($m);
        }
    }
    if ($w == 1 or $w < 0) {
        $m.row = 0;
        $m.col = 0;
    }
    return $m;
}

/**
 * Clear the upper window from the cursor to the end of the row
 * (`erase_line 1`).
 * @param m {Machine} the machine
 * @return {Machine} the machine with the row cleared
 */
func eraseLine(m as Machine) {
    if ($m.window == 1 and $m.row < len($m.upper) and $m.col < $m.width) {
        def r as string init $m.upper[$m.row];
        $m.upper[$m.row] = $r[..$m.col] + strings.repeat(" ", $m.width - $m.col);
    }
    return $m;
}

/**
 * Open or close an output stream (`output_stream`).
 * @param m {Machine} the machine
 * @param n {int} the stream, negative to close
 * @param table {int} the table for stream 3
 * @return {Machine} the machine with the stream changed
 * @throws {Error} on a 17th nested stream 3
 */
func selectStream(m as Machine, n as int, table as int) {
    if ($n == 1) {
        $m.screen = true;
    } elseif ($n == -1) {
        $m.screen = false;
    } elseif ($n == 2 or $n == -2) {
        $m.transcript = $n == 2;
        def flags as int init word($m.mem, 0x10);
        if ($m.transcript) {
            $flags = $flags | 1;
        } else {
            $flags = $flags & 0xfffe;
        }
        $m = storeWord($m, 0x10, $flags);
    } elseif ($n == 3) {
        if (len($m.tables) >= 16) {
            failAt($m, "more than 16 nested output stream 3 tables");
        }
        $m = storeWord($m, $table, 0);
        $m.tables[] = $table;
    } elseif ($n == -3) {
        if (len($m.tables) > 0) {
            $m.tables = $m.tables[..len($m.tables) - 1];
        }
    }
    return $m;
}
