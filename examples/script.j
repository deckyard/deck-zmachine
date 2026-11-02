#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * Play a fixed list of commands and print the transcript with the status
 * line, as a bot or a test would: jennifer run examples/script.j
 *
 * Each step returns a new machine, so keeping an old one is an undo: the
 * last command goes back to the start and tries another way.
 */

use io;

import "../src/zmachine.j" as zmachine;

def start as zmachine.Machine init zmachine.run(zmachine.seed(
    zmachine.open("testdata/lantern.z3"),
    1));
io.printf("%s", zmachine.output($start));

def m as zmachine.Machine init $start;
for (def line in ["take lamp", "north", "drop lamp", "inventory"]) {
    $m = zmachine.send($m, $line);
    io.printf("%s\n%s", $line, zmachine.output($m));
}
io.printf("\nstatus: %s\n", zmachine.upperWindow($m)[0]);

def other as zmachine.Machine init zmachine.send($start, "north");
io.printf("\nfrom the start instead: north\n%s\n", zmachine.output($other));
io.printf("status: %s\n", zmachine.upperWindow($other)[0]);
