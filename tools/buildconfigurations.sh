#!/bin/bash
# Copyright (C) 2026, LibreDarwin
# SPDX-License-Identifier: BSD-3-Clause
#
set -u

PBXMODEL=${PBXMODEL:-build/release/pbxmodel}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [ ! -x "$PBXMODEL" ]; then
	echo "error: $PBXMODEL not built (try: make)" >&2
	exit 1
fi

OUTPUT=$(mktemp "${TMPDIR:-/tmp}/buildconfigurations.XXXXXX")
trap 'rm -f "$OUTPUT"' EXIT

"$PBXMODEL" buildconfigurations > "$OUTPUT" || exit 1
if diff -u "$ROOT/tools/fixtures/buildconfigurations.expected" "$OUTPUT"; then
	echo "buildconfigurations: OK"
else
	echo "buildconfigurations: FAIL" >&2
	exit 1
fi
