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
	if ([_containerPortal respondsToSelector:@selector(loadedContainer)])
		return ([_containerPortal performSelector:@selector(loadedContainer)]);
	return (nil);
}

- (PBXObject *)remoteContainerItem
{
	PBXContainer *container = [self remoteContainer];
	NSInteger type = [_proxyType integerValue];
	PBXObject *item;
	PBXTarget *target;

	if (container == nil)
		return (nil);
	if (type == 1) {
		item = [container itemForGlobalIDHexString:_remoteGlobalIDString];
		if (item != nil)
			return (item);
		if (_remoteInfo == nil ||
		    ![container isKindOfClass:[PBXProject class]])
			return (nil);
		target = [(PBXProject *)container targetNamed:_remoteInfo];
		if (target == nil)
			return (nil);
		_remoteGlobalIDString = [[target objectID] copy];
		if (_remoteGlobalIDString == nil)
			return (target);
		return ([container itemForGlobalIDHexString:_remoteGlobalIDString]);
	}
	if (type == 2) {
		if (_remoteInfo == nil ||
		    ![container isKindOfClass:[PBXProject class]])
			return (nil);
		target = [(PBXProject *)container targetNamed:_remoteInfo];
		return ([target productReference]);
	}
	return (nil);
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
	return (@[@"target", @"targetProxy", @"productReference"]);
}

+ (NSArray *)archivableKeys
{
	NSMutableArray *keys = [[super archivableKeys] mutableCopy];
	NSUInteger index = [keys indexOfObject:@"name"];

	if (index == NSNotFound)
		[keys addObjectsFromArray:@[@"platformFilter",
		    @"platformFilters"]];
	else {
		[keys insertObject:@"platformFilter" atIndex:index + 1];
		[keys insertObject:@"platformFilters" atIndex:index + 2];
	}
	return (keys);
}

static PBXContainerItemProxy *
LocalTargetProxy(PBXTarget *target)
{
	PBXContainer *container = [target container];
	NSString *identifier = [target objectID];
	NSString *info = [target displayName];

	if (![container isKindOfClass:[PBXProject class]])
		return (nil);
	if (identifier == nil)
		identifier = info;
	return ([[PBXContainerItemProxy alloc]
	    initWithType:1 portal:container
	    remoteGlobalIDString:identifier remoteInfo:info]);
}

- (instancetype)initWithLocalTarget:(PBXTarget *)target
{
	self = [self init];
	if (self != nil) {
		_target = target;
		_name = [[target displayName] copy];
		_productReference = [target productReference];
		_targetProxy = LocalTargetProxy(target);
	}
	return (self);
}

