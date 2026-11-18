#!/bin/bash
set -u

PBXMODEL=${PBXMODEL:-build/release/pbxmodel}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [ ! -x "$PBXMODEL" ]; then
	echo "error: $PBXMODEL not built (try: make)" >&2
	exit 1
fi

OUTPUT=$(mktemp "${TMPDIR:-/tmp}/runtimevalues.XXXXXX")
trap 'rm -f "$OUTPUT"' EXIT

"$PBXMODEL" runtimevalues > "$OUTPUT" || exit 1
if diff -u "$ROOT/tools/fixtures/runtimevalues.expected" "$OUTPUT"; then
	echo "runtimevalues: OK"
else
	echo "runtimevalues: FAIL" >&2
	exit 1
fi
