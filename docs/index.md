<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# @deckyard/zmachine

A Z-machine interpreter: plays Infocom and Inform games (story files of
versions 3, 4, 5, 7 and 8).

This deck is part of [Deckyard](https://github.com/deckyard), community decks for [Jennifer](https://jennifer-lang.dev/).

The machine has no terminal of its own. The host gives it lines and keys and
shows what it prints, so one game can run in a console, a chat bot or a web
page. It is pure Jennifer and runs on `jennifer-tiny`; only `open` reads a
file.

## Import

```jennifer
use io;
import "@deckyard/zmachine/" as zmachine;

def m as zmachine.Machine init zmachine.run(zmachine.open("story.z5"));
while (zmachine.waiting($m) == zmachine.Wait.Line) {
    io.printf("%s", zmachine.output($m));
    $m = zmachine.send($m, io.readLine());
}
io.printf("%s", zmachine.output($m));
```

The trailing slash resolves to the entry module.

## Value semantics

`run`, `send`, `resume` and `restore` return a new `Machine` and leave their
argument as it was. Holding on to an old machine is an undo, and two machines
from the same start play independently:

```jennifer
def start as zmachine.Machine init zmachine.run(zmachine.open("story.z5"));
def west as zmachine.Machine init zmachine.send($start, "west");
def east as zmachine.Machine init zmachine.send($start, "east");
```

Write the calls as `$m = zmachine.send($m, ...)`. Jennifer then moves the
machine into the call instead of copying its memory.

## Errors

Every failure is an `Error` with `kind` `"zmachine"` (`ERROR_KIND`): a file
that is not a supported story, a call that does not match what the machine
waits for, an illegal instruction, a damaged save file, or a game that runs
more than the instruction limit (`setLimit`) without asking for input. A
failed call leaves the machine you passed in untouched.

```jennifer
try {
    $m = zmachine.restore($m, $data);
} catch (e) {
    io.printf("%s\n", $e.message);
    $m = zmachine.resume($m, false);
}
```

## Speed

A turn of Zork I takes 100 to 160 ms with the default `jennifer` binary on a
desktop machine, and starting the game 35 ms. The Czech conformance suite, about
400 tests, runs in half a second.

## Contents

| Page | What it covers |
|---|---|
| [Playing a story](guide/playing.md) | the loop, what the machine waits for, keys, randomness |
| [Saving, restoring and undo](guide/saving.md) | Quetzal files, the save and restore waits, undo |
| [The screen](guide/screen.md) | the lower window, the upper window, the status line |
| [What is supported](reference/support.md) | versions, opcodes, what is left out, conformance |
| [Cheatsheet](reference/cheatsheet.md) | every export |
