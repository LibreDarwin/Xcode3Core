/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Build configuration implementation. */

#import "DevToolsCore/XCBuildConfiguration.h"
#import "DevToolsCore/PBXReference.h"

@implementation XCBuildConfiguration

+ (instancetype)buildConfigurationWithName:(NSString *)name
    settings:(NSDictionary *)settings
{
	return ([[self alloc] initWithName:name settings:settings
	    makeImmutable:NO]);
}

+ (NSArray *)archivableAttributes
{
	return ([NSArray arrayWithObject:
	    @"baseConfigurationReferenceRelativePath_forArchiving"]);
}

+ (NSArray *)archivableRelationships
{
	return ([NSArray arrayWithObjects:
	    @"baseConfigurationReference_forArchiving",
	    @"baseConfigurationReferenceAnchor_forArchiving", nil]);
}

+ (NSString *)archiveNameForKey:(NSString *)key
{
	if ([key isEqualToString:
	    @"baseConfigurationReference_forArchiving"])
		return (@"baseConfigurationReference");
	if ([key isEqualToString:
	    @"baseConfigurationReferenceAnchor_forArchiving"])
		return (@"baseConfigurationReferenceAnchor");
	if ([key isEqualToString:
	    @"baseConfigurationReferenceRelativePath_forArchiving"])
		return (@"baseConfigurationReferenceRelativePath");
	return ([super archiveNameForKey:key]);
}

- (instancetype)initWithName:(NSString *)name settings:(NSDictionary *)settings
    makeImmutable:(BOOL)immutable
{
	self = [super init];
	if (self != nil) {
		[self setName:name];
		[self setBuildSettings:settings];
		_hidden = NO;
	}
	return (self);
}

- (NSString *)archiveComment
{
	return ([self name]);
}

- (BOOL)hidden
{
	return (_hidden);
}

- (void)setHidden:(BOOL)hidden
{
	_hidden = hidden;
}

- (BOOL)isHidden
{
	return (_hidden);
}

- (BOOL)couldBeActive
{
	return (!_hidden);
}

- (NSString *)inspectorDisplayName
{
	return ([self name]);
}

- (NSString *)_buildSettingsLabel
{
	return ([NSString stringWithFormat:@"(null) configuration '%@'",
	    [self name]]);
}

- (XCBuildConfiguration *)baseBuildConfiguration
{
	return (nil);
}

- (PBXFileReference *)resolvedBaseConfigurationReference
{
	return (_baseConfigurationReference);
}

- (id)baseConfigurationReferenceAnchor
{
	return (_baseConfigurationReferenceAnchor);
}

- (void)setBaseConfigurationReferenceAnchor:(id)anchor
{
	_baseConfigurationReferenceAnchor = anchor;
}

- (PBXFileReference *)baseConfigurationReference
{
	return (_baseConfigurationReference);
}

- (void)setBaseConfigurationReference:(PBXFileReference *)reference
{
	_baseConfigurationReference = reference;
}

- (PBXFileReference *)baseConfigurationReference_forArchiving
{
	return (_baseConfigurationReference);
}

- (void)setBaseConfigurationReference_forArchiving:(PBXFileReference *)reference
{
	_baseConfigurationReference = reference;
}

- (id)baseConfigurationReferenceAnchor_forArchiving
{
	return (_baseConfigurationReferenceAnchor);
}

- (void)setBaseConfigurationReferenceAnchor_forArchiving:(id)anchor
{
	_baseConfigurationReferenceAnchor = anchor;
}

- (NSString *)baseConfigurationReferenceRelativePath_forArchiving
{
	return (_baseConfigurationReferenceRelativePath);
}

- (void)setBaseConfigurationReferenceRelativePath_forArchiving:(NSString *)path
{
	_baseConfigurationReferenceRelativePath = [path copy];
}

- (id)buildSettingForKeyPath:(NSString *)path
{
	if (path == nil)
		return (nil);
	return ([[self buildSettings] objectForKey:path]);
}

- (void)setBuildSetting:(id)setting forKeyPath:(NSString *)path
{
	if (path == nil)
		return;
	if (setting == nil) {
		[[self buildSettings] removeObjectForKey:path];
		return;
	}
	[[self buildSettings] setObject:setting forKey:path];
}

- (void)removeBuildSettingForKeyPath:(NSString *)path
{
	if (path != nil)
		[[self buildSettings] removeObjectForKey:path];
}

- (NSArray *)buildSettingDictionariesAndGetErrors:(NSError **)errors
{
	if (errors != NULL)
		*errors = nil;
	return ([NSArray arrayWithObject:[self buildSettings]]);
}

@end

@implementation XCConfigurationList

+ (NSArray *)archivableAttributes
{
	return (@[@"defaultConfigurationName",
	    @"defaultConfigurationIsVisible"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"buildConfigurations"]);
}

+ (instancetype)configurationListWithConfigurations:(NSArray *)configurations
{
	return ([[self alloc] initWithConfigurations:configurations]);
}

- (instancetype)init
{
	self = [super init];
	if (self != nil)
		_buildConfigurations = [[NSMutableArray alloc] init];
	return (self);
}

- (instancetype)initWithConfigurations:(NSArray *)configurations
{
	self = [self init];
	if (self != nil)
		[self setBuildConfigurations:configurations];
	return (self);
}

- (NSString *)archiveComment
{
	return ([self defaultConfigurationName] ?: @"List");
}

