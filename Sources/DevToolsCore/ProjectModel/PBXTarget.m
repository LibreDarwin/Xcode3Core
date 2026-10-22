/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Target and proxy/dependency classes (DevToolsCore). */

#import "DevToolsCore/PBXTarget.h"
#import "DevToolsCore/PBXProject.h"

@implementation PBXContainerItemProxy

+ (NSString *)classNameForPListArchive
{
	return (@"PBXContainerItemProxy");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"proxyType", @"remoteGlobalIDString", @"remoteInfo"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"containerPortal"]);
}

- (PBXContainer *)containerPortal
{
	return (_containerPortal);
}

- (void)setContainerPortal:(PBXContainer *)container
{
	_containerPortal = container;
}

- (NSString *)proxyType
{
	return (_proxyType);
}

- (void)setProxyType:(NSString *)type
{
	_proxyType = [type copy];
}

- (NSString *)remoteGlobalIDString
{
	return (_remoteGlobalIDString);
}

- (void)setRemoteGlobalIDString:(NSString *)identifier
{
	_remoteGlobalIDString = [identifier copy];
}

- (NSString *)remoteInfo
{
	return (_remoteInfo);
}

- (void)setRemoteInfo:(NSString *)info
{
	_remoteInfo = [info copy];
}

- (NSString *)archiveComment
{
	return (_remoteInfo);
}

@end

@implementation PBXTargetDependency

+ (NSString *)classNameForPListArchive
{
	return (@"PBXTargetDependency");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"name"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"target", @"targetProxy"]);
}

- (PBXTarget *)target
{
	return (_target);
}

- (void)setTarget:(PBXTarget *)target
{
	_target = target;
}

- (PBXContainerItemProxy *)targetProxy
{
	return (_targetProxy);
}

- (void)setTargetProxy:(PBXContainerItemProxy *)proxy
{
	_targetProxy = proxy;
}

- (NSString *)name
{
	return (_name);
}

- (void)setName:(NSString *)name
{
	_name = [name copy];
}

- (NSString *)archiveComment
{
	return (([_target displayName] != nil) ? [_target displayName] : _name);
}

@end

@implementation PBXTarget

+ (NSArray *)archivableAttributes
{
	return (@[@"name", @"productName", @"productInstallPath", @"productType",
	    @"buildArgumentsString", @"buildToolPath", @"buildWorkingDirectory",
	    @"passBuildSettingsInEnvironment"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"buildConfigurationList", @"buildPhases", @"buildRules",
	    @"dependencies", @"productReference", @"packageProductDependencies",
	    @"fileSystemSynchronizedGroups"]);
}

- (NSString *)name
{
	return (_name);
}

- (void)setName:(NSString *)name
{
	_name = [name copy];
}

- (NSString *)productName
{
	return (_productName);
}

- (void)setProductName:(NSString *)name
{
	_productName = [name copy];
}

- (NSString *)productType
{
	return (_productType);
}

- (void)setProductType:(NSString *)type
{
	_productType = [type copy];
}

- (PBXFileReference *)productReference
{
	return (_productReference);
}

- (void)setProductReference:(PBXFileReference *)reference
{
	_productReference = reference;
}

- (XCConfigurationList *)buildConfigurationList
{
	return (_buildConfigurationList);
}

- (void)setBuildConfigurationList:(XCConfigurationList *)list
{
	_buildConfigurationList = list;
}

- (NSArray *)buildPhases
{
	return (_buildPhases);
}

- (void)setBuildPhases:(NSArray *)phases
{
	_buildPhases = (phases != nil) ? [phases mutableCopy] : nil;
}

- (NSArray *)dependencies
{
	return (_dependencies);
}

- (void)setDependencies:(NSArray *)dependencies
{
	_dependencies = (dependencies != nil) ? [dependencies mutableCopy] : nil;
}

- (NSArray *)buildRules
{
	return (_buildRules);
}

- (void)setBuildRules:(NSArray *)rules
{
	_buildRules = (rules != nil) ? [rules mutableCopy] : nil;
}

- (NSString *)displayName
{
	if (_name != nil)
		return (_name);
	return (_productName);
}

- (NSString *)archiveComment
{
	return ([self displayName]);
}

@end

@implementation PBXNativeTarget

+ (NSString *)classNameForPListArchive
{
	return (@"PBXNativeTarget");
}

@end

@implementation PBXAggregateTarget

+ (NSString *)classNameForPListArchive
{
	return (@"PBXAggregateTarget");
}

@end

@implementation PBXLegacyTarget

+ (NSString *)classNameForPListArchive
{
	return (@"PBXLegacyTarget");
}

@end

@implementation PBXJambaseTarget

+ (NSString *)classNameForPListArchive
{
	return (@"PBXJambaseTarget");
}

@end

@implementation PBXWrappedTarget

+ (NSString *)classNameForPListArchive
{
	return (@"PBXWrappedTarget");
}

@end

@implementation PBXApplicationTarget

+ (NSString *)classNameForPListArchive
{
	return (@"PBXApplicationTarget");
}

@end

@implementation PBXFrameworkTarget

+ (NSString *)classNameForPListArchive
{
	return (@"PBXFrameworkTarget");
}

@end

@implementation PBXBundleTarget

+ (NSString *)classNameForPListArchive
{
	return (@"PBXBundleTarget");
}

@end

@implementation PBXLibraryTarget

+ (NSString *)classNameForPListArchive
{
	return (@"PBXLibraryTarget");
}

@end

@implementation PBXToolTarget

+ (NSString *)classNameForPListArchive
{
	return (@"PBXToolTarget");
}

@end

@implementation PBXStandaloneTarget

+ (NSString *)classNameForPListArchive
{
	return (@"PBXStandaloneTarget");
}

@end

@implementation PBXExternalTarget

+ (NSString *)classNameForPListArchive
{
	return (@"PBXExternalTarget");
}

@end
