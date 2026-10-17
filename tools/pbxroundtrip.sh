#!/bin/bash
# Copyright (C) 2026, LibreDarwin
# SPDX-License-Identifier: BSD-3-Clause
#
# ProjectModel round-trip conformance over pbxproj files.
#
# For each input file we hold three things fixed:
#   1. pbxmodel roundtrip  -- semantic round-trip, stability and idempotence
#      (load -> archive -> re-parse -> deep-equal).
#   2. pbxtool roundtrip   -- byte-exact reproduction of Xcode-canonical input.
#   3. isa losslessness    -- every `isa = X;` in the source survives to the
#      archive.  This is what catches an unknown/new isa being silently
#      renamed (e.g. to PBXObject) or dropped.
#
# Usage: bash tools/pbxroundtrip.sh [FILE_OR_LIST ...]
#   No arguments : every tools/fixtures/*.pbxproj.
#   Directory    : recurse for project.pbxproj / *.pbxproj under it.
#   *.pbxproj    : a single project file.
#   Other file   : a corpus list, one path per line.
#
# Env: PBXMODEL, PBXTOOL override the tool paths.
#      PBXTOOL=off skips the byte-exact check.
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)

PBXMODEL=${PBXMODEL:-$root/build/release/pbxmodel}
PBXTOOL=${PBXTOOL:-$root/build/release/pbxtool}
CHECK_BYTES=1
[ "${PBXTOOL:-}" = off ] && CHECK_BYTES=0

[ -x "$PBXMODEL" ] || { echo "error: $PBXMODEL not built (try: make)" >&2; exit 1; }
[ "$CHECK_BYTES" = 1 ] && [ ! -x "$PBXTOOL" ] && { echo "error: $PBXTOOL not built (try: make)" >&2; exit 1; }

files=()
if [ $# -eq 0 ]; then
	for f in "$here"/fixtures/*.pbxproj; do
		[ -e "$f" ] && files+=("$f")
	done
else
	for arg in "$@"; do
		if [ -d "$arg" ]; then
			while IFS= read -r f; do
				[ -n "$f" ] && files+=("$f")
			done < <(find "$arg" \( -name project.pbxproj -o -name '*.pbxproj' \) -type f)
		elif [ -f "$arg" ] && [[ "$arg" == *.pbxproj ]]; then
			files+=("$arg")
		elif [ -f "$arg" ]; then
			while IFS= read -r f; do
				[ -n "$f" ] && files+=("$f")
			done < "$arg"
		else
			echo "warning: $arg: not found" >&2
		fi
	done
fi

if [ ${#files[@]} -eq 0 ]; then
	echo "=== 0 file(s) ==="
	exit 0
fi

FAIL=0
for f in "${files[@]}"; do
	if [ ! -s "$f" ]; then
		continue
	fi
	why=""
	# 1. semantic round-trip
	if ! "$PBXMODEL" roundtrip "$f" >/dev/null 2>&1; then
		why="$why semantic"
	fi
	# 2. byte-exact round-trip
	if [ "$CHECK_BYTES" = 1 ] && ! "$PBXTOOL" roundtrip "$f" >/dev/null 2>&1; then
		why="$why byte-exact"
	fi
	# 3. isa losslessness
	missing=""
	cat_out=$("$PBXMODEL" cat "$f" 2>/dev/null)
	while IFS= read -r isa; do
		[ -n "$isa" ] || continue
		case "$cat_out" in
			*"isa = $isa;"*) ;;
			*) missing="$missing $isa" ;;
		esac
	done < <(grep -oE 'isa = [A-Za-z0-9_]+' "$f" 2>/dev/null | sed 's/^isa = //' | sort -u)
	[ -n "$missing" ] && why="$why isa:[$missing ]"

	if [ -z "$why" ]; then
		printf 'PASS  %s\n' "$f"
	else
		FAIL=$((FAIL+1))
		printf 'FAIL  %s --%s\n' "$f" "$why"
	fi
done

echo "=== $FAIL failure(s) over ${#files[@]} file(s) ==="
exit $FAIL
