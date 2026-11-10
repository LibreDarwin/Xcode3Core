/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Target and proxy/dependency classes (DevToolsCore). */

#import "DevToolsCore/PBXTarget.h"
#import "DevToolsCore/PBXProject.h"
#import "DevToolsCore/PBXReference.h"
#import "DevToolsCore/PBXProjectModel.h"

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

- (instancetype)initWithType:(NSInteger)type portal:(PBXObject *)portal
    remoteGlobalIDString:(NSString *)idstring remoteInfo:(NSString *)info
{
	self = [self init];
	if (self != nil) {
		_proxyType = [@(type) stringValue];
		_containerPortal = portal;
		_remoteGlobalIDString = [idstring copy];
		_remoteInfo = [info copy];
	}
	return (self);
}

- (instancetype)initWithType:(NSInteger)type portal:(PBXObject *)portal
    remoteGlobalID:(PBXObject *)object remoteInfo:(NSString *)info
{
	return ([self initWithType:type portal:portal
	    remoteGlobalIDString:[object objectID] remoteInfo:info]);
}

- (PBXObject *)containerPortal
{
	return (_containerPortal);
}

- (void)setContainerPortal:(PBXObject *)container
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

- (PBXContainer *)remoteContainer
{
	if ([_containerPortal isKindOfClass:[PBXContainer class]])
		return ((PBXContainer *)_containerPortal);
	return (nil);
}

- (PBXObject *)remoteContainerItem
{
	PBXProjectModel *model = [_containerPortal projectModel];

	if (model == nil || _remoteGlobalIDString == nil)
		return (nil);
	return ([model objectForID:_remoteGlobalIDString]);
}

