#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
#
# Rebuild the story files in testdata/ from their Inform sources. Deck-owned,
# not part of the shared CI layer; CI uses the committed story files and never
# runs this.
#
# Needs Inform 6 (https://github.com/DavidKinder/Inform6) on PATH as inform6,
# or named by $INFORM.
#
# Usage: tools/build-fixtures.sh
set -euo pipefail
cd "$(dirname "$0")/../testdata"

inform="${INFORM:-inform6}"
command -v "$inform" > /dev/null || { echo "error: $inform not found; set INFORM" >&2; exit 1; }

for v in 3 4 5 7 8; do
    "$inform" -q "-v$v" czech/czech.inf "czech/czech.z$v" > /dev/null
done
"$inform" -q praxix/praxix.inf praxix/praxix.z5 > /dev/null
for v in 3 5 8; do
    "$inform" -q "-v$v" lantern.inf "lantern.z$v" > /dev/null
done
echo "rebuilt the story files in testdata/"
