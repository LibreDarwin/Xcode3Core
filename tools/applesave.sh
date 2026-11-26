#!/bin/bash
# Copyright (C) 2026, LibreDarwin
# SPDX-License-Identifier: BSD-3-Clause
set -u

PBXMODEL=${PBXMODEL:-build/release/pbxmodel}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/xc3applesave.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT

if [ ! -x "$PBXMODEL" ]; then
	echo "error: $PBXMODEL not built (try: make)" >&2
	exit 1
fi

check()
{
	name=$1
	source=$2
	expected=$3
	shift 3
	output="$TMP_DIR/$name.pbxproj"

	"$PBXMODEL" applesave "$ROOT/tools/fixtures/$source" "$output" "$@" ||
	    return 1
	if ! diff -u "$ROOT/tools/fixtures/applesave/$expected" "$output"; then
		echo "applesave: FAIL $name" >&2
		return 1
	fi
	echo "applesave: OK $name"
}

check dependencies dependencies.pbxproj dependencies.pbxproj ||
    exit 1
check expanded-api expanded-api.pbxproj expanded-api.pbxproj ||
    exit 1
check modern-features modern-features.pbxproj modern-features.pbxproj ||
    exit 1
check named-App modern-features.pbxproj named-App.pbxproj App ||
    exit 1
check named-Dep dependencies.pbxproj named-Dep.pbxproj Dep ||
    exit 1
check named-Test expanded-api.pbxproj named-Test.pbxproj Test ||
    exit 1

echo "applesave: OK"
