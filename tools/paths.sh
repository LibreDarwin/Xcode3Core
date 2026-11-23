#!/bin/bash
# Copyright (C) 2026, LibreDarwin
# SPDX-License-Identifier: BSD-3-Clause
set -u

PBXMODEL=${PBXMODEL:-build/release/pbxmodel}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [ ! -x "$PBXMODEL" ]; then
	echo "error: $PBXMODEL not built (try: make)" >&2
	exit 1
fi

OUTPUT=$(mktemp "${TMPDIR:-/tmp}/paths.XXXXXX")
trap 'rm -f "$OUTPUT"' EXIT

"$PBXMODEL" paths > "$OUTPUT" || exit 1
if diff -u "$ROOT/tools/fixtures/paths.expected" "$OUTPUT"; then
	echo "paths: OK"
else
	echo "paths: FAIL" >&2
	exit 1
fi
