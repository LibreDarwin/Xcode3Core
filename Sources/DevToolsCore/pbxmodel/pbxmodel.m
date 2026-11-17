/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Command-line driver for the ProjectModel object graph (DevToolsCore). */

#import <Foundation/Foundation.h>

#include <string.h>

#import "DevToolsCore/PBXProjectModel.h"
#import "DevToolsCore/PBXObject.h"
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
	    "       pbxmodel propertydomains\n");
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

int
main(int argc, char **argv)
{
	@autoreleasepool {
		const char *cmd;

		if (argc >= 2 && strcmp(argv[1], "propertydefs") == 0)
			return (cmdPropertyDefs());
		if (argc >= 2 && strcmp(argv[1], "propertydomains") == 0)
			return (cmdPropertyDomains());
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