- (instancetype)initWithProjectReference:(PBXReference *)reference
    remoteTarget:(NSString *)target
{
	self = [self init];
	if (self != nil) {
		_targetProxy = [[PBXContainerItemProxy alloc]
		    initWithType:2 portal:reference remoteGlobalIDString:nil
		    remoteInfo:target];
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
	PBXObject *remote;

	if (_target != nil)
		return (_target);
	remote = [_targetProxy remoteContainerItem];
	if ([remote isKindOfClass:[PBXTarget class]]) {
		_target = (PBXTarget *)remote;
		return (_target);
	}
	return (nil);
}

- (void)setTarget:(PBXTarget *)target
{
	_target = target;
	if (target != nil)
		_targetProxy = LocalTargetProxy(target);
	[[self owner] performSelector:@selector(_invalidateDependencyOrderCaches)];
}

- (PBXContainerItemProxy *)targetProxy
{
	return (_targetProxy);
}

- (void)setTargetProxy:(PBXContainerItemProxy *)proxy
{
	_targetProxy = proxy;
	if (_target == nil) {
		PBXObject *remote = [_targetProxy remoteContainerItem];

		if ([remote isKindOfClass:[PBXTarget class]])
			_target = (PBXTarget *)remote;
	}
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
	return (_productReference);
}

- (void)setProductReference:(PBXObject *)reference
{
	_productReference = reference;
}

- (NSArray *)orderedRecursiveDependencies
{
	PBXTarget *target = [self target];

	if (target == nil)
		return (@[]);
	return ([target orderedRecursiveDependenciesIncludingSelf:YES]);
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
	return ([self name]);
}

- (NSString *)description
{
	return ([self name] ?: [super description]);
}

@end

@implementation PBXTarget

+ (NSArray *)archivableAttributes
{
	return (@[@"name", @"productName", @"productType", @"productInstallPath",
	    @"buildSettings", @"productSettingsXML", @"productSettings"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"dependencies", @"packageProductDependencies", @"buildPhases",
	    @"productReference", @"buildRules", @"productBuildLocation",
	    @"productInstallLocation", @"buildConfigurationList",
	    @"fileSystemSynchronizedGroupsArray"]);
}

+ (NSString *)archiveNameForKey:(NSString *)key
{
	if ([key isEqualToString:@"fileSystemSynchronizedGroupsArray"])
		return (@"fileSystemSynchronizedGroups");
	return ([super archiveNameForKey:key]);
}

- (BOOL)setArchiveValue:(id)value forKey:(NSString *)key
{
	if ([key isEqualToString:@"fileSystemSynchronizedGroups"])
		key = @"fileSystemSynchronizedGroupsArray";
	return ([super setArchiveValue:value forKey:key]);
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

- (NSArray *)buildFiles
{
	NSMutableArray *result = [NSMutableArray array];
	PBXBuildPhase *phase;

	for (phase in _buildPhases) {
		if ([phase isKindOfClass:[PBXBuildPhase class]])
			[result addObjectsFromArray:[phase buildFiles]];
	}
	return (result);
}

- (NSArray *)buildFilesForReference:(PBXReference *)reference
{
	NSMutableArray *result = [NSMutableArray array];
	PBXBuildFile *file;

	for (file in [self buildFiles]) {
		if ([file fileRef] == reference || [file productRef] == reference)
			[result addObject:file];
	}
	return (result);
}

- (NSArray *)buildFilesForReferenceIdenticalTo:(PBXReference *)reference
{
	return ([self buildFilesForReference:reference]);
}

- (BOOL)containsBuildFileForReferenceIdenticalTo:(PBXReference *)reference
    inBuildPhase:(PBXBuildPhase *)phase
{
	return ([phase buildFileForReference:reference] != nil);
}

static NSString *
ArchiveProductName(PBXObject *object)
{
	if (object == nil || ![object respondsToSelector:@selector(productName)])
		return (nil);
	return ([object performSelector:@selector(productName)]);
}

- (void)_invalidateDependencyOrderCaches
{
	PBXProject *project = [self project];
	PBXTarget *target;

	_cachedOrderedRecursiveDependencies = nil;
	_dependencyCycleDetected = NO;
	for (target in [project targets]) {
		target->_cachedOrderedRecursiveDependencies = nil;
		target->_dependencyCycleDetected = NO;
	}
}

- (NSArray *)dependencies
{
	return (_dependencies);
}

- (void)setDependencies:(NSArray *)dependencies
{
	PBXTargetDependency *dependency;

	_dependencies = (dependencies != nil) ? [dependencies mutableCopy] : nil;
	for (dependency in _dependencies) {
		if (![dependency isKindOfClass:[PBXTargetDependency class]])
			continue;
		[dependency setOwner:self];
	}
	[self _invalidateDependencyOrderCaches];
}

- (void)insertDependencies:(NSArray *)dependencies atIndex:(NSUInteger)index
{
	PBXTargetDependency *dependency;

	if (_dependencies == nil)
		_dependencies = [[NSMutableArray alloc] init];
	if (index > [_dependencies count])
		index = [_dependencies count];
	for (dependency in dependencies) {
		NSUInteger existing;

		if (![dependency isKindOfClass:[PBXTargetDependency class]])
			continue;
		existing = [_dependencies indexOfObjectIdenticalTo:dependency];
		if (existing != NSNotFound) {
			if (existing != index) {
				[_dependencies removeObjectAtIndex:existing];
				if (index > [_dependencies count])
					index = [_dependencies count];
				[_dependencies insertObject:dependency atIndex:index];
			}
		} else {
			PBXTarget *depTarget = [dependency target];
			PBXFileReference *product = [depTarget productReference];
			NSArray *buildFiles;
			PBXBuildFile *buildFile;

			[_dependencies insertObject:dependency atIndex:index];
			[dependency setOwner:self];
			[dependency setContainer:[self container]];
			if (product != nil) {
				buildFiles = [self buildFilesForReference:product];
				buildFile = [buildFiles firstObject];
				[dependency setPlatformFilters:[buildFile platformFilters]];
			} else {
				for (buildFile in [self buildFiles]) {
					PBXReference *reference =
					    [buildFile productReference];

					if ([ArchiveProductName(reference)
					    isEqualToString:ArchiveProductName(
					        [dependency productReference])]) {
						[dependency setPlatformFilters:
						    [buildFile platformFilters]];
						break;
					}
				}
			}
		}
		index++;
	}
	[self _invalidateDependencyOrderCaches];
}

- (void)addDependency:(PBXTargetDependency *)dependency
{
	if (dependency == nil)
		return;
	[self insertDependencies:@[ dependency ]
	    atIndex:[_dependencies count]];
}

- (void)removeDependency:(PBXTargetDependency *)dependency
{
	NSUInteger index;

	if (dependency == nil || _dependencies == nil)
		return;
	index = [_dependencies indexOfObjectIdenticalTo:dependency];
	if (index == NSNotFound)
		return;
	[_dependencies removeObjectAtIndex:index];
	if ([dependency owner] == self)
		[dependency setOwner:nil];
	[self _invalidateDependencyOrderCaches];
}

- (void)removeDependencies:(NSArray *)dependencies
{
	PBXTargetDependency *dependency;

	for (dependency in dependencies)
		[self removeDependency:dependency];
}

- (NSArray *)directDependencies
{
	NSMutableArray *result = [NSMutableArray array];
	PBXTargetDependency *dependency;

	for (dependency in _dependencies) {
		PBXTarget *depTarget = [dependency target];

		if (depTarget != nil)
			[result addObject:depTarget];
	}
	return (result);
}

- (BOOL)dependsOnTarget:(PBXTarget *)target
{
	return ([self dependencyForTarget:target] != nil);
}

- (PBXTargetDependency *)dependencyForTarget:(PBXTarget *)target
{
	PBXTargetDependency *dependency;

	if (target == nil)
		return (nil);
	for (dependency in _dependencies) {
		if ([dependency target] == target)
			return (dependency);
	}
	return (nil);
}

- (NSArray *)findDependingTargetsInProject:(PBXProject *)project
{
	NSMutableArray *result = [NSMutableArray array];
	PBXTarget *candidate;

	for (candidate in [project targets]) {
		if ([candidate isKindOfClass:[PBXTarget class]] &&
		    [candidate dependsOnTarget:self])
			[result addObject:candidate];
	}
	return (result);
}

- (NSArray *)missingDependencies
{
	NSMutableArray *result = [NSMutableArray array];
	PBXTargetDependency *dependency;

	for (dependency in _dependencies) {
		PBXContainerItemProxy *proxy = [dependency targetProxy];
		PBXObject *portal = [proxy containerPortal];

		if ([portal isKindOfClass:[PBXFileReference class]] &&
		    ![(PBXFileReference *)portal fileExists]) {
			[result addObject:dependency];
			continue;
		}
		if ([dependency target] != nil)
			continue;
		if ([dependency productReference] == nil)
			[result addObject:dependency];
	}
	return (result);
}

- (BOOL)_uncachedOrderedRecursiveDependencies:(NSMutableArray *)result
    visited:(NSMutableSet *)visited cycleCheck:(NSMutableSet *)cycleCheck
{
	PBXTargetDependency *dependency;

	if ([cycleCheck containsObject:self]) {
		_dependencyCycleDetected = YES;
		return (NO);
	}
	if ([visited containsObject:self])
		return (NO);
	[visited addObject:self];
	[cycleCheck addObject:self];
	for (dependency in _dependencies) {
		PBXTarget *depTarget = [dependency target];

		if (depTarget == nil)
			continue;
		if ([depTarget _uncachedOrderedRecursiveDependencies:result
		    visited:visited cycleCheck:cycleCheck])
			[result addObject:depTarget];
	}
	[cycleCheck removeObject:self];
	return (YES);
}

- (NSArray *)orderedRecursiveDependenciesIncludingSelf:(BOOL)includeSelf
{
	NSMutableArray *result = [NSMutableArray array];
	NSMutableSet *visited = [NSMutableSet set];
	NSMutableSet *cycleCheck = [NSMutableSet set];
	NSArray *ordered;

	if (_cachedOrderedRecursiveDependencies == nil) {
		[self _uncachedOrderedRecursiveDependencies:result
		    visited:visited cycleCheck:cycleCheck];
		_cachedOrderedRecursiveDependencies = [result copy];
	}
	ordered = _cachedOrderedRecursiveDependencies;
	if (includeSelf)
		return ([ordered arrayByAddingObject:self]);
	return (ordered);
}

- (NSArray *)orderedRecursiveDependencies
{
	return ([self orderedRecursiveDependenciesIncludingSelf:YES]);
}

- (PBXProject *)project
{
	PBXContainer *container = [self container];

	if ([container isKindOfClass:[PBXProject class]])
		return ((PBXProject *)container);
	return (nil);
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

- (NSArray *)fileSystemSynchronizedGroupsArray
{
	return (_fileSystemSynchronizedGroups);
}

- (void)setFileSystemSynchronizedGroupsArray:(NSArray *)groups
{
	[self setFileSystemSynchronizedGroups:groups];
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

- (NSString *)description
{
	return ([self displayName] ?: [super description]);
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

+ (NSArray *)archivableAttributes
{
	return (@[@"buildArgumentsString", @"buildToolPath",
	    @"buildWorkingDirectory", @"passBuildSettingsInEnvironment"]);
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
