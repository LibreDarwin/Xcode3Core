#!/bin/bash
# Copyright (C) 2026, LibreDarwin
# SPDX-License-Identifier: BSD-3-Clause
#
# Differential test: Apple's agvtool (a /bin/sh script) versus ours (C).
#
# Apple's tool is a shell script, so there is nothing to be byte-identical
# with; what we hold fixed is its observable contract -- stdout, exit status
# and the in-place edits it makes -- across a matrix of projects and arguments.
#
# Usage: bash tools/difftest.sh [path-to-ours]
#   path-to-ours defaults to build/release/agvtool and must be named
#   "agvtool" (usage lines print basename $0).

set -u

APPLE=${APPLE_AGVTOOL:-/Applications/Xcode.app/Contents/Developer/usr/bin/agvtool}
MINE=${1:-build/release/agvtool}
FAIL=0

if [ ! -x "$APPLE" ]; then
	echo "SKIP: Apple's agvtool not found at $APPLE" >&2
	exit 0
fi
if [ ! -x "$MINE" ]; then
	echo "error: $MINE not built (try: make)" >&2
	exit 1
fi
MINE=$(cd "$(dirname "$MINE")" && pwd)/$(basename "$MINE")

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/agvtool-difftest.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT

mkproject() {  # $1 = dir; modern project with key, plist, -all capable
	local d="$1"
	mkdir -p "$d/MyApp.xcodeproj" "$d/MyApp"
	cat > "$d/MyApp.xcodeproj/project.pbxproj" <<'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 56;
	objects = {
		AA000001 /* Project object */ = {
			isa = PBXProject;
			buildConfigurationList = BB000001;
			INFOPLIST_FILE = MyApp/Info.plist;
			CURRENT_PROJECT_VERSION = 42;
			DYLIB_CURRENT_VERSION = 42;
			MODULE_VERSION = 42;
			PRODUCT_NAME = MyApp;
		};
	};
	rootObject = AA000001 /* Project object */;
}
EOF
	cat > "$d/MyApp/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleShortVersionString</key>
	<string>1.2.3</string>
	<key>CFBundleVersion</key>
	<string>42</string>
</dict>
</plist>
EOF
}

run_case() {
	# $1 = case name, $2 = fixture type, $3... = args
	local name="$1" fixture="$2"; shift 2
	rm -rf "$ROOT/a" "$ROOT/b"
	mkdir -p "$ROOT"
	case "$fixture" in
		modern) mkproject "$ROOT/a" ;;
		noversion)
			mkproject "$ROOT/a"
			sed -i '' '/CURRENT_PROJECT_VERSION/d;/DYLIB_CURRENT_VERSION/d' "$ROOT/a/MyApp.xcodeproj/project.pbxproj" ;;
		multiversion)
			mkproject "$ROOT/a"
			sed -i '' 's/CURRENT_PROJECT_VERSION = 42;/CURRENT_PROJECT_VERSION = 7;/' "$ROOT/a/MyApp.xcodeproj/project.pbxproj"
			printf '\t\tCURRENT_PROJECT_VERSION = 42;\n' >> "$ROOT/a/MyApp.xcodeproj/project.pbxproj" ;;
		multiplist)
			mkproject "$ROOT/a"
			mkdir -p "$ROOT/a/Clip"
			sed 's/1\.2\.3/9.9/' "$ROOT/a/MyApp/Info.plist" > "$ROOT/a/Clip/Info.plist"
			sed -i '' 's|INFOPLIST_FILE = MyApp/Info.plist;|INFOPLIST_FILE = MyApp/Info.plist;\n\t\t\tINFOPLIST_FILE = Clip/Info.plist;|' "$ROOT/a/MyApp.xcodeproj/project.pbxproj" ;;
		noplist)
			mkproject "$ROOT/a"
			sed -i '' '/INFOPLIST_FILE/d' "$ROOT/a/MyApp.xcodeproj/project.pbxproj" ;;
		noplproj) mkdir -p "$ROOT/a" ;;
		twoproj)
			mkproject "$ROOT/a"
			mkdir -p "$ROOT/a/Other.xcodeproj" ;;
		oldproj)
			mkdir -p "$ROOT/a/Legacy.pbproj"
			printf 'CURRENT_PROJECT_VERSION = 5;\n' > "$ROOT/a/Legacy.pbproj/project.pbxproj" ;;
		*) echo "bad fixture $fixture"; exit 1 ;;
	esac
	cp -R "$ROOT/a" "$ROOT/b" 2>/dev/null

	(cd "$ROOT/a" && "$APPLE" "$@" >"$ROOT/out.a" 2>"$ROOT/err.a"; echo $? > "$ROOT/rc.a")
	(cd "$ROOT/b" && "$MINE"   "$@" >"$ROOT/out.b" 2>"$ROOT/err.b"; echo $? > "$ROOT/rc.b")

	local ok=1 why=""
	diff -q "$ROOT/out.a" "$ROOT/out.b" >/dev/null || { ok=0; why="$why stdout"; }
	# The submit path execs ~rc/bin/submitproject; a permission failure is
	# reported by sh with its $0 and a line number we cannot reproduce, so
	# stderr is not part of the contract there (stdout and rc still are).
	case "$name" in
		submit*) : ;;
		*) diff -q "$ROOT/err.a" "$ROOT/err.b" >/dev/null || { ok=0; why="$why stderr"; } ;;
	esac
	[ "$(cat "$ROOT/rc.a")" = "$(cat "$ROOT/rc.b")" ] || { ok=0; why="$why rc($(cat "$ROOT/rc.a")vs$(cat "$ROOT/rc.b"))"; }
	diff -r "$ROOT/a" "$ROOT/b" >"$ROOT/dt" 2>&1 || { ok=0; why="$why files"; }

	if [ $ok = 1 ]; then
		printf 'PASS  %s\n' "$name"
	else
		FAIL=$((FAIL+1))
		printf 'FAIL  %s --%s\n' "$name" "$why"
		printf '      apple-out: %s\n' "$(head -c 400 "$ROOT/out.a" | tr '\n' '|')"
		printf '      ours-out : %s\n' "$(head -c 400 "$ROOT/out.b" | tr '\n' '|')"
		[ -s "$ROOT/dt" ] && sed 's/^/      /' "$ROOT/dt" | head -8
	fi
}

