/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Command-line driver for the ProjectModel object graph (DevToolsCore). */

#import <Foundation/Foundation.h>

#include <string.h>

#import "DevToolsCore/PBXProjectModel.h"
#import "DevToolsCore/PBXObject.h"
#import "DevToolsCore/XCBuildConfiguration.h"
#import "DevToolsCore/BuildSystem/DVTMacroDefinitionTable+XCMacroExpansionExtensions.h"
#import "DevToolsCore/PBXExtendedWrapperPart.h"
#import "DevToolsCore/PBXFileSystemSynchronizedGroupRelativeReferenceID.h"
#import "DevToolsCore/PBXPackageTypeSpecification.h"
#import "DevToolsCore/XCMacroExpansionScope.h"
#import "DevToolsCore/XCProductTypeSpecification.h"
#import "DevToolsCore/BuildSystem/XCPropertyDefinition.h"
#import "DevToolsCore/BuildSystem/XCPropertyDomainSpecification.h"
#import "DevToolsCore/ProjectModel/pbxproj.h"
#import "DevToolsSupport/TSPropertyListDictionary.h"
#import "PBXPListCoding.h"

static void
usage(void)
{
	fprintf(stderr,
	    "usage: pbxmodel roundtrip <project.pbxproj>\n"
	    "       pbxmodel cat <project.pbxproj>\n"
	    "       pbxmodel dump <project.pbxproj>\n"
	    "       pbxmodel propertydefs\n"
	    "       pbxmodel propertydomains\n"
	    "       pbxmodel xcmacroexpansion\n"
	    "       pbxmodel xcproducttypes\n"
	    "       pbxmodel runtimevalues\n"
	    "       pbxmodel buildconfigurations\n");
	exit(2);
}

/* Parse a project.pbxproj into the plain OPP value tree. */
static id
loadOPP(const char *path)
{
	char *err = NULL;
	OPPDocument *d = opp_parse_file(path, &err);
	id v;

	if (d == NULL) {
		fprintf(stderr, "pbxmodel: %s: %s\n", path,
		    (err != NULL) ? err : "parse error");
		free(err);
		return (nil);
	}
	v = PBXObjectFromOPPValue(d->root);
	opp_document_free(d);
	return (v);
}

/* Parse an in-memory archive string into the plain OPP value tree. */
static id
loadOPPString(NSString *s)
{
	char *err = NULL;
	const char *utf8 = [s UTF8String];
	OPPDocument *d = opp_parse_buffer(utf8, (utf8 != NULL) ? strlen(utf8) : 0,
	    &err);
	id v;

	if (d == NULL) {
		fprintf(stderr, "pbxmodel: %s\n", (err != NULL) ? err : "?");
		free(err);
		return (nil);
	}
	v = PBXObjectFromOPPValue(d->root);
	opp_document_free(d);
	return (v);
}

/*
 * roundtrip: load the object graph, re-archive it, and verify that the
 * result still describes the same project:
 *   - semantic  : re-parsing our output yields an equal value tree;
 *   - stability : archiving the same model twice gives identical bytes;
 *   - idempotence: archive(load(archive)) == archive (semantically).
 */
static int
cmdRoundtrip(NSString *path)
{
	NSError *error = nil;
	PBXProjectModel *model;
	NSString *s1, *s2;
	id v0, v1, v2;
	int status = 0;

	v0 = loadOPP([path UTF8String]);
	if (v0 == nil)
		return (1);

	model = [PBXProjectModel modelWithContentsOfFile:path error:&error];
	if (model == nil) {
		fprintf(stderr, "pbxmodel: %s: %s\n", [path UTF8String],
		    [[error description] UTF8String]);
		return (1);
	}

	s1 = [model archiveString];
	v1 = loadOPPString(s1);
	if (v1 == nil)
		return (1);
	if (![v0 isEqual:v1]) {
		fprintf(stderr, "pbxmodel: SEMANTIC MISMATCH %s\n",
		    [path UTF8String]);
		status = 1;
	}
	if (![s1 isEqualToString:[model archiveString]]) {
		fprintf(stderr, "pbxmodel: UNSTABLE ARCHIVE %s\n",
		    [path UTF8String]);
		status = 1;
	}

	{
		PBXProjectModel *m2 = [PBXProjectModel modelWithArchiveString:s1
		    error:&error];

		if (m2 == nil) {
			fprintf(stderr, "pbxmodel: %s: %s\n", [path UTF8String],
			    [[error description] UTF8String]);
			return (1);
		}
		s2 = [m2 archiveString];
		v2 = loadOPPString(s2);
		if (v2 == nil || ![v1 isEqual:v2]) {
			fprintf(stderr, "pbxmodel: NOT IDEMPOTENT %s\n",
			    [path UTF8String]);
			status = 1;
		}
	}

	if (status == 0)
		printf("OK %s\n", [path UTF8String]);
	return (status);
}

/* cat: load the object graph and print its canonical archive. */
static int
cmdCat(NSString *path)
{
	NSError *error = nil;
	PBXProjectModel *model;

	model = [PBXProjectModel modelWithContentsOfFile:path error:&error];
	if (model == nil) {
		fprintf(stderr, "pbxmodel: %s: %s\n", [path UTF8String],
		    [[error description] UTF8String]);
		return (1);
	}
	fputs([[model archiveString] UTF8String], stdout);
	return (0);
}

/* dump: summarize the materialized object graph. */
static int
cmdDump(NSString *path)
{
	NSError *error = nil;
	PBXProjectModel *model;
	NSDictionary *objects;
	NSMutableDictionary *counts;
	NSArray *isas;
	NSString *isa;

	model = [PBXProjectModel modelWithContentsOfFile:path error:&error];
	if (model == nil) {
		fprintf(stderr, "pbxmodel: %s: %s\n", [path UTF8String],
		    [[error description] UTF8String]);
		return (1);
	}
	objects = [model objects];
	counts = [NSMutableDictionary dictionary];
	for (id key in objects) {
		PBXObject *object = [objects objectForKey:key];
		NSString *name = [object classNameForPListArchive];
		NSNumber *n = [counts objectForKey:name];

		[counts setObject:@([n unsignedIntegerValue] + 1)
		    forKey:name];
	}
	printf("archiveVersion = %s\n",
	    [[model archiveVersion] UTF8String]);
	printf("objectVersion = %s\n",
	    [[model objectVersion] UTF8String]);
	printf("objects = %lu\n", (unsigned long)[objects count]);
	isas = [[counts allKeys] sortedArrayUsingSelector:@selector(compare:)];
	for (isa in isas)
		printf("  %-36s %lu\n", [isa UTF8String],
		    (unsigned long)[[counts objectForKey:isa] unsignedIntegerValue]);
	return (0);
}

