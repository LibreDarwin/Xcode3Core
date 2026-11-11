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

- (NSArray *)assetTags
{
	return (_assetTags);
}

- (void)setAssetTags:(NSArray *)tags
{
	_assetTags = (tags != nil) ? [tags mutableCopy] : nil;
}

- (NSSet *)attributes
{
	id raw = [_settings objectForKey:@"ATTRIBUTES"];

	if (raw == nil)
		return ([NSSet set]);
	if ([raw isKindOfClass:[NSArray class]])
		return ([NSSet setWithArray:raw]);
	if ([raw isKindOfClass:[NSSet class]])
		return (raw);
	if ([raw isKindOfClass:[NSString class]]) {
		NSMutableSet *set = [NSMutableSet set];
		NSArray *parts = [raw componentsSeparatedByString:@","];
		NSString *part;

		for (part in parts) {
			NSString *trimmed = [part
			    stringByTrimmingCharactersInSet:
			    [NSCharacterSet whitespaceCharacterSet]];
			if ([trimmed length] > 0)
				[set addObject:trimmed];
		}
		return (set);
	}
	return ([NSSet set]);
}

- (void)setAttributes:(NSSet *)attributes
{
	if (_settings == nil)
		_settings = [[NSMutableDictionary alloc] init];
	if ([attributes count] == 0) {
		[_settings removeObjectForKey:@"ATTRIBUTES"];
	} else {
		[_settings setObject:[[attributes allObjects]
		    sortedArrayUsingSelector:@selector(compare:)]
		    forKey:@"ATTRIBUTES"];
	}
}

- (BOOL)boolValueOfAttributeNamed:(NSString *)name
{
	return ([[self attributes] containsObject:name]);
}

- (void)setBoolValue:(BOOL)value ofAttributeNamed:(NSString *)name
{
	NSMutableSet *set = [[self attributes] mutableCopy];

	if (value)
		[set addObject:name];
	else
		[set removeObject:name];
	[self setAttributes:set];
}

static NSArray *SplitCompilerFlags(NSString *string)
{
	NSMutableArray *result = [NSMutableArray array];
	NSMutableString *current = [NSMutableString string];
	NSUInteger length = [string length];
	BOOL inQuotes = NO;
	NSUInteger i;

	for (i = 0; i < length; i++) {
		unichar c = [string characterAtIndex:i];

		if (c == '"') {
			inQuotes = !inQuotes;
		} else if (!inQuotes &&
		    [[NSCharacterSet whitespaceCharacterSet]
		    characterIsMember:c]) {
			if ([current length] > 0) {
				[result addObject:[current copy]];
				current = [NSMutableString string];
			}
		} else {
			[current appendFormat:@"%C", c];
		}
	}
	if ([current length] > 0)
		[result addObject:[current copy]];
	return (result);
}

- (NSArray *)additionalCompilerArguments
{
	id raw = [_settings objectForKey:@"COMPILER_FLAGS"];

	if (raw == nil)
		return (nil);
	if ([raw isKindOfClass:[NSArray class]])
		return (raw);
	if ([raw isKindOfClass:[NSString class]])
		return (SplitCompilerFlags(raw));
	return (nil);
}

- (void)setAdditionalCompilerArguments:(NSArray *)arguments
{
	if (_settings == nil)
		_settings = [[NSMutableDictionary alloc] init];
	if ([arguments count] == 0)
		[_settings removeObjectForKey:@"COMPILER_FLAGS"];
	else
		[_settings setObject:[arguments componentsJoinedByString:@" "]
		    forKey:@"COMPILER_FLAGS"];
}

- (NSString *)additionalCompilerArgumentsAsString
{
	id raw = [_settings objectForKey:@"COMPILER_FLAGS"];

	if ([raw isKindOfClass:[NSString class]])
		return (raw);
	if ([raw isKindOfClass:[NSArray class]])
		return ([raw componentsJoinedByString:@" "]);
	return (nil);
}

- (void)setAdditionalCompilerArgumentsAsString:(NSString *)string
{
	if (_settings == nil)
		_settings = [[NSMutableDictionary alloc] init];
	if ([string length] == 0)
		[_settings removeObjectForKey:@"COMPILER_FLAGS"];
	else
		[_settings setObject:[string copy] forKey:@"COMPILER_FLAGS"];
}

