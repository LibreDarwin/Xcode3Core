/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Build-configuration classes (DevToolsCore). */

#ifndef DEVTOOLSCORE_XCBUILDCONFIGURATION_H
#define DEVTOOLSCORE_XCBUILDCONFIGURATION_H

#import "DevToolsCore/PBXBuild.h"

@class PBXFileReference;

/* A named set of build settings ("Debug", "Release", ...). */
@interface XCBuildConfiguration : PBXProjectItem
{
	NSString *_name;
	NSMutableDictionary *_buildSettings;
	PBXFileReference *_baseConfigurationReference;
}
- (NSString *)name;
- (void)setName:(NSString *)name;
- (NSMutableDictionary *)buildSettings;
- (void)setBuildSettings:(NSDictionary *)settings;
- (PBXFileReference *)baseConfigurationReference;
- (void)setBaseConfigurationReference:(PBXFileReference *)reference;
@end

/* An ordered list of build configurations owned by a target or project. */
@interface XCConfigurationList : PBXProjectItem
{
	NSMutableArray *_buildConfigurations;
	NSString *_defaultConfigurationName;
	NSNumber *_defaultConfigurationIsVisible;
}
- (NSArray *)buildConfigurations;
- (void)setBuildConfigurations:(NSArray *)configurations;
- (NSString *)defaultConfigurationName;
- (void)setDefaultConfigurationName:(NSString *)name;
- (NSNumber *)defaultConfigurationIsVisible;
- (void)setDefaultConfigurationIsVisible:(NSNumber *)flag;
@end

#endif	/* DEVTOOLSCORE_XCBUILDCONFIGURATION_H */
