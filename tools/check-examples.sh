#!/usr/bin/env bash
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
#
# How this deck's examples are checked. This file belongs to the deck, not to
# the shared CI layer: the workflows call it, and it is the place to say what
# the examples need.
#
# Every example is run by tools/check-examples-shared.sh. They play the story
# files in testdata/ by relative path, so this runs from the repository root;
# examples/play.j reads commands from stdin until it ends, so stdin is empty.
#
# Usage: tools/check-examples.sh
set -euo pipefail
cd "$(dirname "$0")/.."
exec tools/check-examples-shared.sh "$@" < /dev/null