- (NSString *)primaryAttribute
{
	NSSet *attributes = [self attributes];
	NSArray *priority = @[@"Public", @"Private", @"Project", @"Weak"];
	NSString *candidate;

	for (candidate in priority) {
		if ([attributes containsObject:candidate])
			return (candidate);
	}
	return ([[[attributes allObjects]
	    sortedArrayUsingSelector:@selector(compare:)] firstObject]);
}

- (NSString *)stringValueForPrimaryAttribute
{
	return ([self primaryAttribute]);
}

+ (instancetype)buildFileWithReference:(PBXFileReference *)reference
{
	return ([[self alloc] initWithReference:reference]);
}

- (instancetype)initWithReference:(PBXFileReference *)reference
{
	self = [self init];
	if (self != nil)
		_fileRef = reference;
	return (self);
}

- (instancetype)initWithProductReference:(PBXReference *)reference
{
	self = [self init];
	if (self != nil)
		_productRef = reference;
	return (self);
}

- (PBXFileReference *)fileReference
{
	return (_fileRef);
}

- (PBXReference *)reference
{
	return (_fileRef);
}

- (PBXReference *)productReference
{
	return (_productRef);
}

- (BOOL)shouldArchiveSettings
{
	return (_settings != nil && [_settings count] > 0);
}

- (PBXBuildPhase *)buildPhase
{
	return (_buildPhase);
}

- (void)setBuildPhase:(PBXBuildPhase *)phase
{
	_buildPhase = phase;
}

- (PBXTarget *)target
{
	return ([_buildPhase target]);
}

- (NSString *)displayName
{
	PBXReference *ref = _fileRef ?: _productRef;
	NSString *fileName = [ref displayName] ?: [self objectID];
	NSString *phaseName = [_buildPhase displayName];

	if (phaseName == nil)
		phaseName = @"";
	return ([NSString stringWithFormat:@"%@ in %@", fileName, phaseName]);
}

- (NSString *)name
{
	return ([self displayName]);
}

- (NSComparisonResult)compareName:(NSString *)name
{
	return ([[self displayName] compare:name]);
}

