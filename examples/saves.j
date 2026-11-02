#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * Save a game to a Quetzal file and restore it in a new machine:
 * jennifer run examples/saves.j
 */

use io;
use fs;

import "../src/zmachine.j" as zmachine;

def dir as string init fs.makeTempDir("", "zmachine");
def file as string init $dir + "/lantern.qzl";

def m as zmachine.Machine init zmachine.run(zmachine.open("testdata/lantern.z5"));
$m = zmachine.send($m, "take lamp");
$m = zmachine.send($m, "north");
$m = zmachine.send($m, "save");
if (zmachine.waiting($m) == zmachine.Wait.Save) {
    fs.writeBytes($file, zmachine.saveData($m));
    $m = zmachine.resume($m, true);
}
io.printf("saved %d bytes: %s", fs.stat($file).size, zmachine.output($m));

def later as zmachine.Machine init zmachine.run(zmachine.open("testdata/lantern.z5"));
$later = zmachine.send($later, "restore");
$later = zmachine.restore($later, fs.readBytes($file));
$later = zmachine.send($later, "look");
io.printf("restored: %s", zmachine.output($later));

fs.remove($file);
fs.remove($dir);
