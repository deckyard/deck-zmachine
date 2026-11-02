<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Playing a story

```jennifer
import "@deckyard/zmachine/" as zmachine;
```

## Loading

`open(path)` reads a story file, `load(story)` takes its bytes. Both check the
header and throw on anything but a version 3, 4, 5, 7 or 8 story. The file
extension does not matter: Infocom's `.dat` files load as well as `.z3` to
`.z8`. Blorb files (`.zblorb`) do not; extract the `ZCOD` chunk first.

Settings go between loading and the first `run`, because a game reads them
when it starts:

```jennifer
def m as zmachine.Machine init zmachine.open("story.z5");
$m = zmachine.setScreen($m, 60, 24);      # columns, rows
$m = zmachine.seed($m, 42);               # repeatable random numbers
$m = zmachine.setLimit($m, 10000000);     # instructions per call
$m = zmachine.run($m);
```

## The loop

`run` starts the game and executes until the game needs something from the
host. `waiting` says what:

| `Wait` | The game wants | Answer with |
|---|---|---|
| `Line` | a line of input | `send(m, text)` |
| `Key` | one key | `send(m, key)` |
| `Save` | a save file stored | `saveData(m)`, then `resume(m, ok)` |
| `Restore` | a save file loaded | `restore(m, data)`, or `resume(m, false)` to refuse |
| `Quit` | nothing; the game is over | |

Each answer runs the game on to its next wait. `output(m)` is the text the
lower window received during that last stretch.

```jennifer
def m as zmachine.Machine init zmachine.run(zmachine.open("story.z5"));
while (true) {
    io.printf("%s", zmachine.output($m));
    def w as zmachine.Wait init zmachine.waiting($m);
    if ($w == zmachine.Wait.Quit or io.eof()) {
        break;
    }
    if ($w == zmachine.Wait.Line or $w == zmachine.Wait.Key) {
        $m = zmachine.send($m, io.readLine());
    } else {
        $m = zmachine.resume($m, false);
    }
}
```

`examples/play.j` is this loop with saving and restoring to a file.

## Input

A line is lower-cased and cut to the length the game's buffer allows; the game
sees no typing, only the finished line. Characters outside ZSCII arrive as
`?`. The machine does not echo input into `output`: a console host has already
shown it, a chat bot may want to quote it.

A key is the first character of the text sent. An empty string is Return.

## Randomness

Without `seed`, the game's random numbers come from `math.randInt`. With it,
from a generator of its own, so a seed and a list of inputs replay the same
game. Games that seed themselves (the `random` opcode with a negative number)
switch to that seed, as the Standard asks.

## A game that does not stop

The instruction limit (default 50 million) stops a game that loops without
asking for input. The call throws, and the machine passed in is still the one
from before it.