/* propertydefs: deterministic snapshot of the reconstructed property-definition
 * layer.  The fixture is compared against an Apple DevToolsCore probe. */
static XCPropertyDefinition *
DefinitionFromDictionary(NSDictionary *dictionary)
{
	return ([XCPropertyDefinition propertyDefinitionFromPListDictionary:
	    [TSPropertyListDictionary propertyListDictionaryWithDictionary:
	    dictionary]]);
}

static void
PrintValue(const char *label, id value)
{
	printf("%s = <%s>\n", label,
	    (value != nil) ? [[value description] UTF8String] : "nil");
}

static void
PrintDefinition(const char *label, XCPropertyDefinition *definition)
{
	printf("%s:\n", label);
	PrintValue("  class", NSStringFromClass([definition class]));
	PrintValue("  name", [definition name]);
	PrintValue("  type", [definition typeString]);
	PrintValue("  isList", @([definition isListType]));
	PrintValue("  default", [definition defaultValue]);
	PrintValue("  allowed", [definition allowedValues]);
	PrintValue("  localized", [definition localizedAllowedValues]);
	PrintValue("  category", [definition category]);
	PrintValue("  basic", @([definition isBasic]));
	PrintValue("  internal", @([definition isAppleInternalOnly]));
	PrintValue("  canCL", @([definition canGenerateCommandLineArguments]));
	PrintValue("  commandInfo", [definition commandArgumentGenerationInfo]);
	PrintValue("  description", [definition description]);
}

static int
cmdPropertyDefs(void)
{
	PrintDefinition("role", DefinitionFromDictionary(@{
	    @"Name": @"Role", @"Type": @"String",
	    @"AllowedValues": @[@"Required", @"Weak"],
	    @"DisplayValues": @[@"Required", @"Optional"],
	    @"DefaultValue": @"Required"}));
	PrintDefinition("list", DefinitionFromDictionary(@{
	    @"Name": @"FLAGS", @"Type": @"StringList",
	    @"DefaultValue": @"a b $(x)"}));
	PrintDefinition("boolean", DefinitionFromDictionary(@{
	    @"Name": @"ENABLED", @"Type": @"Boolean",
	    @"DefaultValue": @"YES"}));
	PrintDefinition("enumeration", DefinitionFromDictionary(@{
	    @"Name": @"MODE", @"Type": @"Enumeration",
	    @"Values": @[@"fast", @"slow"],
	    @"DisplayValues": @[@"Fast", @"Slow"],
	    @"DefaultValue": @"fast"}));
	return (0);
}

static TSPropertyListDictionary *
PropertyDictionary(NSDictionary *dictionary)
{
	return ([TSPropertyListDictionary propertyListDictionaryWithDictionary:
	    dictionary]);
}

static NSDictionary *
DomainProperty(NSString *name, NSString *type, NSString *value,
    NSString *category)
{
	NSMutableDictionary *dictionary = [NSMutableDictionary
	    dictionaryWithDictionary:@{
	        @"Name": name, @"Type": type, @"DefaultValue": value}];

	if (category != nil)
		[dictionary setObject:category forKey:@"Category"];
	return (dictionary);
}

static XCPropertyDomainSpecification *
MakeDomainSpecification(NSString *identifier, NSString *basedOn,
    NSArray *properties, NSArray *deleted, NSArray *categories)
{
	NSMutableDictionary *dictionary = [NSMutableDictionary
	    dictionaryWithDictionary:@{
	        @"Type": @"PropertyDomain", @"Identifier": identifier,
	        @"Properties": properties}];

	if (basedOn != nil)
		[dictionary setObject:basedOn forKey:@"BasedOn"];
	if (deleted != nil)
		[dictionary setObject:deleted forKey:@"DeletedProperties"];
	if (categories != nil)
		[dictionary setObject:categories forKey:@"OptionCategories"];
	return ([[XCPropertyDomainSpecification alloc]
	    initWithPropertyListDictionary:PropertyDictionary(dictionary)
	    inDomain:@"probe.domain"]);
}

static NSString *
JoinedDescriptions(NSArray *values)
{
	NSMutableArray *strings = [NSMutableArray array];

	for (id value in values)
		[strings addObject:[value description]];
	return ([strings componentsJoinedByString:@", "]);
}

static NSArray *
DefinitionNames(NSArray *definitions)
{
	NSMutableArray *names = [NSMutableArray array];

	for (XCPropertyDefinition *definition in definitions)
		[names addObject:[definition name]];
	return (names);
}

static NSArray *
SortedDictionaryKeys(NSDictionary *dictionary)
{
	return ([[dictionary allKeys] sortedArrayUsingSelector:@selector(compare:)]);
}

static void
PrintNSStringValue(NSString *label, id value)
{
	PrintValue([label UTF8String], value);
}

static void
PrintSettingsDictionary(NSString *label, NSDictionary *settings)
{
	printf("%s = <{\n", [label UTF8String]);
	for (NSString *key in SortedDictionaryKeys(settings)) {
		NSString *value = [[settings objectForKey:key] description] ?: @"nil";

		printf("    \"%s\" = %s;\n", [key UTF8String], [value UTF8String]);
	}
	printf("}>\n");
}

static NSArray *
ConfigurationNames(NSArray *configurations)
{
	NSMutableArray *names = [NSMutableArray array];
	XCBuildConfiguration *configuration;

	for (configuration in configurations) {
		if ([configuration name] != nil)
			[names addObject:[configuration name]];
	}
	return (names);
}

static void
PrintConfigurationState(NSString *label, XCBuildConfiguration *configuration)
{
	PrintNSStringValue([label stringByAppendingString:@".name"],
	    [configuration name]);
	PrintSettingsDictionary([label stringByAppendingString:@".settings"],
	    [configuration buildSettings]);
	PrintNSStringValue([label stringByAppendingString:@".hidden"],
	    @([configuration isHidden]));
	PrintNSStringValue([label stringByAppendingString:@".could"],
	    @([configuration couldBeActive]));
	PrintNSStringValue([label stringByAppendingString:@".display"],
	    [configuration inspectorDisplayName]);
	PrintNSStringValue([label stringByAppendingString:@".label"],
	    [configuration _buildSettingsLabel]);
	PrintNSStringValue([label stringByAppendingString:@".base"],
	    [configuration baseBuildConfiguration]);
	PrintNSStringValue([label stringByAppendingString:@".resolved"],
	    [configuration resolvedBaseConfigurationReference]);
	PrintNSStringValue([label stringByAppendingString:@".arch"],
	    [configuration baseConfigurationReference_forArchiving]);
}

