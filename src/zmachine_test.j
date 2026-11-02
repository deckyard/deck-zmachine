# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * White-box unit tests for the zmachine module.
 *
 * Run with `jennifer test src/zmachine_test.j` from the repository root. One
 * test file per topic under `topics/`, spliced with `include` in the order
 * `zmachine.j` splices the topics. Lantern, the test game, is embedded in
 * `topics/fixtures/`; the conformance suites in `testdata/` (see its README)
 * run only from a checkout.
 */

use testing;
use encoding;

include "topics/core_test.j";
include "topics/text_test.j";
include "topics/objects_test.j";
include "topics/screen_test.j";
include "topics/story_test.j";
include "topics/exec_test.j";
include "topics/quetzal_test.j";
