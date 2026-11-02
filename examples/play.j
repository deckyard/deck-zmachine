#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * Play a story in the console: jennifer run examples/play.j [story]
 *
 * Without a story it plays testdata/lantern.z5. The game's save and restore
 * commands use <story>.qzl. Ends when the game quits or input runs out.
 */

use io;
use os;
use fs;

import "../src/zmachine.j" as zmachine;

def path as string init "testdata/lantern.z5";
if (len(os.ARGS) > 1) {
    $path = os.ARGS[1];
}
def saveFile as string init $path + ".qzl";

def m as zmachine.Machine init zmachine.run(zmachine.open($path));
while (true) {
    io.printf("%s", zmachine.output($m));
    def w as zmachine.Wait init zmachine.waiting($m);
    if ($w == zmachine.Wait.Quit) {
        break;
    }
    if ($w == zmachine.Wait.Save) {
        fs.writeBytes($saveFile, zmachine.saveData($m));
        $m = zmachine.resume($m, true);
        continue;
    }
    if ($w == zmachine.Wait.Restore) {
        if (not fs.isFile($saveFile)) {
            $m = zmachine.resume($m, false);
            continue;
        }
        try {
            $m = zmachine.restore($m, fs.readBytes($saveFile));
        } catch (e) {
            io.eprintf("%s\n", $e.message);
            $m = zmachine.resume($m, false);
        }
        continue;
    }
    if (io.eof()) {
        break;
    }
    $m = zmachine.send($m, io.readLine());
}
