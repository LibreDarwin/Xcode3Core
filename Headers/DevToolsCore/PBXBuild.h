/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Build-file, build-phase and build-rule classes (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXBUILD_H
#define DEVTOOLSCORE_PBXBUILD_H

#import "DevToolsCore/PBXPlatformFilterableItem.h"
#import "DevToolsCore/PBXReference.h"

@class PBXFileReference, PBXFileType, PBXTarget, XCBuildConfiguration,
    XCSpecificationFilter;

/* A file's membership in a build phase. */
@interface PBXBuildFile : PBXPlatformFilterableItem
{
	PBXFileReference *_fileRef;
	PBXReference *_productRef;
	NSMutableDictionary *_settings;
	NSArray *_assetTags;
	__weak PBXBuildPhase *_buildPhase;
}
+ (instancetype)buildFileWithReference:(PBXFileReference *)reference;
- (instancetype)initWithReference:(PBXFileReference *)reference;
- (instancetype)initWithProductReference:(PBXReference *)reference;
- (PBXFileReference *)fileRef;
- (void)setFileRef:(PBXFileReference *)reference;
- (PBXFileReference *)fileReference;
- (PBXReference *)reference;
- (PBXReference *)productRef;
- (void)setProductRef:(PBXReference *)reference;
- (PBXReference *)productReference;
- (NSMutableDictionary *)settings;
- (void)setSettings:(NSDictionary *)settings;
- (BOOL)shouldArchiveSettings;
- (NSArray *)assetTags;
- (void)setAssetTags:(NSArray *)tags;
- (NSSet *)attributes;
- (void)setAttributes:(NSSet *)attributes;
- (BOOL)boolValueOfAttributeNamed:(NSString *)name;
- (void)setBoolValue:(BOOL)value ofAttributeNamed:(NSString *)name;
- (NSArray *)additionalCompilerArguments;
- (void)setAdditionalCompilerArguments:(NSArray *)arguments;
- (NSString *)additionalCompilerArgumentsAsString;
- (void)setAdditionalCompilerArgumentsAsString:(NSString *)string;
- (NSString *)primaryAttribute;
- (NSString *)stringValueForPrimaryAttribute;
- (NSString *)name;
- (PBXBuildPhase *)buildPhase;
- (void)setBuildPhase:(PBXBuildPhase *)phase;
- (PBXTarget *)target;
- (NSString *)displayName;
- (NSComparisonResult)compareName:(NSString *)name;
- (NSComparisonResult)compareFullPath:(NSString *)path;
@end

/* Base class for the build phases attached to a target. */
@interface PBXBuildPhase : PBXProjectItem
{
	NSString *_name;
	NSNumber *_buildActionMask;
	NSNumber *_runOnlyForDeploymentPostprocessing;
	NSMutableArray *_files;
	NSMutableArray *_customBuildRules;
	__weak PBXTarget *_target;
}
+ (NSString *)identifier;
+ (NSString *)defaultName;
+ (instancetype)buildPhase;
+ (instancetype)buildPhaseFromTemplateDictionary:(NSDictionary *)dictionary;
+ (id)fileTypeForCheckingAcceptanceOfReference:(PBXReference *)reference;
+ (BOOL)allowedFileTypes:(XCSpecificationFilter *)filter
    acceptReference:(PBXReference *)reference;
+ (XCSpecificationFilter *)allowedFileTypes;
+ (NSString *)archiveNameForKey:(NSString *)key;
- (NSString *)name;
- (void)setName:(NSString *)name;
- (NSNumber *)buildActionMask;
- (void)setBuildActionMask:(NSNumber *)mask;
- (NSNumber *)runOnlyForDeploymentPostprocessing;
- (void)setRunOnlyForDeploymentPostprocessing:(NSNumber *)flag;
- (NSArray *)files;
- (void)setFiles:(NSArray *)files;
- (void)addFile:(PBXBuildFile *)file;
- (NSArray *)buildFiles;
- (NSArray *)archivedBuildFiles;
- (void)setArchivedBuildFiles:(NSArray *)files;
- (void)insertBuildFiles:(NSArray *)files atIndex:(NSUInteger)index;
- (void)insertBuildFile:(PBXBuildFile *)file atIndex:(NSUInteger)index;
- (void)addBuildFile:(PBXBuildFile *)file;
- (void)addBuildFiles:(NSArray *)files;
- (void)removeBuildFile:(PBXBuildFile *)file;
- (void)removeBuildFiles:(NSArray *)files;
- (PBXBuildFile *)buildFileForReference:(PBXReference *)reference;
- (PBXBuildFile *)buildFileForProductReference:(PBXReference *)reference;
- (BOOL)containsFileReferenceIdenticalTo:(PBXReference *)reference;
- (PBXTarget *)target;
- (void)setTarget:(PBXTarget *)target;
- (BOOL)canRename;
- (BOOL)isDeletable;
- (BOOL)acceptsReference:(PBXReference *)reference;
- (BOOL)acceptsReference:(PBXReference *)reference
    checkFileType:(BOOL)checkFileType;
- (BOOL)allowsFileType:(PBXFileType *)fileType;
- (id)primaryAttributeForBuildFile:(PBXBuildFile *)file;
- (BOOL)acceptsVariantGroups;
- (BOOL)phaseContainsJavaFiles;
- (BOOL)phaseContainsNonJavaFiles;
- (NSArray *)customBuildRules;
- (void)setCustomBuildRules:(NSArray *)rules;
@end

@interface PBXCopyFilesBuildPhase : PBXBuildPhase
{
	NSString *_dstPath;
	NSNumber *_dstSubfolderSpec;
	NSString *_dstSubfolderSpecName;
}
- (NSString *)dstPath;
- (void)setDstPath:(NSString *)path;
- (NSNumber *)dstSubfolderSpec;
- (void)setDstSubfolderSpec:(NSNumber *)spec;
- (NSString *)dstSubfolderSpecName;
- (void)setDstSubfolderSpecName:(NSString *)name;
@end

@interface PBXShellScriptBuildPhase : PBXBuildPhase
{
	NSString *_shellPath;
	NSString *_shellScript;
	NSString *_dependencyFile;
	NSArray *_inputPaths;
	NSArray *_outputPaths;
	NSArray *_inputFileListPaths;
	NSArray *_outputFileListPaths;
	NSNumber *_alwaysOutOfDate;
	NSNumber *_showEnvVarsInLog;
}
- (NSString *)shellPath;
- (void)setShellPath:(NSString *)path;
- (NSString *)shellScript;
- (void)setShellScript:(NSString *)script;
- (id<NSCopying>)archivedShellScript;
- (void)setArchivedShellScript:(id<NSCopying>)script;
- (NSString *)dependencyFile;
- (void)setDependencyFile:(NSString *)path;
- (NSArray *)inputPaths;
- (void)setInputPaths:(NSArray *)paths;
- (NSArray *)outputPaths;
- (void)setOutputPaths:(NSArray *)paths;
- (NSArray *)inputFileListPaths;
- (void)setInputFileListPaths:(NSArray *)paths;
- (NSArray *)outputFileListPaths;
- (void)setOutputFileListPaths:(NSArray *)paths;
- (NSNumber *)alwaysOutOfDate;
- (void)setAlwaysOutOfDate:(NSNumber *)flag;
- (NSNumber *)showEnvVarsInLog;
- (void)setShowEnvVarsInLog:(NSNumber *)flag;
@end

@interface PBXHeadersBuildPhase : PBXBuildPhase @end
@interface PBXSourcesBuildPhase : PBXBuildPhase @end
@interface PBXFrameworksBuildPhase : PBXBuildPhase @end
@interface PBXResourcesBuildPhase : PBXBuildPhase @end
@interface PBXRezBuildPhase : PBXBuildPhase @end

/* AppleScript build phase (has context name / shared-context flag). */
@interface PBXAppleScriptBuildPhase : PBXBuildPhase
{
	NSString *_contextName;
	NSNumber *_isSharedContext;
}
- (NSString *)contextName;
- (void)setContextName:(NSString *)name;
- (NSNumber *)isSharedContext;
- (void)setIsSharedContext:(NSNumber *)flag;
@end

/* Java archive build phase (no phase-specific keys). */
@interface PBXJavaArchiveBuildPhase : PBXBuildPhase @end

/* A user-defined build rule. */
@interface PBXBuildRule : PBXProjectItem
{
	NSString *_compilerSpec;
	NSString *_filePatterns;
	NSString *_fileType;
	NSArray *_inputFiles;
	NSArray *_outputFiles;
	NSArray *_outputFilesCompilerFlags;
	NSNumber *_runOncePerArchitecture;
	NSString *_script;
	NSNumber *_isEditable;
	NSString *_name;
}
- (NSString *)compilerSpec;
- (void)setCompilerSpec:(NSString *)spec;
- (NSString *)filePatterns;
- (void)setFilePatterns:(NSString *)patterns;
- (NSString *)fileType;
- (void)setFileType:(NSString *)type;
- (NSArray *)inputFiles;
- (void)setInputFiles:(NSArray *)files;
- (NSArray *)outputFiles;
- (void)setOutputFiles:(NSArray *)files;
- (NSArray *)outputFilesCompilerFlags;
- (void)setOutputFilesCompilerFlags:(NSArray *)flags;
- (NSNumber *)runOncePerArchitecture;
- (void)setRunOncePerArchitecture:(NSNumber *)flag;
- (NSString *)script;
- (void)setScript:(NSString *)script;
- (NSNumber *)isEditable;
- (void)setIsEditable:(NSNumber *)flag;
- (NSString *)name;
- (void)setName:(NSString *)name;
@end

/* Legacy build style (buildStyles list in old projects). */
@interface PBXBuildStyle : PBXProjectItem
{
	NSString *_name;
	NSMutableDictionary *_buildSettings;
}
- (NSString *)name;
- (void)setName:(NSString *)name;
- (NSMutableDictionary *)buildSettings;
- (void)setBuildSettings:(NSDictionary *)settings;
@end

#endif	/* DEVTOOLSCORE_PBXBUILD_H */
