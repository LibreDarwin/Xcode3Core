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
