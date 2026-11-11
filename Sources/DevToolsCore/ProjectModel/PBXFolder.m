/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Directory-backed containers (DevToolsCore). */

#import "DevToolsCore/PBXFolder.h"
#import "DevToolsCore/PBXReference.h"

#define PBX_FOLDER_MAX_DEPTH 32

static void PBXPopulateGroupFromDirectory(PBXGroup *group, NSString *directory,
    NSUInteger depth)
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *entries;
	NSString *entry;

	if (group == nil || directory == nil || depth > PBX_FOLDER_MAX_DEPTH)
		return;
	entries = [fileManager contentsOfDirectoryAtPath:directory error:NULL];
	entries = [entries sortedArrayUsingSelector:@selector(compare:)];
	for (entry in entries) {
		NSString *childPath;
		NSDictionary *attributes;
		NSString *fileType;
		BOOL isDirectory = NO;

		if ([entry hasPrefix:@"."])
			continue;
		childPath = [directory stringByAppendingPathComponent:entry];
		attributes = [fileManager attributesOfItemAtPath:childPath
		    error:NULL];
		fileType = [attributes objectForKey:NSFileType];
		isDirectory = [fileType isEqualToString:NSFileTypeDirectory];
		if (isDirectory) {
			PBXGroup *subgroup = [PBXGroup groupWithName:entry
			    path:entry];

			[group addChild:subgroup];
			PBXPopulateGroupFromDirectory(subgroup, childPath,
			    depth + 1);
		} else {
			PBXFileReference *reference =
			    [[PBXFileReference alloc] initWithName:entry
			    path:entry];

			[group addChild:reference];
		}
	}
}

@implementation PBXFolder

+ (instancetype)folderForPath:(NSString *)path
    withResolvedPath:(NSString *)resolvedPath
{
	PBXFolder *folder = [[self alloc] init];

	[folder setPath:(resolvedPath != nil ? resolvedPath : path)];
	return (folder);
}

+ (instancetype)folderForPath:(NSString *)path
{
	return ([self folderForPath:path withResolvedPath:nil]);
}

+ (instancetype)folderForFileReference:(PBXFileReference *)reference
{
	NSString *path = [reference absolutePath];

	if (path == nil)
		return (nil);
	return ([self folderForPath:path]);
}

+ (NSString *)_invisibleChildrenFilterExpression
{
	return (nil);
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
		PBXPopulateGroupFromDirectory(_rootGroup, absolutePath, 0);
	}
	return (_rootGroup);
}

- (NSArray *)children
{
	return ([[self rootGroup] children]);
}

- (void)invalidateAbsolutePathCache
{
	_invalidatingAbsolutePath = YES;
	[super invalidateAbsolutePathCache];
	_rootGroup = nil;
	_modTime = nil;
	_invalidatingAbsolutePath = NO;
}

@end
