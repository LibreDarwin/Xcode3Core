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
	return (@[@"dstPath", @"dstSubfolderSpec"]);
}

+ (NSString *)defaultName
{
	return (@"CopyFiles");
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
