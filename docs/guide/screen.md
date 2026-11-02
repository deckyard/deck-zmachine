<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# The screen

```jennifer
import "@deckyard/zmachine/" as zmachine;
```

A Z-machine screen has two windows. The lower one scrolls and holds the story;
the upper one is a fixed grid the game draws into, mostly for a status line.

## The lower window

`output(m)` is the text the lower window received since the last call that ran
the game, with `"\n"` line breaks. The machine does not wrap lines: a console
host wraps them to its width, a chat bot leaves that to the client. Styles
(bold, italic, fixed pitch) and colours are dropped.

## The upper window

`upperWindow(m)` is the upper window, one string per row, each as wide as the
screen. It keeps its content between turns, as on a real screen.

From version 4 on, the game draws it, usually as a one-line status bar. Up to
version 3 the interpreter draws the status line, so the first row is built
from the game's globals: the location on the left, the score and moves (or the
time, for games that keep time) on the right.

```jennifer
def rows as list of string init zmachine.upperWindow($m);
if (len($rows) > 0) {
    io.printf("[%s]\n", $rows[0]);
}
```

## Screen size

`setScreen(m, columns, rows)` sets what the game sees, 80 by 255 by default.
255 rows tell the game the screen never fills, so it never pauses for a key.
Games read the size when they start; set it before the first `run`.
