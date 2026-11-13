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
- [x] PBXPlatformFilter, PBXObjectID, PBXGroupEnumerator
- [x] PBXNamePath/PBXNamePathComponent, PBXAnchoredReference
- [x] PBXPlatformFilterableItem superclass for PBXBuildFile
- [x] PBXContainer path model (path/basePath/absolutePath/resolvedAbsolutePath,
      container registry, item/reference lookup) and PBXFolder/PBXFramework
- [x] PBXFileTypePart (abstract base; DevToolsCore ships no concrete parts)

## In Progress / Next
### 1) Deepen ProjectModel parity
- [x] Complete PBXProject API surface (projectReferences, userBuildSettings, attributes handling, root object behavior) to match Apple behavior
- [x] Complete PBXTarget/PBXProjectItem behaviors, dependencies resolution, display names/comments
- [x] Complete PBXBuildFile settings, platform filters; PBXBuildPhase ordering/semantics
- [x] Complete PBXGroup/PBXFileReference/PBXVariantGroup/XCVersionGroup full APIs
- [x] Ensure archiving canonical order matches Apple for all cases; verify on broader corpus (1088/1088 byte-exact)
- [ ] PBX*ProductType classes: require XCSpecification (BuildSystem), runtime-only and never archived; defer to item 3
- [ ] PBXArchivingBinding/PBXUnarchivingBinding family: depends on AppKit
      NSKeyBinding and on a PListArchiver API (writeValueForObject:toPListArchiver:,
      pbxPlistArchiver:overrideValue:forArchivingKey:) that we do not expose.
      They are not used by the archive path we implement; defer until an
      AppKit-dependent consumer appears.
- [ ] PBXExtendedWrapperPart / PBXFileSystemSynchronizedGroupRelativeReferenceID:
      small runtime-only value objects, not used by the archive path
- [ ] PBXFileType family: depends on XCSpecification; defer to item 3

### 2) DataModel (Core Data model format)
Note: no XCDataModel/XCEntity/XCAttribute/XCRelationship classes exist in
DevToolsCore or Xcode3Core (verified against the binaries and the 264-class
list); Core Data model editing lives in the IDE plugins. Keep the scaffold
only unless a real dependency appears.
- [ ] Confirm no DevToolsCore integration point exists
- [ ] Reverse-engineer .xcdatamodel/.xcdatamodeld parsing/writing only if needed
- [ ] Implement XCDataModel, XCVersionedDataModel, XCEntity, XCAttribute, XCRelationship etc to match Apple behavior

### 3) BuildSystem
- [x] XCSpecification / XCSpecificationProxy / XCSpecificationRegistry / XCSpecificationFilter
- [x] PBXFileType and the PBXProject file-type sets (header/source/rezzable/linkable/appleScript)
- [x] PBXBuildPhase family: identifiers, default names, archivable key tables,
      template construction, file-type filters, reference acceptance
- [ ] Reverse-engineer XCBuildConfiguration/XCConfigurationList usage in build context
- [ ] XCDependencyGraph, build settings expansion, macro evaluation
- [ ] Target dependencies/phase ordering
- [x] Spec loading (.xcspec) compatibility
      (+registerSpecificationProxiesFromPropertyListsInDirectory:recursively:inDomain:inBundle:,
       _registerSpecificationProxiesOfType:fromDictionaryOrArray:inDirectory:bundle:
       sourceDescription:inDomain:, _shouldRecurseIntoDirectoryNamed:ofType:,
       _tryRegisterLocalizationDictionaryForSpecification:bundle:; returns NSError arrays)
- [x] DVTFilePath and DVTPlugInManager (DVTFoundation) partial shims used by spec loading
- [ ] PBX*ProductType family (unblocked once spec loading can instantiate XCProductTypeSpecification)

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
