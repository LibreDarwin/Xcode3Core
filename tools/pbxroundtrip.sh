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
#   4. key losslessness    -- the multiset of dictionary keys in the source
#      equals that produced by re-archiving the object graph.  Catches an
#      attribute being dropped by the typed model (which the semantic check
#      cannot see, because a key dropped on both sides still compares equal).
#      This uses `pbxtool dump` on the source and on `pbxmodel cat`, so it is
#      immune to comments/inline-dict formatting.  Inputs that contain
#      duplicate object IDs (invalid, but present in the wild) are reported
#      and exempted: the ID-keyed model legitimately collapses them.
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
tmpcat=""
trap 'rm -f "$tmpcat"' EXIT
if [ "$CHECK_BYTES" = 1 ]; then
	dumpkeys() { "$PBXTOOL" dump "$1" 2>/dev/null | grep -oE '^[[:space:]]*[^[:space:]].*:$' | sed -E 's/^[[:space:]]+//; s/:$//' | sort | uniq -c; }
	dupids() {
		"$PBXTOOL" dump "$1" 2>/dev/null | awk '
		/^[[:space:]]*objects:[[:space:]]*$/ {want=1; next}
		want==1 && /^[[:space:]]*dict\[/ {match($0,/^[[:space:]]*/); base=RLENGTH; want=2; next}
		want==2 {
			if ($0 ~ /^[[:space:]]*$/) next
			match($0,/^[[:space:]]*/); ind=RLENGTH
			if (ind==base) {want=0; next}
			if (ind==base+1 && $0 ~ /:$/) { k=$0; gsub(/^[[:space:]]+|:$/,"",k); print k }
		}'
	}
else
	dumpkeys() { :; }
	dupids() { :; }
fi

for f in "${files[@]}"; do
	if [ ! -e "$f" ]; then
		FAIL=$((FAIL+1))
		printf 'FAIL  %s -- not found\n' "$f"
		continue
	fi
	if [ ! -s "$f" ]; then
		FAIL=$((FAIL+1))
		printf 'FAIL  %s -- empty\n' "$f"
		continue
	fi
	why=""
	note=""
	# detect duplicate object IDs (invalid; model collapses by ID)
	if [ "$CHECK_BYTES" = 1 ]; then
		ndup=$(dupids "$f" | sort | uniq -d | wc -l | tr -d ' ')
		[ "$ndup" -gt 0 ] && note=" dup-id:$ndup"
	fi
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
	# 4. structural key losslessness (skipped if duplicate IDs: model collapses)
	if [ "$CHECK_BYTES" = 1 ] && [ -z "$why" ] && [ "${ndup:-0}" -eq 0 ]; then
		tmpcat=$(mktemp "${TMPDIR:-/tmp}/pbxrt.XXXXXX")
		if ! "$PBXMODEL" cat "$f" > "$tmpcat" 2>/dev/null; then
			why="$why keys:cat-fail"
		elif ! diff -q <(dumpkeys "$f") <(dumpkeys "$tmpcat") >/dev/null; then
			why="$why keys"
		fi
		rm -f "$tmpcat"
		tmpcat=""
	elif [ "$CHECK_BYTES" = 1 ] && [ "${ndup:-0}" -gt 0 ]; then
		note="$note (keys:skipped-dup-id)"
	fi

	if [ -z "$why" ]; then
		printf 'PASS  %s%s\n' "$f" "$note"
	else
		FAIL=$((FAIL+1))
		printf 'FAIL  %s --%s\n' "$f" "$why"
	fi
done

echo "=== $FAIL failure(s) over ${#files[@]} file(s) ==="
exit $FAIL
