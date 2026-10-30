/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Build-file, build-phase and build-rule classes (DevToolsCore). */

#import "DevToolsCore/PBXBuild.h"

@implementation PBXBuildFile

+ (NSString *)classNameForPListArchive
{
	return (@"PBXBuildFile");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"settings", @"platformFilter", @"platformFilters",
	    @"assetTags"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"fileRef", @"productRef"]);
}

- (PBXFileReference *)fileRef
{
	return (_fileRef);
}

- (void)setFileRef:(PBXFileReference *)reference
{
	_fileRef = reference;
}

- (PBXReference *)productRef
{
	return (_productRef);
}

- (void)setProductRef:(PBXReference *)reference
{
	_productRef = reference;
}

- (NSMutableDictionary *)settings
{
	return (_settings);
}

- (void)setSettings:(NSDictionary *)settings
{
	_settings = (settings != nil) ? [settings mutableCopy] : nil;
}

- (NSArray *)platformFilters
{
	return (_platformFilters);
}

- (void)setPlatformFilters:(NSArray *)filters
{
	_platformFilters = (filters != nil) ? [filters mutableCopy] : nil;
}

- (NSString *)platformFilter
{
	return (_platformFilter);
}

- (void)setPlatformFilter:(NSString *)filter
{
	_platformFilter = [filter copy];
}

- (NSArray *)assetTags
{
	return (_assetTags);
}

- (void)setAssetTags:(NSArray *)tags
{
	_assetTags = (tags != nil) ? [tags mutableCopy] : nil;
}

- (NSString *)archiveComment
{
	return (nil);
}

@end

@implementation PBXBuildPhase

+ (NSArray *)archivableAttributes
{
	return (@[@"buildActionMask", @"name",
	    @"runOnlyForDeploymentPostprocessing"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"files", @"customBuildRules"]);
}

+ (NSString *)defaultName
{
	return (nil);
}

- (NSString *)name
{
	return (_name);
}

- (void)setName:(NSString *)name
{
	_name = [name copy];
}

- (NSNumber *)buildActionMask
{
	return (_buildActionMask);
}

- (void)setBuildActionMask:(NSNumber *)mask
{
	_buildActionMask = mask;
}

- (NSNumber *)runOnlyForDeploymentPostprocessing
{
	return (_runOnlyForDeploymentPostprocessing);
}

- (void)setRunOnlyForDeploymentPostprocessing:(NSNumber *)flag
{
	_runOnlyForDeploymentPostprocessing = flag;
}

- (NSArray *)files
{
	return (_files);
}

- (void)setFiles:(NSArray *)files
{
	_files = (files != nil) ? [files mutableCopy] : nil;
}

- (void)addFile:(PBXBuildFile *)file
{
	if (_files == nil)
		_files = [[NSMutableArray alloc] init];
	[_files addObject:file];
}

- (NSArray *)customBuildRules
{
	return (_customBuildRules);
}

- (void)setCustomBuildRules:(NSArray *)rules
{
	_customBuildRules = (rules != nil) ? [rules mutableCopy] : nil;
}

- (NSString *)displayName
{
	if (_name != nil)
		return (_name);
	return ([[self class] defaultName]);
}

- (NSString *)archiveComment
{
	return ([self displayName]);
}

@end

@implementation PBXCopyFilesBuildPhase

+ (NSArray *)archivableAttributes
{
	return (@[@"dstPath", @"dstSubfolderSpec", @"dstSubfolderSpecName"]);
}

+ (NSString *)defaultName
{
	return (@"CopyFiles");
}

- (NSString *)dstPath
{
	return (_dstPath);
}

- (void)setDstPath:(NSString *)path
{
	_dstPath = [path copy];
}

- (NSNumber *)dstSubfolderSpec
{
	return (_dstSubfolderSpec);
}

- (void)setDstSubfolderSpec:(NSNumber *)spec
{
	_dstSubfolderSpec = spec;
}

- (NSString *)dstSubfolderSpecName
{
	return (_dstSubfolderSpecName);
}

