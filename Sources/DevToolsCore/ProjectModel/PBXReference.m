/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * File/group reference classes (DevToolsCore). */

#import "DevToolsCore/PBXReference.h"

@implementation PBXReference

+ (NSArray *)archivableAttributes
{
	return (@[@"name", @"path", @"sourceTree"]);
}

- (NSString *)name
{
	return (_name);
}

- (void)setName:(NSString *)name
{
	_name = [name copy];
}

- (NSString *)path
{
	return (_path);
}

- (void)setPath:(NSString *)path
{
	_path = [path copy];
}

- (NSString *)sourceTree
{
	return (_sourceTree);
}

- (void)setSourceTree:(NSString *)sourceTree
{
	_sourceTree = [sourceTree copy];
}

- (NSString *)displayName
{
	if (_name != nil)
		return (_name);
	if (_path != nil)
		return ([_path lastPathComponent]);
	return (nil);
}

- (NSString *)archiveComment
{
	return ([self displayName]);
}

- (PBXGroup *)group
{
	return (_group);
}

- (void)setGroup:(PBXGroup *)group
{
	_group = group;
}

- (void)removeFromGroup
{
	[_group removeItem:self];
}

- (BOOL)isGroup
{
	return (NO);
}

- (BOOL)isLeaf
{
	return (YES);
}

- (BOOL)isVariantGroup
{
	return (NO);
}

- (BOOL)isVersionGroup
{
	return (NO);
}

- (BOOL)isProductReference
{
	return (NO);
}

- (NSArray *)children
{
	return (nil);
}

- (void)flattenItemsIntoArray:(NSMutableArray *)array
{
	[array addObject:self];
}

- (BOOL)isAncestorOfItem:(PBXReference *)item
{
	return (NO);
}

- (NSComparisonResult)compareName:(NSString *)name
{
	return ([[self displayName] compare:name]);
}

@end

@implementation PBXFileReference

+ (NSArray *)archivableAttributes
{
	return (@[@"fileEncoding", @"lastKnownFileType", @"explicitFileType",
	    @"includeInIndex", @"languageSpecificationIdentifier",
	    @"plistStructureDefinitionIdentifier", @"usesTabs", @"indentWidth",
	    @"tabWidth", @"wrapsLines",
	    @"xcLanguageSpecificationIdentifier"]);
}

- (NSString *)fileType
{
	return (_explicitFileType != nil ? _explicitFileType : _lastKnownFileType);
}

- (void)setFileType:(NSString *)fileType
{
	if ([fileType length] != 0)
		_explicitFileType = [fileType copy];
}

- (NSString *)lastKnownFileType
{
	return (_lastKnownFileType);
}

- (void)setLastKnownFileType:(NSString *)type
{
	_lastKnownFileType = [type copy];
}

- (NSString *)explicitFileType
{
	return (_explicitFileType);
}

- (void)setExplicitFileType:(NSString *)type
{
	_explicitFileType = [type copy];
}

- (NSString *)fileEncoding
{
	return (_fileEncoding);
}

- (void)setFileEncoding:(NSString *)encoding
{
	_fileEncoding = [encoding copy];
}

- (NSNumber *)includeInIndex
{
	return (_includeInIndex);
}

- (void)setIncludeInIndex:(NSNumber *)flag
{
	_includeInIndex = flag;
}

- (NSNumber *)usesTabs
{
	return (_usesTabs);
}

- (void)setUsesTabs:(NSNumber *)flag
{
	_usesTabs = flag;
}

- (NSNumber *)indentWidth
{
	return (_indentWidth);
}

- (void)setIndentWidth:(NSNumber *)width
{
	_indentWidth = width;
}

- (NSNumber *)tabWidth
{
	return (_tabWidth);
}

- (void)setTabWidth:(NSNumber *)width
{
	_tabWidth = width;
}

- (NSNumber *)wrapsLines
{
	return (_wrapsLines);
}

- (void)setWrapsLines:(NSNumber *)flag
{
	_wrapsLines = flag;
}

- (NSString *)languageSpecificationIdentifier
{
	return (_languageSpecificationIdentifier);
}

