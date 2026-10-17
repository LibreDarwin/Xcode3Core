/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Container classes and PBXProject (DevToolsCore). */

#import "DevToolsCore/PBXProject.h"
#import "DevToolsCore/XCBuildConfiguration.h"

@implementation PBXContainer

- (PBXGroup *)rootGroup
{
	return (_rootGroup);
}

- (void)setRootGroup:(PBXGroup *)group
{
	_rootGroup = group;
}

- (NSArray *)comments
{
	return (_comments);
}

- (void)setComments:(NSArray *)comments
{
	_comments = comments;
}

@end

@implementation PBXContainerItem
@end

@implementation PBXProjectItem
@end

@implementation PBXProductDependency
@end

@implementation XCSwiftPackageReference
@end

@implementation XCLocalSwiftPackageReference
@end

@implementation XCSwiftPackageProductDependency
@end

@implementation PBXProject

+ (NSString *)classNameForPListArchive
{
	return (@"PBXProject");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"attributes", @"buildIndependentTargetsInParallel",
	    @"compatibilityVersion", @"developmentRegion",
	    @"hasScannedForEncodings", @"knownRegions",
	    @"minimizedProjectReferenceProxies", @"preferredProjectObjectVersion",
	    @"projectDirPath", @"projectRoot"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"buildConfigurationList", @"mainGroup", @"packageReferences",
	    @"productRefGroup", @"targets"]);
}

- (NSString *)archiveComment
{
	return (@"Project object");
}

- (NSMutableDictionary *)attributes
{
	return (_attributes);
}

- (void)setAttributes:(NSDictionary *)attributes
{
	_attributes = (attributes != nil) ?
	    [attributes mutableCopy] : nil;
}

- (NSArray *)targets
{
	return (_targets);
}

- (void)setTargets:(NSArray *)targets
{
	_targets = (targets != nil) ? [targets mutableCopy] : nil;
}

- (NSArray *)knownRegions
{
	return (_knownRegions);
}

- (void)setKnownRegions:(NSArray *)regions
{
	_knownRegions = (regions != nil) ? [regions mutableCopy] : nil;
}

- (PBXGroup *)mainGroup
{
	return (_mainGroup);
}

- (void)setMainGroup:(PBXGroup *)group
{
	_mainGroup = group;
}

- (PBXGroup *)productRefGroup
{
	return (_productRefGroup);
}

- (void)setProductRefGroup:(PBXGroup *)group
{
	_productRefGroup = group;
}

- (XCConfigurationList *)buildConfigurationList
{
	return (_buildConfigurationList);
}

- (void)setBuildConfigurationList:(XCConfigurationList *)list
{
	_buildConfigurationList = list;
}

- (NSString *)compatibilityVersion
{
	return (_compatibilityVersion);
}

- (void)setCompatibilityVersion:(NSString *)version
{
	_compatibilityVersion = [version copy];
}

- (NSString *)developmentRegion
{
	return (_developmentRegion);
}

- (void)setDevelopmentRegion:(NSString *)region
{
	_developmentRegion = [region copy];
}

- (NSString *)projectDirPath
{
	return (_projectDirPath);
}

- (void)setProjectDirPath:(NSString *)path
{
	_projectDirPath = [path copy];
}

- (NSString *)projectRoot
{
	return (_projectRoot);
}

- (void)setProjectRoot:(NSString *)root
{
	_projectRoot = [root copy];
}

- (NSArray *)packageReferences
{
	return (_packageReferences);
}

- (void)setPackageReferences:(NSArray *)refs
{
	_packageReferences = (refs != nil) ? [refs mutableCopy] : nil;
}

@end
