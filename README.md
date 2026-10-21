# Xcode3Core

Clean-room, BSD-3 reimplementation of Apple's `Xcode3Core` for the
LibreDarwin release-control toolchain.

Apple's `Xcode3Core` is the IDE plugin that supplied the project model,
data model and build system used by the Xcode 3 era (and still embedded
in current Xcode as `Xcode3Core.ideplugin`, alongside its private
`DevToolsCore.framework` and `DevToolsSupport.framework`).  We reproduce
its components — and the command-line tools that ship next to them —
from observable behavior.

The project is built up one component at a time.  The first complete
component is `agvtool`; the OpenStep `project.pbxproj` reader/writer
(`pbxtool`) and its typed object graph (`pbxmodel`) follow on top of it.

## Why clean-room

The Xcode3Core sources are not public, and `DevToolsCore` /
`DevToolsSupport` are private frameworks.  This project therefore
reimplements behavior from the ground up, without deriving from any
Apple source, using only:

  - the documented, observable interface of each tool,
  - black-box behavior of the shipped binaries as the oracle.

For `agvtool` — which is a `/bin/sh` script, not a binary — there is
nothing to be byte-identical with, so the fixed contract is its
observable behavior: stdout, stderr, exit status and the in-place edits
it makes to `project.pbxproj`, `Info.plist` and related files.

## Building

    make            # builds the tools under Sources/DevToolsCore/
    make test       # differential test of agvtool vs. Apple's (needs Xcode)
    make install    # binaries + man pages under $(PREFIX)

    # Alternative build system (Xcode):
    xcodebuild -project Xcode3Core.xcodeproj -target agvtool build
    xcodebuild -project Xcode3Core.xcodeproj -target pbxtool build
    xcodebuild -project Xcode3Core.xcodeproj -target pbxmodel build

Both writers place products in `build/$(CONFIG)`.

## Layout

    Sources/DevToolsCore/
        agvtool/        the agvtool command
        ProjectModel/   OpenStep project.pbxproj reader/writer + object graph
        pbxtool/        the pbxtool command
        pbxmodel/       the pbxmodel command
        DataModel/      (planned) the data model
        BuildSystem/    (planned) the build system
        RuntimeSupport/ (planned) runtime support
    Headers/DevToolsCore/  public headers of the project-model object graph
    Sources/DevToolsSupport/  (planned) DevToolsSupport
    Sources/XcodePlugIns/     (planned) IDE plug-ins
    tools/          conformance tests
    man/            manual pages
    make/           per-configuration build flags

## agvtool

`agvtool` drives the Apple-generic versioning system for Xcode
projects: it reads and sets `CURRENT_PROJECT_VERSION`,
`DYLIB_CURRENT_VERSION` and the `CFBundleShortVersionString` /
`CFBundleVersion` Info.plist keys, and (for Apple's internal use)
tags and submits projects by CVS or Subversion.  See
man/agvtool.1.

`make test` runs `tools/difftest.sh`, which runs Apple's shipped
`agvtool` and ours side by side over a matrix of projects and arguments
and requires identical stdout, stderr, exit status and resulting files.

## pbxtool

`pbxtool` reads and writes `project.pbxproj` at the OpenStep-property-list
layer.  `pbxtool roundtrip <file>` re-emits the file and requires a
byte-identical result; `pbxtool cat <file>` prints the re-emitted text;
`pbxtool dump <file>` prints the parsed value tree.

## pbxmodel

`pbxmodel` loads `project.pbxproj` into the typed `PBX*` / `XC*` object
graph (`DevToolsCore`'s `PBXProjectModel`).  `pbxmodel roundtrip <file>`
loads the graph, re-archives it, and verifies that re-parsing the result
yields the same project (semantic equality), that archiving the same model
is byte-stable, and that the archive is idempotent.  `pbxmodel cat <file>`
prints the canonical archive; `pbxmodel dump <file>` summarizes the object
graph by class.

The conformance bar over the corpus is that every `project.pbxproj` in the
tree survives `pbxmodel roundtrip` semantically (order, formatting and
comments ignored), and that Xcode-written files round-trip byte-exactly.

The object graph covers the classic container/build/target/reference
classes plus the modern ones Xcode emits: Swift packages
(`XCRemoteSwiftPackageReference`, `XCLocalSwiftPackageReference`,
`XCSwiftPackageProductDependency`), file-system-synchronized groups
(`PBXFileSystemSynchronized*`), `XCVersionGroup`,
`PBXAppleScriptBuildPhase` and `PBXJavaArchiveBuildPhase`.  An `isa` with no
modeled class is preserved verbatim rather than renamed to `PBXObject`.

`make test` also runs `tools/pbxroundtrip.sh` over `tools/fixtures/*.pbxproj`,
which exercise the modern classes, an unknown `isa`, `classes = {}` and
objectVersion 77, plus a multi-line array with no trailing comma.  It checks
the semantic round-trip, the byte-exact round-trip, isa losslessness and
structural key-losslessness (exempting files with duplicate object IDs).
It treats missing/empty inputs as failures (no silent skips).  Point it at
a corpus list to widen coverage, e.g. `bash tools/pbxroundtrip.sh /path/to/list`.

## License

BSD 3-Clause, Copyright (c) 2026 LibreDarwin.  See LICENSE.
