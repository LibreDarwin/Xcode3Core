/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Build-configuration classes (DevToolsCore). */

#ifndef DEVTOOLSCORE_XCBUILDCONFIGURATION_H
#define DEVTOOLSCORE_XCBUILDCONFIGURATION_H

#import "DevToolsCore/PBXBuild.h"

@class PBXFileReference;

/* A named set of build settings ("Debug", "Release", ...). */
@interface XCBuildConfiguration : PBXBuildStyle
{
	PBXFileReference *_baseConfigurationReference;
	id _baseConfigurationReferenceAnchor;
	NSString *_baseConfigurationReferenceRelativePath;
	BOOL _hidden;
}
+ (instancetype)buildConfigurationWithName:(NSString *)name
    settings:(NSDictionary *)settings;
- (instancetype)initWithName:(NSString *)name settings:(NSDictionary *)settings
    makeImmutable:(BOOL)immutable;
- (BOOL)hidden;
- (void)setHidden:(BOOL)hidden;
- (BOOL)isHidden;
- (BOOL)couldBeActive;
- (NSString *)inspectorDisplayName;
- (NSString *)_buildSettingsLabel;
- (XCBuildConfiguration *)baseBuildConfiguration;
- (PBXFileReference *)resolvedBaseConfigurationReference;
- (id)baseConfigurationReferenceAnchor;
- (void)setBaseConfigurationReferenceAnchor:(id)anchor;

- (PBXFileReference *)baseConfigurationReference;
- (void)setBaseConfigurationReference:(PBXFileReference *)reference;
- (PBXFileReference *)baseConfigurationReference_forArchiving;
- (void)setBaseConfigurationReference_forArchiving:(PBXFileReference *)reference;
- (id)baseConfigurationReferenceAnchor_forArchiving;
- (void)setBaseConfigurationReferenceAnchor_forArchiving:(id)anchor;
- (NSString *)baseConfigurationReferenceRelativePath_forArchiving;
- (void)setBaseConfigurationReferenceRelativePath_forArchiving:(NSString *)path;

- (id)buildSettingForKeyPath:(NSString *)path;
- (void)setBuildSetting:(id)setting forKeyPath:(NSString *)path;
- (void)removeBuildSettingForKeyPath:(NSString *)path;
- (NSArray *)buildSettingDictionariesAndGetErrors:(NSError **)errors;
@end

/* An ordered list of build configurations owned by a target or project. */
@interface XCConfigurationList : PBXProjectItem <NSCopying>
{
	NSMutableArray *_buildConfigurations;
	NSString *_defaultConfigurationName;
	BOOL _defaultConfigurationIsVisible;
	BOOL _defaultConfigurationIsVisibleSet;
}
+ (instancetype)configurationListWithConfigurations:(NSArray *)configurations;
- (instancetype)initWithConfigurations:(NSArray *)configurations;
- (NSArray *)buildConfigurations;
- (void)setBuildConfigurations:(NSArray *)configurations;
- (NSString *)defaultConfigurationName;
- (void)setDefaultConfigurationName:(NSString *)name;
- (BOOL)defaultConfigurationIsVisible;
- (void)setDefaultConfigurationIsVisible:(BOOL)visible;
- (XCBuildConfiguration *)defaultConfiguration;
- (NSArray *)buildConfigurationNames;
- (NSUInteger)countOfBuildConfigurations;
- (XCConfigurationList *)baseConfigurationList;
- (id)owner;
- (NSString *)configurationTableDebugLabel;
- (NSArray *)localBuildSettingsDictionariesForAllConfigurations;
- (BOOL)buildConfigurationExistsForName:(NSString *)name;
- (XCBuildConfiguration *)buildConfigurationForName:(NSString *)name;
- (XCBuildConfiguration *)effectiveBuildConfigurationForName:(NSString *)name;
- (NSArray *)buildSettingDictionariesForConfigurationName:(NSString *)name
    errors:(NSError **)errors;
- (void)insertObject:(XCBuildConfiguration *)configuration
    inBuildConfigurationsAtIndex:(NSUInteger)index;
- (void)addBuildConfiguration:(XCBuildConfiguration *)configuration;
- (void)removeObjectFromBuildConfigurationsAtIndex:(NSUInteger)index;
- (void)moveBuildConfigurationsAtIndexes:(NSIndexSet *)indexes
    toIndex:(NSUInteger)index;
@end

#endif	/* DEVTOOLSCORE_XCBUILDCONFIGURATION_H */
