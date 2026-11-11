/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Directory-backed containers (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXFOLDER_H
#define DEVTOOLSCORE_PBXFOLDER_H

#import "DevToolsCore/PBXProject.h"

@class PBXFileReference;

/*
 * A PBXFolder is a container whose reference tree mirrors a directory on
 * disk.  Children are created lazily the first time the root group is asked
 * for and re-created after -invalidateAbsolutePathCache.
 */
@interface PBXFolder : PBXContainer
{
	NSDate *_modTime;
	BOOL _invalidatingAbsolutePath;
}
+ (instancetype)folderForPath:(NSString *)path
    withResolvedPath:(NSString *)resolvedPath;
+ (instancetype)folderForPath:(NSString *)path;
+ (instancetype)folderForFileReference:(PBXFileReference *)reference;
+ (NSString *)_invisibleChildrenFilterExpression;

- (PBXGroup *)rootGroup;
- (NSArray *)children;
- (void)invalidateAbsolutePathCache;
@end

#endif	/* DEVTOOLSCORE_PBXFOLDER_H */
