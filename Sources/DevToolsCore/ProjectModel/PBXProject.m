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

@implementation XCRemoteSwiftPackageReference

+ (NSArray *)archivableAttributes
{
	return (@[@"repositoryURL", @"requirement"]);
}

- (NSString *)repositoryURL
{
	return (_repositoryURL);
}

- (void)setRepositoryURL:(NSString *)url
{
	_repositoryURL = [url copy];
}

- (NSMutableDictionary *)requirement
{
	return (_requirement);
}

- (void)setRequirement:(NSDictionary *)requirement
{
	_requirement = (requirement != nil) ? [requirement mutableCopy] : nil;
}

@end

@implementation XCLocalSwiftPackageReference

+ (NSArray *)archivableAttributes
{
	return (@[@"relativePath"]);
}

- (NSString *)relativePath
{
	return (_relativePath);
}

- (void)setRelativePath:(NSString *)path
{
	_relativePath = [path copy];
}

@end

@implementation XCSwiftPackageProductDependency

+ (NSArray *)archivableAttributes
{
	return (@[@"productName"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"package"]);
}

- (NSString *)productName
{
	return (_productName);
}

- (void)setProductName:(NSString *)name
{
	_productName = [name copy];
}

- (XCRemoteSwiftPackageReference *)package
{
	return (_package);
}

- (void)setPackage:(XCRemoteSwiftPackageReference *)package
{
	_package = package;
}

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
	    @"projectDirPath", @"projectRoot", @"userBuildSettings"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"buildConfigurationList", @"mainGroup", @"packageReferences",
	    @"productRefGroup", @"projectReferences", @"targets"]);
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

- (NSArray *)projectReferences
{
	return (_projectReferences);
}

- (void)setProjectReferences:(NSArray *)refs
{
	_projectReferences = (refs != nil) ? [refs mutableCopy] : nil;
}

- (NSMutableDictionary *)userBuildSettings
{
	return (_userBuildSettings);
}

- (void)setUserBuildSettings:(NSDictionary *)settings
{
	_userBuildSettings = (settings != nil) ?
	    [settings mutableCopy] : nil;
}

@end