static void
PrintListState(NSString *label, XCConfigurationList *list)
{
	PrintNSStringValue([label stringByAppendingString:@".configs"],
	    ConfigurationNames([list buildConfigurations]));
	PrintNSStringValue([label stringByAppendingString:@".names"],
	    [list buildConfigurationNames]);
	PrintNSStringValue([label stringByAppendingString:@".count"],
	    @([list countOfBuildConfigurations]));
	PrintNSStringValue([label stringByAppendingString:@".defaultName"],
	    [list defaultConfigurationName]);
	PrintNSStringValue([label stringByAppendingString:@".defaultVisible"],
	    @([list defaultConfigurationIsVisible]));
	PrintNSStringValue([label stringByAppendingString:@".default"],
	    [[list defaultConfiguration] name]);
	PrintNSStringValue([label stringByAppendingString:@".baseList"],
	    [list baseConfigurationList]);
	PrintNSStringValue([label stringByAppendingString:@".owner"],
	    [list owner]);
	PrintNSStringValue([label stringByAppendingString:@".debugLabel"],
	    [list configurationTableDebugLabel]);
}

static void
PrintDomainSpecification(NSString *label, XCPropertyDomainSpecification *spec)
{
	PrintNSStringValue([label stringByAppendingString:@".identifier"],
	    [spec identifier]);
	PrintNSStringValue([label stringByAppendingString:@".domain"], [spec domain]);
	PrintNSStringValue([label stringByAppendingString:@".direct"],
	    SortedDictionaryKeys([spec directlyDeclaredBuildOptions]));
	PrintNSStringValue([label stringByAppendingString:@".build"],
	    SortedDictionaryKeys([spec buildOptions]));
	PrintNSStringValue([label stringByAppendingString:@".ordered"],
	    DefinitionNames([spec orderedBuildOptions]));
	PrintNSStringValue([label stringByAppendingString:@".orderedSelf"],
	    DefinitionNames([spec orderedSelfDefinedBuildOptions]));
	PrintNSStringValue([label stringByAppendingString:@".categories"],
	    [spec buildOptionCategories]);
	PrintNSStringValue([label stringByAppendingString:@".flatCategories"],
	    [spec flattenedOptionCategories]);
	PrintNSStringValue([label stringByAppendingString:@".namesCL"],
	    [spec namesOfBuildOptionsForCommandLine]);
	PrintNSStringValue([label stringByAppendingString:@".flatNamesCL"],
	    [spec namesOfFlattenedOptionsForCommandLine]);
	PrintNSStringValue([label stringByAppendingString:@".defaults"],
	    [spec defaultMacrosForAllOptions]);
	PrintNSStringValue([label stringByAppendingString:@".ui"],
	    [[spec specificationToShowInUserInterface] identifier]);
}

static int
cmdPropertyDomains(void)
{
	NSArray *baseProperties = @[
	    DomainProperty(@"FOO", @"String", @"bar", @"Test"),
	    DomainProperty(@"BAR", @"Boolean", @"YES", @"Build"),
	    DomainProperty(@"BAZ", @"StringList", @"a b", @"Test")
	];
	NSArray *derivedProperties = @[
	    DomainProperty(@"EXTRA", @"String", @"x", @"Test"),
	    DomainProperty(@"FOO", @"String", @"override", nil)
	];
	XCPropertyDomainSpecification *base = MakeDomainSpecification(@"base", nil,
	    baseProperties, nil,
	    @[@{@"Name": @"Test", @"Options": @[@"FOO", @"BAZ"]},
	      @{@"Name": @"Build", @"Options": @[@"BAR"]}]);
	XCPropertyDomainSpecification *derived;

	[XCPropertyDomainSpecification registerSpecificationOrProxy:base];
	derived = MakeDomainSpecification(@"derived", @"base", derivedProperties,
	    @[@"BAR"], nil);
	[XCPropertyDomainSpecification registerSpecificationOrProxy:derived];

	PrintNSStringValue(@"meta.type",
	    [XCPropertyDomainSpecification specificationType]);
	PrintNSStringValue(@"meta.localizedType",
	    [XCPropertyDomainSpecification localizedSpecificationTypeName]);
	PrintNSStringValue(@"meta.extensions", JoinedDescriptions(
	    [[XCPropertyDomainSpecification specificationTypePathExtensions]
	    allObjects]));
	PrintNSStringValue(@"meta.registry",
	    [XCPropertyDomainSpecification specificationRegistryName]);
	PrintDomainSpecification(@"base", base);
	PrintDomainSpecification(@"derived", derived);
	PrintNSStringValue(@"registry.domains",
	    [[[XCPropertyDomainSpecification allRegisteredSpecificationDomains]
	    allObjects] sortedArrayUsingSelector:@selector(compare:)]);
	PrintNSStringValue(@"registry.identifiers", SortedDictionaryKeys(
	    [XCPropertyDomainSpecification
	    dictionaryOfallRegisteredPropertyDomainsInSpecificationDomain:
	    @"probe.domain"]));
	PrintNSStringValue(@"registry.count", @([[XCPropertyDomainSpecification
	    allRegisteredPropertyDomainsInSpecificationDomain:@"probe.domain"] count]));
	PrintNSStringValue(@"registry.domainBase", [[XCPropertyDomainSpecification
	    propertyDomainForIdentifier:@"base" inSpecificationDomain:@"probe.domain"]
	    identifier]);
	PrintNSStringValue(@"registry.propertiesFOO", DefinitionNames(
	    [XCPropertyDomainSpecification allRegisteredPropertiesForName:@"FOO"]));
	PrintNSStringValue(@"property.FOO",
	    [XCPropertyDomainSpecification allRegisteredPropertiesForName:@"FOO"]);
	return (0);
}

static id
ArchiveDescription(DVTMacroDefinitionTable *table)
{
	NSDictionary *archive = [table xc_dictionaryRepresentationForProjectArchiving];
	NSArray *keys = [[archive allKeys] sortedArrayUsingSelector:@selector(compare:)];
	NSMutableArray *entries = [NSMutableArray arrayWithCapacity:[keys count]];

	for (NSString *key in keys)
		[entries addObject:[NSString stringWithFormat:@"%@=%@", key,
		    [archive objectForKey:key]]];
	return ([entries componentsJoinedByString:@"|"]);
}

static DVTMacroDefinitionTable *
TableWithValue(id name, id value)
{
	DVTMacroDefinitionTable *table = [DVTMacroDefinitionTable newWithLabel:@"probe"];

	[table xc_setValue:value forMacroName:name errorHandler:^(id error) {
		(void)error;
	}];
	return (table);
}

