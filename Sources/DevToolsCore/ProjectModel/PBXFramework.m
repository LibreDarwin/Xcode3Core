/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Framework-bundle containers (DevToolsCore). */

#import "DevToolsCore/PBXFramework.h"
#import "DevToolsCore/PBXReference.h"

#define PBX_FRAMEWORK_MAX_DEPTH 32

static void PBXPopulateFrameworkGroup(PBXGroup *group, NSString *directory,
    NSUInteger depth)
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *entries;
	NSString *entry;

	if (group == nil || directory == nil || depth > PBX_FRAMEWORK_MAX_DEPTH)
		return;
	entries = [fileManager contentsOfDirectoryAtPath:directory error:NULL];
	entries = [entries sortedArrayUsingSelector:@selector(compare:)];
	for (entry in entries) {
		NSString *childPath;
		NSDictionary *attributes;
		NSString *fileType;

		if ([entry hasPrefix:@"."])
			continue;
		childPath = [directory stringByAppendingPathComponent:entry];
		attributes = [fileManager attributesOfItemAtPath:childPath
		    error:NULL];
		fileType = [attributes objectForKey:NSFileType];
		if ([fileType isEqualToString:NSFileTypeDirectory]) {
			PBXGroup *subgroup = [PBXGroup groupWithName:entry
			    path:entry];

			[group addChild:subgroup];
			PBXPopulateFrameworkGroup(subgroup, childPath,
			    depth + 1);
		} else {
			PBXFileReference *reference =
			    [[PBXFileReference alloc] initWithName:entry
			    path:entry];

			[group addChild:reference];
		}
	}
}

@implementation PBXFramework

+ (instancetype)frameworkForPath:(NSString *)path
    withResolvedPath:(NSString *)resolvedPath
{
	PBXFramework *framework = [[self alloc] init];

	[framework setPath:(resolvedPath != nil ? resolvedPath : path)];
	return (framework);
}

+ (instancetype)frameworkForPath:(NSString *)path
{
	return ([self frameworkForPath:path withResolvedPath:nil]);
}

+ (instancetype)frameworkForFileReference:(PBXFileReference *)reference
{
	NSString *path = [reference absolutePath];

	if (path == nil)
		return (nil);
	return ([self frameworkForPath:path]);
}

- (PBXGroup *)rootGroup
{
	if (_rootGroup == nil) {
		NSString *absolutePath = [self absolutePath];
		NSString *name = [self name];
		NSDictionary *attributes;

		if (name == nil)
			name = [absolutePath lastPathComponent];
		_rootGroup = [PBXGroup groupWithName:name path:absolutePath];
		[_rootGroup setSourceTree:@"<absolute>"];
		attributes = [[NSFileManager defaultManager]
		    attributesOfItemAtPath:absolutePath error:NULL];
		_modTime = [attributes objectForKey:NSFileModificationDate];
		PBXPopulateFrameworkGroup(_rootGroup, absolutePath, 0);
	}
	return (_rootGroup);
}

- (void)invalidateAbsolutePathCache
{
	_invalidatingAbsolutePath = YES;
	[super invalidateAbsolutePathCache];
	_rootGroup = nil;
	_modTime = nil;
	_invalidatingAbsolutePath = NO;
}

- (NSArray *)_absolutePathsOfFilesInSubdirectoryNamed:(NSString *)name
{
	NSString *absolutePath = [self absolutePath];
	NSString *subdirectory;
	NSMutableArray *paths = [NSMutableArray array];
	NSDirectoryEnumerator *enumerator;
	NSString *relativePath;

	if (absolutePath == nil || name == nil)
		return (paths);
	subdirectory = [absolutePath stringByAppendingPathComponent:name];
	enumerator = [[NSFileManager defaultManager]
	    enumeratorAtPath:subdirectory];
	for (relativePath in enumerator) {
		NSString *fullPath =
		    [subdirectory stringByAppendingPathComponent:relativePath];
		BOOL isDirectory = NO;

		if (![[NSFileManager defaultManager] fileExistsAtPath:fullPath
		    isDirectory:&isDirectory] || isDirectory)
			continue;
		[paths addObject:fullPath];
	}
	return (paths);
}

- (NSArray *)absolutePathsOfPublicHeaderFiles
{
	return ([self _absolutePathsOfFilesInSubdirectoryNamed:@"Headers"]);
}

- (NSArray *)absolutePathsOfPrivateHeaderFiles
{
	return ([self _absolutePathsOfFilesInSubdirectoryNamed:
	    @"PrivateHeaders"]);
}

@end
