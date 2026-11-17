/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCPropertyDomainSpecification.
 */

#ifndef DEVTOOLSCORE_BUILDSYSTEM_XCPROPERTYDOMAINSPECIFICATION_H
#define DEVTOOLSCORE_BUILDSYSTEM_XCPROPERTYDOMAINSPECIFICATION_H

#import <Foundation/Foundation.h>

#import "DevToolsCore/BuildSystem/XCSpecification.h"

@class DVTMacroDefinitionTable, TSPropertyListDictionary;

@interface XCPropertyDomainSpecification : XCSpecification {
	NSSet *_deletedOptionNames;
	NSDictionary *_buildOptions;
	NSArray *_orderedBuildOptions;
	NSArray *_optionNamesForCommandLine;
	NSArray *_buildOptionCategories;
	NSSet *_buildOptionConditionFlavors;
	XCPropertyDomainSpecification *_specForUserInterface;
	NSDictionary *_flattenedBuildOptions;
	NSArray *_flattenedOrderedBuildOptions;
	NSArray *_flattenedCommonBuildOptions;
	NSArray *_flattenedOptionNamesForCommandLine;
	NSArray *_flattenedOptionCategories;
	DVTMacroDefinitionTable *_flattenedDefaultValues;
	DVTMacroDefinitionTable *_flattenedDefaultValuesTable;
	DVTMacroDefinitionTable *_defaultOptionValues;
}

+ (Class)specificationTypeBaseClass;
+ (NSString *)specificationType;
+ (NSString *)localizedSpecificationTypeName;
+ (NSSet *)specificationTypePathExtensions;
+ (NSString *)specificationRegistryName;
+ (void)registerSpecificationOrProxy:(id)specification;
+ (NSDictionary *)dictionaryOfallRegisteredPropertyDomainsInSpecificationDomain:(NSString *)domain;
+ (NSSet *)allRegisteredSpecificationDomains;
+ (NSArray *)allRegisteredPropertyDomainsInSpecificationDomain:(NSString *)domain;
+ (id)propertyDomainForIdentifier:(NSString *)identifier inSpecificationDomain:(NSString *)domain;
+ (NSArray *)allRegisteredPropertiesForName:(NSString *)name;

- (instancetype)initWithPropertyListDictionary:(TSPropertyListDictionary *)dictionary
				      inDomain:(NSString *)domain;
- (NSDictionary *)directlyDeclaredBuildOptions;
- (NSDictionary *)buildOptions;
- (id)buildOptionNamed:(NSString *)name;
- (NSArray *)orderedBuildOptions;
- (NSArray *)orderedSelfDefinedBuildOptions;
- (NSArray *)buildOptionCategories;
- (NSArray *)flattenedOptionCategories;
- (NSArray *)namesOfBuildOptionsForCommandLine;
- (NSArray *)namesOfFlattenedOptionsForCommandLine;
- (NSSet *)buildOptionConditionFlavors;
- (XCPropertyDomainSpecification *)specificationToShowInUserInterface;
- (void)_addToDefaultMacros:(DVTMacroDefinitionTable *)macros;
- (DVTMacroDefinitionTable *)defaultMacrosForAllOptions;

@end

#endif	/* DEVTOOLSCORE_BUILDSYSTEM_XCPROPERTYDOMAINSPECIFICATION_H */