static id
ScopeConditionsDescription(DVTMacroExpansionScope *scope)
{
	NSDictionary *values = [scope allConditionParameterValues];
	NSArray *keys = [[values allKeys] sortedArrayUsingSelector:@selector(compare:)];
	NSMutableArray *entries = [NSMutableArray arrayWithCapacity:[keys count]];

	for (NSString *key in keys)
		[entries addObject:[NSString stringWithFormat:@"%@=%@", key,
		    [values objectForKey:key]]];
	return ([entries componentsJoinedByString:@"|"]);
}

static int
cmdXCMacroExpansion(void)
{
	DVTMacroDefinitionTable *split = [DVTMacroDefinitionTable newWithLabel:@"probe"];
	DVTMacroDefinitionTable *conditions = [DVTMacroDefinitionTable newWithLabel:@"probe"];
	NSArray *defaults = @[
	    [XCPropertyDefinition stringPropertyDefinitionWithName:@"ROLE"
		defaultValue:@"defaultRole"],
	    [XCPropertyDefinition stringPropertyDefinitionWithName:@"FLAGS"
		defaultValue:@"one two"]
	];
	NSDictionary *archiving = @{
	    @"SDKROOT": @"/Applications/Xcode.app/usr",
	    @"ARCHS": @[@"arm64", @"x86_64"],
	    @"FLAGS": @"base",
	    @"FLAGS[sdk=macosx]": @"conditioned"
	};
	DVTMacroDefinitionTable *unarchived;
	DVTMacroDefinitionTable *scopeTable = [DVTMacroDefinitionTable newWithLabel:@"T"];
	XCMacroExpansionScope *scopeZero;
	XCMacroExpansionScope *scopeFull;
	XCMacroExpansionScope *scopeValues;
	NSDictionary *scopeValuesDict = @{@"sdk": @"macosx", @"ARCHS": @"arm64"};

	[scopeTable xc_setValue:@"bar" forMacroName:@"FOO"
	    usingPropertyDefinitionsFromSpecificationDomain:nil
	    errorHandler:^(id error) {
		(void)error;
	}];

	PrintNSStringValue(@"split.OTHER_LDFLAGS",
	    @([split _xc_shouldSplitValueOfListSettingNamed:@"OTHER_LDFLAGS"
		whenArchivingToFormat:nil]));
	PrintNSStringValue(@"split.FLAGS",
	    @([split _xc_shouldSplitValueOfListSettingNamed:@"FLAGS"
		whenArchivingToFormat:nil]));
	PrintNSStringValue(@"archive.simple", ArchiveDescription(
	    TableWithValue(@"OTHER_LDFLAGS", @"a b  c")));
	PrintNSStringValue(@"archive.escaped", ArchiveDescription(
	    TableWithValue(@"OTHER_LDFLAGS", @"a\\ b")));
	PrintNSStringValue(@"archive.array", ArchiveDescription(
	    TableWithValue(@"HEADER_SEARCH_PATHS",
		@[@"a", @"b c", @"\"d e\"", @"$(FOO)"])));
	PrintNSStringValue(@"archive.sdkroot", ArchiveDescription(
	    TableWithValue(@"SDKROOT", @"path/to sdk")));
	PrintNSStringValue(@"archive.archs", ArchiveDescription(
	    TableWithValue(@"ARCHS", @"arm64 x86_64")));
	PrintNSStringValue(@"archive.archsArray", ArchiveDescription(
	    TableWithValue(@"ARCHS", @[@"arm64", @"x86_64"])));
	PrintNSStringValue(@"archive.archsEmpty", ArchiveDescription(
	    TableWithValue(@"ARCHS", @"")));
	PrintNSStringValue(@"archive.unknown", ArchiveDescription(
	    TableWithValue(@"CUSTOM_SETTING", @"a b")));

	[conditions xc_setMacroNamesAndValuesFromDictionary:archiving
	    usingPropertyDefinitionsFromSpecificationDomain:nil
	    errorHandler:^(id error) {
		(void)error;
	}];
	PrintNSStringValue(@"archive.conditions", ArchiveDescription(conditions));

	[split xc_addPropertyDefinitionDefaultValues:defaults];
	PrintNSStringValue(@"defaults", ArchiveDescription(split));

	unarchived = [DVTMacroDefinitionTable
	    xc_macroDefinitionTableFromDictionaryRepresentationForProjectArchiving:archiving
	    usingPropertyDefinitionsFromSpecificationDomain:nil];
	PrintNSStringValue(@"unarchive", ArchiveDescription(unarchived));

	PrintNSStringValue(@"scope.levels",
	    @([XCMacroExpansionScope numberOfDefinitionLevels]));
	PrintNSStringValue(@"scope.level.0",
	    [XCMacroExpansionScope stringForDefinitionLevel:0]);
	PrintNSStringValue(@"scope.level.5",
	    [XCMacroExpansionScope stringForDefinitionLevel:5]);
	PrintNSStringValue(@"scope.level.13",
	    [XCMacroExpansionScope stringForDefinitionLevel:13]);
	PrintNSStringValue(@"scope.level.unknown",
	    [XCMacroExpansionScope stringForDefinitionLevel:14]);

	scopeZero = [XCMacroExpansionScope newWithParentScope:nil
	    macroDefinitionTable:scopeTable definitionLevel:0];
	PrintNSStringValue(@"scope.zero.class", NSStringFromClass([scopeZero class]));
	PrintNSStringValue(@"scope.zero.level", @([scopeZero definitionLevel]));
	PrintNSStringValue(@"scope.zero.options", @([scopeZero options]));
	PrintNSStringValue(@"scope.zero.conditions",
	    ScopeConditionsDescription(scopeZero));
	PrintNSStringValue(@"scope.zero.FOO",
	    [scopeZero evaluatedStringValueForMacroNamed:@"FOO"]);

	scopeFull = [[XCMacroExpansionScope alloc] initWithParentScope:scopeZero
	    macroDefinitionTable:scopeTable definitionLevel:1
	    definitionLevelsToClear:nil conditionParameterValues:nil
	    conditionParameterFallbackValues:nil expansionOptions:1];
	PrintNSStringValue(@"scope.full.level", @([scopeFull definitionLevel]));
	PrintNSStringValue(@"scope.full.options", @([scopeFull options]));
	PrintNSStringValue(@"scope.full.FOO",
	    [scopeFull evaluatedStringValueForMacroNamed:@"FOO"]);

	scopeValues = [[XCMacroExpansionScope alloc] initWithParentScope:scopeZero
	    macroDefinitionTable:scopeTable definitionLevel:2
	    definitionLevelsToClear:nil conditionParameterValues:scopeValuesDict
	    conditionParameterFallbackValues:@{@"sdk": @"iphoneos"}
	    expansionOptions:0];
	PrintNSStringValue(@"scope.values.conditions",
	    ScopeConditionsDescription(scopeValues));
	PrintNSStringValue(@"scope.values.sdk",
	    [scopeValues valueForConditionParameter:@"sdk"]);
	PrintNSStringValue(@"scope.values.archs",
	    [scopeValues valueForConditionParameter:@"ARCHS"]);
	return (0);
}

