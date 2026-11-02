# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * zmachine - a Z-machine interpreter: plays Infocom and Inform games.
 *
 * Versions 3, 4, 5, 7 and 8 of the Z-machine Standard 1.1, which covers the
 * Infocom catalogue except the graphical version 6 games, and Inform games.
 * The machine never touches a terminal: the host feeds it input and shows its
 * output, so the same game runs in a console, a chat bot or a web page.
 *
 *   load      {@link load} / {@link open} / {@link info}
 *   settings  {@link setScreen} / {@link seed} / {@link setLimit}
 *   play      {@link run} / {@link waiting} / {@link send}
 *   screen    {@link output} / {@link upperWindow}
 *   saving    {@link saveData} / {@link resume} / {@link restore}
 *
 * A function that advances the game returns a new `Machine`:
 * `$m = zmachine.send($m, "north")`. Keeping an old one is a free undo.
 * Every failure throws an `Error` with `kind` {@link ERROR_KIND}.
 *
 * The topic files under `topics/` are spliced in with `include`; this file is
 * the module boundary. White-box tests: `zmachine_test.j`.
 *
 * @module zmachine
 * @see https://inform-fiction.org/zmachine/standards/z1point1/
 * @example
 *   import "@deckyard/zmachine/" as zmachine;
 *
 *   def m as zmachine.Machine init zmachine.run(zmachine.open("story.z5"));
 *   while (zmachine.waiting($m) == zmachine.Wait.Line) {
 *       io.printf("%s", zmachine.output($m));
 *       $m = zmachine.send($m, io.readLine());
 *   }
 */

use strings;
use convert;
use binary;
use lists;
use math;
use fs;

include "topics/version.j";
include "topics/core.j";
include "topics/text.j";
include "topics/objects.j";
include "topics/screen.j";
include "topics/story.j";
include "topics/exec.j";
include "topics/quetzal.j";
