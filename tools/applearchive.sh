#!/bin/bash
# Copyright (C) 2026, LibreDarwin
# SPDX-License-Identifier: BSD-3-Clause
set -u

PBXMODEL=${PBXMODEL:-build/release/pbxmodel}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
EXPECTED="$ROOT/tools/fixtures/applearchive.expected"

if [ ! -x "$PBXMODEL" ]; then
	echo "error: $PBXMODEL not built (try: make)" >&2
	exit 1
fi

if [ ! -f "$EXPECTED" ]; then
	echo "error: $EXPECTED not found" >&2
	exit 1
fi

OUTPUT=$(mktemp "${TMPDIR:-/tmp}/xc3applearchive.XXXXXX")
trap 'rm -f "$OUTPUT"' EXIT

status=0
while read -r expected name; do
	if [ -z "$expected" ] || [ -z "$name" ]; then
		continue
	fi

	project="$ROOT/tools/fixtures/$name"
	if [ ! -f "$project" ]; then
		echo "applearchive: FAIL $name (missing fixture)" >&2
		status=1
		continue
	fi

	if ! "$PBXMODEL" applearchive "$project" > "$OUTPUT"; then
		echo "applearchive: FAIL $name (archive)" >&2
		status=1
		continue
	fi

	actual=$(shasum -a 256 "$OUTPUT" | cut -d ' ' -f1)
	if [ "$actual" = "$expected" ]; then
		echo "applearchive: OK $name"
	else
		echo "applearchive: FAIL $name" >&2
		echo "expected: $expected" >&2
		echo "actual:   $actual" >&2
		status=1
	fi
done < "$EXPECTED"

if [ "$status" -ne 0 ]; then
	echo "applearchive: FAIL" >&2
else
	echo "applearchive: OK"
fi
exit "$status"
