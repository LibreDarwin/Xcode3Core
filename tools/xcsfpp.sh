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

OUTPUT=$(mktemp "${TMPDIR:-/tmp}/xcsfpp.XXXXXX")
trap 'rm -f "$OUTPUT"' EXIT

"$PBXMODEL" xcsfpp > "$OUTPUT" || exit 1
if diff -u "$ROOT/tools/fixtures/xcsfpp.expected" "$OUTPUT"; then
	echo "xcsfpp: OK"
else
	echo "xcsfpp: FAIL" >&2
	exit 1
fi
