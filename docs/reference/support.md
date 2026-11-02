<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# What is supported

The machine follows the
[Z-Machine Standard 1.1](https://inform-fiction.org/zmachine/standards/z1point1/)
and reports revision 1.1 in the header.

## Versions

| Version | Games | Supported |
|---|---|---|
| 1, 2 | the earliest Zork releases | no |
| 3 | most Infocom games: Zork I-III, Planetfall, Hitchhiker's Guide | yes |
| 4 | A Mind Forever Voyaging, Trinity, Bureaucracy | yes |
| 5 | Beyond Zork, Border Zone, Inform games | yes |
| 6 | the graphical games: Zork Zero, Journey, Shogun | no |
| 7 | rare Inform builds | yes |
| 8 | large Inform games | yes |

## Left out

| Feature | What happens |
|---|---|
| colours, text styles, fonts other than 1 and 4 | ignored; the header says colours are unavailable |
| sound effects | ignored |
| timed input | the game waits without a timeout |
| output stream 2 (transcript) and 4 (commands) | the header bit is kept, nothing is written |
| input streams | ignored |
| auxiliary save files | `save` and `restore` with operands fail |
| mouse, menus, pictures | refused in the header |

## Conformance

The test suite runs these story files, in `testdata/`, on every push:

| Suite | Versions | Result |
|---|---|---|
| Czech 0.8 | 3, 4, 5, 7, 8 | every test passes |
| Praxix | 5 | every test passes |

Zork I (Release 119, the one Microsoft published under the MIT licence in
2025) plays turn for turn as in Frotz, and save files move between the two in
both directions.
