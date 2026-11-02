<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# Saving, restoring and undo

```jennifer
import "@deckyard/zmachine/" as zmachine;
```

## Saving

When the player saves, the machine stops with `Wait.Save`. `saveData(m)` is
the save file in Quetzal format, the one most other interpreters write.
Saves move between this deck and Frotz in both directions. Store it where
the host keeps files, then tell the game whether that worked:

```jennifer
if (zmachine.waiting($m) == zmachine.Wait.Save) {
    fs.writeBytes("story.qzl", zmachine.saveData($m));
    $m = zmachine.resume($m, true);
}
```

`resume(m, false)` makes the game report a failed save.

## Restoring

When the player restores, the machine stops with `Wait.Restore`. Hand it the
file:

```jennifer
$m = zmachine.restore($m, fs.readBytes("story.qzl"));
```

The game goes on from the `save` that wrote the file, which now reports
success (Zork says "Ok."). `restore` throws on a file that is not a Quetzal
save, is damaged, or belongs to another story or release (the header's
release, serial and checksum must match); the machine passed in is still
waiting, and `resume(m, false)` turns the restore down.

## Undo

Version 5 and later games implement `undo` themselves with the `save_undo` and
`restore_undo` opcodes. The machine keeps the last 8 states.

The host has an undo of its own: every call returns a new machine, so keeping
the previous one and playing on from it takes a turn back.

```jennifer
def before as zmachine.Machine init $m;
$m = zmachine.send($m, "jump into the chasm");
$m = $before;
```

## Not supported

Saving or restoring a table to an auxiliary file (`save` and `restore` with
operands, used by a few games for high scores) fails quietly, as an
interpreter without a file system may.
