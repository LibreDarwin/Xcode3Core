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

@end

@implementation PBXFileReference

+ (NSArray *)archivableAttributes
{
	return (@[@"fileEncoding", @"lastKnownFileType", @"explicitFileType",
	    @"includeInIndex", @"usesTabs", @"indentWidth", @"tabWidth",
	    @"wrapsLines"]);
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

@end

@implementation PBXGroup

+ (NSArray *)archivableRelationships
{
	return (@[@"children"]);
}

- (NSArray *)children
{
	return (_children);
}

- (void)setChildren:(NSArray *)children
{
	_children = (children != nil) ? [children mutableCopy] : nil;
}

- (void)addChild:(PBXReference *)reference
{
	if (_children == nil)
		_children = [[NSMutableArray alloc] init];
	[_children addObject:reference];
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

@end

@implementation PBXFileSystemSynchronizedGroupAbstractMembershipExceptionSet

+ (NSString *)classNameForPListArchive
{
	return (@"PBXFileSystemSynchronizedGroupAbstractMembershipExceptionSet");
}

@end

@implementation PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet

+ (NSString *)classNameForPListArchive
{
	return (@"PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet");
}

@end

@implementation PBXFileSystemSynchronizedBuildFileExceptionSet

+ (NSString *)classNameForPListArchive
{
	return (@"PBXFileSystemSynchronizedBuildFileExceptionSet");
}

@end

@implementation PBXReferenceProxy

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