- (BOOL)isEqualToProxy:(PBXContainerItemProxy *)proxy
{
	if (proxy == nil)
		return (NO);
	return (_proxyType == [proxy proxyType] ||
	    [_proxyType isEqualToString:[proxy proxyType]]) &&
	    (_containerPortal == [proxy containerPortal] ||
	    [_containerPortal isEqual:[proxy containerPortal]]) &&
	    (_remoteGlobalIDString == [proxy remoteGlobalIDString] ||
	    [_remoteGlobalIDString isEqualToString:[proxy remoteGlobalIDString]]) &&
	    (_remoteInfo == [proxy remoteInfo] ||
	    [_remoteInfo isEqualToString:[proxy remoteInfo]]);
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

- (instancetype)initWithLocalTarget:(PBXTarget *)target
{
	self = [self init];
	if (self != nil) {
		_target = target;
		_targetProxy = [[PBXContainerItemProxy alloc]
		    initWithType:1 portal:[target container]
		    remoteGlobalIDString:[target objectID]
		    remoteInfo:[target displayName]];
	}
	return (self);
}

- (instancetype)initWithProjectReference:(PBXReference *)reference
    remoteTarget:(NSString *)target
{
	self = [self init];
	if (self != nil) {
		_targetProxy = [[PBXContainerItemProxy alloc]
		    initWithType:2 portal:reference remoteGlobalIDString:target
		    remoteInfo:nil];
	}
	return (self);
}

- (instancetype)initWithProductReference:(PBXObject *)reference
{
	self = [self init];
	if (self != nil) {
		_targetProxy = [[PBXContainerItemProxy alloc]
		    initWithType:1 portal:[reference container]
		    remoteGlobalIDString:[reference objectID]
		    remoteInfo:[reference description]];
	}
	return (self);
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

- (PBXObject *)productReference
{
	PBXObject *remote = [_targetProxy remoteContainerItem];

	if ([remote isKindOfClass:[PBXProductDependency class]])
		return (remote);
	return (nil);
}

- (NSArray *)orderedRecursiveDependencies
{
	NSMutableArray *result = [NSMutableArray array];
	NSMutableSet *seen = [NSMutableSet set];
	NSMutableArray *stack = [NSMutableArray arrayWithArray:
	    ([_target dependencies] ?: @[])];

	while ([stack count] > 0) {
		PBXTargetDependency *dep = [stack objectAtIndex:0];

		[stack removeObjectAtIndex:0];
		if ([seen containsObject:dep])
			continue;
		[seen addObject:dep];
		[result addObject:dep];
		[stack addObjectsFromArray:([dep->_target dependencies] ?: @[])];
	}
	return (result);
}

- (PBXTarget *)owner
{
	return (_owner);
}

- (void)setOwner:(PBXTarget *)owner
{
	_owner = owner;
}

- (BOOL)needsSync
{
	return (_needsSync);
}

- (void)setNeedsSync:(BOOL)flag
{
	_needsSync = flag;
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

+ (NSArray *)standardBuildPhaseClasses
{
	return (@[[PBXHeadersBuildPhase class], [PBXSourcesBuildPhase class],
	    [PBXFrameworksBuildPhase class], [PBXResourcesBuildPhase class],
	    [PBXCopyFilesBuildPhase class], [PBXShellScriptBuildPhase class]]);
}

- (void)setBuildPhases:(NSArray *)phases
{
	PBXBuildPhase *phase;

	_buildPhases = (phases != nil) ? [phases mutableCopy] : nil;
	for (phase in _buildPhases) {
		if ([phase isKindOfClass:[PBXBuildPhase class]])
			[phase setTarget:self];
	}
}

- (void)insertBuildPhase:(PBXBuildPhase *)phase atIndex:(NSUInteger)index
{
	if (phase == nil)
		return;
	if (_buildPhases == nil)
		_buildPhases = [[NSMutableArray alloc] init];
	if (index > [_buildPhases count])
		index = [_buildPhases count];
	[_buildPhases insertObject:phase atIndex:index];
	[phase setTarget:self];
}

- (void)addBuildPhase:(PBXBuildPhase *)phase
{
	if (phase == nil)
		return;
	if (_buildPhases == nil)
		_buildPhases = [[NSMutableArray alloc] init];
	[_buildPhases addObject:phase];
	[phase setTarget:self];
}

- (void)removeBuildPhase:(PBXBuildPhase *)phase
{
	if (phase == nil || _buildPhases == nil)
		return;
	if ([phase target] == self)
		[phase setTarget:nil];
	[_buildPhases removeObject:phase];
}

- (void)moveBuildPhase:(PBXBuildPhase *)phase toIndex:(NSUInteger)index
{
	NSUInteger current;

	if (phase == nil || _buildPhases == nil)
		return;
	current = [_buildPhases indexOfObject:phase];
	if (current == NSNotFound)
		return;
	[_buildPhases removeObjectAtIndex:current];
	if (index > [_buildPhases count])
		index = [_buildPhases count];
	[_buildPhases insertObject:phase atIndex:index];
}

- (PBXBuildPhase *)buildPhaseNamed:(NSString *)name
{
	PBXBuildPhase *phase;

	for (phase in _buildPhases) {
		if ([phase isKindOfClass:[PBXBuildPhase class]] &&
		    [[phase name] caseInsensitiveCompare:name] == NSOrderedSame)
			return (phase);
	}
	return (nil);
}

- (PBXBuildPhase *)buildPhaseOfClass:(Class)aClass
{
	PBXBuildPhase *phase;

	for (phase in _buildPhases) {
		if ([phase isKindOfClass:aClass])
			return (phase);
	}
	return (nil);
}

- (NSArray *)buildPhasesOfClass:(Class)aClass
{
	NSMutableArray *result = [NSMutableArray array];
	PBXBuildPhase *phase;

	for (phase in _buildPhases) {
		if ([phase isKindOfClass:aClass])
			[result addObject:phase];
	}
	return (result);
}

static PBXBuildPhase *DefaultBuildPhase(PBXTarget *target, Class aClass)
{
	PBXBuildPhase *phase = [target buildPhaseOfClass:aClass];

	if (phase == nil) {
		phase = [[aClass alloc] init];
		[target addBuildPhase:phase];
	}
	return (phase);
}

- (PBXBuildPhase *)defaultHeaderBuildPhase
{
	return (DefaultBuildPhase(self, [PBXHeadersBuildPhase class]));
}

- (PBXBuildPhase *)defaultResourceBuildPhase
{
	return (DefaultBuildPhase(self, [PBXResourcesBuildPhase class]));
}

- (PBXBuildPhase *)defaultSourceCodeBuildPhase
{
	return (DefaultBuildPhase(self, [PBXSourcesBuildPhase class]));
}

- (PBXBuildPhase *)defaultLinkBuildPhase
{
	return (DefaultBuildPhase(self, [PBXFrameworksBuildPhase class]));
}

- (PBXBuildPhase *)defaultFrameworksBuildPhase
{
	return (DefaultBuildPhase(self, [PBXFrameworksBuildPhase class]));
}

- (PBXBuildPhase *)defaultRezBuildPhase
{
	return (DefaultBuildPhase(self, [PBXRezBuildPhase class]));
}

- (PBXBuildPhase *)defaultJavaArchiveBuildPhase
{
	return (DefaultBuildPhase(self, [PBXJavaArchiveBuildPhase class]));
}

- (NSArray *)copyFilesBuildPhases
{
	return ([self buildPhasesOfClass:[PBXCopyFilesBuildPhase class]]);
}

- (NSArray *)shellScriptBuildPhases
{
	return ([self buildPhasesOfClass:[PBXShellScriptBuildPhase class]]);
}

- (NSArray *)appleScriptBuildPhases
{
	return ([self buildPhasesOfClass:[PBXAppleScriptBuildPhase class]]);
}

- (BOOL)wantsTopLevelItemForBuildPhases
{
	return (YES);
}

- (BOOL)allowsBuildPhasesOfClass:(Class)aClass
{
	return (YES);
}

- (BOOL)allowsShellScriptBuildPhases
{
	return (YES);
}

- (BOOL)allowsCopyFilesBuildPhases
{
	return (YES);
}

- (BOOL)allowsZeroBuildPhases
{
	return (NO);
}

- (NSArray *)buildPhasesContainingReference:(PBXReference *)reference
{
	NSMutableArray *result = [NSMutableArray array];
	PBXBuildPhase *phase;

	for (phase in _buildPhases) {
		if (![phase isKindOfClass:[PBXBuildPhase class]])
			continue;
		if ([phase buildFileForReference:reference] != nil)
			[result addObject:phase];
	}
	return (result);
}

- (BOOL)containsBuildFileForReferenceIdenticalTo:(PBXReference *)reference
    inBuildPhase:(PBXBuildPhase *)phase
{
	return ([phase buildFileForReference:reference] != nil);
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

- (NSString *)productInstallPath
{
	return (_productInstallPath);
}

- (void)setProductInstallPath:(NSString *)path
{
	_productInstallPath = [path copy];
}

- (NSString *)buildArgumentsString
{
	return (_buildArgumentsString);
}

- (void)setBuildArgumentsString:(NSString *)string
{
	_buildArgumentsString = [string copy];
}

- (NSString *)buildToolPath
{
	return (_buildToolPath);
}

- (void)setBuildToolPath:(NSString *)path
{
	_buildToolPath = [path copy];
}

- (NSString *)buildWorkingDirectory
{
	return (_buildWorkingDirectory);
}

- (void)setBuildWorkingDirectory:(NSString *)path
{
	_buildWorkingDirectory = [path copy];
}

- (NSNumber *)passBuildSettingsInEnvironment
{
	return (_passBuildSettingsInEnvironment);
}

- (void)setPassBuildSettingsInEnvironment:(NSNumber *)flag
{
	_passBuildSettingsInEnvironment = flag;
}

- (PBXReference *)productReferenceProxy
{
	return (_productReferenceProxy);
}

- (void)setProductReferenceProxy:(PBXReference *)reference
{
	_productReferenceProxy = reference;
}

- (NSArray *)packageProductDependencies
{
	return (_packageProductDependencies);
}

- (void)setPackageProductDependencies:(NSArray *)dependencies
{
	_packageProductDependencies = (dependencies != nil) ? [dependencies mutableCopy] : nil;
}

- (NSArray *)fileSystemSynchronizedGroups
{
	return (_fileSystemSynchronizedGroups);
}

- (void)setFileSystemSynchronizedGroups:(NSArray *)groups
{
	_fileSystemSynchronizedGroups = (groups != nil) ? [groups mutableCopy] : nil;
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

- (BOOL)allowsZeroBuildPhases
{
	return (YES);
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
