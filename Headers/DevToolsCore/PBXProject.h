/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Container classes and PBXProject (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXPROJECT_H
#define DEVTOOLSCORE_PBXPROJECT_H

#import "DevToolsCore/PBXObject.h"

@class PBXGroup, XCConfigurationList, PBXReference;

/* A container owns the references and targets of a project. */
@interface PBXContainer : PBXObject
{
	PBXGroup *_rootGroup;
	NSArray *_comments;
}
- (PBXGroup *)rootGroup;
- (void)setRootGroup:(PBXGroup *)group;
- (NSArray *)comments;
- (void)setComments:(NSArray *)comments;
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
	NSMutableArray *_targets;
	NSMutableArray *_knownRegions;
	NSMutableArray *_packageReferences;
	PBXGroup *_mainGroup;
	PBXGroup *_productRefGroup;
	XCConfigurationList *_buildConfigurationList;
	NSString *_compatibilityVersion;
	NSString *_developmentRegion;
	NSString *_projectDirPath;
	NSString *_projectRoot;
	NSNumber *_hasScannedForEncodings;
	NSNumber *_minimizedProjectReferenceProxies;
}
- (NSMutableDictionary *)attributes;
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
- (NSArray *)packageReferences;
- (void)setPackageReferences:(NSArray *)refs;
@end

#endif	/* DEVTOOLSCORE_PBXPROJECT_H */
