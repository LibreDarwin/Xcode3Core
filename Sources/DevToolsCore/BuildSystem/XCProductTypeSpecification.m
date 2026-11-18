/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsCore/XCProductTypeSpecification.h"

#import <DVTMacroFoundation/DVTMacroDefinitionTable.h>

#import "DevToolsCore/PBXBuild.h"
#import "DevToolsCore/PBXPackageTypeSpecification.h"
#import "DevToolsCore/XCMacroExpansionScope.h"

static NSArray *
XCArrayOrString(id value)
{
	if ([value isKindOfClass:[NSArray class]]) {
		return (value);
	}
	if (value != nil) {
		return ([NSArray arrayWithObject:value]);
	}
	return ([NSArray array]);
}

static id
XCNormalizedValue(id value)
{
	if ([value isKindOfClass:[NSString class]]) {
		NSString *string = (NSString *)value;

		if ([string caseInsensitiveCompare:@"YES"] == NSOrderedSame) {
			return ([NSNumber numberWithBool:YES]);
		}
		if ([string caseInsensitiveCompare:@"NO"] == NSOrderedSame) {
			return ([NSNumber numberWithBool:NO]);
		}
		return (value);
	}
	if ([value isKindOfClass:[NSArray class]]) {
		NSMutableArray *result = [NSMutableArray arrayWithCapacity:[(NSArray *)value count]];

		for (id item in (NSArray *)value) {
			[result addObject:XCNormalizedValue(item)];
		}
		return (result);
	}
	if ([value isKindOfClass:[NSDictionary class]]) {
		NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[(NSDictionary *)value count]];

		for (id key in (NSDictionary *)value) {
			[result setObject:XCNormalizedValue([(NSDictionary *)value objectForKey:key])
				   forKey:key];
		}
		return (result);
	}
	return (value);
}

static Class
XCClassForBuildPhaseIdentifier(id identifier)
{
	if ([identifier isEqualToString:@"com.apple.buildphase.sources"]) {
		return ([PBXSourcesBuildPhase class]);
	}
	if ([identifier isEqualToString:@"com.apple.buildphase.frameworks"]) {
		return ([PBXFrameworksBuildPhase class]);
	}
	if ([identifier isEqualToString:@"com.apple.buildphase.resources"]) {
		return ([PBXResourcesBuildPhase class]);
	}
	if ([identifier isEqualToString:@"com.apple.buildphase.headers"]) {
		return ([PBXHeadersBuildPhase class]);
	}
	if ([identifier isEqualToString:@"com.apple.buildphase.copy-files"]) {
		return ([PBXCopyFilesBuildPhase class]);
	}
	if ([identifier isEqualToString:@"com.apple.buildphase.shell-script"]) {
		return ([PBXShellScriptBuildPhase class]);
	}
	if ([identifier isEqualToString:@"com.apple.buildphase.rez"]) {
		return ([PBXRezBuildPhase class]);
	}
	if ([identifier isEqualToString:@"com.apple.buildphase.java"]) {
		return ([PBXJavaArchiveBuildPhase class]);
	}
	if ([identifier isEqualToString:@"com.apple.buildphase.appleScript"]) {
		return ([PBXAppleScriptBuildPhase class]);
	}
	return (Nil);
}

static DVTMacroDefinitionTable *
XCFlattenedTable(XCProductTypeSpecification *superSpecification,
    DVTMacroDefinitionTable *own, NSString *label, SEL selector)
{
	DVTMacroDefinitionTable *table = [[DVTMacroDefinitionTable alloc] initWithLabel:label];

	if ([superSpecification isKindOfClass:[XCProductTypeSpecification class]]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		DVTMacroDefinitionTable *superTable = [superSpecification performSelector:selector];
#pragma clang diagnostic pop

		if (superTable != nil) {
			[table setMacroNamesAndValuesFromMacroDefinitionTable:superTable];
		}
	}
	if (own != nil) {
		[table setMacroNamesAndValuesFromMacroDefinitionTable:own];
	}
	[table makeImmutable];
	return (table);
}