- (id)archiveValueForKey:(NSString *)key
{
	if ([key isEqualToString:@"defaultConfigurationIsVisible"] &&
	    !_defaultConfigurationIsVisibleSet)
		return (nil);
	return ([super archiveValueForKey:key]);
}

- (id)copyWithZone:(NSZone *)zone
{
	XCConfigurationList *copy = [[[self class] allocWithZone:zone]
	    initWithConfigurations:_buildConfigurations];

	[copy setDefaultConfigurationName:_defaultConfigurationName];
	[copy setDefaultConfigurationIsVisible:_defaultConfigurationIsVisible];
	copy->_defaultConfigurationIsVisibleSet =
	    _defaultConfigurationIsVisibleSet;
	return (copy);
}

- (NSArray *)buildConfigurations
{
	return (_buildConfigurations);
}

- (void)setBuildConfigurations:(NSArray *)configurations
{
	NSMutableArray *copy = (configurations != nil) ?
	    [configurations mutableCopy] : [[NSMutableArray alloc] init];

	_buildConfigurations = copy;
}

- (NSString *)defaultConfigurationName
{
	return (_defaultConfigurationName);
}

- (void)setDefaultConfigurationName:(NSString *)name
{
	_defaultConfigurationName = [name copy];
}

- (BOOL)defaultConfigurationIsVisible
{
	return (_defaultConfigurationIsVisible);
}

- (void)setDefaultConfigurationIsVisible:(BOOL)visible
{
	_defaultConfigurationIsVisible = visible;
	_defaultConfigurationIsVisibleSet = YES;
}

- (XCBuildConfiguration *)defaultConfiguration
{
	if (_defaultConfigurationName == nil)
		return (nil);
	return ([self buildConfigurationForName:_defaultConfigurationName]);
}

- (NSArray *)buildConfigurationNames
{
	NSMutableArray *names = [NSMutableArray arrayWithCapacity:
	    [_buildConfigurations count]];
	XCBuildConfiguration *configuration;

	for (configuration in _buildConfigurations)
		[names addObject:[configuration name] ?: @""];
	return (names);
}

- (NSUInteger)countOfBuildConfigurations
{
	return ([_buildConfigurations count]);
}

- (XCConfigurationList *)baseConfigurationList
{
	return (nil);
}

- (id)owner
{
	return (nil);
}

- (NSString *)configurationTableDebugLabel
{
	return (nil);
}

- (NSArray *)localBuildSettingsDictionariesForAllConfigurations
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:
	    [_buildConfigurations count]];
	XCBuildConfiguration *configuration;

	for (configuration in _buildConfigurations)
		[result addObject:[configuration buildSettings]];
	return (result);
}

- (BOOL)buildConfigurationExistsForName:(NSString *)name
{
	return ([self buildConfigurationForName:name] != nil);
}

- (XCBuildConfiguration *)buildConfigurationForName:(NSString *)name
{
	XCBuildConfiguration *configuration;

	if (name == nil)
		return (nil);
	for (configuration in _buildConfigurations) {
		if ([[configuration name] isEqualToString:name])
			return (configuration);
	}
	return (nil);
}

- (XCBuildConfiguration *)effectiveBuildConfigurationForName:(NSString *)name
{
	XCBuildConfiguration *configuration = [self buildConfigurationForName:name];

	if (configuration != nil)
		return (configuration);
	return ([_buildConfigurations count] > 0) ? [_buildConfigurations
	    objectAtIndex:0] : nil;
}

- (NSArray *)buildSettingDictionariesForConfigurationName:(NSString *)name
    errors:(NSError **)errors
{
	XCBuildConfiguration *configuration = [self
	    buildConfigurationForName:name];

	if (errors != NULL)
		*errors = nil;
	if (configuration == nil)
		return ([NSArray array]);
	return ([NSArray arrayWithObject:[configuration buildSettings]]);
}

- (void)insertObject:(XCBuildConfiguration *)configuration
    inBuildConfigurationsAtIndex:(NSUInteger)index
{
	if (configuration == nil)
		return;
	[_buildConfigurations insertObject:configuration atIndex:index];
}

- (void)addBuildConfiguration:(XCBuildConfiguration *)configuration
{
	if (configuration == nil)
		return;
	[_buildConfigurations addObject:configuration];
}

- (void)removeObjectFromBuildConfigurationsAtIndex:(NSUInteger)index
{
	if (index < [_buildConfigurations count])
		[_buildConfigurations removeObjectAtIndex:index];
}

- (void)moveBuildConfigurationsAtIndexes:(NSIndexSet *)indexes
    toIndex:(NSUInteger)index
{
	NSMutableArray *moved = [NSMutableArray array];
	NSMutableIndexSet *valid = [NSMutableIndexSet indexSet];
	NSUInteger i;
	NSUInteger adjust = 0;

	if ([indexes count] == 0)
		return;
	for (i = [indexes firstIndex]; i != NSNotFound;
	    i = [indexes indexGreaterThanIndex:i]) {
		if (i >= [_buildConfigurations count])
			continue;
		[valid addIndex:i];
		[moved addObject:[_buildConfigurations objectAtIndex:i]];
		if (i < index)
			adjust++;
	}
	if ([valid count] == 0)
		return;
	[_buildConfigurations removeObjectsAtIndexes:valid];
	NSUInteger destination = (index >= adjust) ? index - adjust : 0;

	if (destination > [_buildConfigurations count])
		destination = [_buildConfigurations count];
	[_buildConfigurations insertObjects:moved atIndexes:
	    [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(destination,
	    [moved count])]];
}

@end