static NSString *
ProductDescription(id value)
{
	if ([value isKindOfClass:[NSDictionary class]]) {
		NSMutableArray *parts = [NSMutableArray array];

		for (id key in SortedDictionaryKeys(value)) {
			[parts addObject:[NSString stringWithFormat:@"%@=%@",
			    key, ProductDescription([(NSDictionary *)value objectForKey:key])]];
		}
		return ([NSString stringWithFormat:@"{%@}",
		    [parts componentsJoinedByString:@","]]);
	}
	if ([value isKindOfClass:[NSArray class]]) {
		NSMutableArray *parts = [NSMutableArray array];

		for (id item in (NSArray *)value) {
			[parts addObject:ProductDescription(item)];
		}
		return ([NSString stringWithFormat:@"(%@)",
		    [parts componentsJoinedByString:@","]]);
	}
	if ([value isKindOfClass:[NSSet class]]) {
		NSMutableArray *items = [NSMutableArray array];

		for (id item in (NSSet *)value) {
			[items addObject:[item description]];
		}
		return (ProductDescription([items sortedArrayUsingSelector:@selector(compare:)]));
	}
	return ([value description]);
}

static NSString *
ProductMacroDescription(id table)
{
	id representation = nil;

	if ([table respondsToSelector:@selector(xc_dictionaryRepresentationForProjectArchiving)]) {
		representation = [table xc_dictionaryRepresentationForProjectArchiving];
	}
	return (ProductDescription(representation));
}

static void
RegisterProductPackageType(NSString *identifier)
{
	NSDictionary *dictionary = @{
		@"Type": @"PackageType",
		@"Identifier": identifier,
		@"Name": identifier,
		@"Description": identifier,
		@"Class": @"PBXPackageTypeSpecification",
		@"DefaultBuildSettings": @{@"FOO": @"bar"},
		@"ProductReference": @{
			@"FileType": @"wrapper.application",
			@"Name": @"$(PRODUCT_NAME)",
			@"IsLaunchable": @"YES"
		}
	};
	id plist = [TSPropertyListDictionary propertyListDictionaryWithDictionary:dictionary];
	PBXPackageTypeSpecification *specification =
	    [[PBXPackageTypeSpecification alloc] initWithPropertyListDictionary:plist inDomain:@""];

	[PBXPackageTypeSpecification registerSpecificationOrProxy:specification];
}

static XCProductTypeSpecification *
MakeProductSpecification(NSString *className)
{
	NSDictionary *dictionary = @{
		@"Type": @"ProductType",
		@"Identifier": @"probe.id",
		@"Name": @"Probe Name",
		@"Description": @"Probe Description",
		@"Class": className,
		@"DefaultTargetName": @"Probe Target",
		@"DefaultBuildProperties": @{@"FOO": @"bar", @"BAZ": @"$(FOO)/x"},
		@"OverridingBuildSettings": @{@"OVR": @"qux"},
		@"PackageTypes": @[@"com.apple.package-type.bundle", @"com.apple.package-type.mach-o-executable"],
		@"AllowedBuildPhases": @[@"com.apple.buildphase.sources", @"com.apple.buildphase.frameworks"],
		@"DefaultEntitlements": @{@"com.apple.developer.test": @"YES"},
		@"InfoPlistAdditions": @{@"CFBundleIdentifier": @"$(PRODUCT_BUNDLE_IDENTIFIER)"},
		@"CanEmbedCompilerSanitizerLibraries": @"YES",
		@"RunpathSearchPathForEmbeddedFrameworks": @"@executable_path/../Frameworks/$(FOO)",
		@"IsEmbeddable": @"YES",
		@"BuildPhaseInjectionsWhenEmbedding": @[@{@"BuildPhase": @"CopyFiles"}],
		@"RequiredBuiltProductsDir": @"WATCH_BUILT_PRODUCTS_DIR",
		@"Platforms": @[@"macosx", @"iphoneos"],
		@"WantsSimpleTargetEditing": @"YES",
		@"WantsInfoEditorHidden": @"YES",
		@"IsCapabilitiesUnsupported": @"YES",
		@"ValidateEmbeddedBinaries": @"YES",
		@"WantsBundleIdentifierEditing": @"YES",
		@"WantsSigningEditing": @"YES",
		@"IsUnitTest": @"YES",
		@"IsUITest": @"YES",
		@"XCTContainsUITests": @"YES",
		@"IsExternalTest": @"YES",
		@"SupportsHostingTests": @"YES",
		@"SupportsBeingUITestTarget": @"YES",
		@"AllowEmbedding": @"YES",
		@"HasInfoPlist": @"YES"
	};
	id plist = [TSPropertyListDictionary propertyListDictionaryWithDictionary:dictionary];
	Class cls = NSClassFromString(className);

	return ([[cls alloc] initWithPropertyListDictionary:plist inDomain:@"probe"]);
}

static void
PrintProductClassMethods(NSString *label, Class cls)
{
	PrintNSStringValue([label stringByAppendingString:@".base"],
	    NSStringFromClass([cls specificationTypeBaseClass]));
	PrintNSStringValue([label stringByAppendingString:@".type"],
	    [cls specificationType]);
	PrintNSStringValue([label stringByAppendingString:@".registry"],
	    [cls specificationRegistryName]);
	PrintNSStringValue([label stringByAppendingString:@".extensions"],
	    ProductDescription([cls specificationTypePathExtensions]));
	PrintNSStringValue([label stringByAppendingString:@".localized"],
	    [cls localizedSpecificationTypeName]);
}

static NSArray *
ProductPackageIdentifiers(NSArray *packageTypes)
{
	NSMutableArray *identifiers = [NSMutableArray arrayWithCapacity:[packageTypes count]];

	for (PBXPackageTypeSpecification *specification in packageTypes) {
		[identifiers addObject:[specification identifier]];
	}
	return (identifiers);
}

