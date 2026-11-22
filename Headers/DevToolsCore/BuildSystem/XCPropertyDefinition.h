/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCPropertyDefinition and
 * XCPropertyTypes.  Only the behavior reachable from xcspec loading and
 * PBXFrameworksBuildPhase's primary attribute is modeled here; unsupported
 * class methods are declared for source compatibility but return empty
 * collections.
 */

#ifndef DEVTOOLSCORE_BUILDSYSTEM_XCPROPERTYDEFINITION_H
#define DEVTOOLSCORE_BUILDSYSTEM_XCPROPERTYDEFINITION_H

#import <Foundation/Foundation.h>

#import "DevToolsSupport/TSPropertyListDictionary.h"
#import <DVTMacroFoundation/DVTMacroExpansion-Protocol.h>

@class XCPropertyDefinition_SupportedVersionRange, XCPropertyDomainSpecification;

@interface XCPropertyMacroExpression : NSObject
+ (id)propertyMacroExpressionFromString:(NSString *)string error:(NSError **)error;
- (id)evaluateWithMacroExpansionScope:(id)scope;
- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope;
@end

@interface XCPropertyValueDefinition : NSObject
- (instancetype)initFromPListDictionary:(NSDictionary *)dictionary
			     forPropertyName:(NSString *)name;
@property (readonly) NSDictionary *properties;
@property (readonly) id value;
@property (readonly) id localizedValue;
@property (readonly) NSString *localizedDescription;
@property (readonly) id commandArgumentGenerationInfo;
@end

@protocol XCPropertyTypes
+ (NSString *)identifier;
+ (NSString *)localizedName;
+ (BOOL)isListType;
@end

@interface XCPropertyDefinition : NSObject <XCPropertyTypes> {
    NSString *_name;
    Class _typeClass;
    Class _uiTypeClass;
    NSString *_defaultString;
    id <DVTMacroExpansion> _defaultValue;
    NSArray *_allowedValues;
    NSArray *_localizedAllowedValues;
    NSString *_category;
    NSString *_localizedName;
    NSString *_localizedDescription;
    NSString *_definitionLocationDescription;
    NSSet *_conditionFlavors;
    id _conditionExpression;
    NSArray *_commandLineArgs;
    NSString *_commandLineFlag;
    NSString *_commandLinePrefixFlag;
    NSDictionary *_additionalBuildSettings;
    TSPropertyListDictionary *_properties;
    NSSet *_supportedVersionRanges;
    XCPropertyDomainSpecification *_domain;
    BOOL _isUserDefined;
    BOOL _isAppleInternalOnly;
    BOOL _isBasic;
    BOOL _uiShouldRemoveIfEmpty;
}

@property (readonly) NSString *name;
@property (readonly) Class <XCPropertyTypes> type;
@property (readonly) BOOL isListType;
@property (readonly) Class <XCPropertyTypes> uiType;
@property (readonly) NSString *uiTypeString;
@property (readonly) NSArray *allowedValues;
@property (readonly) id <DVTMacroExpansion> defaultValue;
@property (copy) NSString *category;
@property (readonly) NSString *categoryNameForUserInterface;
@property (readonly) NSString *localizedName;
@property (readonly) NSString *localizedDescription;
@property (readonly) NSArray *localizedAllowedValues;

+ (NSArray *)dbgAllPropertyDefinitions;
+ (id)_parsedDefaultValueForString:(NSString *)string;
+ (instancetype)propertyDefinitionFromPListDictionary:(TSPropertyListDictionary *)dictionary;
+ (instancetype)stringPropertyDefinitionWithName:(NSString *)name
				    defaultValue:(id)value;
+ (void)_addPropertyDefinitionsInSpecificationDomain:(id)domain
					  toDictionary:(NSMutableDictionary *)dictionary;
