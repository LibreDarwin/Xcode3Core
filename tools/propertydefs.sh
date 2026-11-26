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

OUTPUT=$(mktemp "${TMPDIR:-/tmp}/propertydefs.XXXXXX")
trap 'rm -f "$OUTPUT"' EXIT

"$PBXMODEL" propertydefs > "$OUTPUT" || exit 1
if diff -u "$ROOT/tools/fixtures/propertydefs.expected" "$OUTPUT"; then
	echo "propertydefs: OK"
else
	echo "propertydefs: FAIL" >&2
	exit 1
fi