static int
cmdXCProductTypes(void)
{
	NSArray *classNames = @[
		@"XCProductTypeSpecification",
		@"PBXApplicationProductType",
		@"PBXBundleProductType",
		@"PBXFrameworkProductType",
		@"PBXStaticLibraryProductType",
		@"PBXDynamicLibraryProductType",
		@"PBXToolProductType",
		@"PBXXCTestBundleProductType",
		@"XCKernelExtensionProductType",
		@"XCStandaloneExecutableProductType",
		@"XCStaticFrameworkProductType"
	];

	RegisterProductPackageType(@"com.apple.package-type.bundle");
	RegisterProductPackageType(@"com.apple.package-type.mach-o-executable");
	PrintProductClassMethods(@"package.class.PBXPackageTypeSpecification",
	    [PBXPackageTypeSpecification class]);
	for (NSString *name in classNames) {
		PrintProductClassMethods([@"product.class." stringByAppendingString:name],
		    NSClassFromString(name));
	}

	PBXPackageTypeSpecification *package = [PBXPackageTypeSpecification
	    specificationForIdentifier:@"com.apple.package-type.bundle"];
	PrintNSStringValue(@"package.identifier", [package identifier]);
	PrintNSStringValue(@"package.macros", ProductMacroDescription([package defaultMacros]));
	PrintNSStringValue(@"package.reference.name", [package productReferenceName]);
	PrintNSStringValue(@"package.reference.launchable", @([package productReferenceIsLaunchable]));

	DVTMacroDefinitionTable *scopeTable = [DVTMacroDefinitionTable empty];
	XCMacroExpansionScope *scope = [XCMacroExpansionScope newWithParentScope:nil
	    macroDefinitionTable:scopeTable definitionLevel:0];

	for (NSString *name in classNames) {
		NSString *label = [@"product." stringByAppendingString:name];
		XCProductTypeSpecification *specification = MakeProductSpecification(name);
		id expanded;

		PrintNSStringValue([label stringByAppendingString:@".class"],
		    NSStringFromClass([specification class]));
		PrintNSStringValue([label stringByAppendingString:@".identifier"],
		    [specification identifier]);
		PrintNSStringValue([label stringByAppendingString:@".targetName"],
		    [specification defaultTargetName]);
		PrintNSStringValue([label stringByAppendingString:@".defaultMacros"],
		    ProductMacroDescription([specification defaultMacros]));
		PrintNSStringValue([label stringByAppendingString:@".overridingMacros"],
		    ProductMacroDescription([specification overridingMacros]));
		PrintNSStringValue([label stringByAppendingString:@".allowedClasses"],
		    ProductDescription([specification allowedBuildPhaseClasses]));
		PrintNSStringValue([label stringByAppendingString:@".allowsSources"],
		    @([specification allowsBuildPhaseWithIdentifier:@"com.apple.buildphase.sources"]));
		PrintNSStringValue([label stringByAppendingString:@".allowsUnknown"],
		    @([specification allowsBuildPhaseWithIdentifier:@"com.apple.buildphase.unknown"]));
		PrintNSStringValue([label stringByAppendingString:@".allowedFileTypes"],
		    ProductDescription([specification allowedFileTypesForBuildPhaseIdentifier:
			@"com.apple.buildphase.sources"]));
		PrintNSStringValue([label stringByAppendingString:@".packageTypes"],
		    ProductDescription(ProductPackageIdentifiers([specification packageTypes])));
		PrintNSStringValue([label stringByAppendingString:@".defaultPackage"],
		    [[specification defaultPackageType] identifier]);
		PrintNSStringValue([label stringByAppendingString:@".hasInfoPlist"],
		    @([specification hasInfoPlist]));
		PrintNSStringValue([label stringByAppendingString:@".infoPlistAdditions"],
		    ProductDescription([specification infoPlistAdditions]));
		PrintNSStringValue([label stringByAppendingString:@".canEmbedSanitizers"],
		    @([specification canEmbedCompilerSanitizerLibraries]));
		PrintNSStringValue([label stringByAppendingString:@".runpath"],
		    [specification runpathSearchPathForEmbeddedFrameworks]);
		PrintNSStringValue([label stringByAppendingString:@".isEmbeddable"],
		    @([specification isEmbeddable]));
		PrintNSStringValue([label stringByAppendingString:@".injections"],
		    ProductDescription([specification buildPhaseInjectionsWhenEmbedding]));
		PrintNSStringValue([label stringByAppendingString:@".requiredDir"],
		    [specification requiredBuiltProductsDir]);
		PrintNSStringValue([label stringByAppendingString:@".entitlements"],
		    ProductDescription([specification additionalEntitlementsForMacroExpansionScope:scope]));
		expanded = [specification macroExpansionScopeByAddingMacroDefinitionTablesToScope:scope];
		PrintNSStringValue([label stringByAppendingString:@".expanded.class"],
		    NSStringFromClass([expanded class]));
		PrintNSStringValue([label stringByAppendingString:@".expanded.PRODUCT_TYPE"],
		    [expanded evaluatedStringValueForMacroNamed:@"PRODUCT_TYPE"]);
		PrintNSStringValue([label stringByAppendingString:@".expanded.OVR"],
		    [expanded evaluatedStringValueForMacroNamed:@"OVR"]);
		PrintNSStringValue([label stringByAppendingString:@".simple"],
		    @([specification wantsSimpleTargetEditing]));
		PrintNSStringValue([label stringByAppendingString:@".infoHidden"],
		    @([specification wantsInfoEditorHidden]));
		PrintNSStringValue([label stringByAppendingString:@".caps"],
		    @([specification areCapabilitiesSupported]));
		PrintNSStringValue([label stringByAppendingString:@".validate"],
		    @([specification validateEmbeddedBinaries]));
		PrintNSStringValue([label stringByAppendingString:@".bundleId"],
		    @([specification wantsBundleIdentifierEditing]));
		PrintNSStringValue([label stringByAppendingString:@".signing"],
		    @([specification wantsSigningEditing]));
		PrintNSStringValue([label stringByAppendingString:@".unit"],
		    @([specification isUnitTest]));
		PrintNSStringValue([label stringByAppendingString:@".ui"],
		    @([specification isUITest]));
		PrintNSStringValue([label stringByAppendingString:@".multi"],
		    @([specification isMultiDeviceUITest]));
		PrintNSStringValue([label stringByAppendingString:@".external"],
		    @([specification isExternalTest]));
		PrintNSStringValue([label stringByAppendingString:@".hosting"],
		    @([specification supportsHostingTests]));
		PrintNSStringValue([label stringByAppendingString:@".beingUI"],
		    @([specification supportsBeingUITestTarget]));
		PrintNSStringValue([label stringByAppendingString:@".embedding"],
		    @([specification allowEmbedding]));
		PrintNSStringValue([label stringByAppendingString:@".platforms"],
		    ProductDescription([specification platforms]));
		if ([specification isKindOfClass:[PBXXCTestBundleProductType class]]) {
			PBXXCTestBundleProductType *test = (PBXXCTestBundleProductType *)specification;

			PrintNSStringValue([label stringByAppendingString:@".xct.plistReplacements"],
			    ProductDescription([test _XCTRunnerInfoPlistReplacements]));
			PrintNSStringValue([label stringByAppendingString:@".xct.definitions"],
			    ProductDescription([test _XCTRunnerInfoPlistPreprocessorDefinitions]));
			PrintNSStringValue([label stringByAppendingString:@".xct.bundleId"],
			    [test _XCTRunnerBundleIdentifierWithMacroExpansionScope:scope]);
			PrintNSStringValue([label stringByAppendingString:@".xct.testHost"],
			    [test _adjustedTestHostFromOriginalTestHost:@"host"
			    addingOverridesToMacroDefinitionTable:nil macroExpansionScope:scope]);
			PrintNSStringValue([label stringByAppendingString:@".xct.pluginDirectory"],
			    [test _pluginDirectoryForTestHost:@"host" macroExpansionScope:scope]);
		}
	}
	return (0);
}

