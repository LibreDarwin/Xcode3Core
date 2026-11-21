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

OUTPUT=$(mktemp "${TMPDIR:-/tmp}/tsstringbom.XXXXXX")
trap 'rm -f "$OUTPUT"' EXIT

"$PBXMODEL" tsstringbom > "$OUTPUT" || exit 1
if diff -u "$ROOT/tools/fixtures/tsstringbom.expected" "$OUTPUT"; then
	echo "tsstringbom: OK"
else
	echo "tsstringbom: FAIL" >&2
	exit 1
fi
