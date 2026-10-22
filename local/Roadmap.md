# LibreDarwin Xcode3Core — Roadmap

We must achieve behavioral parity and, where specified, byte-identical output with Apple's Xcode3Core/DevToolsCore. Use only observable behavior + RE.

## Completed
- [x] agvtool: byte-identical behavior vs Apple's script (difftest green)
- [x] pbxtool (OpenStep plist): byte-identical roundtrip on corpus
- [x] ProjectModel object graph: full class coverage for corpus + Apple-known classes; semantic roundtrip + stability + idempotence; unknown isa preserved; structural key-losslessness checks
- [x] Modern Xcode classes (Swift packages, FS-synchronized groups/exceptions), XCVersionGroup
- [x] Trailing-comma preservation, quoting fixes, dict append/perf fixes
- [x] Target/reference classes expanded (PBX{Application,Bundle,Framework,Library,Tool,Jambase,Wrapped,Standalone,External}Target, PBX*Reference variants, PBXReferenceProxy)
- [x] FS-synchronized exceptions (all three variants)
- [x] Scaffolds for DataModel, BuildSystem, RuntimeSupport, DevToolsSupport, XcodePlugIns

## In Progress / Next
### 1) Deepen ProjectModel parity
- [ ] Complete PBXProject API surface (projectReferences, userBuildSettings, attributes handling, root object behavior) to match Apple behavior
- [ ] Complete PBXTarget/PBXProjectItem behaviors, dependencies resolution, display names/comments
- [ ] Complete PBXBuildFile settings, platform filters; PBXBuildPhase ordering/semantics
- [ ] Complete PBXGroup/PBXFileReference/PBXVariantGroup/XCVersionGroup full APIs
- [ ] Ensure archiving canonical order matches Apple for all cases; verify on broader corpus
- [ ] Handle all PBX*ProductType classes if seen (from Apple binary) - add if required

### 2) DataModel (Core Data model format)
- [ ] Reverse-engineer .xcdatamodel/.xcdatamodeld parsing/writing
- [ ] Implement XCDataModel, XCVersionedDataModel, XCEntity, XCAttribute, XCRelationship etc to match Apple behavior
- [ ] Integration points if used by DevToolsCore

### 3) BuildSystem
- [ ] Reverse-engineer XCBuildConfiguration/XCConfigurationList usage in build context
- [ ] XCDependencyGraph, build settings expansion, macro evaluation
- [ ] Target dependencies/phase ordering
- [ ] Spec loading (.xcspec) compatibility

### 4) RuntimeSupport
- [ ] Macro expansion (XCMacroExpansionExtensions), SDK/package handling
- [ ] Environment/paths behavior

### 5) pbxtool/pbxmodel parity hardening
- [ ] Eliminate any remaining byte differences on Apple-written projects
- [ ] Strengthen roundtrip harness against larger corpora
- [ ] Handle all edge cases in OPP parser/writer

### 6) DevToolsSupport / XcodePlugIns
- [ ] Reverse-engineer and implement needed APIs

## Methodology
1. Extract class/method lists from Apple's DevToolsCore/Xcode3Core
2. Dump behaviors from real projects
3. Implement to match, test against corpus + difftest
4. Never guess - RE with disarm/ipsw/jtool2/rea/ghidra
5. Commit frequently with descriptive messages
