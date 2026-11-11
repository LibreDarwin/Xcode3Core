/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Framework-bundle containers (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXFRAMEWORK_H
#define DEVTOOLSCORE_PBXFRAMEWORK_H

#import "DevToolsCore/PBXProject.h"

@class PBXFileReference;

/*
 * A PBXFramework is a container backed by a framework bundle.  Its reference
 * tree mirrors the bundle contents and it can enumerate the public and
 * private headers of the framework.
 */
@interface PBXFramework : PBXContainer
{
	NSDate *_modTime;
	BOOL _invalidatingAbsolutePath;
}
+ (instancetype)frameworkForPath:(NSString *)path
    withResolvedPath:(NSString *)resolvedPath;
+ (instancetype)frameworkForPath:(NSString *)path;
+ (instancetype)frameworkForFileReference:(PBXFileReference *)reference;

- (PBXGroup *)rootGroup;
- (void)invalidateAbsolutePathCache;
- (NSArray *)_absolutePathsOfFilesInSubdirectoryNamed:(NSString *)name;
- (NSArray *)absolutePathsOfPublicHeaderFiles;
- (NSArray *)absolutePathsOfPrivateHeaderFiles;
@end

#endif	/* DEVTOOLSCORE_PBXFRAMEWORK_H */