run_case "no-args"            modern
run_case "help"               modern help
run_case "help-empty-dir"     noplproj help
run_case "unknown-op"         modern frobnicate
run_case "unknown-op-nodir"   noplproj frobnicate
run_case "vers"               modern vers
run_case "vers-terse"         modern vers -terse
run_case "vers-badarg"        modern vers -bogus
run_case "vers-extra-arg"     modern vers -terse extra
run_case "vers-nodir"         noplproj vers
run_case "vers-noversion"     noversion vers
run_case "vers-noversion-terse" noversion vers -terse
run_case "vers-multiversion"  multiversion vers
run_case "bump"               modern bump
run_case "bump-all"           modern bump -all
run_case "bump-increment-minor" modern bump -increment-minor-version
run_case "bump-badarg"        modern bump -bogus
run_case "bump-noversion"     noversion bump
run_case "next-version"       modern next-version
run_case "new-version-noarg"  modern new-version
run_case "new-version-noarg2" modern new-marketing-version
run_case "new-version"        modern new-version 99
run_case "new-version-all"    modern new-version -all 99
run_case "new-version-empty"  modern new-version ""
run_case "new-version-2args"  modern new-version 99 100
run_case "mvers"              modern mvers
run_case "mvers-terse"        modern mvers -terse
run_case "mvers-terse1"       modern mvers -terse1
run_case "mvers-2plists"      multiplist mvers
run_case "mvers-2plists-terse" multiplist mvers -terse
run_case "mvers-2plists-terse1" multiplist mvers -terse1
run_case "mvers-noplist"      noplist mvers
run_case "mvers-noplist-terse" noplist mvers -terse
run_case "mvers-badarg"       modern mvers -bogus
run_case "mvers-nodir"        noplproj mvers
run_case "nmv"                modern new-marketing-version 2.0
run_case "nmv-2args"          modern new-marketing-version 2.0 3.0
run_case "nmv-noplist"        noplist new-marketing-version 2.0
run_case "nmv-allfiles"       multiplist new-marketing-version 2.0
run_case "tag"                modern tag
run_case "tag-nodir"          noplproj tag
run_case "submit"             modern submit
run_case "submit-noarg"       modern submit
run_case "submit-nodir"       noplproj submit
run_case "submit-with-arg"    modern submit myrel
run_case "submit-bytag"       modern submit -bytag myrel
run_case "twoproj"            twoproj vers
run_case "apple-built"        modern apple-built
run_case "flag-after-op"      modern vers -noscm
run_case "flag-first-bad"     modern -terse vers
run_case "unknownflag-global" modern -bytag vers
run_case "bump-all-noplist"   noplist bump -all
run_case "oldproj"            oldproj vers

echo "=== $FAIL failure(s) ==="
exit $FAIL
