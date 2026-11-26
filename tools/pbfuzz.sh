#!/bin/bash
# Copyright (C) 2026, LibreDarwin
# SPDX-License-Identifier: BSD-3-Clause
set -u

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
PBXMODEL=${PBXMODEL:-$root/build/release/pbxmodel}
PBXTOOL=${PBXTOOL:-$root/build/release/pbxtool}
PYTHON=${FUZZ_PYTHON:-python3}
ITERATIONS=${FUZZ_ITERATIONS:-120}
SEED=${FUZZ_SEED:-20261126}
LIMIT=${FUZZ_TIMEOUT:-15}

[ -x "$PBXMODEL" ] || { echo "error: $PBXMODEL not built (try: make)" >&2; exit 1; }
[ -x "$PBXTOOL" ] || { echo "error: $PBXTOOL not built (try: make)" >&2; exit 1; }
command -v "$PYTHON" >/dev/null 2>&1 || { echo "error: $PYTHON not found" >&2; exit 1; }

if command -v timeout >/dev/null 2>&1; then
	run_limited() { timeout "$LIMIT" "$@"; }
else
	run_limited() { "$@"; }
fi

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
	echo "error: no seed project files" >&2
	exit 1
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/pbfuzz.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
mut="$WORK/mutant.pbxproj"
once="$WORK/once"
twice="$WORK/twice"
err="$WORK/err"
out="$WORK/out"

rng_seed=$SEED
next_rand()
{
	rng_seed=$(( (rng_seed * 1103515245 + 12345) % 2147483647 ))
	rand_value=$(( rng_seed % $1 ))
}

FAIL=0
fail()
{
	FAIL=$((FAIL+1))
	printf 'FAIL  i=%s src=%s -- %s\n' "$i" "$src" "$1"
	if [ -n "${FUZZ_KEEP:-}" ]; then
		mkdir -p "$FUZZ_KEEP"
		cp "$mut" "$FUZZ_KEEP/fuzz-$i-${src##*/}"
	fi
}

bad_status()
{
	[ "$1" -eq 124 ] || [ "$1" -eq 137 ] || [ "$1" -gt 128 ]
}