- (void)setDstSubfolderSpecName:(NSString *)name
{
	_dstSubfolderSpecName = [name copy];
}

@end

@implementation PBXShellScriptBuildPhase

+ (NSArray *)archivableAttributes
{
	return (@[@"shellPath", @"shellScript", @"inputPaths", @"outputPaths",
	    @"inputFileListPaths", @"outputFileListPaths", @"alwaysOutOfDate",
	    @"showEnvVarsInLog"]);
}

+ (NSString *)defaultName
{
	return (@"ShellScript");
}

- (NSString *)shellPath
{
	return (_shellPath);
}

- (void)setShellPath:(NSString *)path
{
	_shellPath = [path copy];
}

- (NSString *)shellScript
{
	return (_shellScript);
}

- (void)setShellScript:(NSString *)script
{
	_shellScript = [script copy];
}

- (NSArray *)inputPaths
{
	return (_inputPaths);
}

- (void)setInputPaths:(NSArray *)paths
{
	_inputPaths = (paths != nil) ? [paths mutableCopy] : nil;
}

- (NSArray *)outputPaths
{
	return (_outputPaths);
}

- (void)setOutputPaths:(NSArray *)paths
{
	_outputPaths = (paths != nil) ? [paths mutableCopy] : nil;
}

- (NSArray *)inputFileListPaths
{
	return (_inputFileListPaths);
}

- (void)setInputFileListPaths:(NSArray *)paths
{
	_inputFileListPaths = (paths != nil) ? [paths mutableCopy] : nil;
}

- (NSArray *)outputFileListPaths
{
	return (_outputFileListPaths);
}

- (void)setOutputFileListPaths:(NSArray *)paths
{
	_outputFileListPaths = (paths != nil) ? [paths mutableCopy] : nil;
}

- (NSNumber *)alwaysOutOfDate
{
	return (_alwaysOutOfDate);
}

- (void)setAlwaysOutOfDate:(NSNumber *)flag
{
	_alwaysOutOfDate = flag;
}

- (NSNumber *)showEnvVarsInLog
{
	return (_showEnvVarsInLog);
}

- (void)setShowEnvVarsInLog:(NSNumber *)flag
{
	_showEnvVarsInLog = flag;
}

@end

@implementation PBXHeadersBuildPhase
+ (NSString *)defaultName { return (@"Headers"); }
@end

@implementation PBXSourcesBuildPhase
+ (NSString *)defaultName { return (@"Sources"); }
@end

@implementation PBXFrameworksBuildPhase
+ (NSString *)defaultName { return (@"Frameworks"); }
@end

@implementation PBXResourcesBuildPhase
+ (NSString *)defaultName { return (@"Resources"); }
@end

@implementation PBXRezBuildPhase
+ (NSString *)defaultName { return (@"Rez"); }
@end

@implementation PBXAppleScriptBuildPhase

+ (NSArray *)archivableAttributes
{
	return (@[@"contextName", @"isSharedContext"]);
}

+ (NSString *)defaultName
{
	return (@"AppleScript");
}

@end

@implementation PBXJavaArchiveBuildPhase
+ (NSString *)defaultName { return (@"JavaArchive"); }
@end

@implementation PBXBuildRule

+ (NSArray *)archivableAttributes
{
	return (@[@"compilerSpec", @"filePatterns", @"fileType", @"inputFiles",
	    @"isEditable", @"outputFiles", @"outputFilesCompilerFlags",
	    @"runOncePerArchitecture", @"script"]);
}

@end

@implementation PBXBuildStyle

+ (NSArray *)archivableAttributes
{
	return (@[@"name", @"buildSettings"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"buildRules"]);
}

- (NSString *)name
{
	return (_name);
}

- (void)setName:(NSString *)name
{
	_name = [name copy];
}

- (NSMutableDictionary *)buildSettings
{
	return (_buildSettings);
}

- (void)setBuildSettings:(NSDictionary *)settings
{
	_buildSettings = (settings != nil) ? [settings mutableCopy] : nil;
}

- (NSString *)archiveComment
{
	return (_name);
}

@end
