/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Container classes and PBXProject (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXPROJECT_H
#define DEVTOOLSCORE_PBXPROJECT_H

#import "DevToolsCore/PBXObject.h"

@class PBXGroup, PBXGroupEnumerator, PBXTarget, XCConfigurationList;
@class PBXReference, PBXFileReference;

/*
 * A container owns a reference tree.  A project container is backed by an
 * .xcodeproj wrapper; PBXFolder and PBXFramework containers are backed by a
 * directory or framework bundle on disk.
 */
@interface PBXContainer : PBXObject
{
	PBXGroup *_rootGroup;
	NSArray *_comments;
	NSString *_path;
	NSString *_resolvedAbsolutePath;
	NSString *_basePath;
	PBXGroupEnumerator *_groupEnumerator;
	NSMapTable *_uniqueIDsToContainerItems;
}
+ (PBXContainer *)containerForResolvedAbsolutePath:(NSString *)path;
+ (void)setContainer:(PBXContainer *)container
    forResolvedAbsolutePath:(NSString *)path;
+ (void)removeContainerForResolvedAbsolutePath:(NSString *)path;

- (PBXGroup *)rootGroup;
- (void)setRootGroup:(PBXGroup *)group;
- (void)_setRootGroup:(PBXGroup *)group;
- (NSArray *)comments;
- (void)setComments:(NSArray *)comments;

- (NSString *)path;
- (void)setPath:(NSString *)path;
- (NSString *)name;
- (NSString *)basePath;
- (void)setBasePath:(NSString *)path;
- (NSString *)absolutePath;
- (NSString *)resolvedAbsolutePath;
- (void)invalidateAbsolutePathCache;
- (NSString *)stringByExpandingString:(NSString *)string;
- (void)close;

- (NSArray *)children;
- (NSArray *)references;
- (void)addReference:(PBXReference *)reference;
- (void)removeReference:(PBXReference *)reference;
- (void)addItem:(PBXObject *)item;
- (void)removeItem:(PBXObject *)item;
- (PBXObject *)itemForGlobalID:(NSString *)globalID;
- (PBXObject *)itemForGlobalIDHexString:(NSString *)string;
- (PBXReference *)referenceForPath:(NSString *)path;
- (PBXFileReference *)fileReferenceForPath:(NSString *)path;
- (BOOL)enumerateReferencesUsingBlock:
    (BOOL (^)(PBXReference *reference))block;
- (PBXGroupEnumerator *)groupEnumerator;
- (void)_clearGroupEnumerator;
- (BOOL)isReadOnly;
- (BOOL)allowsEditingOfChildren;
- (BOOL)validateValueForRootGroup:(PBXGroup *)group error:(NSError **)error;
@end

/* A container item has a (non-archived) reference to its owning container. */
@interface PBXContainerItem : PBXObject
@end

/* A property-list-archivable project item. */
@interface PBXProjectItem : PBXContainerItem
@end

/* A dependency on a Swift package product (Xcode 11+). */
@interface PBXProductDependency : PBXProjectItem
@end

/* A Swift package reference and its local (path-based) variant. */
@interface XCRemoteSwiftPackageReference : PBXProjectItem
{
	NSString *_repositoryURL;
	NSMutableDictionary *_requirement;
}
- (NSString *)repositoryURL;
- (void)setRepositoryURL:(NSString *)url;
- (NSMutableDictionary *)requirement;
- (void)setRequirement:(NSDictionary *)requirement;
@end

@interface XCLocalSwiftPackageReference : XCRemoteSwiftPackageReference
{
	NSString *_relativePath;
}
- (NSString *)relativePath;
- (void)setRelativePath:(NSString *)path;
@end

/* A concrete dependency on a product vended by a package. */
@interface XCSwiftPackageProductDependency : PBXProductDependency
{
	NSString *_productName;
	XCRemoteSwiftPackageReference *_package;
}
- (NSString *)productName;
- (void)setProductName:(NSString *)name;
- (XCRemoteSwiftPackageReference *)package;
- (void)setPackage:(XCRemoteSwiftPackageReference *)package;
@end

/*
 * PBXProject is the root object of the archive.  It carries the project-wide
 * attributes and owns the top-level group, the targets and the build configs.
 */
@interface PBXProject : PBXContainer
{
	NSMutableDictionary *_attributes;
	NSNumber *_buildIndependentTargetsInParallel;
	NSMutableArray *_targets;
	NSMutableArray *_knownRegions;
	NSMutableArray *_packageReferences;
	NSMutableArray *_projectReferences;
	NSMutableDictionary *_userBuildSettings;
	PBXGroup *_mainGroup;
	PBXGroup *_productRefGroup;
	XCConfigurationList *_buildConfigurationList;
	NSString *_compatibilityVersion;
	NSString *_developmentRegion;
	NSString *_projectDirPath;
	NSString *_projectRoot;
	NSNumber *_hasScannedForEncodings;
	NSNumber *_minimizedProjectReferenceProxies;
	NSNumber *_preferredProjectObjectVersion;
	NSMutableArray *_knownPlatforms;
}
+ (NSArray *)defaultKnownRegions;
+ (NSArray *)defaultKnownPlatforms;
+ (NSString *)projectWrapperExtension;
+ (BOOL)isProjectWrapperExtension:(NSString *)extension;
+ (NSArray *)knownProjectWrapperExtensions;
+ (NSString *)projectFilePathWithPath:(NSString *)path
    hasArchivingDelegate:(BOOL)delegate;
- (NSString *)name;
- (NSString *)path;
- (void)setPath:(NSString *)path;
- (NSString *)projectDirectory;
- (NSString *)lastUpgradeCheck;
- (void)setLastUpgradeCheck:(NSString *)check;
- (NSString *)organizationName;
- (void)setOrganizationName:(NSString *)name;
- (NSString *)classPrefix;
- (void)setClassPrefix:(NSString *)prefix;
- (NSArray *)knownAssetTags;
- (void)addKnownAssetTag:(NSString *)tag;
- (void)removeKnownAssetTag:(NSString *)tag;
- (PBXTarget *)targetNamed:(NSString *)name;
- (PBXTarget *)targetWithGlobalID:(NSString *)identifier;
- (void)insertTargets:(NSArray *)targets atIndex:(NSUInteger)index;
- (void)addTarget:(PBXTarget *)target;
- (void)removeTarget:(PBXTarget *)target;
- (NSArray *)allTargetsInDependencyOrder;
- (void)addRegion:(NSString *)region;
- (void)removeRegion:(NSString *)region;
- (NSArray *)knownPlatforms;
- (void)addPlatform:(NSString *)platform;
- (PBXGroup *)productReferenceGroup;
- (void)setProductReferenceGroup:(PBXGroup *)group;
- (BOOL)shouldArchiveDevelopmentRegion;
- (BOOL)shouldArchiveKnownRegions;
- (BOOL)shouldArchiveKnownPlatforms;
- (BOOL)shouldArchiveAttributes;
- (void)addTopLevelItem:(PBXObject *)item;
- (NSUInteger)preferredInsertionIndexForAppendingTopLevelItems;
- (void)addProjectReference:(PBXReference *)reference;
- (void)removeProjectReference:(PBXReference *)reference;
- (void)insertPackageReferences:(NSArray *)references atIndex:(NSUInteger)index;
- (void)addPackageReference:(PBXReference *)reference;
- (void)removePackageReference:(PBXReference *)reference;
- (NSString *)defaultConfigurationName;
- (void)setDefaultConfigurationName:(NSString *)name;
- (NSMutableDictionary *)attributes;
- (void)setAttributes:(NSDictionary *)attributes;
- (NSNumber *)buildIndependentTargetsInParallel;
- (void)setBuildIndependentTargetsInParallel:(NSNumber *)flag;
- (void)setAttributes:(NSDictionary *)attributes;
- (NSArray *)targets;
- (void)setTargets:(NSArray *)targets;
- (NSArray *)knownRegions;
- (void)setKnownRegions:(NSArray *)regions;
- (PBXGroup *)mainGroup;
- (void)setMainGroup:(PBXGroup *)group;
- (PBXGroup *)productRefGroup;
- (void)setProductRefGroup:(PBXGroup *)group;
- (XCConfigurationList *)buildConfigurationList;
- (void)setBuildConfigurationList:(XCConfigurationList *)list;
- (NSString *)compatibilityVersion;
- (void)setCompatibilityVersion:(NSString *)version;
- (NSString *)developmentRegion;
- (void)setDevelopmentRegion:(NSString *)region;
- (NSString *)projectDirPath;
- (void)setProjectDirPath:(NSString *)path;
- (NSString *)projectRoot;
- (void)setProjectRoot:(NSString *)root;
- (NSNumber *)hasScannedForEncodings;
- (void)setHasScannedForEncodings:(NSNumber *)flag;
- (NSNumber *)minimizedProjectReferenceProxies;
- (void)setMinimizedProjectReferenceProxies:(NSNumber *)flag;
- (NSNumber *)preferredProjectObjectVersion;
- (void)setPreferredProjectObjectVersion:(NSNumber *)version;
- (NSArray *)packageReferences;
- (void)setPackageReferences:(NSArray *)refs;
- (NSArray *)projectReferences;
- (void)setProjectReferences:(NSArray *)refs;
- (NSMutableDictionary *)userBuildSettings;
- (void)setUserBuildSettings:(NSDictionary *)settings;
@end

#endif	/* DEVTOOLSCORE_PBXPROJECT_H */