- (NSComparisonResult)compareFullPath:(NSString *)path
{
	NSString *full = [_fileRef path] ?: [_productRef path];

	if (full == nil)
		return (NSOrderedSame);
	return ([full compare:path]);
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

+ (NSString *)identifier
{
	return ([[self class] classNameForPListArchive]);
}

+ (NSString *)defaultName
{
	return (nil);
}

+ (instancetype)buildPhase
{
	return ([[self alloc] init]);
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
	PBXBuildFile *file;

	_files = (files != nil) ? [files mutableCopy] : nil;
	for (file in _files) {
		if ([file isKindOfClass:[PBXBuildFile class]])
			[file setBuildPhase:self];
	}
}

- (void)addFile:(PBXBuildFile *)file
{
	[self addBuildFile:file];
}

- (NSArray *)buildFiles
{
	return (_files);
}

- (NSArray *)archivedBuildFiles
{
	return (_files);
}

- (void)setArchivedBuildFiles:(NSArray *)files
{
	[self setFiles:files];
}

- (void)insertBuildFiles:(NSArray *)files atIndex:(NSUInteger)index
{
	PBXBuildFile *file;

	if (_files == nil)
		_files = [[NSMutableArray alloc] init];
	if (index > [_files count])
		index = [_files count];
	for (file in files) {
		if (![file isKindOfClass:[PBXBuildFile class]])
			continue;
		[_files insertObject:file atIndex:index++];
		[file setBuildPhase:self];
	}
}

- (void)insertBuildFile:(PBXBuildFile *)file atIndex:(NSUInteger)index
{
	if (file != nil)
		[self insertBuildFiles:@[ file ] atIndex:index];
}

- (void)addBuildFile:(PBXBuildFile *)file
{
	if (file == nil)
		return;
	if (_files == nil)
		_files = [[NSMutableArray alloc] init];
	[_files addObject:file];
	[file setBuildPhase:self];
}

- (void)addBuildFiles:(NSArray *)files
{
	PBXBuildFile *file;

	for (file in files)
		[self addBuildFile:file];
}

- (void)removeBuildFile:(PBXBuildFile *)file
{
	if (file == nil || _files == nil)
		return;
	if ([file buildPhase] == self)
		[file setBuildPhase:nil];
	[_files removeObject:file];
}

- (void)removeBuildFiles:(NSArray *)files
{
	PBXBuildFile *file;

	for (file in files)
		[self removeBuildFile:file];
}

- (PBXBuildFile *)buildFileForReference:(PBXReference *)reference
{
	PBXBuildFile *file;

	if (reference == nil)
		return (nil);
	for (file in _files) {
		if (![file isKindOfClass:[PBXBuildFile class]])
			continue;
		if ([file fileRef] == reference || [file productRef] == reference)
			return (file);
	}
	return (nil);
}

- (PBXBuildFile *)buildFileForProductReference:(PBXReference *)reference
{
	PBXBuildFile *file;

	if (reference == nil)
		return (nil);
	for (file in _files) {
		if (![file isKindOfClass:[PBXBuildFile class]])
			continue;
		if ([file productRef] == reference)
			return (file);
	}
	return (nil);
}

- (BOOL)containsFileReferenceIdenticalTo:(PBXReference *)reference
{
	return ([self buildFileForReference:reference] != nil);
}

- (PBXTarget *)target
{
	return (_target);
}

- (void)setTarget:(PBXTarget *)target
{
	_target = target;
}

- (BOOL)canRename
{
	return (YES);
}

- (BOOL)isDeletable
{
	return (YES);
}

- (NSArray *)allowedFileTypes
{
	return (nil);
}

- (BOOL)acceptsReference:(PBXReference *)reference
{
	return (YES);
}

- (BOOL)acceptsVariantGroups
{
	return (NO);
}

- (BOOL)phaseContainsJavaFiles
{
	PBXBuildFile *file;

	for (file in _files) {
		NSString *path = [[file fileRef] path];

		if ([[path pathExtension] isEqualToString:@"java"])
			return (YES);
	}
	return (NO);
}

- (BOOL)phaseContainsNonJavaFiles
{
	PBXBuildFile *file;

	for (file in _files) {
		NSString *path = [[file fileRef] path];

		if (![[path pathExtension] isEqualToString:@"java"])
			return (YES);
	}
	return (NO);
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

- (NSString *)contextName
{
	return (_contextName);
}

- (void)setContextName:(NSString *)name
{
	_contextName = [name copy];
}

- (NSNumber *)isSharedContext
{
	return (_isSharedContext);
}

- (void)setIsSharedContext:(NSNumber *)flag
{
	_isSharedContext = flag;
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
	    @"runOncePerArchitecture", @"script", @"name"]);
}

- (NSString *)compilerSpec
{
	return (_compilerSpec);
}

- (void)setCompilerSpec:(NSString *)spec
{
	_compilerSpec = [spec copy];
}

- (NSString *)filePatterns
{
	return (_filePatterns);
}

- (void)setFilePatterns:(NSString *)patterns
{
	_filePatterns = [patterns copy];
}

- (NSString *)fileType
{
	return (_fileType);
}

- (void)setFileType:(NSString *)type
{
	_fileType = [type copy];
}

- (NSArray *)inputFiles
{
	return (_inputFiles);
}

- (void)setInputFiles:(NSArray *)files
{
	_inputFiles = (files != nil) ? [files mutableCopy] : nil;
}

- (NSArray *)outputFiles
{
	return (_outputFiles);
}

- (void)setOutputFiles:(NSArray *)files
{
	_outputFiles = (files != nil) ? [files mutableCopy] : nil;
}

- (NSArray *)outputFilesCompilerFlags
{
	return (_outputFilesCompilerFlags);
}

- (void)setOutputFilesCompilerFlags:(NSArray *)flags
{
	_outputFilesCompilerFlags = (flags != nil) ? [flags mutableCopy] : nil;
}

- (NSNumber *)runOncePerArchitecture
{
	return (_runOncePerArchitecture);
}

- (void)setRunOncePerArchitecture:(NSNumber *)flag
{
	_runOncePerArchitecture = flag;
}

- (NSString *)script
{
	return (_script);
}

- (void)setScript:(NSString *)script
{
	_script = [script copy];
}

- (NSNumber *)isEditable
{
	return (_isEditable);
}

- (void)setIsEditable:(NSNumber *)flag
{
	_isEditable = flag;
}

- (NSString *)name
{
	return (_name);
}

- (void)setName:(NSString *)name
{
	_name = [name copy];
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
