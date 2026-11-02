<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Test stories

The test overlays run these story files. Each `.z*` file is compiled from the
`.inf` beside it by `tools/build-fixtures.sh` (Inform 6.45); rebuild them
after changing a source.

| Files | What they test | Licence |
|---|---|---|
| `czech/` | Czech 0.8, the Comprehensive Z-machine Emulation CHecker by Amir Karger: about 400 opcode tests, built for versions 3, 4, 5, 7 and 8 | Czech's own, in `czech/README.txt`: use, distribution and modification for any purpose, keeping that licence and the copyright notice |
| `praxix/` | Praxix by Zarf and Dannii: arithmetic, undo, streams, tables, Standard 1.1 | public domain; its indirect-variable test is from Czech, under Czech's licence |
| `lantern.*` | a two-room game written for this deck: line input, the status line, save, restore, undo, keys, random numbers, Unicode | LGPL-3.0-only, like the deck |

None of them is an Infocom game.
