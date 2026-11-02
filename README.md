# @deckyard/zmachine

[![test](https://github.com/deckyard/deck-zmachine/actions/workflows/test.yml/badge.svg)](https://github.com/deckyard/deck-zmachine/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-github%20pages-blue)](https://deckyard.github.io/deck-zmachine/)
[![release](https://img.shields.io/github/v/release/deckyard/deck-zmachine)](https://github.com/deckyard/deck-zmachine/releases/latest)

A Z-machine interpreter: plays Infocom and Inform games, story files of
versions 3, 4, 5, 7 and 8, with Quetzal saves and undo. The machine has no
terminal of its own; the host sends it lines and shows what it prints, so a
game runs as well in a chat bot or a web page as in a console. Pure Jennifer
with no capabilities, so it runs on `jennifer-tiny`; only `open` reads a file.

Manual: **<https://deckyard.github.io/deck-zmachine/>**

## Install

Requires Jennifer 0.25.0 or newer.

```sh
jvc add @deckyard/zmachine
```

jvc vendors the deck to `vendor/deckyard/zmachine/`. Without jvc, copy `src/`
from a checkout or a `deckyard-zmachine-<version>.tar.gz` release archive
there, minus the test overlays:

```sh
mkdir -p vendor/deckyard/zmachine
cp -R path/to/deck-zmachine/src/. vendor/deckyard/zmachine/
find vendor/deckyard/zmachine -name '*_test.j' -delete
```

## Example

```jennifer
use io;
import "@deckyard/zmachine/" as zmachine;

def m as zmachine.Machine init zmachine.run(zmachine.open("zork1.z3"));
$m = zmachine.send($m, "open mailbox");
io.printf("%s", zmachine.output($m));
# Opening the small mailbox reveals a leaflet.
#
# >
io.printf("%s\n", zmachine.upperWindow($m)[0]);
#  West of House                                               Score: 0  Moves: 1
```

`examples/play.j` plays a story in the console:

```sh
jennifer run examples/play.j zork1.z3
```

No game ships with the deck. Zork I-III are
[published by Microsoft under the MIT licence](https://github.com/historicalsource/zork1),
the [IF Archive](https://ifarchive.org/indexes/if-archive/games/zcode/) holds
hundreds of free Inform games, and `testdata/lantern.z5` is a two-room test
game.

## Conformance

The test suite plays the Czech conformance suite in versions 3, 4, 5, 7 and 8
and Praxix in version 5, and every test in both passes. The manual's *What is
supported* page lists what is left out.

## Licence

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.
The test stories in `testdata/` carry their own licences; see its README.