@implementation XCProductTypeSpecification

+ (void)initialize
{
	if (self == [XCProductTypeSpecification class]) {
		[XCSpecification registerSpecificationTypeBaseClass:self];
	}
}

+ (Class)specificationTypeBaseClass
{
	return ([XCProductTypeSpecification class]);
}

+ (NSString *)specificationType
{
	return (@"ProductType");
}

+ (NSString *)localizedSpecificationTypeName
{
	return (@"product type");
}

+ (NSSet *)specificationTypePathExtensions
{
	return ([NSSet setWithObject:@"pbprodspec"]);
}

+ (NSString *)specificationRegistryName
{
	return ([self specificationType]);
}

- (id)initWithPropertyListDictionary:(id)dictionary inDomain:(id)domain
{
	self = [super initWithPropertyListDictionary:dictionary inDomain:domain];
	if (self == nil) {
		return (nil);
	}

	NSString *identifier = [self identifier];
	NSString *defaultLabel = [NSString stringWithFormat:@"// product type %@ defaults", identifier];
	NSString *overrideLabel = [NSString stringWithFormat:@"// product type %@ overrides", identifier];
	NSDictionary *defaultProperties = [self _objectForKeyIgnoringInheritance:@"DefaultBuildProperties"];
	DVTMacroDefinitionTable *defaults = [[DVTMacroDefinitionTable alloc] initWithLabel:defaultLabel];

	for (NSString *name in [[defaultProperties allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
		[defaults setStringValue:[defaultProperties objectForKey:name]
			     forMacroName:name
			      conditionSet:nil];
	}
	[defaults setLiteralValue:identifier
		      forMacroName:@"PRODUCT_TYPE"
		       conditionSet:nil];
	[defaults makeImmutable];
	_defaultMacros = defaults;

	NSDictionary *overridingSettings = [self _objectForKeyIgnoringInheritance:@"OverridingBuildSettings"];
	DVTMacroDefinitionTable *overrides = [[DVTMacroDefinitionTable alloc] initWithLabel:overrideLabel];

	for (NSString *name in [[overridingSettings allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
		[overrides setStringValue:[overridingSettings objectForKey:name]
				forMacroName:name
				 conditionSet:nil];
	}
	[overrides makeImmutable];
	_overridingMacros = overrides;

	XCProductTypeSpecification *superSpecification = (XCProductTypeSpecification *)[self superSpecification];
	_flattenedDefaultMacros = XCFlattenedTable(superSpecification, defaults,
	    defaultLabel, @selector(defaultMacros));
	_flattenedOverridingMacros = XCFlattenedTable(superSpecification, overrides,
	    overrideLabel, @selector(overridingMacros));

	NSArray *allowedIdentifiers = XCArrayOrString([self objectForKey:@"AllowedBuildPhases"]);
	NSMutableSet *allowedClasses = [NSMutableSet setWithCapacity:[allowedIdentifiers count]];

	for (id phaseIdentifier in allowedIdentifiers) {
		Class phaseClass = XCClassForBuildPhaseIdentifier(phaseIdentifier);

		if (phaseClass != Nil) {
			[allowedClasses addObject:phaseClass];
		}
	}
	_allowedBuildPhaseClasses = [allowedClasses copy];
	_allowedBuildPhaseIdentifiers = [[NSSet alloc] initWithArray:allowedIdentifiers];

	NSDictionary *fileTypes = [self dictionaryForKey:@"AllowedFileTypes"];
	NSMutableDictionary *normalizedFileTypes = [NSMutableDictionary dictionaryWithCapacity:[fileTypes count]];

	for (id phaseIdentifier in fileTypes) {
		[normalizedFileTypes setObject:XCArrayOrString([fileTypes objectForKey:phaseIdentifier])
					forKey:phaseIdentifier];
	}
	_allowedFileTypesByBuildPhaseIdentifier = [normalizedFileTypes copy];

	NSMutableArray *packageTypes = [NSMutableArray array];
	for (id packageIdentifier in XCArrayOrString([self objectForKey:@"PackageTypes"])) {
		PBXPackageTypeSpecification *specification =
		    [PBXPackageTypeSpecification specificationForIdentifier:packageIdentifier];

		if (specification == nil) {
			specification = [[PBXPackageTypeSpecification alloc]
			    initAsMissingSpecificationProxyWithIdentifier:packageIdentifier
			    name:nil
			    description:nil
			    inDomain:@""];
			[PBXPackageTypeSpecification registerSpecificationOrProxy:specification];
		}
		[packageTypes addObject:specification];
	}
	_packageTypes = [packageTypes copy];

	_defaultEntitlements = [XCNormalizedValue([self dictionaryForKey:@"DefaultEntitlements"]) copy];
	return (self);
}

- (id)defaultTargetName
{
	return ([self stringForKey:@"DefaultTargetName"]);
}

- (id)defaultMacros
{
	if (_flattenedDefaultMacros != nil) {
		return (_flattenedDefaultMacros);
	}
	return (_defaultMacros);
}

- (id)overridingMacros
{
	if (_flattenedOverridingMacros != nil) {
		return (_flattenedOverridingMacros);
	}
	return (_overridingMacros);
}

- (id)allowedBuildPhaseClasses
{
	return (_allowedBuildPhaseClasses);
}

- (BOOL)allowsBuildPhaseWithIdentifier:(id)identifier
{
	return ([_allowedBuildPhaseIdentifiers containsObject:identifier]);
}

- (id)allowedFileTypesForBuildPhaseIdentifier:(id)identifier
{
	return ([_allowedFileTypesByBuildPhaseIdentifier objectForKey:identifier]);
}

- (id)packageTypes
{
	return (_packageTypes);
}

- (id)defaultPackageType
{
	if ([_packageTypes count] == 0) {
		return (nil);
	}
	return ([_packageTypes objectAtIndex:0]);
}

- (BOOL)hasInfoPlist
{
	return ([self boolForKey:@"HasInfoPlist"]);
}

- (id)infoPlistAdditions
{
	return ([self dictionaryForKey:@"InfoPlistAdditions"]);
}

- (BOOL)canEmbedCompilerSanitizerLibraries
{
	return ([self boolForKey:@"CanEmbedCompilerSanitizerLibraries"]);
}

- (id)runpathSearchPathForEmbeddedFrameworks
{
	return ([self stringForKey:@"RunpathSearchPathForEmbeddedFrameworks"]);
}

- (BOOL)isEmbeddable
{
	return ([self boolForKey:@"IsEmbeddable"]);
}

- (id)buildPhaseInjectionsWhenEmbedding
{
	return ([self arrayForKey:@"BuildPhaseInjectionsWhenEmbedding"]);
}

- (id)requiredBuiltProductsDir
{
	return ([self stringForKey:@"RequiredBuiltProductsDir"]);
}

- (id)additionalEntitlementsForMacroExpansionScope:(id)scope
{
	(void)scope;
	return (_defaultEntitlements);
}

- (id)macroExpansionScopeByAddingMacroDefinitionTablesToScope:(id)scope
{
	NSString *label = [NSString stringWithFormat:@"// product type %@ macro expansion", [self identifier]];
	DVTMacroDefinitionTable *table = [[DVTMacroDefinitionTable alloc] initWithLabel:label];

	[table setMacroNamesAndValuesFromMacroDefinitionTable:[self overridingMacros]];
	[table makeImmutable];
	return ([[XCMacroExpansionScope alloc] initWithParentScope:scope
	    macroDefinitionTable:table
	    definitionLevel:1
	    definitionLevelsToClear:nil
	    conditionParameterValues:nil
	    conditionParameterFallbackValues:nil
	    expansionOptions:0]);
}

- (BOOL)wantsSimpleTargetEditing
{
	return ([self boolForKey:@"WantsSimpleTargetEditing"]);
}

- (BOOL)wantsInfoEditorHidden
{
	return ([self boolForKey:@"WantsInfoEditorHidden"]);
}

- (BOOL)areCapabilitiesSupported
{
	return (![self boolForKey:@"IsCapabilitiesUnsupported"]);
}

- (BOOL)validateEmbeddedBinaries
{
	return ([self boolForKey:@"ValidateEmbeddedBinaries"]);
}

- (BOOL)wantsBundleIdentifierEditing
{
	return ([self boolForKey:@"WantsBundleIdentifierEditing"]);
}

- (BOOL)wantsSigningEditing
{
	return ([self boolForKey:@"WantsSigningEditing"]);
}

- (BOOL)isUnitTest
{
	return ([self boolForKey:@"IsUnitTest"]);
}

- (BOOL)isUITest
{
	return ([self boolForKey:@"IsUITest"]);
}

- (BOOL)isMultiDeviceUITest
{
	if ([self boolForKey:@"IsMultiDeviceUITest"]) {
		return (YES);
	}
	return ([self boolForKey:@"XCTContainsUITests"]);
}

- (BOOL)isExternalTest
{
	return ([self boolForKey:@"IsExternalTest"]);
}

- (BOOL)supportsHostingTests
{
	return ([self boolForKey:@"SupportsHostingTests"]);
}

- (BOOL)supportsBeingUITestTarget
{
	return ([self boolForKey:@"SupportsBeingUITestTarget"]);
}

- (BOOL)allowEmbedding
{
	return ([self boolForKey:@"AllowEmbedding"]);
}

- (NSArray *)platforms
{
	return ([self arrayForKey:@"Platforms"]);
}

@end

@implementation XCStandaloneExecutableProductType
@end

@implementation PBXBundleProductType
@end

@implementation PBXApplicationProductType
@end

@implementation PBXFrameworkProductType
@end

@implementation XCStaticFrameworkProductType
@end

@implementation XCKernelExtensionProductType
@end

@implementation PBXXCTestBundleProductType

- (id)_XCTRunnerInfoPlistReplacements
{
	return (nil);
}

- (id)_XCTRunnerInfoPlistPreprocessorDefinitions
{
	return (nil);
}

- (id)_XCTRunnerBundleIdentifierWithMacroExpansionScope:(id)scope
{
	(void)scope;
	return (nil);
}

- (void)_addSettingsForXCTRunnerToMacroDefinitionTable:(id)table usingScope:(id)scope
{
	(void)table;
	(void)scope;
}

- (id)_adjustedTestHostFromOriginalTestHost:(id)host
       addingOverridesToMacroDefinitionTable:(id)table
			      macroExpansionScope:(id)scope
{
	(void)table;
	(void)scope;
	return (host);
}

- (id)_pluginDirectoryForTestHost:(id)host macroExpansionScope:(id)scope
{
	(void)host;
	(void)scope;
	return (nil);
}

- (void)_addSettingsForTestHost:(id)host toMacroDefinitionTable:(id)table usingScope:(id)scope
{
	(void)host;
	(void)table;
	(void)scope;
}

- (void)_addAdditionalTestingSearchPathsToMacroDefinitionTable:(id)table usingScope:(id)scope
{
	(void)table;
	(void)scope;
}

- (id)additionalEntitlementsForMacroExpansionScope:(id)scope
{
	return ([super additionalEntitlementsForMacroExpansionScope:scope]);
}

- (id)macroExpansionScopeByAddingMacroDefinitionTablesToScope:(id)scope
{
	return ([super macroExpansionScopeByAddingMacroDefinitionTablesToScope:scope]);
}

@end

@implementation PBXStaticLibraryProductType
@end

@implementation PBXDynamicLibraryProductType
@end

@implementation PBXToolProductType
@end
