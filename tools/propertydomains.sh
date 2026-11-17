#!/bin/bash
set -u

PBXMODEL=${PBXMODEL:-build/release/pbxmodel}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

if [ ! -x "$PBXMODEL" ]; then
	echo "error: $PBXMODEL not built (try: make)" >&2
	exit 1
fi

OUTPUT=$(mktemp "${TMPDIR:-/tmp}/propertydomains.XXXXXX")
trap 'rm -f "$OUTPUT"' EXIT

"$PBXMODEL" propertydomains > "$OUTPUT" || exit 1
if diff -u "$ROOT/tools/fixtures/propertydomains.expected" "$OUTPUT"; then
	echo "propertydomains: OK"
else
	echo "propertydomains: FAIL" >&2
	exit 1
fi
