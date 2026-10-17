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
@end

/* Base class for the build phases attached to a target. */
@interface PBXBuildPhase : PBXProjectItem
{
	NSString *_name;
	NSNumber *_buildActionMask;
	NSNumber *_runOnlyForDeploymentPostprocessing;
	NSMutableArray *_files;
}
+ (NSString *)defaultName;
- (NSString *)name;
- (void)setName:(NSString *)name;
- (NSArray *)files;
- (void)setFiles:(NSArray *)files;
- (void)addFile:(PBXBuildFile *)file;
- (NSString *)displayName;
@end

@interface PBXCopyFilesBuildPhase : PBXBuildPhase
{
	NSString *_dstPath;
	NSNumber *_dstSubfolderSpec;
}
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
@end

@interface PBXHeadersBuildPhase : PBXBuildPhase @end
@interface PBXSourcesBuildPhase : PBXBuildPhase @end
@interface PBXFrameworksBuildPhase : PBXBuildPhase @end
@interface PBXResourcesBuildPhase : PBXBuildPhase @end
@interface PBXRezBuildPhase : PBXBuildPhase @end

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
}
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
