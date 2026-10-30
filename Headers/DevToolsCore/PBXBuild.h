/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Build-file, build-phase and build-rule classes (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXBUILD_H
#define DEVTOOLSCORE_PBXBUILD_H

#import "DevToolsCore/PBXReference.h"

@class PBXFileReference, PBXTarget, XCBuildConfiguration;

/* A file's membership in a build phase. */
@interface PBXBuildFile : PBXProjectItem
{
	PBXFileReference *_fileRef;
	PBXReference *_productRef;
	NSMutableDictionary *_settings;
	NSArray *_platformFilters;
	NSArray *_assetTags;
	NSString *_platformFilter;
}
- (PBXFileReference *)fileRef;
- (void)setFileRef:(PBXFileReference *)reference;
- (PBXReference *)productRef;
- (void)setProductRef:(PBXReference *)reference;
- (NSMutableDictionary *)settings;
- (void)setSettings:(NSDictionary *)settings;
- (NSArray *)platformFilters;
- (void)setPlatformFilters:(NSArray *)filters;
- (NSString *)platformFilter;
- (void)setPlatformFilter:(NSString *)filter;
- (NSArray *)assetTags;
- (void)setAssetTags:(NSArray *)tags;
@end

/* Base class for the build phases attached to a target. */
@interface PBXBuildPhase : PBXProjectItem
{
	NSString *_name;
	NSNumber *_buildActionMask;
	NSNumber *_runOnlyForDeploymentPostprocessing;
	NSMutableArray *_files;
	NSMutableArray *_customBuildRules;
}
+ (NSString *)defaultName;
- (NSString *)name;
- (void)setName:(NSString *)name;
- (NSNumber *)buildActionMask;
- (void)setBuildActionMask:(NSNumber *)mask;
- (NSNumber *)runOnlyForDeploymentPostprocessing;
- (void)setRunOnlyForDeploymentPostprocessing:(NSNumber *)flag;
- (NSArray *)files;
- (void)setFiles:(NSArray *)files;
- (void)addFile:(PBXBuildFile *)file;
- (NSArray *)customBuildRules;
- (void)setCustomBuildRules:(NSArray *)rules;
- (NSString *)displayName;
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
