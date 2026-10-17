/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * File/group reference classes (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXREFERENCE_H
#define DEVTOOLSCORE_PBXREFERENCE_H

#import "DevToolsCore/PBXProject.h"

@class PBXFileReference;

/* A named node in the project's reference tree. */
@interface PBXReference : PBXContainerItem
{
	NSString *_name;
	NSString *_path;
	NSString *_sourceTree;
}
- (NSString *)name;
- (void)setName:(NSString *)name;
- (NSString *)path;
- (void)setPath:(NSString *)path;
- (NSString *)sourceTree;
- (void)setSourceTree:(NSString *)sourceTree;

/* Display name used for archive comments (name, else the path's last part). */
- (NSString *)displayName;
@end

@interface PBXFileReference : PBXReference
{
	NSString *_fileEncoding;
	NSString *_lastKnownFileType;
	NSString *_explicitFileType;
	NSNumber *_includeInIndex;
	NSNumber *_usesTabs;
	NSNumber *_indentWidth;
	NSNumber *_tabWidth;
	NSNumber *_wrapsLines;
}
- (NSString *)fileType;
- (void)setFileType:(NSString *)fileType;
- (NSString *)lastKnownFileType;
- (void)setLastKnownFileType:(NSString *)type;
- (NSString *)explicitFileType;
- (void)setExplicitFileType:(NSString *)type;
- (NSString *)fileEncoding;
- (void)setFileEncoding:(NSString *)encoding;
@end

/* A group of references (a folder node). */
@interface PBXGroup : PBXReference
{
	NSMutableArray *_children;
}
- (NSArray *)children;
- (void)setChildren:(NSArray *)children;
- (void)addChild:(PBXReference *)reference;
@end

/* A localized variant group (children share one logical name). */
@interface PBXVariantGroup : PBXGroup
@end

/*
 * Project Builder era concrete product references.  Retained as thin
 * subclasses so their isa names round-trip from older archives.
 */
@interface PBXFrameworkReference : PBXFileReference @end

@interface PBXLibraryReference : PBXFileReference @end

@interface PBXBundleReference : PBXFileReference @end

@interface PBXApplicationReference : PBXFileReference @end

@interface PBXExecutableFileReference : PBXFileReference @end

/* File-system-synchronized groups (Xcode 16+). */
@interface PBXFileSystemSynchronizedAbstractGroup : PBXGroup @end

@interface PBXFileSystemSynchronizedRootGroup
    : PBXFileSystemSynchronizedAbstractGroup
@end

/* Membership exception sets used by synchronized groups. */
@interface PBXFileSystemSynchronizedGroupAbstractMembershipExceptionSet
    : PBXObject
@end

@interface PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet
    : PBXFileSystemSynchronizedGroupAbstractMembershipExceptionSet
@end

@interface PBXFileSystemSynchronizedBuildFileExceptionSet : PBXObject @end

/* A proxy for a reference in an external (referenced) project. */
@interface PBXReferenceProxy : PBXReference
{
	NSString *_fileType;
	PBXReference *_remoteRef;
}
- (NSString *)fileType;
- (void)setFileType:(NSString *)fileType;
- (PBXReference *)remoteRef;
- (void)setRemoteRef:(PBXReference *)reference;
@end

#endif	/* DEVTOOLSCORE_PBXREFERENCE_H */
