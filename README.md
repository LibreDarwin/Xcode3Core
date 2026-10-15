# Xcode3Core

Clean-room, BSD-3 reimplementation of Apple's `Xcode3Core` for the
LibreDarwin release-control toolchain.

Apple's `Xcode3Core` is the IDE plugin that supplied the project model,
data model and build system used by the Xcode 3 era (and still embedded
in current Xcode as `Xcode3Core.ideplugin`, alongside its private
`DevToolsCore.framework` and `DevToolsSupport.framework`).  We reproduce
its components — and the command-line tools that ship next to them —
from observable behavior.

The project is built up one component at a time.  The first, complete
component is `agvtool`.

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

Both writers place products in `build/$(CONFIG)`.

## Layout

    Sources/DevToolsCore/
        agvtool/        the agvtool command
        ProjectModel/   (planned) the project model
        DataModel/      (planned) the data model
        BuildSystem/    (planned) the build system
        RuntimeSupport/ (planned) runtime support
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

## License

BSD 3-Clause, Copyright (c) 2026 LibreDarwin.  See LICENSE.