- (void)setLanguageSpecificationIdentifier:(NSString *)identifier
{
	_languageSpecificationIdentifier = [identifier copy];
}

- (NSString *)xcLanguageSpecificationIdentifier
{
	return (_xcLanguageSpecificationIdentifier);
}

- (void)setXcLanguageSpecificationIdentifier:(NSString *)identifier
{
	_xcLanguageSpecificationIdentifier = [identifier copy];
}

- (NSString *)plistStructureDefinitionIdentifier
{
	return (_plistStructureDefinitionIdentifier);
}

- (void)setPlistStructureDefinitionIdentifier:(NSString *)identifier
{
	_plistStructureDefinitionIdentifier = [identifier copy];
}

- (BOOL)isProductReference
{
	return ([_sourceTree isEqualToString:@"BUILT_PRODUCTS_DIR"]);
}

@end

@implementation PBXGroup

+ (NSArray *)archivableRelationships
{
	return (@[@"children"]);
}

+ (instancetype)groupWithName:(NSString *)name
{
	return ([self groupWithName:name path:nil]);
}

+ (instancetype)groupWithName:(NSString *)name path:(NSString *)path
{
	PBXGroup *group = [[self alloc] init];

	[group setName:name];
	if (path != nil)
		[group setPath:path];
	[group setSourceTree:@"<group>"];
	return (group);
}

- (NSArray *)children
{
	return (_children);
}

- (void)_setChildren:(NSArray *)children
{
	[self setChildren:children];
}

- (void)_setItems:(NSArray *)items
{
	[self setChildren:items];
}

- (void)setChildren:(NSArray *)children
{
	PBXReference *child;

	_children = (children != nil) ? [children mutableCopy] : nil;
	for (child in _children) {
		if ([child respondsToSelector:@selector(setGroup:)])
			[child setGroup:self];
	}
}

- (void)addChild:(PBXReference *)reference
{
	if (_children == nil)
		_children = [[NSMutableArray alloc] init];
	[_children addObject:reference];
	if ([reference respondsToSelector:@selector(setGroup:)])
		[reference setGroup:self];
}

- (BOOL)isGroup
{
	return (YES);
}

- (BOOL)isLeaf
{
	return (NO);
}

- (BOOL)allowsSubgroups
{
	return (YES);
}

- (BOOL)containsItem:(PBXReference *)item
{
	return (_children != nil && [_children containsObject:item]);
}

- (BOOL)isAncestorOfItem:(PBXReference *)item
{
	PBXGroup *group = [item group];

	while (group != nil) {
		if (group == self)
			return (YES);
		group = [group group];
	}
	return (NO);
}

- (PBXReference *)itemAtIndex:(NSUInteger)index
{
	if (index >= [_children count])
		return (nil);
	return (_children[index]);
}

- (PBXReference *)itemNamed:(NSString *)name
{
	PBXReference *child;

	for (child in _children) {
		if (![child isKindOfClass:[PBXReference class]])
			continue;
		if ([[child displayName] isEqualToString:name] ||
		    [[child name] isEqualToString:name])
			return (child);
	}
	return (nil);
}

- (NSUInteger)itemCount
{
	return ([_children count]);
}

- (NSUInteger)indexOfItem:(PBXReference *)item
{
	NSUInteger index = [_children indexOfObject:item];

	return (index == NSNotFound ? NSNotFound : index);
}

- (void)insertItem:(PBXReference *)item atIndex:(NSUInteger)index
{
	if (_children == nil)
		_children = [[NSMutableArray alloc] init];
	if (index > [_children count])
		index = [_children count];
	[_children insertObject:item atIndex:index];
	if ([item respondsToSelector:@selector(setGroup:)])
		[item setGroup:self];
}

- (void)addItem:(PBXReference *)item
{
	[self addChild:item];
}

- (void)addItems:(NSArray *)items
{
	PBXReference *item;

	for (item in items)
		[self addItem:item];
}

- (void)insertItems:(NSArray *)items atIndex:(NSUInteger)index
{
	PBXReference *item;

	for (item in items)
		[self insertItem:item atIndex:index++];
}

