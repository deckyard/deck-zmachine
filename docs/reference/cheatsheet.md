<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Cheatsheet

Every export. Names are written bare; after
`import "@deckyard/zmachine/" as zmachine;` they read `zmachine.run(...)`.
Every failure throws an `Error` with `kind` `"zmachine"`. Functions that return
a `Machine` leave their `m` argument unchanged.

## Types

### `Wait`

What a machine needs before it can go on. Zero value `Line`.

| Variant | Notes |
|---|---|
| `Line` | a line of input: `send` |
| `Key` | one key: `send` |
| `Save` | a save file to store: `saveData`, then `resume` |
| `Restore` | a save file to load: `restore`, or `resume` to refuse |
| `Quit` | the game has ended |

### `Info`

A story's identity, from its header.

| Field | Notes |
|---|---|
| `version as int` | 3, 4, 5, 7 or 8 |
| `release as int` | release number |
| `serial as string` | six characters, usually the compile date |
| `checksum as int` | header checksum |

### `Machine`

A running story. Opaque: read it through the functions below. The fields are
listed because the type is exported, not for use.

| Field | Notes |
|---|---|
| `mem as bytes` | story memory |
| `story as bytes` | the story file as loaded |
| `version as int` | Z-machine version |
| `pc as int` | program counter |
| `stack as list of int` | locals and evaluation stack |
| `sp as int` | next free stack slot |
| `bp as int` | first local of the current frame |
| `frames as list of int` | five ints per call frame |
| `fp as int` | ints of `frames` in use |
| `ops as list of int` | operands of the current instruction |
| `nops as int` | how many of `ops` are in use |
| `globals as int` | address of the global variables |
| `objects as int` | address of the object table |
| `abbrevs as int` | address of the abbreviations table |
| `dict as int` | address of the dictionary |
| `staticBase as int` | first byte of static memory |
| `packShift as int` | packed address multiplier, as a shift |
| `routineOffset as int` | version 7 routine offset |
| `stringOffset as int` | version 7 string offset |
| `alphabet as list of int` | alphabets A0, A1, A2 as ZSCII |
| `zscii as list of string` | ZSCII code to text |
| `waitOn as int` | what the machine waits for |
| `readText as int` | text buffer of the pending read |
| `readParse as int` | parse buffer of the pending read |
| `readStore as int` | store variable of the pending read |
| `resultPc as int` | result byte of a pending save or restore |
| `out as list of string` | lower window text of the last run |
| `screen as bool` | output stream 1 selected |
| `transcript as bool` | output stream 2 selected |
| `tables as list of int` | output stream 3 tables |
| `window as int` | selected window |
| `upper as list of string` | upper window rows |
| `row as int` | upper window cursor row |
| `col as int` | upper window cursor column |
| `width as int` | screen width |
| `height as int` | screen height |
| `font as int` | current font |
| `rng as int` | random generator state |
| `rngMode as int` | random, seeded or counting |
| `rngCount as int` | next value when counting |
| `rngTop as int` | cycle length when counting |
| `undos as list of Snap` | `save_undo` states |
| `saved as bytes` | Quetzal file of a pending save |
| `limit as int` | instructions per call |

### `Snap`

A `save_undo` state, held in `Machine.undos`.

| Field | Notes |
|---|---|
| `dynamic as bytes` | dynamic memory |
| `stack as list of int` | the used stack |
| `frames as list of int` | the used frames |
| `pc as int` | the `save_undo`'s store byte |

## Loading

| Function | Returns | Notes |
|---|---|---|
| `load(story)` | `Machine` | from the story file's bytes; throws unless it is version 3, 4, 5, 7 or 8 |
| `open(path)` | `Machine` | from a file |
| `info(m)` | `Info` | version, release, serial, checksum |

## Settings

Set them before the first `run`; games read them when they start.

| Function | Returns | Notes |
|---|---|---|
| `setScreen(m, columns, rows)` | `Machine` | 20-255 columns, 1-255 rows; default 80 by 255, which never fills |
| `seed(m, n)` | `Machine` | repeatable random numbers, `n` at least 1 |
| `setLimit(m, steps)` | `Machine` | instructions one call may run before it throws; default 50 million |

## Playing

| Function | Returns | Notes |
|---|---|---|
| `run(m)` | `Machine` | start the game; runs to the first wait |
| `waiting(m)` | `Wait` | what the game needs; throws before `run` |
| `send(m, text)` | `Machine` | answer `Line` or `Key`; a key is the first character, `""` is Return |

## Screen

| Function | Returns | Notes |
|---|---|---|
| `output(m)` | `string` | lower window text since the last call that ran the game |
| `upperWindow(m)` | `list of string` | the upper window's rows; up to version 3 the first is the status line |

## Saving

| Function | Returns | Notes |
|---|---|---|
| `saveData(m)` | `bytes` | the Quetzal file of a `Save` wait |
| `resume(m, ok)` | `Machine` | answer `Save` with whether storing worked, or refuse a `Restore` |
| `restore(m, data)` | `Machine` | answer `Restore` with a Quetzal file; throws on a bad file and leaves `m` waiting |

## Constants

| Name | Value | What it is |
|---|---:|---|
| `ERROR_KIND` | `"zmachine"` | the `kind` every `Error` here carries |
| `VERSION` | generated | the deck version, injected from the git tag |