@interface PBXRuntimeValueBasePath : NSObject
- (id)filePathForRelativePathString:(id)relativePath;
@end

@implementation PBXRuntimeValueBasePath
- (id)filePathForRelativePathString:(id)relativePath
{
	return ([@"BASE/" stringByAppendingString:relativePath]);
}
@end

static NSArray *
SortedDescriptions(id collection)
{
	NSMutableArray *strings = [NSMutableArray array];

	for (id value in collection)
		[strings addObject:[value description]];
	return ([strings sortedArrayUsingSelector:@selector(compare:)]);
}

static NSString *
DictionaryDescription(NSDictionary *dictionary)
{
	NSMutableDictionary *described = [NSMutableDictionary dictionaryWithCapacity:
	    [dictionary count]];

	for (id key in dictionary)
		[described setObject:[dictionary objectForKey:key]
		    forKey:[key description]];
	NSArray *keys = [[described allKeys]
	    sortedArrayUsingSelector:@selector(compare:)];
	NSMutableArray *parts = [NSMutableArray arrayWithCapacity:[keys count]];

	for (id key in keys)
		[parts addObject:[NSString stringWithFormat:@"%@=%@", key,
		    [[described objectForKey:key] description]]];
	return ([parts componentsJoinedByString:@"; "]);
}

static void
PrintReferenceState(NSString *label,
    PBXFileSystemSynchronizedGroupRelativeReferenceID *identifier)
{
	PrintNSStringValue([label stringByAppendingString:@".description"],
	    [identifier description]);
	PrintNSStringValue([label stringByAppendingString:@".plist"],
	    [identifier propertyListRepresentation]);
	PrintNSStringValue([label stringByAppendingString:@".variant"],
	    @([identifier isVariantGroup]));
	PrintNSStringValue([label stringByAppendingString:@".nested"],
	    @([identifier isNestedVariantGroup]));
	PrintNSStringValue([label stringByAppendingString:@".hash"],
	    @([identifier hash]));
}

static int
cmdRuntimeValues(void)
{
	PBXExtendedWrapperPart *part = [[PBXExtendedWrapperPart alloc]
	    initWithBasedOnWrapperPart:42 subPath:@"a/b"];
	Class refClass = [PBXFileSystemSynchronizedGroupRelativeReferenceID class];
	PBXFileSystemSynchronizedGroupRelativeReferenceID *a = [[refClass alloc]
	    initWithRelativePath:@"foo/bar.m" isVariantGroup:NO];
	PBXFileSystemSynchronizedGroupRelativeReferenceID *b = [[refClass alloc]
	    initWithRelativePath:@"foo/bar.m" isVariantGroup:NO];
	PBXFileSystemSynchronizedGroupRelativeReferenceID *c = [[refClass alloc]
	    initWithRelativePath:@"foo/baz.m" isVariantGroup:NO];
	PBXFileSystemSynchronizedGroupRelativeReferenceID *v = [[refClass alloc]
	    initWithRelativePath:@"foo/bar.m" isVariantGroup:YES];
	id copy = [a copy];
	PBXFileSystemSynchronizedGroupReferenceIDValueTransformer transformer =
	    ^id(id value) { return value; };

	PrintNSStringValue(@"part.based", @([part basedOnWrapperPart]));
	PrintNSStringValue(@"part.subPath", [part subPath]);
	PrintReferenceState(@"ref.a", a);
	PrintReferenceState(@"ref.v", v);
	PrintNSStringValue(@"ref.a.path", [a filePathForBasePath:
	    [[PBXRuntimeValueBasePath alloc] init]]);
	PrintNSStringValue(@"ref.a.eq.b", @([a isEqual:b]));
	PrintNSStringValue(@"ref.a.eq.c", @([a isEqual:c]));
	PrintNSStringValue(@"ref.a.eq.v", @([a isEqual:v]));
	PrintNSStringValue(@"ref.a.eqType.v", @([a
	    isEqualToFileSystemSynchronizedGroupReferenceID:v]));
	PrintNSStringValue(@"ref.copy.eq", @([copy isEqual:a]));

	for (NSString *representation in @[@"foo/bar.m", @"/Localized/foo/bar.m",
	    @"foo/bar.m:variant", @"foo/bar.m (variant)", @"foo"]) {
		NSError *error = nil;
		NSString *label = [@"parse." stringByAppendingString:
		    representation];
		id identifier = [refClass
		    referenceIDFromPropertyListRepresentation:representation
		    error:&error];

		PrintReferenceState(label, identifier);
		PrintNSStringValue([label stringByAppendingString:@".error"],
		    [error localizedDescription]);
	}

	NSSet *set = [NSSet setWithObjects:a, c, nil];
	NSArray *archivedSet = [refClass
	    translateSetToArchivedRepresentation:set];
	NSSet *restoredSet = [refClass
	    translateSetFromArchivedRepresentation:archivedSet];
	PrintNSStringValue(@"set.archived", SortedDescriptions(archivedSet));
	PrintNSStringValue(@"set.restored", SortedDescriptions(restoredSet));

	NSDictionary *dictionary = @{a: @"v1", c: @"v2"};
	NSDictionary *archivedNo = [refClass
	    translateDictionaryToArchivedRepresentation:dictionary
	    archiveEachValueOnSingleLine:NO valueTransformer:transformer];
	NSDictionary *archivedYes = [refClass
	    translateDictionaryToArchivedRepresentation:dictionary
	    archiveEachValueOnSingleLine:YES valueTransformer:transformer];
	PrintNSStringValue(@"dict.archived.no", DictionaryDescription(archivedNo));
	PrintNSStringValue(@"dict.archived.yes",
	    DictionaryDescription(archivedYes));
	PrintNSStringValue(@"dict.restored", DictionaryDescription([refClass
	    translateDictionaryFromArchivedRepresentation:archivedYes
	    valueTransformer:transformer]));
	return (0);
}