+ (NSArray *)allPropertyDefinitionsInAllSpecificationDomains;
+ (NSArray *)baseDefinitionsForAllPropertyDefinitionsInAllSpecificationDomains;
+ (Class)typeOfPropertyNamed:(NSString *)name;
+ (BOOL)registerPropertyType:(Class)type forPropertyNamed:(NSString *)name;
+ (BOOL)unregisterPropertyTypeForPropertyNamed:(NSString *)name;

- (instancetype)initWithName:(NSString *)name
		      uiType:(id)type
	       allowedValues:(NSArray *)values
		 defaultValue:(id)value
	isAppleInternalOnly:(BOOL)only
		     isBasic:(BOOL)basic
	 commandLineArguments:(NSArray *)arguments;
- (instancetype)initWithName:(NSString *)name
	       allowedValues:(NSArray *)values
		 defaultValue:(id)value
	isAppleInternalOnly:(BOOL)only
		     isBasic:(BOOL)basic
	 commandLineArguments:(NSArray *)arguments;
- (instancetype)initFromPListDictionary:(TSPropertyListDictionary *)dictionary;
- (NSString *)typeString;
- (NSArray *)allowedValuesInTarget:(id)target;
- (NSDictionary *)additionalBuildSettings;
- (NSSet *)supportedArchitectures;
- (NSSet *)supportedArchitecturesInDomain:(id)domain
			 withMacroExpansionScope:(id)scope;
- (BOOL)supportsArchitecture:(NSString *)architecture
		    inDomain:(id)domain
	 withMacroExpansionScope:(id)scope;
- (NSSet *)supportedFileTypes;
- (BOOL)supportsFileType:(NSString *)type;
- (BOOL)hasSupportedVersionRanges;
- (BOOL)supportsVersion:(id)version;
- (XCPropertyDomainSpecification *)propertyDomain;
- (void)setPropertyDomain:(XCPropertyDomainSpecification *)domain;
- (NSSet *)conditionFlavors;
- (BOOL)canGenerateCommandLineArguments;
- (id)commandArgumentGenerationInfo;
- (id)conditionExpression;
- (BOOL)isAppleInternalOnly;
- (BOOL)isBasic;
- (NSString *)nameOfOptionToPrecedeOnCommandLine;
- (NSString *)nameOfOptionToSucceedOnCommandLine;
- (NSString *)nameOfOptionToPrecedeInUserInterface;
- (NSString *)nameOfOptionToSucceedInUserInterface;
- (BOOL)uiShouldRemoveIfEmptyValue;
- (BOOL)isUserDefined;
- (void)setUserDefined:(BOOL)defined;
- (TSPropertyListDictionary *)properties;
- (id)valueForUndefinedKey:(NSString *)key;
- (NSString *)definitionLocationDescription;
- (void)setDefinitionLocationDescription:(NSString *)description;
- (NSArray *)localizedAllowedValuesInTarget:(id)target;
- (BOOL)propertyIsEnabledWithMacroExpansionScope:(id)scope;
- (void)printToStdout;

@end

@interface XCStringPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCStringListPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCPathPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCPathListPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCEnumerationPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
- (NSArray *)_filteredValueDefinitionsForTarget:(id)target;
@end
@interface XCSDKRootPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCCompilerVersionPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCBooleanPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCArchitectureListPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCDeploymentTargetPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCSupportedPlatformsPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCCodeSignIdentityPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCCodeSignStylePropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCDevelopmentTeamPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCOpenCLArchitecturesPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCProvisioningProfilePropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCProvisioningProfileSpecifierPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCSwiftVersionPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end
@interface XCTargetedDeviceFamilyPropertyDefinition : XCPropertyDefinition <XCPropertyTypes>
@end

/* Concrete class for an xcspec Type identifier.  Unknown identifiers fall
 * back to XCStringPropertyDefinition, matching Apple's observable behavior. */
Class XCPropertyTypeClassForIdentifier(NSString *identifier);

#endif	/* DEVTOOLSCORE_BUILDSYSTEM_XCPROPERTYDEFINITION_H */
