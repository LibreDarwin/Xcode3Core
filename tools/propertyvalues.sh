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

OUTPUT=$(mktemp "${TMPDIR:-/tmp}/xcpropertyvalues.XXXXXX")
trap 'rm -f "$OUTPUT"' EXIT

"$PBXMODEL" propertyvalues > "$OUTPUT" || exit 1
if diff -u "$ROOT/tools/fixtures/propertyvalues.expected" "$OUTPUT"; then
	echo "propertyvalues: OK"
else
	echo "propertyvalues: FAIL" >&2
	exit 1
fi