for ((i = 0; i < ITERATIONS; i++)); do
	next_rand ${#files[@]}
	src="${files[$rand_value]}"

	"$PYTHON" - "$src" "$mut" "$SEED" "$i" > "$WORK/mutate.err" 2>&1 <<'PY'
import random
import sys

source, destination, seed, index = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
with open(source, "rb") as handle:
    data = handle.read()
if not data:
    data = b"// !$*UTF8*$!\n{\n}\n"
rng = random.Random((seed << 32) ^ index)
mode = index % 12
pool = b"{}()=;,\"/\n\t ABCabc012"
tokens = [b"isa", b"PBXProject", b"objects", b"rootObject", b"YES", b"NO", b"1", b"A", b"NULL", b"PBXFileReference", b"buildConfigurationList", b"path", b"name", b"sourceTree", b"string", b"array", b"dict"]
if len(data) > 1:
    pos = rng.randrange(len(data))
    if mode == 0:
        data = data[:pos] + data[pos + 1:]
    elif mode == 1:
        data = data[:pos] + bytes([pool[rng.randrange(len(pool))]]) + data[pos:]
    elif mode == 2:
        data = data[:pos] + bytes([pool[rng.randrange(len(pool))]]) + data[pos + 1:]
    elif mode == 3:
        lines = data.splitlines(True)
        if len(lines) > 1:
            target = rng.randrange(len(lines))
            del lines[target]
            data = b"".join(lines)
        else:
            data = data[:pos] + data[pos + 1:]
    elif mode == 4:
        lines = data.splitlines(True)
        target = rng.randrange(len(lines))
        lines.insert(target, lines[target])
        data = b"".join(lines)
    elif mode == 5:
        lines = data.splitlines(True)
        if len(lines) > 1:
            target = rng.randrange(len(lines) - 1)
            lines[target], lines[target + 1] = lines[target + 1], lines[target]
            data = b"".join(lines)
        else:
            data = data[::-1]
    elif mode == 6:
        data = data[:rng.randrange(len(data) + 1)]
    elif mode == 7:
        token = rng.choice(tokens)
        offset = data.find(token, pos)
        if offset < 0:
            offset = data.find(token)
        if offset >= 0:
            data = data[:offset] + rng.choice(tokens) + data[offset + len(token):]
        else:
            data = data[:pos] + token + data[pos:]
    elif mode == 8:
        data = data[:pos] + b" " + rng.choice(tokens) + b" = " + rng.choice(tokens) + b";\n" + data[pos:]
    elif mode == 9:
        data = data + rng.choice(tokens) + b" = " + rng.choice(tokens) + b";\n"
    elif mode == 10:
        target = rng.randrange(len(data))
        data = data[:target] + bytes([pool[rng.randrange(len(pool))]]) + data[target + 1:]
    else:
        end = min(len(data), pos + rng.randrange(1, 64))
        data = data[:pos] + data[pos:end] + data[pos:]
else:
    data += b" " + rng.choice(tokens)
with open(destination, "wb") as handle:
    handle.write(data)
PY
	rc=$?
	if [ "$rc" -ne 0 ]; then
		fail "mutate:$(tr '\n' ' ' < "$WORK/mutate.err")"
		continue
	fi

	run_limited "$PBXMODEL" dump "$mut" > "$out" 2> "$err"
	rc=$?
	if bad_status "$rc"; then
		fail "model-dump-status:$rc"
		continue
	fi

	run_limited "$PBXMODEL" roundtrip "$mut" > "$out" 2> "$err"
	rc=$?
	if bad_status "$rc"; then
		fail "model-roundtrip-status:$rc"
		continue
	fi
	if [ "$rc" -ne 0 ] && grep -Eq 'UNSTABLE ARCHIVE|NOT IDEMPOTENT' "$err"; then
		fail "model-roundtrip-invariant:$(tr '\n' ' ' < "$err")"
		continue
	fi

	run_limited "$PBXMODEL" cat "$mut" > "$once" 2> "$err"
	rc=$?
	if bad_status "$rc"; then
		fail "model-cat-status:$rc"
		continue
	fi
	if [ "$rc" -eq 0 ]; then
		run_limited "$PBXMODEL" cat "$once" > "$twice" 2> "$err"
		rc=$?
		if bad_status "$rc"; then
			fail "model-cat-idempotence-status:$rc"
			continue
		fi
		if [ "$rc" -ne 0 ] || ! cmp -s "$once" "$twice"; then
			fail "model-cat-idempotence"
			continue
		fi
		run_limited "$PBXTOOL" roundtrip "$once" > "$out" 2> "$err"
		rc=$?
		if bad_status "$rc"; then
			fail "cross-roundtrip-status:$rc"
			continue
		fi
		if [ "$rc" -ne 0 ]; then
			fail "cross-roundtrip:$rc"
			continue
		fi
	fi

	run_limited "$PBXTOOL" dump "$mut" > "$out" 2> "$err"
	rc=$?
	if bad_status "$rc"; then
		fail "pbxtool-dump-status:$rc"
		continue
	fi

	run_limited "$PBXTOOL" cat "$mut" > "$once" 2> "$err"
	rc=$?
	if bad_status "$rc"; then
		fail "pbxtool-cat-status:$rc"
		continue
	fi
	if [ "$rc" -eq 0 ]; then
		run_limited "$PBXTOOL" cat "$once" > "$twice" 2> "$err"
		rc=$?
		if bad_status "$rc"; then
			fail "pbxtool-cat-idempotence-status:$rc"
			continue
		fi
		if [ "$rc" -ne 0 ] || ! cmp -s "$once" "$twice"; then
			fail "pbxtool-cat-idempotence"
			continue
		fi
	fi
done

echo "=== $FAIL failure(s) over $ITERATIONS mutant(s) from ${#files[@]} seed(s) ==="
exit "$FAIL"
