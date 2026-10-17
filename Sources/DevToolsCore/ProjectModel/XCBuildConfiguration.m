/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Build-configuration classes (DevToolsCore). */

#import "DevToolsCore/XCBuildConfiguration.h"

@implementation XCBuildConfiguration

+ (NSString *)classNameForPListArchive
{
	return (@"XCBuildConfiguration");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"buildSettings", @"name"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"baseConfigurationReference"]);
}

- (NSString *)name
{
	return (_name);
}

- (void)setName:(NSString *)name
{
	_name = [name copy];
}

- (NSMutableDictionary *)buildSettings
{
	return (_buildSettings);
}

- (void)setBuildSettings:(NSDictionary *)settings
{
	_buildSettings = (settings != nil) ? [settings mutableCopy] : nil;
}

- (PBXFileReference *)baseConfigurationReference
{
	return (_baseConfigurationReference);
}

- (void)setBaseConfigurationReference:(PBXFileReference *)reference
{
	_baseConfigurationReference = reference;
}

- (NSString *)archiveComment
{
	return (_name);
}

@end

@implementation XCConfigurationList

+ (NSString *)classNameForPListArchive
{
	return (@"XCConfigurationList");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"defaultConfigurationIsVisible", @"defaultConfigurationName"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"buildConfigurations"]);
}

- (NSArray *)buildConfigurations
{
	return (_buildConfigurations);
}

- (void)setBuildConfigurations:(NSArray *)configurations
{
	_buildConfigurations = (configurations != nil) ?
	    [configurations mutableCopy] : nil;
}

- (NSString *)defaultConfigurationName
{
	return (_defaultConfigurationName);
}

- (void)setDefaultConfigurationName:(NSString *)name
{
	_defaultConfigurationName = [name copy];
}

- (NSNumber *)defaultConfigurationIsVisible
{
	return (_defaultConfigurationIsVisible);
}

- (void)setDefaultConfigurationIsVisible:(NSNumber *)flag
{
	_defaultConfigurationIsVisible = flag;
}

@end