- (void)removeItemsFromChildrenOnly:(NSArray *)items
{
	PBXReference *item;

	for (item in items) {
		if ([item respondsToSelector:@selector(group)] &&
		    [item group] == self)
			[item setGroup:nil];
		[_children removeObject:item];
	}
}

- (BOOL)acceptsItem:(PBXReference *)item
{
	return (item != nil && ![self containsItem:item]);
}

- (PBXGroup *)destinationGroupForInsertion
{
	return (self);
}

- (NSEnumerator *)groupEnumerator
{
	return ([_children objectEnumerator]);
}

- (BOOL)enumerateDescendantReferencesUsingBlock:
    (BOOL (^)(PBXReference *reference))block
{
	PBXReference *child;

	for (child in _children) {
		if (![child isKindOfClass:[PBXReference class]])
			continue;
		if (block != nil && !block(child))
			return (NO);
		if ([child isKindOfClass:[PBXGroup class]] &&
		    ![(PBXGroup *)child enumerateDescendantReferencesUsingBlock:block])
			return (NO);
	}
	return (YES);
}

- (void)removeItem:(PBXReference *)item
{
	if (_children == nil)
		return;
	if ([item respondsToSelector:@selector(group)] &&
	    [item group] == self)
		[item setGroup:nil];
	[_children removeObject:item];
}

- (void)removeItems:(NSArray *)items
{
	PBXReference *item;

	for (item in items)
		[self removeItem:item];
}

- (NSArray *)_items
{
	return (_children);
}

- (void)flattenItemsIntoArray:(NSMutableArray *)array
{
	PBXReference *child;

	[array addObject:self];
	for (child in _children) {
		if ([child isKindOfClass:[PBXReference class]])
			[child flattenItemsIntoArray:array];
	}
}

@end

@implementation PBXVariantGroup

+ (NSString *)classNameForPListArchive
{
	return (@"PBXVariantGroup");
}

- (NSString *)archiveComment
{
	return ([self displayName]);
}

- (BOOL)isVariantGroup
{
	return (YES);
}

@end

@implementation XCVersionGroup

+ (NSArray *)archivableAttributes
{
	return (@[@"versionGroupType"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"currentVersion"]);
}

- (NSString *)versionGroupType
{
	return (_versionGroupType);
}

- (void)setVersionGroupType:(NSString *)type
{
	_versionGroupType = [type copy];
}

- (PBXFileReference *)currentVersion
{
	return (_currentVersion);
}

- (void)setCurrentVersion:(PBXFileReference *)reference
{
	_currentVersion = reference;
}

- (BOOL)isVersionGroup
{
	return (YES);
}

- (BOOL)allowsSubgroups
{
	return (NO);
}

- (NSString *)fileType
{
	return (_versionGroupType);
}

- (NSString *)versionedFileType
{
	return (_versionGroupType);
}

- (void)setVersionedFileType:(NSString *)type
{
	_versionGroupType = [type copy];
}

- (PBXFileReference *)versionForName:(NSString *)name
{
	PBXReference *child;

	for (child in _children) {
		if (![child isKindOfClass:[PBXReference class]])
			continue;
		if ([[child displayName] isEqualToString:name] ||
		    [[child name] isEqualToString:name])
			return ((PBXFileReference *)child);
	}
	return (nil);
}

@end

@implementation PBXFrameworkReference

+ (NSString *)classNameForPListArchive
{
	return (@"PBXFrameworkReference");
}

@end

@implementation PBXLibraryReference

+ (NSString *)classNameForPListArchive
{
	return (@"PBXLibraryReference");
}

@end

@implementation PBXBundleReference

+ (NSString *)classNameForPListArchive
{
	return (@"PBXBundleReference");
}

@end

@implementation PBXApplicationReference

+ (NSString *)classNameForPListArchive
{
	return (@"PBXApplicationReference");
}

@end

@implementation PBXExecutableFileReference

+ (NSString *)classNameForPListArchive
{
	return (@"PBXExecutableFileReference");
}

@end

@implementation PBXFileSystemSynchronizedAbstractGroup

+ (NSString *)classNameForPListArchive
{
	return (@"PBXFileSystemSynchronizedAbstractGroup");
}

- (NSString *)archiveComment
{
	return ([self displayName]);
}