static int
cmdBuildConfigurations(void)
{
	XCBuildConfiguration *debug = [XCBuildConfiguration
	    buildConfigurationWithName:@"Debug" settings:@{
		@"PRODUCT_NAME": @"App",
		@"GCC_OPTIMIZATION_LEVEL": @"0",
		@"CLANG_ENABLE_OBJC_ARC": @"YES",
	    }];
	XCBuildConfiguration *release = [[XCBuildConfiguration alloc]
	    initWithName:@"Release" settings:@{@"PRODUCT_NAME": @"App"}
	    makeImmutable:NO];
	XCConfigurationList *list = [XCConfigurationList
	    configurationListWithConfigurations:@[debug, release]];

	PrintNSStringValue(@"class.buildStyle.attrs",
	    [PBXBuildStyle archivableAttributes]);
	PrintNSStringValue(@"class.attrs", [XCBuildConfiguration
	    archivableAttributes]);
	PrintNSStringValue(@"class.rels", [XCBuildConfiguration
	    archivableRelationships]);
	PrintNSStringValue(@"class.list.attrs", [XCConfigurationList
	    archivableAttributes]);
	PrintNSStringValue(@"class.archiveName.ref", [XCBuildConfiguration
	    archiveNameForKey:@"baseConfigurationReference_forArchiving"]);
	PrintNSStringValue(@"class.archiveName.anchor", [XCBuildConfiguration
	    archiveNameForKey:@"baseConfigurationReferenceAnchor_forArchiving"]);
	PrintNSStringValue(@"class.archiveName.path", [XCBuildConfiguration
	    archiveNameForKey:@"baseConfigurationReferenceRelativePath_forArchiving"]);
	PrintNSStringValue(@"class.list.rels", [XCConfigurationList
	    archivableRelationships]);
	PrintConfigurationState(@"config.debug", debug);
	PrintConfigurationState(@"config.release", release);
	PrintNSStringValue(@"config.debug.get", [debug
	    buildSettingForKeyPath:@"PRODUCT_NAME"]);
	[debug setBuildSetting:@"Renamed" forKeyPath:@"PRODUCT_NAME"];
	PrintSettingsDictionary(@"config.debug.set", [debug buildSettings]);
	[debug removeBuildSettingForKeyPath:@"GCC_OPTIMIZATION_LEVEL"];
	PrintSettingsDictionary(@"config.debug.remove", [debug buildSettings]);
	PrintNSStringValue(@"config.debug.missing", [debug
	    buildSettingForKeyPath:@"MISSING"]);

	PrintListState(@"list", list);
	PrintNSStringValue(@"list.exists.debug", @([list
	    buildConfigurationExistsForName:@"Debug"]));
	PrintNSStringValue(@"list.exists.missing", @([list
	    buildConfigurationExistsForName:@"Missing"]));
	PrintNSStringValue(@"list.for.debug", [[list
	    buildConfigurationForName:@"Debug"] name]);
	PrintNSStringValue(@"list.for.missing", [[list
	    buildConfigurationForName:@"Missing"] name]);
	PrintNSStringValue(@"list.effective.debug", [[list
	    effectiveBuildConfigurationForName:@"Debug"] name]);
	PrintNSStringValue(@"list.effective.missing", [[list
	    effectiveBuildConfigurationForName:@"Missing"] name]);

	[list setDefaultConfigurationName:@"Release"];
	[list setDefaultConfigurationIsVisible:NO];
	PrintListState(@"list.after", list);

	XCBuildConfiguration *added = [XCBuildConfiguration
	    buildConfigurationWithName:@"Custom" settings:@{}];

	[list addBuildConfiguration:added];
	PrintNSStringValue(@"list.added", ConfigurationNames(
	    [list buildConfigurations]));
	[list removeObjectFromBuildConfigurationsAtIndex:1];
	PrintNSStringValue(@"list.removed", ConfigurationNames(
	    [list buildConfigurations]));
	[list insertObject:release inBuildConfigurationsAtIndex:0];
	PrintNSStringValue(@"list.inserted", ConfigurationNames(
	    [list buildConfigurations]));
	[list moveBuildConfigurationsAtIndexes:
	    [NSIndexSet indexSetWithIndex:0] toIndex:2];
	PrintNSStringValue(@"list.moved", ConfigurationNames(
	    [list buildConfigurations]));

	XCConfigurationList *empty = [[XCConfigurationList alloc] init];

	PrintListState(@"list.empty", empty);
	PrintNSStringValue(@"list.empty.local",
	    [empty localBuildSettingsDictionariesForAllConfigurations]);
	PrintNSStringValue(@"list.copy", ConfigurationNames(
	    [[list copy] buildConfigurations]));
	return (0);
}

int
main(int argc, char **argv)
{
	@autoreleasepool {
		const char *cmd;

		if (argc >= 2 && strcmp(argv[1], "propertydefs") == 0)
			return (cmdPropertyDefs());
		if (argc >= 2 && strcmp(argv[1], "propertydomains") == 0)
			return (cmdPropertyDomains());
		if (argc >= 2 && strcmp(argv[1], "xcmacroexpansion") == 0)
			return (cmdXCMacroExpansion());
		if (argc >= 2 && strcmp(argv[1], "xcproducttypes") == 0)
			return (cmdXCProductTypes());
		if (argc >= 2 && strcmp(argv[1], "runtimevalues") == 0)
			return (cmdRuntimeValues());
		if (argc >= 2 && strcmp(argv[1], "buildconfigurations") == 0)
			return (cmdBuildConfigurations());
		if (argc < 3)
			usage();
		cmd = argv[1];

		if (strcmp(cmd, "roundtrip") == 0)
			return (cmdRoundtrip([NSString stringWithUTF8String:
			    argv[2]]));
		if (strcmp(cmd, "cat") == 0)
			return (cmdCat([NSString stringWithUTF8String:
			    argv[2]]));
		if (strcmp(cmd, "dump") == 0)
			return (cmdDump([NSString stringWithUTF8String:
			    argv[2]]));

		usage();
		return (2);
	}
}
