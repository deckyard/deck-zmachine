<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Design

## Scope

`@deckyard/zmachine` is a Z-machine interpreter in pure Jennifer. It plays
Infocom™ and Inform story files of versions 3, 4, 5, 7 and 8 following the
Z-Machine Standard 1.1, with Quetzal saves and undo. It has no terminal of its
own: the host feeds it lines or keys and reads its output, so the same game
runs in a console, a chat bot or a web page.

Not in scope:

- **Versions 1, 2 and 6.** The earliest Zork™ releases and the graphical games
  are rejected by `load`.
- **Presentation.** Colours, text styles, extra fonts, sound, mouse, menus and
  pictures are ignored or refused in the header; the host decides how text
  looks.
- **Timed input, transcripts and input streams.** Timed input waits without a
  timeout; output streams 2 and 4 write nothing; input streams are ignored.
- **Auxiliary save files.** `save` and `restore` with operands fail.
- **File handling beyond `open`.** Save data goes to and from the host as
  bytes; where it is stored is the host's choice.

## Decisions

- **A host-driven machine.** The machine runs until it needs something:
  `run` starts a game, `waiting` reports a `Wait` (line, key, save, restore,
  quit), `send` answers a line or key, `saveData` and `resume` answer a save,
  `restore` or `resume` with false answer a restore. Each entry point checks
  the wait state and clears the previous output first. Lower-window text is
  collected for `output`; the upper window is a list of fixed-width rows from
  `upperWindow`, which in version 3 starts with the status line built from
  the game's globals. Input is not echoed.
- **The whole state is one value.** `Machine` holds memory, the pristine story
  bytes, the stack, call frames as flat integers, screen and random-number
  state, the undo snapshots and the pending save. Every function takes a
  machine and returns a new one, so an old machine is a free snapshot.
- **The call form `$m = f($m, ...)`.** Written this way, with no other
  argument naming the machine, the interpreter moves the machine into the
  call instead of copying its memory. Every handler follows it, and the docs
  ask hosts to do the same.
- **An instruction budget.** `run`, `send` and the other entry points fail
  after a limit of instructions without a wait (`setLimit`, 50,000,000 by
  default), so a looping game cannot hang the host.
- **Save and restore as round trips.** A `save` opcode stops with the Quetzal
  file already built; the host stores `saveData` and answers with `resume`.
  The dummy bottom frame of the stack chunk is written with zero flags and
  arguments because Frotz requires it, and saves move between this deck and
  Frotz in both directions. `restore` checks release, serial and checksum
  against the save and throws before touching the machine, so the host can
  still answer `resume` with false.
- **Undo in memory.** `save_undo` keeps up to 8 snapshots of dynamic memory,
  stack and frames; the oldest is dropped.
- **Random numbers.** Unseeded play uses the interpreter's random source;
  `seed` gives repeatable games (a seeded generator), and small negative
  seeds from the game select the Standard's counting mode.
- **Header.** The machine reports interpreter number 6 (IBM™ PC), version `J`
  and Standard revision 1.1. Restart and restore keep the transcript and
  fixed-pitch bits, as the Standard requires.
- **Pure computation.** No capabilities; `open` reads a story file with `fs`,
  and `load` takes the bytes directly. The deck runs on `jennifer-tiny` too.
- **Topics layout.** `src/zmachine.j` includes core, text, objects, screen,
  story, exec and quetzal, each with its overlay.

## Errors

- Every failure is an `Error` of kind `"zmachine"` (`ERROR_KIND`), message
  `zmachine: ...`; a fault inside the story adds the program counter.
- Host misuse (the wrong wait state, a bad screen size, a seed below 1) and
  story faults (an illegal opcode, stack underflow, a write outside dynamic
  memory, division by zero, a return from the main routine) both throw.
- A read past the end of story memory surfaces as the interpreter's own
  index error (kind `"runtime"`), not as kind `"zmachine"`.
- The deck reports no external status or code, so it has no error struct.

## Security and limits

- A story file is untrusted input: writes are confined to dynamic memory,
  stack and local-variable access is checked, a read past the end of memory
  fails through the interpreter's own bounds check, and the instruction
  budget stops a game that never waits.
- A save file is checked against the running story before it replaces any
  state.
- Undo depth is fixed at 8 snapshots, bounding memory use.

## Testing and validation

- One suite, `src/zmachine_test.j`, includes the topic overlays (64 tests).
- **Lantern**, the deck's own two-room game (`testdata/lantern.inf`, built as
  versions 3, 5 and 8), exercises line input, keys, the status line, save and
  restore, undo, random numbers and Unicode. It is embedded in the overlays as
  base64 because the publish gate runs them from a copy of `src/` alone; a
  test checks the embedded copy against `testdata/`.
- **Conformance**: Czech 0.8 (versions 3, 4, 5, 7, 8) and Praxix (version 5)
  in `testdata/` pass in full. These tests skip when `testdata/` is absent.
- Zork I (Release 119, published under the MIT licence in 2025) plays turn
  for turn as in Frotz, with saves moving between the two.
- `tools/build-fixtures.sh` rebuilds the story files with Inform 6.45; CI uses
  the committed files.

## Known limitations and open questions

- The features listed under Scope degrade quietly rather than fail; a game
  that depends on timed input or colour still runs, without them.
- Version 6 would need a graphics model the host side does not have.

## Dependencies on the interpreter

- Floor `jennifer >=0.27.0` and `jennifer-tiny >=0.27.0`: the UTF-8 codecs
  of `encoding.encode` / `decode` and `strings.replicate` arrived in 0.27.0.
- Built-in libraries `binary`, `strings`, `convert`, `lists`, `math`, `fs`.
- Moving a value into a call in the `$m = f($m, ...)` form, without which
  each instruction would copy the story's memory.