@end

@implementation PBXFileSystemSynchronizedRootGroup

+ (NSString *)classNameForPListArchive
{
	return (@"PBXFileSystemSynchronizedRootGroup");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"explicitFileTypes", @"explicitFolders"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"exceptions"]);
}

- (NSArray *)exceptions
{
	return (_exceptions);
}

- (void)setExceptions:(NSArray *)exceptions
{
	_exceptions = (exceptions != nil) ? [exceptions mutableCopy] : nil;
}

- (NSMutableDictionary *)explicitFileTypes
{
	return (_explicitFileTypes);
}

- (void)setExplicitFileTypes:(NSDictionary *)types
{
	_explicitFileTypes = (types != nil) ? [types mutableCopy] : nil;
}

- (NSArray *)explicitFolders
{
	return (_explicitFolders);
}

- (void)setExplicitFolders:(NSArray *)folders
{
	_explicitFolders = (folders != nil) ? [folders mutableCopy] : nil;
}

@end

@implementation PBXFileSystemSynchronizedGroupAbstractMembershipExceptionSet

+ (NSString *)classNameForPListArchive
{
	return (@"PBXFileSystemSynchronizedGroupAbstractMembershipExceptionSet");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"membershipExceptions"]);
}

- (NSArray *)membershipExceptions
{
	return (_membershipExceptions);
}

- (void)setMembershipExceptions:(NSArray *)exceptions
{
	_membershipExceptions = (exceptions != nil) ? [exceptions mutableCopy] : nil;
}

@end

@implementation PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet

+ (NSString *)classNameForPListArchive
{
	return (@"PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"additionalCompilerFlagsByRelativePath",
	    @"attributesByRelativePath"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"buildPhase"]);
}

- (PBXBuildPhase *)buildPhase
{
	return (_buildPhase);
}

- (void)setBuildPhase:(PBXBuildPhase *)phase
{
	_buildPhase = phase;
}

- (NSMutableDictionary *)additionalCompilerFlagsByRelativePath
{
	return (_additionalCompilerFlagsByRelativePath);
}

- (void)setAdditionalCompilerFlagsByRelativePath:(NSDictionary *)flags
{
	_additionalCompilerFlagsByRelativePath =
	    (flags != nil) ? [flags mutableCopy] : nil;
}

- (NSMutableDictionary *)attributesByRelativePath
{
	return (_attributesByRelativePath);
}

- (void)setAttributesByRelativePath:(NSDictionary *)attributes
{
	_attributesByRelativePath =
	    (attributes != nil) ? [attributes mutableCopy] : nil;
}

@end

@implementation PBXFileSystemSynchronizedBuildFileExceptionSet

+ (NSString *)classNameForPListArchive
{
	return (@"PBXFileSystemSynchronizedBuildFileExceptionSet");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"membershipExceptions"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"target"]);
}

- (NSArray *)membershipExceptions
{
	return (_membershipExceptions);
}

- (void)setMembershipExceptions:(NSArray *)exceptions
{
	_membershipExceptions = (exceptions != nil) ? [exceptions mutableCopy] : nil;
}

- (PBXTarget *)target
{
	return (_target);
}

- (void)setTarget:(PBXTarget *)target
{
	_target = target;
}

@end

@implementation PBXReferenceProxy

+ (NSString *)classNameForPListArchive
{
	return (@"PBXReferenceProxy");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"fileType"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"remoteRef"]);
}

- (NSString *)fileType
{
	return (_fileType);
}

- (void)setFileType:(NSString *)fileType
{
	_fileType = [fileType copy];
}

- (PBXReference *)remoteRef
{
	return (_remoteRef);
}

- (void)setRemoteRef:(PBXReference *)reference
{
	_remoteRef = reference;
}

@end

@implementation PBXFileSystemSynchronizedGroupTargetMembershipExceptionSet

+ (NSString *)classNameForPListArchive
{
	return (@"PBXFileSystemSynchronizedGroupTargetMembershipExceptionSet");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"membershipExceptions"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"target"]);
}

- (PBXTarget *)target
{
	return (_target);
}

- (void)setTarget:(PBXTarget *)target
{
	_target = target;
}

@end
