/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * File/group reference classes (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXREFERENCE_H
#define DEVTOOLSCORE_PBXREFERENCE_H

#import "DevToolsCore/PBXProject.h"

@class PBXFileReference;
@class PBXGroup;
@class PBXBuildPhase, PBXTarget;

/* A named node in the project's reference tree. */
@interface PBXReference : PBXContainerItem
{
	NSString *_name;
	NSString *_path;
	NSString *_sourceTree;
	__weak PBXGroup *_group;
}
- (NSString *)name;
- (void)setName:(NSString *)name;
- (NSString *)path;
- (void)setPath:(NSString *)path;
- (NSString *)sourceTree;
- (void)setSourceTree:(NSString *)sourceTree;

/* Display name used for archive comments (name, else the path's last part). */
- (NSString *)displayName;

/* Owning group (weak back-pointer; set when the group's children are bound). */
- (PBXGroup *)group;
- (void)setGroup:(PBXGroup *)group;
- (void)removeFromGroup;

/* Tree shape and traversal (overridden by PBXGroup). */
- (BOOL)isGroup;
- (BOOL)isLeaf;
- (BOOL)isVariantGroup;
- (BOOL)isVersionGroup;
- (BOOL)isProductReference;
- (NSArray *)children;
- (void)flattenItemsIntoArray:(NSMutableArray *)array;
- (BOOL)isAncestorOfItem:(PBXReference *)item;

/* Name ordering used when sorting siblings. */
- (NSComparisonResult)compareName:(NSString *)name;
@end

@interface PBXFileReference : PBXReference
{
	NSString *_fileEncoding;
	NSString *_lastKnownFileType;
	NSString *_explicitFileType;
	NSString *_languageSpecificationIdentifier;
	NSString *_xcLanguageSpecificationIdentifier;
	NSString *_plistStructureDefinitionIdentifier;
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
- (NSNumber *)includeInIndex;
- (void)setIncludeInIndex:(NSNumber *)flag;
- (NSNumber *)usesTabs;
- (void)setUsesTabs:(NSNumber *)flag;
- (NSNumber *)indentWidth;
- (void)setIndentWidth:(NSNumber *)width;
- (NSNumber *)tabWidth;
- (void)setTabWidth:(NSNumber *)width;
- (NSNumber *)wrapsLines;
- (void)setWrapsLines:(NSNumber *)flag;
- (NSString *)languageSpecificationIdentifier;
- (void)setLanguageSpecificationIdentifier:(NSString *)identifier;
- (NSString *)xcLanguageSpecificationIdentifier;
- (void)setXcLanguageSpecificationIdentifier:(NSString *)identifier;
- (NSString *)plistStructureDefinitionIdentifier;
- (void)setPlistStructureDefinitionIdentifier:(NSString *)identifier;
@end

/* A group of references (a folder node). */
@interface PBXGroup : PBXReference
{
	NSMutableArray *_children;
}
- (NSArray *)children;
- (void)setChildren:(NSArray *)children;
- (void)addChild:(PBXReference *)reference;

- (BOOL)allowsSubgroups;
- (BOOL)containsItem:(PBXReference *)item;
- (PBXReference *)itemAtIndex:(NSUInteger)index;
- (PBXReference *)itemNamed:(NSString *)name;
- (NSUInteger)itemCount;
- (NSUInteger)indexOfItem:(PBXReference *)item;
- (void)insertItem:(PBXReference *)item atIndex:(NSUInteger)index;
- (void)addItem:(PBXReference *)item;
- (void)removeItem:(PBXReference *)item;
- (void)removeItems:(NSArray *)items;
- (NSArray *)_items;
@end

/* A localized variant group (children share one logical name). */
@interface PBXVariantGroup : PBXGroup
@end

/*
 * A versioned group, e.g. an .xcdatamodeld, whose children are the individual
 * .xcdatamodel versions; currentVersion points at the active one.
 */
@interface XCVersionGroup : PBXGroup
{
	NSString *_versionGroupType;
	PBXFileReference *_currentVersion;
}
- (NSString *)versionGroupType;
- (void)setVersionGroupType:(NSString *)type;
- (PBXFileReference *)currentVersion;
- (void)setCurrentVersion:(PBXFileReference *)reference;
- (NSString *)fileType;
- (NSString *)versionedFileType;
- (void)setVersionedFileType:(NSString *)type;
- (PBXFileReference *)versionForName:(NSString *)name;
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
{
	NSMutableArray *_exceptions;
	NSMutableDictionary *_explicitFileTypes;
	NSMutableArray *_explicitFolders;
}
- (NSArray *)exceptions;
- (void)setExceptions:(NSArray *)exceptions;
- (NSMutableDictionary *)explicitFileTypes;
- (void)setExplicitFileTypes:(NSDictionary *)types;
- (NSArray *)explicitFolders;
- (void)setExplicitFolders:(NSArray *)folders;
@end

/* Membership exception sets used by synchronized groups. */
@interface PBXFileSystemSynchronizedGroupAbstractMembershipExceptionSet
    : PBXObject
{
	NSMutableArray *_membershipExceptions;
}
- (NSArray *)membershipExceptions;
- (void)setMembershipExceptions:(NSArray *)exceptions;
@end

@interface PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet
    : PBXFileSystemSynchronizedGroupAbstractMembershipExceptionSet
{
	PBXBuildPhase *_buildPhase;
	NSMutableDictionary *_additionalCompilerFlagsByRelativePath;
	NSMutableDictionary *_attributesByRelativePath;
}
- (PBXBuildPhase *)buildPhase;
- (void)setBuildPhase:(PBXBuildPhase *)phase;
- (NSMutableDictionary *)additionalCompilerFlagsByRelativePath;
- (void)setAdditionalCompilerFlagsByRelativePath:(NSDictionary *)flags;
- (NSMutableDictionary *)attributesByRelativePath;
- (void)setAttributesByRelativePath:(NSDictionary *)attributes;
@end

@interface PBXFileSystemSynchronizedBuildFileExceptionSet : PBXObject
{
	NSMutableArray *_membershipExceptions;
	PBXTarget *_target;
}
- (NSArray *)membershipExceptions;
- (void)setMembershipExceptions:(NSArray *)exceptions;
- (PBXTarget *)target;
- (void)setTarget:(PBXTarget *)target;
@end

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

@interface PBXFileSystemSynchronizedGroupTargetMembershipExceptionSet
    : PBXFileSystemSynchronizedGroupAbstractMembershipExceptionSet
{
	PBXTarget *_target;
}
- (PBXTarget *)target;
- (void)setTarget:(PBXTarget *)target;
@end

#endif	/* DEVTOOLSCORE_PBXREFERENCE_H */
