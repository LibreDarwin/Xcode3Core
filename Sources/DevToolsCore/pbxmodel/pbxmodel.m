/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Command-line driver for the ProjectModel object graph (DevToolsCore). */

#import <Foundation/Foundation.h>

#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#import <objc/message.h>
#import <objc/runtime.h>

#import "DevToolsCore/PBXProjectModel.h"
#import "DevToolsCore/PBXObject.h"
#import "DevToolsCore/PBXReference.h"
#import "DevToolsCore/PBXObjectID.h"
#import "DevToolsCore/ProjectModel/PBXArchiveBinding.h"
#import "DevToolsCore/ProjectModel/PBXPListArchiver.h"
#import "DevToolsCore/PBXTarget.h"
#import "DevToolsCore/XCBuildConfiguration.h"
#import <DVTFoundation/DVTVersion.h>
#import <DVTMacroFoundation/DVTMacroDefinitionConditionParameter.h>
#import <DVTMacroFoundation/DVTMacroDefinitionConditionSet.h>
#import <DVTMacroFoundation/DVTMacroExpansion-Protocol.h>
#import <DVTMacroFoundation/DVTMacroExpressionParser.h>
#import "DevToolsCore/BuildSystem/DVTMacroDefinitionTable+XCMacroExpansionExtensions.h"
#import "DevToolsCore/PBXExtendedWrapperPart.h"
#import "DevToolsCore/PBXFileSystemSynchronizedGroupRelativeReferenceID.h"
#import "DevToolsCore/PBXPackageTypeSpecification.h"
#import "DevToolsCore/BuildSystem/XCPropertyDefinition_SupportedVersionRange.h"
#import "DevToolsCore/XCCompatibilityFeature.h"
#import "DevToolsCore/PBXPlistArchiverAdditions.h"
#import "DevToolsCore/XCMacroExpansionScope.h"
#import "DevToolsCore/XCObjectGraphPath.h"
#import "DevToolsCore/XCProductTypeSpecification.h"
#import "DevToolsCore/XCStringList.h"
#import "DevToolsCore/BuildSystem/XCSimpleFilePreprocessor.h"
#import "DevToolsCore/ProjectModel/XCProjectRenameItem.h"
#import "DevToolsCore/BuildSystem/XCPropertyDefinition.h"
#import "DevToolsCore/BuildSystem/XCPropertyDomainSpecification.h"
#import "DevToolsCore/ProjectModel/pbxproj.h"
#import "DevToolsSupport/NSString+TSStringAdditions.h"
#import "DevToolsSupport/TSPropertyListDictionary.h"
#import "DevToolsSupport/TSRegularExpression.h"
#import "DevToolsSupport/TSFileManager.h"
#import "DevToolsSupport/TSTimedTrace.h"
#import "PBXPListCoding.h"

static void
usage(void)
{
	fprintf(stderr,
	    "usage: pbxmodel roundtrip <project.pbxproj>\n"
	    "       pbxmodel cat <project.pbxproj>\n"
	    "       pbxmodel applearchive <project.pbxproj>\n"
	    "       pbxmodel applesave <project.pbxproj> <output.pbxproj> [project-name]\n"
	    "       pbxmodel dump <project.pbxproj>\n"
	    "       pbxmodel propertydefs\n"
	    "       pbxmodel propertydomains\n"
	    "       pbxmodel xcmacroexpansion\n"
	    "       pbxmodel macroevaluation\n"
	    "       pbxmodel objectgraphpath\n"
	    "       pbxmodel compatfeatures\n"
	    "       pbxmodel supportedversionranges\n"
	    "       pbxmodel propertyvalues\n"
	    "       pbxmodel propertyconditions\n"
	    "       pbxmodel propertysupported\n"
	    "       pbxmodel plistwrappers\n"
	    "       pbxmodel stringlist\n"
	    "       pbxmodel tsstringbom\n"
	    "       pbxmodel tsregularexpression\n"
	    "       pbxmodel tsfilemanager\n"
	    "       pbxmodel tstimedtrace\n"
	    "       pbxmodel tspropertylistdictionary\n"
	    "       pbxmodel xcsfpp\n"
	    "       pbxmodel xcprojectrename\n"
	    "       pbxmodel xcproducttypes\n"
	    "       pbxmodel runtimevalues\n"
	    "       pbxmodel buildconfigurations\n"
	    "       pbxmodel paths\n"
	    "       pbxmodel targetdependencies\n"
	    "       pbxmodel archivebindings\n"
	    "       pbxmodel plistarchive\n");
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

static int
AppleSaveCompareKeys(const void *a, const void *b)
{
	const OPPDictEntry *ea = a;
	const OPPDictEntry *eb = b;

	return (strcmp(ea->key, eb->key));
}

static int
AppleSaveCompareObjectKeys(const void *a, const void *b)
{
	const OPPDictEntry *ea = a;
	const OPPDictEntry *eb = b;
	int ia = strcmp(ea->key, "isa") == 0;
	int ib = strcmp(eb->key, "isa") == 0;

	if (ia != ib)
		return (ia ? -1 : 1);
	return (strcmp(ea->key, eb->key));
}

static const char *
AppleSaveEntryISA(const OPPDictEntry *entry)
{
	if (entry->value == NULL || entry->value->kind != OPP_DICT)
		return ("");
	return (opp_scalar_get(entry->value, "isa") ?: "");
}

static int
AppleSaveCompareObjects(const void *a, const void *b)
{
	const OPPDictEntry *ea = a;
	const OPPDictEntry *eb = b;
	int result = strcmp(AppleSaveEntryISA(ea), AppleSaveEntryISA(eb));

	if (result != 0)
		return (result);
	return (strcmp(ea->key, eb->key));
}

static NSString *
AppleSaveScalarString(OPPValue *dict, const char *key)
{
	const char *value = opp_scalar_get(dict, key);

	return (value != NULL ? [NSString stringWithUTF8String:value] : nil);
}

static OPPValue *
AppleSaveOwnerOfID(OPPValue *objects, const char *objectID)
{
	size_t i;

	if (objects == NULL || objects->kind != OPP_DICT)
		return (NULL);
	for (i = 0; i < objects->nentry; i++) {
		OPPValue *value = opp_dict_get(objects->entries[i].value,
		    "buildConfigurationList");

		if (value != NULL && value->kind == OPP_STRING &&
		    value->str != NULL && strcmp(value->str, objectID) == 0)
			return (objects->entries[i].value);
	}
	return (NULL);
}

static NSString *
AppleSaveArchiveComment(OPPValue *objects, const char *objectID,
    OPPValue *object, NSString *projectName)
{
	NSString *isa = AppleSaveScalarString(object, "isa");
	NSString *name = AppleSaveScalarString(object, "name");
	NSString *path = AppleSaveScalarString(object, "path");

	if ([isa isEqualToString:@"PBXProject"])
		return (@"Project object");
	if ([isa isEqualToString:@"XCConfigurationList"]) {
		OPPValue *owner = AppleSaveOwnerOfID(objects, objectID);
		NSString *ownerISA = AppleSaveScalarString(owner, "isa");
		NSString *ownerName = AppleSaveScalarString(owner, "name");

		if ([ownerISA isEqualToString:@"PBXProject"])
			ownerName = projectName;
		if (ownerName == nil)
			ownerName = AppleSaveScalarString(owner, "path");
		if (ownerISA != nil && ownerName != nil)
			return ([NSString stringWithFormat:
			    @"Build configuration list for %@ \"%@\"",
			    ownerISA, ownerName]);
		return (nil);
	}
	if ([isa isEqualToString:@"XCBuildConfiguration"])
		return (name);
	if ([isa hasPrefix:@"PBX"] && name != nil &&
	    ![isa isEqualToString:@"PBXFileSystemSynchronizedRootGroup"])
		return (name);
	if ([isa isEqualToString:@"XCRemoteSwiftPackageReference"]) {
		NSString *url = AppleSaveScalarString(object, "repositoryURL");
		NSString *last = [[url componentsSeparatedByString:@"/"]
		    lastObject];

		return ([NSString stringWithFormat:
		    @"XCRemoteSwiftPackageReference \"%@\"", last]);
	}
	if ([isa isEqualToString:@"XCLocalSwiftPackageReference"]) {
		NSString *relativePath = AppleSaveScalarString(object,
		    "relativePath");

		return ([NSString stringWithFormat:
		    @"XCLocalSwiftPackageReference \"%@\"", relativePath]);
	}
	if ([isa isEqualToString:@"XCSwiftPackageProductDependency"])
		return (AppleSaveScalarString(object, "productName"));
	if ([isa isEqualToString:@"PBXFileSystemSynchronizedRootGroup"] ||
	    [isa hasPrefix:@"PBXFileSystemSynchronized"])
		return (path ?: name);
	if (name != nil)
		return (name);
	if (path != nil)
		return (path);
	return (nil);
}

static NSDictionary *
AppleSaveBuildComments(OPPValue *root, NSString *projectName)
{
	OPPValue *objects = opp_dict_get(root, "objects");
	NSMutableDictionary *comments = [NSMutableDictionary dictionary];
	size_t i;

	if (objects == NULL || objects->kind != OPP_DICT)
		return (comments);
	for (i = 0; i < objects->nentry; i++) {
		OPPDictEntry *entry = &objects->entries[i];
		NSString *key = [NSString stringWithUTF8String:entry->key];
		NSString *comment = AppleSaveArchiveComment(objects, entry->key,
		    entry->value, projectName);

		if (comment == nil && entry->key_comment != NULL)
			comment = [NSString stringWithUTF8String:
			    entry->key_comment];
		if (comment != nil)
			comments[key] = comment;
		opp_dict_set_comment(objects, entry->key, [comment UTF8String],
		    NULL);
	}
	return (comments);
}

static char *
AppleSaveApplyReferenceComments(OPPValue *value, NSDictionary *comments,
    const char *suppressedKey)
{
	if (value == NULL)
		return (NULL);
	if (value->kind == OPP_STRING) {
		NSString *comment;

		if (suppressedKey != NULL)
			return (NULL);
		comment = (value->str != NULL) ?
		    comments[[NSString stringWithUTF8String:value->str]] : nil;
		return (comment != NULL ? strdup([comment UTF8String]) : NULL);
	}
	if (value->kind == OPP_ARRAY) {
		size_t i;

		for (i = 0; i < value->nelem; i++) {
			char *comment = AppleSaveApplyReferenceComments(
			    value->elems[i].value, comments, NULL);

			free(value->elems[i].comment);
			value->elems[i].comment = comment;
		}
		return (NULL);
	}
	if (value->kind == OPP_DICT) {
		size_t i;

		for (i = 0; i < value->nentry; i++) {
			const char *suppressed = (strcmp(value->entries[i].key,
			    "remoteGlobalIDString") == 0) ?
			    value->entries[i].key : NULL;
			char *comment = AppleSaveApplyReferenceComments(
			    value->entries[i].value, comments, suppressed);

			free(value->entries[i].value_comment);
			value->entries[i].value_comment = comment;
		}
	}
	return (NULL);
}

static void
AppleSaveSetInline(OPPValue *value)
{
	size_t i;

	if (value == NULL)
		return;
	value->inline_form = 1;
	if (value->kind == OPP_DICT) {
		value->inline_lead_space = 0;
		value->inline_tight = 0;
		for (i = 0; i < value->nentry; i++)
			AppleSaveSetInline(value->entries[i].value);
	} else if (value->kind == OPP_ARRAY) {
		value->inline_join = 0;
		value->inline_array_lead_space = 0;
		value->inline_array_trail_space = (value->nelem != 0);
		for (i = 0; i < value->nelem; i++)
			AppleSaveSetInline(value->elems[i].value);
	}
}

static void
AppleSaveClearLayout(OPPValue *objects)
{
	size_t i;

	if (objects == NULL)
		return;
	for (i = 0; i < objects->nlayout; i++) {
		free(objects->layout[i].text);
		free(objects->layout[i].indent);
	}
	free(objects->layout);
	objects->layout = NULL;
	objects->nlayout = 0;
	objects->has_sections = 0;
}

static void
AppleSaveApplyMigrations(OPPValue *root)
{
	OPPValue *objects = opp_dict_get(root, "objects");
	const char *version = opp_scalar_get(root, "objectVersion");
	BOOL modern = (version != NULL && strcmp(version, "77") == 0);
	size_t i;

	if (objects == NULL || objects->kind != OPP_DICT)
		return;
	if (modern) {
		NSMutableArray *dropped = [NSMutableArray array];

		for (i = 0; i < objects->nentry; i++) {
			const char *isa = opp_scalar_get(
			    objects->entries[i].value, "isa");

			if (isa != NULL && strcmp(isa, "PBXFutureThing") == 0)
				[dropped addObject:[NSString stringWithUTF8String:
				    objects->entries[i].key]];
		}
		for (NSString *key in dropped)
			opp_dict_remove(objects, [key UTF8String]);
	}
	for (i = 0; i < objects->nentry; i++) {
		OPPValue *object = objects->entries[i].value;
		const char *isa = opp_scalar_get(object, "isa");

		if (isa == NULL || strcmp(isa, "PBXProject") != 0)
			continue;
		opp_dict_remove(object, "minimizedProjectReferenceProxies");
		opp_dict_remove(object, "preferredProjectObjectVersion");
		if (modern) {
			opp_dict_remove(object, "compatibilityVersion");
			opp_dict_set(object, "preferredProjectObjectVersion",
			    opp_string_new("60"));
		}
	}
	if (modern)
		opp_dict_set(root, "objectVersion", opp_string_new("73"));
}

static void
AppleSaveCanonicalize(OPPValue *root, NSString *projectName)
{
	OPPValue *objects = opp_dict_get(root, "objects");
	NSDictionary *comments;
	size_t i;

	qsort(root->entries, root->nentry, sizeof(root->entries[0]),
	    AppleSaveCompareKeys);
	if (objects == NULL || objects->kind != OPP_DICT)
		return;
	AppleSaveClearLayout(objects);
	qsort(objects->entries, objects->nentry, sizeof(objects->entries[0]),
	    AppleSaveCompareObjects);
	for (i = 0; i < objects->nentry; i++) {
		OPPValue *object = objects->entries[i].value;
		NSString *isa = AppleSaveScalarString(object, "isa");

		if (![PBXProjectModel isSupportedArchiveClass:isa])
			continue;
		qsort(object->entries, object->nentry,
		    sizeof(object->entries[0]), AppleSaveCompareObjectKeys);
		if ([isa isEqualToString:
		    @"PBXFileSystemSynchronizedRootGroup"])
			AppleSaveSetInline(object);
	}
	comments = AppleSaveBuildComments(root, projectName);
	AppleSaveApplyReferenceComments(root, comments, NULL);
}

/* applearchive: print the PBXPListArchiver-compatible dictionary as XML. */
static int
cmdAppleArchive(NSString *path)
{
	NSError *error = nil;
	PBXProjectModel *model;
	NSDictionary *archive;
	NSData *data;

	model = [PBXProjectModel modelWithContentsOfFile:path error:&error];
	if (model == nil) {
		fprintf(stderr, "pbxmodel: %s: %s\n", [path UTF8String],
		    [[error description] UTF8String]);
		return (1);
	}
	archive = [model applePListArchive];
	if (archive == nil) {
		fprintf(stderr, "pbxmodel: %s: unable to build plist archive\n",
		    [path UTF8String]);
		return (1);
	}
	data = [NSPropertyListSerialization
	    dataWithPropertyList:archive
	    format:NSPropertyListXMLFormat_v1_0
	    options:0
	    error:&error];
	if (data == nil) {
		fprintf(stderr, "pbxmodel: %s: %s\n", [path UTF8String],
		    [[error description] UTF8String]);
		return (1);
	}
	fwrite([data bytes], 1, [data length], stdout);
	return (0);
}

static int
cmdAppleSave(NSString *input, NSString *output, NSString *projectName)
{
	OPPDocument *document;
	char *err = NULL;
	char *text;
	size_t length = 0;
	NSString *wrapper = [[input stringByDeletingLastPathComponent]
	    lastPathComponent];

	document = opp_parse_file([input UTF8String], &err);
	if (document == NULL) {
		fprintf(stderr, "pbxmodel: %s: %s\n", [input UTF8String],
		    (err != NULL) ? err : "parse error");
		free(err);
		return (1);
	}
	if (projectName == nil) {
		if ([wrapper hasSuffix:@".xcodeproj"])
			projectName = [wrapper stringByDeletingPathExtension];
		else
			projectName = [[input lastPathComponent]
			    stringByDeletingPathExtension];
	}
	AppleSaveApplyMigrations(document->root);
	AppleSaveCanonicalize(document->root, projectName);
	text = opp_write_document(document, &length, &err);
	opp_document_free(document);
	if (text == NULL) {
		fprintf(stderr, "pbxmodel: %s: %s\n", [output UTF8String],
		    (err != NULL) ? err : "write error");
		free(err);
		return (1);
	}
	{
		NSData *data = [NSData dataWithBytes:text length:length];

		free(text);
		if (![data writeToFile:output atomically:YES]) {
			fprintf(stderr, "pbxmodel: %s: unable to write output\n",
			    [output UTF8String]);
			return (1);
		}
	}
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

static id
EvaluateMacroString(DVTMacroExpansionScope *scope, NSString *string)
{
	return ([scope evaluatedStringValueForMacroExpression:
	    DVTMacroExpressionByParsingString(string)]);
}

static id
EvaluateMacroList(DVTMacroExpansionScope *scope, NSString *string)
{
	return ([scope evaluatedStringListValueForMacroExpression:
	    DVTMacroExpressionByParsingStringAsList(string)]);
}

static int
cmdMacroEvaluation(void)
{
	DVTMacroDefinitionTable *table = [DVTMacroDefinitionTable newWithLabel:@"oracle"];
	NSString *baseName = nil;
	DVTMacroDefinitionConditionSet *macCondition =
	    [DVTMacroDefinitionConditionSet conditionSetFromStringRepresentation:@"COND[sdk=macosx]"
							     getBaseMacroName:&baseName error:NULL];
	DVTMacroDefinitionConditionSet *iosCondition =
	    [DVTMacroDefinitionConditionSet conditionSetFromStringRepresentation:@"COND[sdk=iphoneos]"
							     getBaseMacroName:&baseName error:NULL];
	DVTMacroExpansionScope *scope;
	DVTMacroExpansionScope *preservingScope;

	[table parseAndSetValue:@"bar" forMacroName:@"FOO" conditionSet:nil];
	[table parseAndSetValue:@"foo bar" forMacroName:@"NAME" conditionSet:nil];
	[table parseAndSetValue:@"/a/b/c.txt" forMacroName:@"PATH" conditionSet:nil];
	[table parseAndSetValue:@"" forMacroName:@"EMPTY" conditionSet:nil];
	[table parseAndSetValue:@"$(FOO)-$(MISSING)" forMacroName:@"RECURSIVE"
	    conditionSet:nil];
	[table setValue:@[@"a", @"b c", @"$(FOO)"] forMacroName:@"LIST"
	    conditionSet:nil];
	[table parseAndSetValue:@"mac" forMacroName:@"COND" conditionSet:macCondition];
	[table parseAndSetValue:@"ios" forMacroName:@"COND" conditionSet:iosCondition];

	scope = [DVTMacroExpansionScope newWithParentScope:nil macros:table
	    definitionLevel:0 conditionParameterValues:@{@"sdk": @"macosx"}
	    preserveUnresolvedReferences:NO];
	for (NSString *string in @[@"literal", @"$(FOO)", @"$FOO", @"$(NAME)",
	    @"$(MISSING)", @"$$", @"$(FOO)/$(MISSING)", @"$(FOO:quote)",
	    @"$(FOO:upper)", @"$(FOO:lower)", @"$(FOO:identifier)",
	    @"$(PATH:dir)", @"$(PATH:file)", @"$(PATH:base)", @"$(PATH:suffix)",
	    @"$(FOO:default=baz)", @"$(MISSING:default=baz)",
	    @"$(FOO:relativeto=/a)", @"$(COND)", @"$(RECURSIVE)", @"$(EMPTY)",
	    @"$(LIST)", @"$(FOO:badop)"]) {
		PrintNSStringValue([@"string." stringByAppendingString:string],
		    EvaluateMacroString(scope, string));
	}
	for (NSString *string in @[@"a b c", @"\"a b\" 'c d'", @"a\\ b",
	    @"$(NAME)", @"$(MISSING)", @"\"$(FOO) x\"", @""]) {
		PrintNSStringValue([@"list." stringByAppendingString:string],
		    EvaluateMacroList(scope, string));
	}
	PrintNSStringValue(@"arrayList", [scope evaluatedStringListValueForMacroExpression:
	    DVTMacroExpressionByParsingStringArrayAsList(@[@"a", @"b c", @"$(FOO)"])]);
	PrintNSStringValue(@"debug.simple", [DVTMacroExpressionByParsingString(@"$(FOO)")
	    dvt_debugDescription]);
	PrintNSStringValue(@"stringForm.list",
	    [DVTMacroExpressionByParsingStringAsList(@"a $(FOO)") dvt_stringForm]);

	preservingScope = [DVTMacroExpansionScope newWithParentScope:nil macros:table
	    definitionLevel:0 conditionParameterValues:@{@"sdk": @"macosx"}
	    preserveUnresolvedReferences:YES];
	PrintNSStringValue(@"preserving.MISSING",
	    EvaluateMacroString(preservingScope, @"$(MISSING)"));
	PrintNSStringValue(@"preserving.RECURSIVE",
	    EvaluateMacroString(preservingScope, @"$(RECURSIVE)"));
	return (0);
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

static void
PathsPrintValue(NSString *label, id value)
{
	printf("%s = %s\n", [label UTF8String],
	    value != nil ? [[value description] UTF8String] : "(null)");
}

static void
PathsPrintPathValue(NSString *label, id value)
{
	PathsPrintValue(label, value != nil ? value : @"");
}

static PBXFileReference *
PathReference(NSString *path, NSString *tree)
{
	return ([[PBXFileReference alloc] initWithName:nil path:path
	    sourceTree:tree]);
}

static void
PrintPathReference(NSString *label, PBXFileReference *ref)
{
	PathsPrintValue([label stringByAppendingString:@".sourceTree"],
	    [ref sourceTree]);
	PathsPrintPathValue([label stringByAppendingString:@".path"], [ref path]);
	PathsPrintValue([label stringByAppendingString:@".absolutePath"],
	    [ref absolutePath]);
	PathsPrintValue([label stringByAppendingString:@".resolvedAbsolutePath"],
	    [ref resolvedAbsolutePath]);
	PathsPrintValue([label stringByAppendingString:
	    @".absolutePathForBuildParameters"],
	    [ref absolutePathForBuildParameters:nil]);
}

static int
cmdPaths(void)
{
	NSArray *trees = @[@"<absolute>", @"SOURCE_ROOT", @"SRCROOT",
	    @"PROJECT_DIR", @"<group>", @"DEVELOPER_DIR", @"SDKROOT",
	    @"BUILT_PRODUCTS_DIR", @"SOURCE_TREE", @"GROUP"];
	NSArray *paths = @[@"foo/bar.m", @"/tmp/foo.m", @"", @"../x",
	    @"$(FOO)/x"];
	PBXFileReference *ref;
	PBXGroup *group;

	for (NSString *tree in trees) {
		for (NSString *path in paths) {
			NSString *label = [NSString stringWithFormat:
			    @"tree.%@.path.%@", tree, path];

			PrintPathReference(label, PathReference(path, tree));
		}
	}
	PrintPathReference(@"tree.<absolute>.path.nil",
	    PathReference(nil, @"<absolute>"));
	PrintPathReference(@"tree.SOURCE_ROOT.path.nil",
	    PathReference(nil, @"SOURCE_ROOT"));
	PrintPathReference(@"tree.<group>.path.nil",
	    PathReference(nil, @"<group>"));

	group = [[PBXGroup alloc] initWithName:nil path:@"/base"
	    sourceTree:@"<absolute>"];
	ref = PathReference(@"foo/bar.m", @"<group>");
	[group addItem:ref];
	PrintPathReference(@"group.absolute.foo", ref);

	group = [[PBXGroup alloc] initWithName:nil path:@"base"
	    sourceTree:@"SOURCE_ROOT"];
	ref = PathReference(@"foo/bar.m", @"<group>");
	[group addItem:ref];
	PrintPathReference(@"group.sourceRoot.foo", ref);

	group = [[PBXGroup alloc] initWithName:nil path:nil
	    sourceTree:@"SOURCE_ROOT"];
	ref = PathReference(@"foo/bar.m", @"<group>");
	[group addItem:ref];
	PrintPathReference(@"group.sourceRoot.nilPath.foo", ref);

	for (NSString *string in @[@"foo/bar", @"/foo/bar", @"$(SRCROOT)/x",
	    @"$(FOO)/x", @"../x", @""]) {
		NSString *label = [@"expand." stringByAppendingString:string];

		PathsPrintValue(label, [PathReference(nil, @"<absolute>")
		    absoluteExpandedPathForString:string
		    forBuildParameters:nil]);
	}
	printf("sourceTreeDisplayNamesDictionary = {\n}\n");
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

static id
OrNull(id value)
{
	return (value != nil ? value : @"(null)");
}

static NSArray *
TargetNames(NSArray *targets)
{
	NSMutableArray *names = [NSMutableArray array];
	id target;

	for (target in targets) {
		if ([target isKindOfClass:[PBXTarget class]])
			[names addObject:[target name] ?: [target displayName]];
		else
			[names addObject:OrNull(target)];
	}
	return (names);
}

static PBXTarget *
MakeNamedTarget(NSString *name, NSString *identifier)
{
	PBXTarget *target = [[PBXTarget alloc] init];

	[target setName:name];
	[target setObjectID:identifier];
	return (target);
}

static int
cmdTargetDependencies(void)
{
	PBXProject *project = [[PBXProject alloc] init];
	PBXTarget *a = MakeNamedTarget(@"A", @"AAAAAAAAAAAAAAAAAAAAAAAA");
	PBXTarget *b = MakeNamedTarget(@"B", @"BBBBBBBBBBBBBBBBBBBBBBBB");
	PBXTarget *c = MakeNamedTarget(@"C", @"CCCCCCCCCCCCCCCCCCCCCCCC");
	PBXTargetDependency *depAB;
	PBXTargetDependency *depBC;

	PrintNSStringValue(@"class.dependency.attrs",
	    [PBXTargetDependency archivableAttributes]);
	PrintNSStringValue(@"class.dependency.rels",
	    [PBXTargetDependency archivableRelationships]);
	PrintNSStringValue(@"class.proxy.attrs",
	    [PBXContainerItemProxy archivableAttributes]);
	PrintNSStringValue(@"class.proxy.rels",
	    [PBXContainerItemProxy archivableRelationships]);
	PrintNSStringValue(@"class.target.attrs",
	    [PBXTarget archivableAttributes]);
	PrintNSStringValue(@"class.target.rels",
	    [PBXTarget archivableRelationships]);

	[project addTarget:a];
	[project addTarget:b];
	[project addTarget:c];
	PrintNSStringValue(@"project.targets", TargetNames([project targets]));
	PrintNSStringValue(@"a.project", @((BOOL)([a project] == project)));

	depAB = [[PBXTargetDependency alloc] initWithLocalTarget:b];
	depBC = [[PBXTargetDependency alloc] initWithLocalTarget:c];
	PrintNSStringValue(@"dep.ab.target",
	    @[ [depAB target] ?: @"<nil>" ]);
	PrintNSStringValue(@"dep.ab.name", OrNull([depAB name]));
	PrintNSStringValue(@"dep.ab.owner", OrNull([depAB owner]));
	PrintNSStringValue(@"dep.ab.needsSync", @([depAB needsSync]));
	PrintNSStringValue(@"dep.ab.productReference",
	    OrNull([depAB productReference]));
	PrintNSStringValue(@"dep.ab.recursive",
	    TargetNames([depAB orderedRecursiveDependencies]));

	[a addDependency:depAB];
	[b addDependency:depBC];
	PrintNSStringValue(@"a.deps", TargetNames([a dependencies]));
	PrintNSStringValue(@"a.direct", TargetNames([a directDependencies]));
	PrintNSStringValue(@"a.recursive", TargetNames([a
	    orderedRecursiveDependenciesIncludingSelf:NO]));
	PrintNSStringValue(@"a.recursive.self", TargetNames([a
	    orderedRecursiveDependenciesIncludingSelf:YES]));
	PrintNSStringValue(@"a.depends.b", @([a dependsOnTarget:b]));
	PrintNSStringValue(@"a.depends.c", @([a dependsOnTarget:c]));
	PrintNSStringValue(@"a.dependencyFor.b",
	    @[ [a dependencyForTarget:b] ?: @"<nil>" ]);
	PrintNSStringValue(@"a.dependencyFor.c",
	    @[ [a dependencyForTarget:c] ?: @"<nil>" ]);
	PrintNSStringValue(@"a.missing", TargetNames([a missingDependencies]));
	PrintNSStringValue(@"a.owner.ab", @((BOOL)([depAB owner] == a)));
	PrintNSStringValue(@"b.owner.bc", @((BOOL)([depBC owner] == b)));
	PrintNSStringValue(@"project.order", TargetNames([project
	    allTargetsInDependencyOrder]));
	PrintNSStringValue(@"b.depending", TargetNames([b
	    findDependingTargetsInProject:project]));

	[a removeDependency:depAB];
	PrintNSStringValue(@"a.after.remove", TargetNames([a dependencies]));
	PrintNSStringValue(@"a.owner.after.remove", OrNull([depAB owner]));
	[a addDependency:depAB];
	PrintNSStringValue(@"a.after.readd", TargetNames([a dependencies]));

	{
		PBXProject *cycleProject = [[PBXProject alloc] init];
		PBXTarget *d = MakeNamedTarget(@"D", @"DDDDDDDDDDDDDDDDDDDDDDDD");
		PBXTarget *e = MakeNamedTarget(@"E", @"EEEEEEEEEEEEEEEEEEEEEEEE");

		[cycleProject addTarget:d];
		[cycleProject addTarget:e];
		[d addDependency:[[PBXTargetDependency alloc]
		    initWithLocalTarget:e]];
		[e addDependency:[[PBXTargetDependency alloc]
		    initWithLocalTarget:d]];
		PrintNSStringValue(@"cycle.d.recursive", TargetNames([d
		    orderedRecursiveDependenciesIncludingSelf:NO]));
		PrintNSStringValue(@"cycle.d.recursive.self", TargetNames([d
		    orderedRecursiveDependenciesIncludingSelf:YES]));
		PrintNSStringValue(@"cycle.order", TargetNames([cycleProject
		    allTargetsInDependencyOrder]));
	}
	return (0);
}

static NSString *
NormalizedCompatibilityDescription(id value)
{
	NSString *description = [value description];
	NSRange range = [description rangeOfString:@"0x[0-9a-f]+"
	    options:NSRegularExpressionSearch];

	if (range.location == NSNotFound)
		return (description);
	return ([description stringByReplacingCharactersInRange:range
	    withString:@"0xADDR"]);
}

static void
PrintCompatibilityValue(NSString *label, id value)
{
	printf("%s = <%s>\n", [label UTF8String],
	    value != nil ? [NormalizedCompatibilityDescription(value) UTF8String]
	    : "nil");
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
static int
cmdCompatibilityFeatures(void)
{
	NSArray *names = @[@"XCPerArchitectureSettingsFeature",
	    @"XCPerSDKSettingsFeature", @"XCDataModelVersionGroupsFeature",
	    @"XCParallelTargetBuildsFeature", @"XCCompositeSDKsFeature",
	    @"XCWeakLinkFrameworkAttributeFeature",
	    @"XCGCCUseStandardIncludeSearchingFeature",
	    @"XCGCCRecognizeBuiltinFunctionsFeature",
	    @"XCGCCEnableLinkingWithSharedLibrariesFeature",
	    @"XCGCCGenerateIndirectFunctionCallsFeature",
	    @"XCGCCGenerateRegisterSubroutineFunctionCallsFeature",
	    @"XCGCCKernelDevelopmentModeFeature",
	    @"XCGCCGenerateFloatingPointLibraryCallsFeature",
	    @"XCCodeSigningIdentityFeature",
	    @"XCCodeSigningEntitlementsFeature",
	    @"XCCodeSigningResourceRulesPathFeature",
	    @"XCCodeSigningOtherFlagsFeature", @"XCMultipleProjectRootsFeature",
	    @"XCProvisioningProfileFeature", @"XCBuildRuleCompilerFlagsFeature",
	    @"XCLocalSwiftPackageReferenceFeature",
	    @"XCRemoteSwiftPackageReferenceFeature",
	    @"XCRegistrySwiftPackageReferenceFeature",
	    @"XCSwiftPackageTraitsFeature",
	    @"XCSwiftPackageProductDependencyFeature",
	    @"XCPackageProductDependenciesInBuildFilesFeature",
	    @"XCScriptPhaseInputFileListFeature",
	    @"XCScriptPhaseOutputFileListFeature",
	    @"XCScriptPhaseDependencyFileFeature",
	    @"XCScriptPhaseAlwaysOutOfDateFeature",
	    @"XCExtendedBuildFilePlatformFilterSupportFeature",
	    @"XCInternalXROSPlatformFilterSupportFeature",
	    @"XCBuildRuleInputDependenciesFeature",
	    @"XCBuildRuleArchitectureNeutralFlagFeature",
	    @"XCBuildRuleFileListFeature", @"XCXCFrameworkSupportFeature",
	    @"XCBuildFilePlatformFilterSupportFeature",
	    @"XCBuildFileProductReferenceSupportFeature",
	    @"XCProjectArchivingDelegateFeature",
	    @"XCXCFrameworkFileReferenceSignatureFeature",
	    @"XCLocalizationStringCatalogVariantGroupFeature",
	    @"XCMinimizedProjectReferenceProxiesFeature",
	    @"XCFileSystemSynchronizedGroupFeature",
	    @"XCFileSystemSynchronizedGroupWithBuildPhaseExceptions",
	    @"XCConfigFilesAnchoredReferenceFeature",
	    @"XCFileSystemSynchronizedGroupVariantGroupExceptions",
	    @"XCFileSystemSynchronizedGroupNestedVariantGroupExceptions",
	    @"XCFileSystemSynchronizedPlatformFilterInExceptionalBuildPhase",
	    @"XCFileSystemSynchronizedExtraAttributesInDefaultBuildPhase",
	    @"XCFileSystemSynchronizedGroupWithReferencesWithAssetTags"];

	for (NSString *selectorName in names) {
		SEL selector = NSSelectorFromString(selectorName);
		XCCompatibilityFeature *feature =
		    [XCCompatibilityFeature performSelector:selector];
		XCCompatibilityFeature *again =
		    [XCCompatibilityFeature performSelector:selector];
		XCCompatibilityFeature *fresh = [[XCCompatibilityFeature alloc]
		    initWithName:[feature name]];
		id copy = [feature copy];

		printf("== %s ==\n", [selectorName UTF8String]);
		PrintCompatibilityValue(@"feature.class",
		    NSStringFromClass([feature class]));
		PrintCompatibilityValue(@"feature.name", [feature name]);
		PrintCompatibilityValue(@"feature.description", [feature description]);
		printf("feature.hash = <%lu>\n", (unsigned long)[feature hash]);
		printf("feature.same_ptr = <%d>\n", feature == again);
		printf("feature.equal.again = <%d>\n", [feature isEqual:again]);
		printf("feature.equal.fresh = <%d>\n", [feature isEqual:fresh]);
		printf("feature.equal.string = <%d>\n",
		    [feature isEqual:[feature name]]);
		printf("feature.copy.class = <%s>\n",
		    [NSStringFromClass([copy class]) UTF8String]);
		printf("feature.copy.equal = <%d>\n", [feature isEqual:copy]);
	}

	XCCompatibilityFeature *named = [[XCCompatibilityFeature alloc]
	    initWithName:@"Custom Feature"];
	XCCompatibilityFeatureUse *use = [[XCCompatibilityFeatureUse alloc]
	    initWithFeature:named path:@"/tmp/project.pbxproj"];

	printf("== feature.use ==\n");
	PrintCompatibilityValue(@"use.class", NSStringFromClass([use class]));
	PrintCompatibilityValue(@"use.description", [use description]);
	PrintCompatibilityValue(@"use.feature", [use feature]);
	PrintCompatibilityValue(@"use.feature.name", [[use feature] name]);
	PrintCompatibilityValue(@"use.path", [use path]);
	return (0);
}
#pragma clang diagnostic pop

static DVTVersion *
SupportedVersionRangeVersion(NSString *stringValue)
{
	if ([stringValue isEqualToString:@"(nil)"])
		return (nil);
	return ([DVTVersion versionWithStringValue:stringValue]);
}

static void
PrintSupportedVersionValue(const char *label, id value)
{
	printf("%s = <%s>\n", label,
	    (value != nil) ? [[value description] UTF8String] : "nil");
}

static void
ProbeSupportedVersionRange(NSArray *pair, NSArray *versions)
{
	DVTVersion *start = SupportedVersionRangeVersion([pair objectAtIndex:0]);
	DVTVersion *end = SupportedVersionRangeVersion([pair objectAtIndex:1]);
	XCPropertyDefinition_SupportedVersionRange *range;

	range = [[XCPropertyDefinition_SupportedVersionRange alloc]
	    initWithStartOfRange:start endOfRange:end];
	printf("== range %s..%s ==\n",
	    [[pair objectAtIndex:0] UTF8String],
	    [[pair objectAtIndex:1] UTF8String]);
	PrintSupportedVersionValue("class", NSStringFromClass([range class]));
	PrintSupportedVersionValue("description", [range description]);
	printf("hash.same = <%d>\n", [range hash] == [range hash]);
	printf("equal.same = <%d>\n", [range isEqual:range]);
	XCPropertyDefinition_SupportedVersionRange *same =
	    [[XCPropertyDefinition_SupportedVersionRange alloc]
		initWithStartOfRange:start endOfRange:end];
	printf("equal.fresh = <%d>\n", [range isEqual:same]);
	printf("hash.fresh = <%d>\n", [range hash] == [same hash]);
	printf("equal.string = <%d>\n", [range isEqual:@"x"]);
	for (NSString *versionString in versions) {
		DVTVersion *version = [DVTVersion versionWithStringValue:versionString];

		printf("supports[%s] = <%d>\n", [versionString UTF8String],
		    (int)[range supportsVersion:version]);
	}
}

static void
ProbeSupportedVersionDefinition(NSString *label, NSArray *ranges,
    NSArray *versions)
{
	NSDictionary *dictionary = @{
		@"Name": @"TEST_SETTING",
		@"Type": @"String",
		@"SupportedVersionRanges": ranges,
	};
	TSPropertyListDictionary *plist =
	    [TSPropertyListDictionary propertyListDictionaryWithDictionary:dictionary];
	XCPropertyDefinition *definition =
	    [XCPropertyDefinition propertyDefinitionFromPListDictionary:plist];

	printf("== %s ==\n", [label UTF8String]);
	printf("has = <%d>\n", [definition hasSupportedVersionRanges]);
	for (NSString *versionString in versions) {
		DVTVersion *version = [DVTVersion versionWithStringValue:versionString];

		printf("supports[%s] = <%d>\n", [versionString UTF8String],
		    (int)[definition supportsVersion:version]);
	}
}

static int
cmdSupportedVersionRanges(void)
{
	NSArray *cases = @[
		@[@"1.0", @"2.0"],
		@[@"1.0", @"1.0"],
		@[@"2.0", @"1.0"],
		@[@"", @"2.0"],
		@[@"1.0", @""],
		@[@"", @""],
		@[@"1.0", @"(nil)"]
	];
	NSArray *versions = @[@"0.9", @"1", @"1.0", @"1.0.0", @"01.0",
	    @"1.5", @"1.9.9", @"2", @"2.0", @"2.0.1", @"2.1", @"10.0",
	    @"abc", @""];
	NSArray *definitionVersions = @[@"0", @"1", @"100", @"119", @"120",
	    @"602", @"602.0.0", @"603", @"800", @"900", @"1000",
	    @"107.60.1", @"107.60.2", @"107.60.999", @"107.61.0",
	    @"107.100.2", @"107.100.3", @"107.100.999", @"107.101.0"];

	PrintSupportedVersionValue("class",
	    NSStringFromClass([XCPropertyDefinition_SupportedVersionRange class]));
	for (NSArray *pair in cases)
		ProbeSupportedVersionRange(pair, versions);

	XCPropertyDefinition_SupportedVersionRange *r1 =
	    [[XCPropertyDefinition_SupportedVersionRange alloc]
		initWithStartOfRange:[DVTVersion versionWithStringValue:@"1.0"]
		endOfRange:[DVTVersion versionWithStringValue:@"2.0"]];
	XCPropertyDefinition_SupportedVersionRange *r2 =
	    [[XCPropertyDefinition_SupportedVersionRange alloc]
		initWithStartOfRange:[DVTVersion versionWithStringValue:@"1.0"]
		endOfRange:[DVTVersion versionWithStringValue:@"2.0"]];
	XCPropertyDefinition_SupportedVersionRange *r3 =
	    [[XCPropertyDefinition_SupportedVersionRange alloc]
		initWithStartOfRange:[DVTVersion versionWithStringValue:@"1.0"]
		endOfRange:[DVTVersion versionWithStringValue:@"3.0"]];
	printf("== equality ==\n");
	printf("r1.r2 = <%d>\n", [r1 isEqual:r2]);
	printf("r1.r3 = <%d>\n", [r1 isEqual:r3]);
	printf("hash.r1.r2 = <%d>\n", [r1 hash] == [r2 hash]);

	printf("== supported range definitions ==\n");
	ProbeSupportedVersionDefinition(@"string-only", @[@"800.0.0"],
	    definitionVersions);
	ProbeSupportedVersionDefinition(@"array-pair",
	    @[@[@"107.60.2", @"107.60.999"]], definitionVersions);
	ProbeSupportedVersionDefinition(@"mixed",
	    @[@[@"107.60.2", @"107.60.999"],
	      @[@"107.100.3", @"107.100.999"], @"119"], definitionVersions);
	ProbeSupportedVersionDefinition(@"one-element-pair", @[@[@"1.0"]],
	    definitionVersions);
	ProbeSupportedVersionDefinition(@"three-element-pair",
	    @[@[@"1.0", @"2.0", @"3.0"]], definitionVersions);
	ProbeSupportedVersionDefinition(@"reversed-pair",
	    @[@[@"2.0", @"1.0"]], definitionVersions);
	ProbeSupportedVersionDefinition(@"bad-string", @[@"abc"],
	    definitionVersions);
	ProbeSupportedVersionDefinition(@"empty", @[], definitionVersions);
	return (0);
}

static NSString *
PropertyValueFlat(id object)
{
	if (object == nil)
		return (@"");
	if ([object isKindOfClass:[NSArray class]]) {
		NSMutableArray *parts = [NSMutableArray array];

		for (id item in object)
			[parts addObject:PropertyValueFlat(item)];
		return ([NSString stringWithFormat:@"[%@]",
		    [parts componentsJoinedByString:@"|"]]);
	}
	return ([object description]);
}

static NSString *
PropertyValuesJoined(NSArray *values)
{
	NSMutableArray *parts = [NSMutableArray array];

	for (id value in values)
		[parts addObject:PropertyValueFlat(value)];
	return ([parts componentsJoinedByString:@","]);
}

static void
ProbePropertyValues(NSString *name, NSDictionary *dictionary)
{
	TSPropertyListDictionary *plist = [TSPropertyListDictionary
	    propertyListDictionaryWithDictionary:dictionary];
	XCPropertyDefinition *definition = [XCPropertyDefinition
	    propertyDefinitionFromPListDictionary:plist];
	NSArray *valueDefinitions = [(XCEnumerationPropertyDefinition *)definition
	    _filteredValueDefinitionsForTarget:nil];

	printf("== %s ==\n", [name UTF8String]);
	printf("definition = %s\n",
	    [NSStringFromClass([definition class]) UTF8String]);
	printf("allowed = %s\n",
	    [PropertyValuesJoined([definition allowedValues]) UTF8String]);
	printf("localized = %s\n",
	    [PropertyValuesJoined([definition localizedAllowedValues]) UTF8String]);
	printf("valueDefs = %lu\n", (unsigned long)[valueDefinitions count]);
	for (NSUInteger i = 0; i < [valueDefinitions count]; i++) {
		XCPropertyValueDefinition *valueDefinition =
		    [valueDefinitions objectAtIndex:i];

		printf("value[%lu] = %s|%s|%s|%s\n", (unsigned long)i,
		    [PropertyValueFlat([valueDefinition value]) UTF8String],
		    [PropertyValueFlat([valueDefinition localizedValue]) UTF8String],
		    [PropertyValueFlat([valueDefinition localizedDescription])
			UTF8String],
		    [PropertyValueFlat([valueDefinition
			commandArgumentGenerationInfo]) UTF8String]);
	}
}

static int
cmdPropertyValues(void)
{
	ProbePropertyValues(@"strings", @{
		@"Name": @"TEST_SETTING", @"Type": @"Enumeration",
		@"Values": @[@"one", @"two"],
	});
	ProbePropertyValues(@"dictionaries-value-only", @{
		@"Name": @"TEST_SETTING", @"Type": @"Enumeration",
		@"Values": @[@{@"Value": @"one"}, @{@"Value": @"two"}],
	});
	ProbePropertyValues(@"dictionaries-rich", @{
		@"Name": @"TEST_SETTING", @"Type": @"Enumeration",
		@"Values": @[
			@{
				@"Value": @"one",
				@"DisplayName": @"First",
				@"Description": @"First value",
				@"CommandLineArgs": @"-first",
				@"CommandLineFlag": @"--first",
				@"CommandLinePrefixFlag": @"-pf",
			},
			@{
				@"Value": @"two",
				@"DisplayName": @"Second",
				@"Description": @"Second value",
				@"CommandLineArgs": @[@"-second", @"$(VALUE)"],
				@"CommandLineFlag": @"--second",
				@"CommandLinePrefixFlag": @"-ps",
			},
		],
	});
	ProbePropertyValues(@"mixed", @{
		@"Name": @"TEST_SETTING", @"Type": @"Enumeration",
		@"Values": @[@"one",
		    @{@"Value": @"two", @"DisplayName": @"Second"}],
	});
	ProbePropertyValues(@"missing-value", @{
		@"Name": @"TEST_SETTING", @"Type": @"Enumeration",
		@"Values": @[@{@"DisplayName": @"Missing"}],
	});
	ProbePropertyValues(@"empty-dictionary", @{
		@"Name": @"TEST_SETTING", @"Type": @"Enumeration",
		@"Values": @[@{}],
	});
	ProbePropertyValues(@"alias-keys", @{
		@"Name": @"TEST_SETTING", @"Type": @"Enumeration",
		@"Values": @[@{
			@"Value": @"one",
			@"Name": @"AliasName",
			@"LocalizedValue": @"AliasLocalized",
			@"CommandArgumentGenerationInfo": @"AliasCAGI",
		}],
	});
	return (0);
}

static NSString *
PropertyConditionText(id object)
{
	if (object == nil)
		return (@"<nil>");
	return ([object description]);
}

static void
ProbePropertyCondition(NSString *name, NSDictionary *dictionary)
{
	TSPropertyListDictionary *plist = [TSPropertyListDictionary
	    propertyListDictionaryWithDictionary:dictionary];
	XCPropertyDefinition *definition = [XCPropertyDefinition
	    propertyDefinitionFromPListDictionary:plist];
	id expression = [definition conditionExpression];
	NSMutableArray *flavorNames = [NSMutableArray array];

	for (id parameter in [definition conditionFlavors]) {
		NSString *flavor = [parameter valueForKey:@"name"];

		if (flavor != nil)
			[flavorNames addObject:flavor];
	}
	[flavorNames sortUsingSelector:@selector(compare:)];

	printf("== def %s ==\n", [name UTF8String]);
	printf("condition = %s\n", [PropertyConditionText(
	    [definition valueForUndefinedKey:@"Condition"]) UTF8String]);
	printf("expr = %s|%s\n",
	    [NSStringFromClass([expression class]) UTF8String],
	    [PropertyConditionText(expression) UTF8String]);
	printf("flavors = %s\n", ([flavorNames count] == 0)
	    ? "-" : [[flavorNames componentsJoinedByString:@","]
		UTF8String]);
	printf("enabled = %s\n",
	    [definition propertyIsEnabledWithMacroExpansionScope:nil]
	    ? "YES" : "NO");
}

static void
ProbePropertyConditionExpression(NSString *string)
{
	NSError *error = nil;
	id expression = [XCPropertyMacroExpression
	    propertyMacroExpressionFromString:string error:&error];

	printf("== expr <%s> ==\n", [string UTF8String]);
	printf("class = %s\n",
	    [NSStringFromClass([expression class]) UTF8String]);
	printf("desc = %s\n",
	    [PropertyConditionText(expression) UTF8String]);
	printf("error = %s\n",
	    [PropertyConditionText([error localizedDescription]) UTF8String]);
}

static int
cmdPropertyConditions(void)
{
	ProbePropertyCondition(@"none", @{});
	ProbePropertyCondition(@"condition-simple",
	    @{@"Condition": @"$(FOO) == YES"});
	ProbePropertyCondition(@"condition-empty", @{@"Condition": @""});
	ProbePropertyCondition(@"condition-space",
	    @{@"Condition": @"  $(FOO)  "});
	ProbePropertyCondition(@"condition-complex",
	    @{@"Condition": @"$(FOO) == YES && !$(BAR)"});
	ProbePropertyCondition(@"condition-flavors",
	    @{@"ConditionFlavors": @[@"arch", @"sdk"]});
	ProbePropertyCondition(@"option-condition-flavors",
	    @{@"OptionConditionFlavors": @[@"product"]});
	ProbePropertyCondition(@"condition-and-flavors", @{
		@"Condition": @"$(FOO)",
		@"ConditionFlavors": @[@"arch"],
		@"OptionConditionFlavors": @[@"product"],
	});
	ProbePropertyCondition(@"flavors-unknown",
	    @{@"ConditionFlavors": @[@"bogus", @"sdk"]});
	ProbePropertyCondition(@"flavors-empty", @{@"ConditionFlavors": @[]});

	ProbePropertyConditionExpression(@"YES");
	ProbePropertyConditionExpression(@"NO");
	ProbePropertyConditionExpression(@"\"YES\"");
	ProbePropertyConditionExpression(@"'YES'");
	ProbePropertyConditionExpression(@"$(FOO)");
	ProbePropertyConditionExpression(@"$(FOO) == YES");
	ProbePropertyConditionExpression(@"$(FOO) != YES");
	ProbePropertyConditionExpression(@"$(FOO) == 'YES'");
	ProbePropertyConditionExpression(@"$(FOO) = YES");
	ProbePropertyConditionExpression(@"!$(FOO)");
	ProbePropertyConditionExpression(@"! $(FOO)");
	ProbePropertyConditionExpression(@"$(FOO) && $(BAR)");
	ProbePropertyConditionExpression(@"$(FOO) || $(BAR)");
	ProbePropertyConditionExpression(@"$(FOO) xor $(BAR)");
	ProbePropertyConditionExpression(@"$(FOO) && !$(BAR)");
	ProbePropertyConditionExpression(@"( $(FOO) && $(BAR) ) || $(BAZ)");
	ProbePropertyConditionExpression(@"$(FOO) ? $(BAR) : $(BAZ)");
	ProbePropertyConditionExpression(@"$(FOO) contains bar");
	ProbePropertyConditionExpression(@"$(FOO) CONTAINS bar");
	ProbePropertyConditionExpression(@"$(FOO) == YES && $(BAR) != NO");
	ProbePropertyConditionExpression(@"  $(FOO)  ");
	ProbePropertyConditionExpression(@"");
	ProbePropertyConditionExpression(@"$(FOO) == YES $(BAR)");
	ProbePropertyConditionExpression(@"$(FOO) &&");
	ProbePropertyConditionExpression(@"( YES )");
	ProbePropertyConditionExpression(@"( $(FOO) == YES )");
	ProbePropertyConditionExpression(@"! ( $(FOO) == YES )");
	ProbePropertyConditionExpression(@"$(FOO) || $(BAR) && $(BAZ)");
	ProbePropertyConditionExpression(@"$(FOO) && $(BAR) == $(BAZ)");
	ProbePropertyConditionExpression(@"$(FOO) == $(BAR) == $(BAZ)");
	ProbePropertyConditionExpression(
	    @"$(FOO) ? $(BAR) : $(BAZ) && $(QUX)");
	ProbePropertyConditionExpression(
	    @"$(FOO) && $(BAR) ? $(BAZ) : $(QUX)");
	ProbePropertyConditionExpression(@"\"hello world\"");
	ProbePropertyConditionExpression(@"'hello world'");
	ProbePropertyConditionExpression(@"\"a\\\"b\"");
	ProbePropertyConditionExpression(@"$(FOO) == -Onone");
	ProbePropertyConditionExpression(@"$(FOO) != \"\"");
	ProbePropertyConditionExpression(@"$(FOO) && ( $(BAR) == YES )");
	return (0);
}

static NSString *
PropertySupportedSetText(NSSet *set)
{
	NSMutableArray *items = [NSMutableArray array];

	for (id item in set)
		[items addObject:PropertyConditionText(item)];
	[items sortUsingSelector:@selector(compare:)];
	if ([items count] == 0)
		return (@"-");
	return ([items componentsJoinedByString:@","]);
}

static void
ProbePropertySupported(NSString *name, NSDictionary *dictionary)
{
	NSMutableDictionary *full = [dictionary mutableCopy];
	TSPropertyListDictionary *plist;
	XCPropertyDefinition *definition;
	NSMutableArray *flavorNames = [NSMutableArray array];
	NSSet *architectures;

	[full setObject:@"TEST_SETTING" forKey:@"Name"];
	[full setObject:@"String" forKey:@"Type"];
	plist = [TSPropertyListDictionary
	    propertyListDictionaryWithDictionary:full];
	definition = [XCPropertyDefinition
	    propertyDefinitionFromPListDictionary:plist];
	architectures = [definition supportedArchitectures];
	for (id parameter in [definition conditionFlavors]) {
		NSString *flavor = [parameter valueForKey:@"name"];

		if (flavor != nil)
			[flavorNames addObject:flavor];
	}
	[flavorNames sortUsingSelector:@selector(compare:)];

	printf("== def %s ==\n", [name UTF8String]);
	printf("archs = %s\n", [PropertySupportedSetText(architectures)
	    UTF8String]);
	printf("filetypes = %s\n", [PropertySupportedSetText(
	    [definition supportedFileTypes]) UTF8String]);
	if ([dictionary objectForKey:@"Architectures"] == nil) {
		printf("supports-absent-arm64 = %s\n", [definition
		    supportsArchitecture:@"arm64" inDomain:nil
		    withMacroExpansionScope:nil] ? "YES" : "NO");
	} else {
		printf("supports-absent-arm64 = SKIP\n");
	}
	printf("flavors = %s\n", ([flavorNames count] == 0)
	    ? "-" : [[flavorNames componentsJoinedByString:@","]
		UTF8String]);
}

static int
cmdPropertySupported(void)
{
	ProbePropertySupported(@"none", @{});
	ProbePropertySupported(@"legacy-supportedarchs", @{
		@"SupportedArchs": @[@"arm64", @"x86_64"],
	});
	ProbePropertySupported(@"architectures", @{
		@"Architectures": @[@"x86_64", @"arm64"],
	});
	ProbePropertySupported(@"architectures-macro", @{
		@"Architectures": @[@"$(ARCHS)", @"arm64"],
	});
	ProbePropertySupported(@"architectures-empty",
	    @{@"Architectures": @[]});
	ProbePropertySupported(@"filetypes", @{
		@"FileTypes": @[@"wrapper.framework", @"sourcecode.c.objc"],
	});
	ProbePropertySupported(@"legacy-supportedfiletypes", @{
		@"SupportedFileTypes": @[@"sourcecode.c.objc"],
	});
	ProbePropertySupported(@"filetypes-macro", @{
		@"FileTypes": @[@"$(FILETYPE)", @"sourcecode.c.objc"],
	});
	ProbePropertySupported(@"flavors-arch", @{
		@"Architectures": @[@"arm64", @"x86_64"],
		@"ConditionFlavors": @[@"arch", @"sdk"],
	});
	return (0);
}

static void
PrintWrapperValue(const char *label, id value)
{
	printf("%s = <%s>\n", label,
	    (value != nil) ? [[value description] UTF8String] : "nil");
}

static void
PrintWrapperPList(const char *label, id value, NSUInteger level)
{
	NSMutableData *data = [NSMutableData data];

	[value _appendPListDescriptionToUTF8Data:data withIndentLevel:level];
	printf("%s.%lu = <%.*s>\n", label, (unsigned long)level,
	    (int)[data length], (const char *)[data bytes]);
}

static int
cmdPlistWrappers(void)
{
	NSString *plain = @"abc";
	NSString *spaced = @"a b";
	NSString *quoted = @"a\"b";
	NSString *unicode = @"αβ";
	PBXPlistArchiverAlwaysQuotedString *always =
	    [PBXPlistArchiverAlwaysQuotedString wrapString:spaced];
	PBXPlistArchiverAlwaysQuotedString *alwaysInit =
	    [[PBXPlistArchiverAlwaysQuotedString alloc] initWithString:spaced];

	PrintWrapperValue("always.class", NSStringFromClass([always class]));
	PrintWrapperValue("always.description", [always description]);
	PrintWrapperValue("always.string", [always description]);
	PrintWrapperValue("always.length", @([always length]));
	PrintWrapperValue("always.char0", @([always characterAtIndex:0]));
	PrintWrapperValue("always.equal.raw", @([always isEqual:spaced]));
	PrintWrapperValue("always.equal.init", @([always isEqual:alwaysInit]));
	PrintWrapperValue("always.equal.plain", @([always isEqual:plain]));
	PrintWrapperValue("always.hash.raw", @([always hash] == [spaced hash]));
	PrintWrapperValue("always.copy.class",
	    NSStringFromClass([[always copy] class]));
	PrintWrapperValue("always.init.description", [alwaysInit description]);
	PrintWrapperPList("always.plist", always, 0);
	PrintWrapperPList("always.plist", always, 2);
	PrintWrapperPList("always.plist.init", alwaysInit, 1);

	for (NSString *string in @[@"", plain, spaced, quoted, unicode,
	    @"line1\nline2", @"tab\there", @"back\\slash"]) {
		PBXPlistArchiverAlwaysQuotedString *wrapped =
		    [PBXPlistArchiverAlwaysQuotedString wrapString:string];

		printf("always.case = <%s> => ", [string UTF8String]);
		PrintWrapperPList("wrapped", wrapped, 0);
	}

	PBXPListArchiverStringWithComment *commented =
	    [[PBXPListArchiverStringWithComment alloc] initWithString:spaced
	    comment:@"note"];
	PBXPListArchiverStringWithComment *commentedOther =
	    [[PBXPListArchiverStringWithComment alloc] initWithString:spaced
	    comment:@"other"];
	PrintWrapperValue("comment.class", NSStringFromClass([commented class]));
	PrintWrapperValue("comment.description", [commented description]);
	PrintWrapperValue("comment.length", @([commented length]));
	PrintWrapperValue("comment.equal.raw", @([commented isEqual:spaced]));
	PrintWrapperValue("comment.equal.same", @([commented isEqual:commented]));
	PrintWrapperValue("comment.equal.comment",
	    @([commented isEqual:commentedOther]));
	PrintWrapperValue("comment.hash.raw",
	    @([commented hash] == [spaced hash]));
	PrintWrapperValue("comment.copy.class",
	    NSStringFromClass([[commented copy] class]));
	PrintWrapperPList("comment.plist", commented, 0);
	PrintWrapperPList("comment.plist", commented, 2);
	PrintWrapperPList("comment.plist.other", commentedOther, 0);

	for (NSString *string in @[@"", plain, spaced, quoted, unicode,
	    @"line1\nline2", @"tab\there", @"back\\slash"]) {
		PBXPListArchiverStringWithComment *wrapped =
		    [[PBXPListArchiverStringWithComment alloc]
		    initWithString:string comment:@"c"];

		printf("comment.case = <%s> => ", [string UTF8String]);
		PrintWrapperPList("wrapped", wrapped, 0);
	}

	for (NSString *string in @[@"A", @"ABC", @"a_b", @"a-b", @"a.b",
	    @"a/b", @"1abc", @"abc1", @"a$b", @"a:b", @"a+b", @"a@b",
	    @"a#b", @"A1", @"1", @"_", @"-", @".", @"YES", @"NO", @"nil",
	    @"NULL", @"a=b", @"a,b", @"a;b", @"a?b", @"a!b"]) {
		PBXPListArchiverStringWithComment *wrapped =
		    [[PBXPListArchiverStringWithComment alloc]
		    initWithString:string comment:@"c"];

		printf("comment.identifier = <%s> => ", [string UTF8String]);
		PrintWrapperPList("wrapped", wrapped, 0);
	}

	for (id comment in @[@"", @"multi word", @"line1\nline2",
	    @"note */ end", @"start /* here", @"(*), (*)/", [NSNull null]]) {
		NSString *actual = (comment == [NSNull null]) ? nil : comment;
		PBXPListArchiverStringWithComment *wrapped =
		    [[PBXPListArchiverStringWithComment alloc]
		    initWithString:plain comment:actual];

		printf("comment.comment = <%s> => ",
		    actual ? [actual UTF8String] : "(nil)");
		PrintWrapperPList("wrapped", wrapped, 0);
	}

	NSArray *rawArray = @[plain, spaced, @1, @[@"nested"]];
	PBXPlistArchiverSingleLineArray *array =
	    [PBXPlistArchiverSingleLineArray wrapArray:rawArray];
	PBXPlistArchiverSingleLineArray *arrayInit =
	    [[PBXPlistArchiverSingleLineArray alloc] initWithArray:rawArray];
	PrintWrapperValue("array.class", NSStringFromClass([array class]));
	PrintWrapperValue("array.description", [array description]);
	PrintWrapperValue("array.count", @([array count]));
	PrintWrapperValue("array.object0", [array objectAtIndex:0]);
	PrintWrapperValue("array.object1", [array objectAtIndex:1]);
	PrintWrapperValue("array.equal.raw", @([array isEqual:rawArray]));
	PrintWrapperValue("array.equal.init", @([array isEqual:arrayInit]));
	PrintWrapperValue("array.hash.raw",
	    @([array hash] == [rawArray hash]));
	PrintWrapperValue("array.copy.class",
	    NSStringFromClass([[array copy] class]));
	PrintWrapperPList("array.plist", array, 0);
	PrintWrapperPList("array.plist", array, 2);
	PrintWrapperPList("array.plist.init", arrayInit, 1);

	PrintWrapperPList("array.empty",
	    [PBXPlistArchiverSingleLineArray wrapArray:@[]], 0);
	PrintWrapperPList("array.one",
	    [PBXPlistArchiverSingleLineArray wrapArray:@[@"x"]], 0);
	PrintWrapperPList("array.commented", [PBXPlistArchiverSingleLineArray
	    wrapArray:@[[[PBXPListArchiverStringWithComment alloc]
	    initWithString:@"x" comment:@"c"], @1]], 0);
	return (0);
}

static void
DumpStringList(NSString *label, XCStringList *list)
{
	PrintNSStringValue([label stringByAppendingString:@".class"],
	    NSStringFromClass([list class]));
	PrintNSStringValue([label stringByAppendingString:@".count"],
	    @([list count]));
	PrintNSStringValue([label stringByAppendingString:@".array"],
	    [list arrayRepresentation]);
	PrintNSStringValue([label stringByAppendingString:@".string"],
	    [list stringRepresentation]);
	PrintNSStringValue([label stringByAppendingString:@".debug"],
	    [list stringRepresentationForDebugging]);
	PrintNSStringValue([label stringByAppendingString:@".description"],
	    [list description]);
}

static int
cmdStringList(void)
{
	XCStringList *empty = [XCStringList stringList];
	XCStringList *single = [XCStringList stringListWithString:@"alpha"];
	XCStringList *three = [[XCStringList alloc] initWithStringArray:
	    @[@"alpha", @"beta one", @"gamma"]];
	XCStringList *parsed = [XCStringList
	    stringListFromStringRepresentation:@"'alpha', \"beta one\", gamma"];

	DumpStringList(@"empty", empty);
	DumpStringList(@"single", single);
	DumpStringList(@"three", three);
	DumpStringList(@"parsed", parsed);

	NSUInteger count = [three count];
	const char *pointers[16] = {0};

	[three getUTF8StringPtrs:pointers];
	for (NSUInteger i = 0; i < count; i++)
		PrintNSStringValue([NSString stringWithFormat:@"ptr.%lu",
		    (unsigned long)i], [NSString stringWithUTF8String:
		    pointers[i]]);

	__block NSUInteger blockIndex = 0;
	[three enumerateUTF8StringsUsingBlock:^(const char *string) {
		PrintNSStringValue([NSString stringWithFormat:@"enum.%lu",
		    (unsigned long)blockIndex++],
		    [NSString stringWithUTF8String:string]);
	}];

	const char *representations[] = {
		"", "  ", "alpha beta", "alpha\\ beta",
		"'alpha', \"beta one\", gamma", "a\\b", "a\\\\b", NULL
	};
	NSString *labels[] = {
		@"parse.empty", @"parse.spaces", @"parse.plain", @"parse.escaped",
		@"parse.quoted", @"parse.backslash", @"parse.backslash2", nil
	};
	for (NSUInteger i = 0; labels[i] != nil; i++) {
		XCStringList *list = [XCStringList
		    stringListFromStringRepresentation:
		    [NSString stringWithUTF8String:representations[i]]];

		PrintNSStringValue([labels[i]
		    stringByAppendingString:@".array"],
		    [list arrayRepresentation]);
		PrintNSStringValue([labels[i]
		    stringByAppendingString:@".string"],
		    [list stringRepresentation]);
	}

	XCStringList *patterns = [[XCStringList alloc] initWithStringArray:
	    @[@"alpha", @"*.h", @"beta one", @"dir/file"]];
	const char *patternInputs[] = {
		"alpha", "ALPHA", " alpha", "alpha ", "xalpha",
		"alpha/beta", "/tmp/alpha", "*.h", "x.h", "/tmp/x.h",
		"beta one", "/tmp/beta one", "dir/file", "/tmp/dir/file",
		"file", "/tmp/file", NULL
	};
	NSString *patternLabels[] = {
		@"alpha", @"ALPHA", @"leadingSpace", @"trailingSpace", @"xalpha",
		@"alphaSlashBeta", @"tmpAlpha", @"starDotH", @"xDotH", @"tmpXDotH",
		@"betaOne", @"tmpBetaOne", @"dirFile", @"tmpDirFile",
		@"file", @"tmpFile", nil
	};
	for (NSUInteger i = 0; patternLabels[i] != nil; i++) {
		PrintNSStringValue([NSString stringWithFormat:
		    @"pattern.string.%@", patternLabels[i]],
		    @([patterns areStringPatternsMatchedByUTF8String:
		    patternInputs[i]]));
		PrintNSStringValue([NSString stringWithFormat:
		    @"pattern.filename.%@", patternLabels[i]],
		    @([patterns areFilenamePatternsMatchedByUTF8String:
		    patternInputs[i]]));
	}

	XCStringList *mutated = [XCStringList stringListWithString:@"a"];
	[mutated appendUTF8String:"b c"];
	[mutated appendUTF8String:"d" length:1];
	DumpStringList(@"append", mutated);

	XCStringList *appendList = [XCStringList stringListWithString:@"a"];
	[appendList appendStringList:three];
	DumpStringList(@"append.list", appendList);

	XCStringList *transferList = [XCStringList stringListWithString:@"a"];
	[transferList appendElementsByTransferringFromStringList:three];
	DumpStringList(@"transfer.list", transferList);

	XCStringList *prepended = [XCStringList stringListWithString:@"b"];
	[prepended prependUTF8String:"a"];
	DumpStringList(@"prepend", prepended);

	XCStringList *removed = [[XCStringList alloc] initWithStringArray:
	    @[@"a", @"b", @"a"]];
	[removed removeUTF8String:"a" length:1];
	DumpStringList(@"remove", removed);

	XCStringList *replaced = [[XCStringList alloc] initWithStringArray:
	    @[@"abc", @"xabc", @"abc"]];
	[replaced replaceUTF8String:"abc" length:3
	    withUTF8String:"Z" length:1];
	DumpStringList(@"replace", replaced);

	XCStringList *copy = [three copy];
	PrintNSStringValue(@"equal.same", @([three isEqual:three]));
	PrintNSStringValue(@"equal.copy", @([three isEqual:copy]));
	PrintNSStringValue(@"equal.short", @([three isEqual:single]));
	PrintNSStringValue(@"equal.nonList", @([three isEqual:
	    [three arrayRepresentation]]));
	PrintNSStringValue(@"hash.copy", @([three hash] == [copy hash]));
	PrintNSStringValue(@"hash.short", @([three hash] == [single hash]));
	return (0);
}

static void
PrintObjectGraphPath(NSString *label, XCObjectGraphPath *path)
{
	NSUInteger count = [path segmentCount];

	PrintNSStringValue([label stringByAppendingString:@".class"],
	    NSStringFromClass([path class]));
	PrintNSStringValue([label stringByAppendingString:@".count"], @(count));
	PrintNSStringValue([label stringByAppendingString:@".string"],
	    [path stringRepresentation]);
	PrintNSStringValue([label stringByAppendingString:@".gids"],
	    [path pathSegmentGIDs]);
	PrintNSStringValue([label stringByAppendingString:@".names"],
	    [path pathSegmentNames]);
	for (NSUInteger i = 0; i < count; i++) {
		PrintNSStringValue([NSString stringWithFormat:@"%@.name.%lu",
		    label, (unsigned long)i], [path segmentNameAtIndex:i]);
	}
}

static int
cmdObjectGraphPath(void)
{
	XCObjectGraphPath *empty = [[XCObjectGraphPath alloc] init];
	XCObjectGraphPath *one = [[XCObjectGraphPath alloc]
	    initWithSegmentGIDs:@[@"G1"] names:@[@"Alpha"]];
	XCObjectGraphPath *three = [[XCObjectGraphPath alloc]
	    initWithSegmentGIDs:@[@"G1", @"G2", @"G3"]
	    names:@[@"Alpha", @"Beta", @"Gamma"]];
	XCObjectGraphPath *equal = [[XCObjectGraphPath alloc]
	    initWithSegmentGIDs:@[@"G1", @"G2", @"G3"]
	    names:@[@"Alpha", @"Beta", @"Gamma"]];
	XCObjectGraphPath *differentGIDs = [[XCObjectGraphPath alloc]
	    initWithSegmentGIDs:@[@"X1", @"X2", @"X3"]
	    names:@[@"Alpha", @"Beta", @"Gamma"]];
	XCObjectGraphPath *differentNames = [[XCObjectGraphPath alloc]
	    initWithSegmentGIDs:@[@"G1", @"G2", @"G3"]
	    names:@[@"A", @"B", @"C"]];

	PrintObjectGraphPath(@"empty", empty);
	PrintObjectGraphPath(@"one", one);
	PrintObjectGraphPath(@"three", three);
	PrintObjectGraphPath(@"empty.add", [empty
	    pathByAddingSegmentWithGID:@"G9" name:@"Nine"]);
	PrintObjectGraphPath(@"three.add", [three
	    pathByAddingSegmentWithGID:@"G4" name:@"Delta"]);
	PrintNSStringValue(@"three.copy.equal", @([[three copy] isEqual:three]));
	PrintNSStringValue(@"three.equal.equal", @([three isEqual:equal]));
	PrintNSStringValue(@"three.equal.gids", @([three isEqual:differentGIDs]));
	PrintNSStringValue(@"three.equal.names", @([three isEqual:differentNames]));
	PrintNSStringValue(@"one.three.equal", @([one isEqual:three]));
	PrintNSStringValue(@"three.equal.hash", @([three hash] == [equal hash]));
	return (0);
}

static void
PrintBOMState(NSString *label, NSData *data, NSString *path)
{
	PrintNSStringValue([label stringByAppendingString:@".unicode"],
	    @([NSString isFileUnicode:path fileData:data]));
	PrintNSStringValue([label stringByAppendingString:@".utf8"],
	    @([NSString isFileUTF8WithBOM:path fileData:data]));
}

static NSString *
WriteBOMFixtureFile(NSString *name, NSData *data)
{
	NSString *path = [[NSTemporaryDirectory() stringByAppendingPathComponent:
	    @"xcode3core-bom-oracle"]
	    stringByAppendingPathComponent:name];

	[[NSFileManager defaultManager] createDirectoryAtPath:
	    [path stringByDeletingLastPathComponent]
	    withIntermediateDirectories:YES attributes:nil error:NULL];
	[data writeToFile:path atomically:YES];
	return (path);
}

static int
cmdTSStringBOM(void)
{
	NSData *empty = [NSData data];
	NSData *fe = [NSData dataWithBytes:"\xFE" length:1];
	NSData *ff = [NSData dataWithBytes:"\xFF" length:1];
	NSData *ef = [NSData dataWithBytes:"\xEF" length:1];
	NSData *feff = [NSData dataWithBytes:"\xFE\xFF" length:2];
	NSData *fffe = [NSData dataWithBytes:"\xFF\xFE" length:2];
	NSData *fefe = [NSData dataWithBytes:"\xFE\xFE" length:2];
	NSData *ffff = [NSData dataWithBytes:"\xFF\xFF" length:2];
	NSData *efbb = [NSData dataWithBytes:"\xEF\xBB" length:2];
	NSData *efbbbf = [NSData dataWithBytes:"\xEF\xBB\xBF" length:3];
	NSData *efbbbe = [NSData dataWithBytes:"\xEF\xBB\xBE" length:3];
	NSData *feff00 = [NSData dataWithBytes:"\xFE\xFF\x00" length:3];
	NSData *fffe00 = [NSData dataWithBytes:"\xFF\xFE\x00" length:3];
	NSData *efbbbf41 = [NSData dataWithBytes:"\xEF\xBB\xBF\x41" length:4];
	NSData *plain = [@"ABC" dataUsingEncoding:NSUTF8StringEncoding];
	NSData *utf32be = [NSData dataWithBytes:"\x00\x00\xFE\xFF" length:4];
	NSData *utf32le = [NSData dataWithBytes:"\xFF\xFE\x00\x00" length:4];
	NSString *dir = NSTemporaryDirectory();
	NSString *utf16Path = WriteBOMFixtureFile(@"utf16", feff);
	NSString *utf8Path = WriteBOMFixtureFile(@"utf8", efbbbf);
	NSString *plainPath = WriteBOMFixtureFile(@"plain", plain);
	NSString *emptyPath = WriteBOMFixtureFile(@"empty", empty);
	NSString *missing = [dir stringByAppendingPathComponent:
	    @"xcode3core-bom-oracle-missing"];

	PrintBOMState(@"data.empty", empty, nil);
	PrintBOMState(@"data.fe", fe, nil);
	PrintBOMState(@"data.ff", ff, nil);
	PrintBOMState(@"data.ef", ef, nil);
	PrintBOMState(@"data.feff", feff, nil);
	PrintBOMState(@"data.fffe", fffe, nil);
	PrintBOMState(@"data.fefe", fefe, nil);
	PrintBOMState(@"data.ffff", ffff, nil);
	PrintBOMState(@"data.efbb", efbb, nil);
	PrintBOMState(@"data.efbbbf", efbbbf, nil);
	PrintBOMState(@"data.efbbbe", efbbbe, nil);
	PrintBOMState(@"data.feff00", feff00, nil);
	PrintBOMState(@"data.fffe00", fffe00, nil);
	PrintBOMState(@"data.efbbbf41", efbbbf41, nil);
	PrintBOMState(@"data.plain", plain, nil);
	PrintBOMState(@"data.utf32be", utf32be, nil);
	PrintBOMState(@"data.utf32le", utf32le, nil);

	PrintBOMState(@"path.utf16", nil, utf16Path);
	PrintBOMState(@"path.utf8", nil, utf8Path);
	PrintBOMState(@"path.plain", nil, plainPath);
	PrintBOMState(@"path.empty", nil, emptyPath);
	PrintBOMState(@"path.missing", nil, missing);
	PrintBOMState(@"path.directory", nil, dir);
	PrintBOMState(@"path.nil", nil, nil);
	PrintBOMState(@"data.overrides.path", efbbbf, utf16Path);

	[[NSFileManager defaultManager] removeItemAtPath:
	    [dir stringByAppendingPathComponent:@"xcode3core-bom-oracle"]
	    error:NULL];
	return (0);
}

static void
TSRegexPrintBool(NSString *label, BOOL value)
{
	printf("%s = <%d>\n", [label UTF8String], value ? 1 : 0);
}

static void
TSRegexPrintString(NSString *label, id value)
{
	printf("%s = <%s>\n", [label UTF8String],
	    (value != nil) ? [value UTF8String] : "nil");
}

static void
TSRegexPrintRange(NSString *label, NSRange range)
{
	printf("%s = <%lu,%lu>\n", [label UTF8String],
	    (unsigned long)range.location, (unsigned long)range.length);
}

static int
cmdTSRegularExpression(void)
{
	TSRegularExpression *plain;
	TSRegularExpression *ignoreCase;
	TSRegularExpression *groups;
	TSRegularExpression *copied;
	TSRegularExpression *empty;
	TSRegularExpression *uninitialized;
	NSString *text = @"xxabcxx";
	NSString *upperText = @"xxABCxx";
	NSString *groupText = @"item-42";
	NSRange range;

	plain = [[TSRegularExpression alloc] initWithExpressionString:@"abc"];
	ignoreCase = [[TSRegularExpression alloc]
	    initWithExpressionString:@"abc" ignoreCase:YES];
	groups = [[TSRegularExpression alloc]
	    initWithExpressionString:@"([a-z]+)-([0-9]+)"];
	copied = [plain copy];
	empty = [[TSRegularExpression alloc] initWithExpressionString:nil];
	uninitialized = [[TSRegularExpression alloc] init];

	TSRegexPrintString(@"ctor.plain.class", NSStringFromClass([plain class]));
	TSRegexPrintString(@"ctor.plain.expr", [plain expressionString]);
	TSRegexPrintString(@"ctor.groups.class", NSStringFromClass([groups class]));
	TSRegexPrintString(@"ctor.groups.expr", [groups expressionString]);
	TSRegexPrintString(@"ctor.nil.class",
	    (empty != nil) ? NSStringFromClass([empty class]) : nil);
	TSRegexPrintString(@"ctor.init.class",
	    (uninitialized != nil) ? NSStringFromClass([uninitialized class]) : nil);

	TSRegexPrintBool(@"match.plain", [plain matchesString:text]);
	TSRegexPrintBool(@"match.plain.upper", [plain matchesString:upperText]);
	TSRegexPrintBool(@"match.ignoreCase.upper", [ignoreCase matchesString:upperText]);
	TSRegexPrintBool(@"match.groups", [groups matchesString:groupText]);
	TSRegexPrintBool(@"match.nil", [plain matchesString:nil]);

	range = [plain rangeForSubexpressionAtIndex:0 inString:text];
	TSRegexPrintRange(@"range.plain.full", range);
	range = [plain rangeForSubexpressionAtIndex:0 inString:upperText];
	TSRegexPrintRange(@"range.plain.upper", range);
	range = [groups rangeForSubexpressionAtIndex:0 inString:groupText];
	TSRegexPrintRange(@"range.groups.full", range);
	range = [groups rangeForSubexpressionAtIndex:1 inString:groupText];
	TSRegexPrintRange(@"range.groups.one", range);
	range = [groups rangeForSubexpressionAtIndex:2 inString:groupText];
	TSRegexPrintRange(@"range.groups.two", range);
	range = [groups rangeForSubexpressionAtIndex:3 inString:groupText];
	TSRegexPrintRange(@"range.groups.out", range);
	range = [plain rangeForSubexpressionAtIndex:0 inString:nil];
	TSRegexPrintRange(@"range.nil", range);

	TSRegexPrintString(@"sub.groups.full",
	    [groups substringForSubexpressionAtIndex:0 inString:groupText]);
	TSRegexPrintString(@"sub.groups.one",
	    [groups substringForSubexpressionAtIndex:1 inString:groupText]);
	TSRegexPrintString(@"sub.groups.two",
	    [groups substringForSubexpressionAtIndex:2 inString:groupText]);
	TSRegexPrintString(@"sub.groups.out",
	    [groups substringForSubexpressionAtIndex:3 inString:groupText]);
	TSRegexPrintString(@"sub.nil",
	    [plain substringForSubexpressionAtIndex:0 inString:nil]);

	TSRegexPrintBool(@"equal.same", [plain isEqual:plain]);
	TSRegexPrintBool(@"equal.copy", [plain isEqual:copied]);
	TSRegexPrintBool(@"equal.ignoreCase", [plain isEqual:ignoreCase]);
	TSRegexPrintBool(@"equal.other", [plain isEqual:groups]);
	TSRegexPrintBool(@"equal.string", [plain isEqual:@"abc"]);
	TSRegexPrintBool(@"equal.nil", [plain isEqual:nil]);
	TSRegexPrintBool(@"hash.copy", [plain hash] == [copied hash]);
	TSRegexPrintBool(@"hash.ignoreCase", [plain hash] == [ignoreCase hash]);
	TSRegexPrintBool(@"hash.other", [plain hash] != [groups hash]);

	TSRegexPrintString(@"copy.class", NSStringFromClass([copied class]));
	TSRegexPrintBool(@"copy.identity", copied == plain);
	TSRegexPrintString(@"copy.expr", [copied expressionString]);
	TSRegexPrintBool(@"responds.encode",
	    [plain respondsToSelector:@selector(encodeWithCoder:)]);
	TSRegexPrintBool(@"responds.decode",
	    [plain respondsToSelector:@selector(initWithCoder:)]);
	return (0);
}

static void
TSFMPrintBool(NSString *label, BOOL value)
{
	printf("%s = <%d>\n", [label UTF8String], value ? 1 : 0);
}

static void
TSFMPrintString(NSString *label, id value)
{
	printf("%s = <%s>\n", [label UTF8String],
	    (value != nil) ? [value UTF8String] : "nil");
}

static void
TSFMPrintMode(NSString *label, NSUInteger value)
{
	printf("%s = <%lu>\n", [label UTF8String], (unsigned long)value);
}

static NSUInteger
TSFMModeAtPath(NSString *path)
{
	NSDictionary *attributes = [[NSFileManager defaultManager]
	    attributesOfItemAtPath:path error:NULL];
	return ([[attributes objectForKey:NSFilePosixPermissions] unsignedIntegerValue]);
}

static int
cmdTSFileManager(void)
{
	@autoreleasepool {
		NSFileManager *fm = [NSFileManager defaultManager];
		TSFileManager *mgr = [TSFileManager defaultManager];
		NSString *unique = [[NSProcessInfo processInfo] globallyUniqueString];
		NSString *root = [[NSTemporaryDirectory()
		    stringByAppendingPathComponent:@"tsfm-oracle"]
		    stringByAppendingPathComponent:unique];
		NSString *dir = [root stringByAppendingPathComponent:@"dir"];
		NSString *file = [root stringByAppendingPathComponent:@"file.txt"];
		NSString *copy1 = [root stringByAppendingPathComponent:@"copy1.txt"];
		NSString *copy2 = [root stringByAppendingPathComponent:@"copy2.txt"];
		NSString *moved = [root stringByAppendingPathComponent:@"moved.txt"];
		NSString *moved2 = [root stringByAppendingPathComponent:@"moved2.txt"];
		NSString *link = [root stringByAppendingPathComponent:@"link.txt"];
		NSString *symlink = [root stringByAppendingPathComponent:@"symlink"];
		NSString *permSrc = [root stringByAppendingPathComponent:@"permsrc"];
		NSString *permDst = [root stringByAppendingPathComponent:@"permdst"];
		NSString *missing = [root stringByAppendingPathComponent:@"missing"];
		NSError *error = nil;
		BOOL ok;

		[fm createDirectoryAtPath:root withIntermediateDirectories:YES
		    attributes:nil error:NULL];

		TSFMPrintString(@"default.class", NSStringFromClass([mgr class]));
		TSFMPrintBool(@"default.singleton", mgr == [TSFileManager defaultManager]);
		TSFMPrintBool(@"default.nsfm", [mgr isEqual:fm]);

		TSFMPrintBool(@"dir.create", [mgr createDirectoryAtPath:dir
		    withIntermediateDirectories:YES attributes:nil error:&error]);
		TSFMPrintBool(@"dir.create.error", error == nil);
		TSFMPrintBool(@"dir.is.traverse", [mgr isDirectoryAtPath:dir traverseLink:YES]);
		TSFMPrintBool(@"dir.is.notraverse", [mgr isDirectoryAtPath:dir traverseLink:NO]);
		TSFMPrintBool(@"dir.is.missing", [mgr isDirectoryAtPath:missing traverseLink:YES]);
		TSFMPrintBool(@"dir.is.nil", [mgr isDirectoryAtPath:nil traverseLink:YES]);
		TSFMPrintBool(@"dir.legacy.create", [mgr createDirectoryAtPath:
		    [root stringByAppendingPathComponent:@"legacy"] attributes:nil]);
		TSFMPrintBool(@"dir.recurse.create", [mgr createDirectoryAtPath:
		    [root stringByAppendingPathComponent:@"recurse/a/b"]
		    attributes:nil recurse:YES]);

		TSFMPrintBool(@"file.create", [mgr createFileAtPath:file
		    contents:[@"hello" dataUsingEncoding:NSUTF8StringEncoding]
		    attributes:nil]);
		TSFMPrintBool(@"file.exists", [fm fileExistsAtPath:file]);
		TSFMPrintBool(@"file.isdir", [mgr isDirectoryAtPath:file traverseLink:YES]);
		TSFMPrintString(@"file.contents", [NSString stringWithContentsOfFile:file
		    encoding:NSUTF8StringEncoding error:NULL]);

		TSFMPrintMode(@"chmod.755", [mgr posixPermissionsByApplyingChmodString:@"755" to:0644]);
		TSFMPrintMode(@"chmod.addx", [mgr posixPermissionsByApplyingChmodString:@"+x" to:0644]);
		TSFMPrintMode(@"chmod.addx.user", [mgr posixPermissionsByApplyingChmodString:@"+x" to:0600]);
		TSFMPrintMode(@"chmod.uw", [mgr posixPermissionsByApplyingChmodString:@"u+w" to:0444]);
		TSFMPrintMode(@"chmod.ar", [mgr posixPermissionsByApplyingChmodString:@"a+r" to:0600]);
		TSFMPrintMode(@"chmod.ow", [mgr posixPermissionsByApplyingChmodString:@"o+w" to:0444]);
		TSFMPrintMode(@"chmod.gow", [mgr posixPermissionsByApplyingChmodString:@"go-w" to:0777]);
		TSFMPrintMode(@"chmod.multi", [mgr posixPermissionsByApplyingChmodString:@"u+x,g-w" to:0644]);
		TSFMPrintMode(@"chmod.equal", [mgr posixPermissionsByApplyingChmodString:@"=r" to:0777]);
		TSFMPrintMode(@"chmod.bare.w", [mgr posixPermissionsByApplyingChmodString:@"+w" to:0]);
		TSFMPrintMode(@"chmod.bare.rw", [mgr posixPermissionsByApplyingChmodString:@"+rw" to:0]);
		TSFMPrintMode(@"chmod.bare.minusw", [mgr posixPermissionsByApplyingChmodString:@"-w" to:0666]);
		TSFMPrintMode(@"chmod.bare.equalw", [mgr posixPermissionsByApplyingChmodString:@"=w" to:0777]);
		TSFMPrintMode(@"chmod.explicit.aw", [mgr posixPermissionsByApplyingChmodString:@"a+w" to:0]);
		TSFMPrintMode(@"chmod.X.noexec", [mgr posixPermissionsByApplyingChmodString:@"+X" to:0600]);
		TSFMPrintMode(@"chmod.X.exec", [mgr posixPermissionsByApplyingChmodString:@"+X" to:0700]);
		TSFMPrintMode(@"chmod.X.equal", [mgr posixPermissionsByApplyingChmodString:@"=X" to:0777]);

		TSFMPrintBool(@"setattrs", [mgr setAttributes:
		    [NSDictionary dictionaryWithObject:
		    [NSNumber numberWithUnsignedInteger:0755]
		    forKey:NSFilePosixPermissions] ofItemAtPath:file error:&error]);
		TSFMPrintBool(@"setattrs.error", error == nil);
		TSFMPrintMode(@"setattrs.mode", TSFMModeAtPath(file));
		TSFMPrintBool(@"changeattrs", [mgr changeFileAttributes:
		    [NSDictionary dictionaryWithObject:
		    [NSNumber numberWithUnsignedInteger:0640]
		    forKey:NSFilePosixPermissions] atPath:file]);
		TSFMPrintMode(@"changeattrs.mode", TSFMModeAtPath(file));

		TSFMPrintBool(@"copy.item", [mgr copyItemAtPath:file toPath:copy1 error:&error]);
		TSFMPrintBool(@"copy.item.error", error == nil);
		TSFMPrintBool(@"copy.item.exists", [fm fileExistsAtPath:copy1]);
		TSFMPrintBool(@"copy.path", [mgr copyPath:file toPath:copy2 handler:nil]);
		TSFMPrintBool(@"copy.path.exists", [fm fileExistsAtPath:copy2]);

		TSFMPrintBool(@"move.item", [mgr moveItemAtPath:copy1 toPath:moved error:&error]);
		TSFMPrintBool(@"move.item.error", error == nil);
		TSFMPrintBool(@"move.item.source", [fm fileExistsAtPath:copy1]);
		TSFMPrintBool(@"move.item.dest", [fm fileExistsAtPath:moved]);
		TSFMPrintBool(@"move.path", [mgr movePath:copy2 toPath:moved2 handler:nil]);
		TSFMPrintBool(@"move.path.source", [fm fileExistsAtPath:copy2]);
		TSFMPrintBool(@"move.path.dest", [fm fileExistsAtPath:moved2]);

		TSFMPrintBool(@"link.item", [mgr linkItemAtPath:file toPath:link error:&error]);
		TSFMPrintBool(@"link.item.error", error == nil);
		TSFMPrintBool(@"link.exists", [fm fileExistsAtPath:link]);
		TSFMPrintBool(@"symlink.create", [mgr createSymbolicLinkAtPath:symlink
		    withDestinationPath:dir error:&error]);
		TSFMPrintBool(@"symlink.is.traverse", [mgr isDirectoryAtPath:symlink traverseLink:YES]);
		TSFMPrintBool(@"symlink.is.notraverse", [mgr isDirectoryAtPath:symlink traverseLink:NO]);

		TSFMPrintBool(@"permsrc.create", [mgr createFileAtPath:permSrc contents:nil attributes:nil]);
		TSFMPrintBool(@"permdst.create", [mgr createFileAtPath:permDst contents:nil attributes:nil]);
		TSFMPrintBool(@"permsrc.set", [mgr setAttributes:
		    [NSDictionary dictionaryWithObject:
		    [NSNumber numberWithUnsignedInteger:0701]
		    forKey:NSFilePosixPermissions] ofItemAtPath:permSrc error:NULL]);
		TSFMPrintBool(@"permdst.set", [mgr setAttributes:
		    [NSDictionary dictionaryWithObject:
		    [NSNumber numberWithUnsignedInteger:0644]
		    forKey:NSFilePosixPermissions] ofItemAtPath:permDst error:NULL]);
		TSFMPrintBool(@"copy.permissions", [mgr copyPermissionsFromPath:permSrc toPath:permDst]);
		TSFMPrintMode(@"copy.permissions.mode", TSFMModeAtPath(permDst));
		TSFMPrintBool(@"permdst.reset", [mgr setAttributes:
		    [NSDictionary dictionaryWithObject:
		    [NSNumber numberWithUnsignedInteger:0644]
		    forKey:NSFilePosixPermissions] ofItemAtPath:permDst error:NULL]);
		TSFMPrintBool(@"copy.ownerpermissions", [mgr copyOwnerGroupAndPermissionsFromPath:permSrc
		    toPath:permDst]);
		TSFMPrintMode(@"copy.ownerpermissions.mode", TSFMModeAtPath(permDst));
		TSFMPrintBool(@"copy.findinfo", [mgr copyFinderInfoFromPath:file toPath:permDst]);
		TSFMPrintBool(@"copy.resourcefork", [mgr copyResourceForkFromPath:file toPath:permDst]);

		TSFMPrintBool(@"remove.item", [mgr removeItemAtPath:moved error:&error]);
		TSFMPrintBool(@"remove.item.error", error == nil);
		TSFMPrintBool(@"remove.item.exists", [fm fileExistsAtPath:moved]);
		TSFMPrintBool(@"remove.file", [mgr removeFileAtPath:moved2 handler:nil]);
		TSFMPrintBool(@"remove.file.exists", [fm fileExistsAtPath:moved2]);
		TSFMPrintBool(@"remove.nil", [mgr removeItemAtPath:nil error:&error]);

		ok = [fm removeItemAtPath:root error:NULL];
		TSFMPrintBool(@"cleanup", ok);
	}
	return (0);
}

static void
TSTTPrintString(const char *label, NSString *value)
{
	printf("%s = <%s>\n", label,
	    (value != nil) ? [value UTF8String] : "nil");
}

static void
TSTTPrintBool(const char *label, BOOL value)
{
	printf("%s = <%s>\n", label, value ? "YES" : "NO");
}

static void
TSTTPrintInt(const char *label, int value)
{
	printf("%s = <%d>\n", label, value);
}

static void
TSTTPrintCount(const char *label, NSUInteger value)
{
	printf("%s = <%lu>\n", label, (unsigned long)value);
}

static void
TSTTPrintDouble(const char *label, double value)
{
	printf("%s = <%.2f>\n", label, value);
}

static int
TSTTTraceFileDescriptor(NSString *path)
{
	return (open([path fileSystemRepresentation],
	    O_WRONLY | O_CREAT | O_TRUNC, 0600));
}

static void
TSTTPrintTraceFile(NSString *path)
{
	NSData *data = [NSData dataWithContentsOfFile:path];

	if (data != nil)
		fwrite([data bytes], 1, [data length], stdout);
}

static int
cmdTSTimedTrace(void)
{
	@autoreleasepool {
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSString *temp = [NSTemporaryDirectory()
		    stringByAppendingPathComponent:[[NSProcessInfo processInfo]
		    globallyUniqueString]];
		NSSet *enabled;
		NSDictionary *objects;
		TSTimedTrace *trace;
		TSTimedTrace *gamma;
		TSTimedTraceSubtrace *subtrace;
		int fd;

		[defaults registerDefaults:[NSDictionary
		    dictionaryWithObject:[NSArray arrayWithObjects:
		    @"alpha", @"beta", nil]
		    forKey:@"TSEnabledTimedTraces"]];
		enabled = [TSTimedTrace _enabledTraceNames];
		objects = [TSTimedTrace _namesToTraceObjectsDictionary];
		TSTTPrintCount("enabled.count", [enabled count]);
		TSTTPrintBool("enabled.alpha", [enabled containsObject:@"alpha"]);
		TSTTPrintBool("enabled.beta", [enabled containsObject:@"beta"]);
		TSTTPrintBool("enabled.gamma", [enabled containsObject:@"gamma"]);
		TSTTPrintCount("objects.count.before", [objects count]);
		TSTTPrintBool("should.alpha",
		    [TSTimedTrace shouldCreateTimedTraceWithName:@"alpha"]);
		TSTTPrintBool("should.gamma",
		    [TSTimedTrace shouldCreateTimedTraceWithName:@"gamma"]);
		gamma = [TSTimedTrace timedTraceWithName:@"gamma"];
		TSTTPrintString("gamma.class", NSStringFromClass([gamma class]));
		trace = [TSTimedTrace timedTraceWithName:@"alpha"];
		TSTTPrintString("alpha.class", NSStringFromClass([trace class]));
		TSTTPrintBool("alpha.cached",
		    trace == [TSTimedTrace timedTraceWithName:@"alpha"]);
		TSTTPrintCount("objects.count.after", [objects count]);
		TSTTPrintInt("alpha.fd", [trace outputFileDescriptor]);
		TSTTPrintCount("alpha.level", [trace currentSubtraceLevel]);
		TSTTPrintString("alpha.top.class",
		    NSStringFromClass([[trace toplevelSubtrace] class]));
		TSTTPrintString("alpha.current.class",
		    NSStringFromClass([[trace currentSubtrace] class]));

		subtrace = [[TSTimedTraceSubtrace alloc]
		    initWithStartTime:10.0 userDescription:@"root"];
		TSTTPrintDouble("sub.start", [subtrace startTime]);
		TSTTPrintDouble("sub.last", [subtrace lastMarkTime]);
		TSTTPrintDouble("sub.average", [subtrace averageTimeBetweenMarks]);
		TSTTPrintString("sub.description", [subtrace userDescription]);
		[subtrace setLastMarkTime:14.0];
		TSTTPrintDouble("sub.last.mark", [subtrace lastMarkTime]);
		TSTTPrintDouble("sub.average.mark",
		    [subtrace averageTimeBetweenMarks]);
		[subtrace setStartTime:20.0];
		TSTTPrintDouble("sub.start.reset", [subtrace startTime]);
		TSTTPrintDouble("sub.average.reset",
		    [subtrace averageTimeBetweenMarks]);

		fd = TSTTTraceFileDescriptor(temp);
		[trace setOutputFileDescriptor:fd closeWhenDone:NO];
		[trace _emitLineWithCurrentTime:1.0
		    timeIntoTrace:2.0 timeIntoSubtrace:3.0
		    timeSinceLastMark:-1.0 averageTimeBetweenMarks:-1.0
		    typeTokenString:@"<< " userDescription:@"three"];
		[trace _emitLineWithCurrentTime:1.0
		    timeIntoTrace:2.0 timeIntoSubtrace:3.0
		    timeSinceLastMark:4.0 averageTimeBetweenMarks:-1.0
		    typeTokenString:@" | " userDescription:@"four"];
		[trace _emitLineWithCurrentTime:1.0
		    timeIntoTrace:2.0 timeIntoSubtrace:3.0
		    timeSinceLastMark:4.0 averageTimeBetweenMarks:5.0
		    typeTokenString:@">> " userDescription:@"five"];
		close(fd);
		TSTTPrintTraceFile(temp);

		fd = TSTTTraceFileDescriptor(temp);
		[trace setOutputFileDescriptor:fd closeWhenDone:NO];
		[trace beginSubtraceWithDescription:@"outer"];
		[trace beginSubtraceWithDescription:@"inner"];
		TSTTPrintCount("alpha.level.nested", [trace currentSubtraceLevel]);
		close(fd);
		fd = TSTTTraceFileDescriptor(temp);
		[trace setOutputFileDescriptor:fd closeWhenDone:NO];
		[trace _emitLineWithCurrentTime:1.0
		    timeIntoTrace:2.0 timeIntoSubtrace:3.0
		    timeSinceLastMark:4.0 averageTimeBetweenMarks:5.0
		    typeTokenString:@">> " userDescription:@"nested"];
		close(fd);
		TSTTPrintTraceFile(temp);

		fd = TSTTTraceFileDescriptor(temp);
		[trace setOutputFileDescriptor:fd closeWhenDone:NO];
		[trace endSubtraceWithDescription:@"inner"];
		[trace endSubtraceWithDescription:@"outer"];
		TSTTPrintCount("alpha.level.after", [trace currentSubtraceLevel]);
		close(fd);
		fd = TSTTTraceFileDescriptor(temp);
		[trace setOutputFileDescriptor:fd closeWhenDone:NO];
		[trace endSubtraceWithDescription:@"overflow"];
		close(fd);
		TSTTPrintTraceFile(temp);
		[[NSFileManager defaultManager] removeItemAtPath:temp error:NULL];
	}
	return (0);
}

static const char *
TSPLHKind(id object)
{
	if (object == nil)
		return ("nil");
	if ([object isKindOfClass:[NSString class]])
		return ("NSString");
	if ([object isKindOfClass:[NSNumber class]])
		return ("NSNumber");
	if ([object isKindOfClass:[NSData class]])
		return ("NSData");
	if ([object isKindOfClass:[NSArray class]])
		return ("NSArray");
	if ([object isKindOfClass:[NSDictionary class]])
		return ("NSDictionary");
	return ("other");
}

static void
TSPLHPrintValue(const char *label, id object)
{
	if ([object isKindOfClass:[NSString class]]) {
		printf("%s = <string:%s>\n", label, [object UTF8String]);
	} else if ([object isKindOfClass:[NSNumber class]]) {
		printf("%s = <number:%s>\n", label,
		    [[object stringValue] UTF8String]);
	} else if ([object isKindOfClass:[NSData class]]) {
		printf("%s = <data:%lu>\n", label,
		    (unsigned long)[(NSData *)object length]);
	} else if ([object isKindOfClass:[NSArray class]]) {
		printf("%s = <array:%lu>\n", label,
		    (unsigned long)[(NSArray *)object count]);
	} else if ([object isKindOfClass:[NSDictionary class]]) {
		printf("%s = <dictionary:%lu>\n", label,
		    (unsigned long)[(NSDictionary *)object count]);
	} else {
		printf("%s = <%s>\n", label, TSPLHKind(object));
	}
}

static void
TSPLHTry(const char *label, void (^block)(void))
{
	@try {
		block();
		printf("%s = <ok>\n", label);
	} @catch (NSException *exception) {
		printf("%s.exception = <%s: %s>\n", label,
		    [[exception name] UTF8String],
		    [[exception reason] UTF8String]);
	}
}

static NSString *
XCSFPPClean(NSString *value, NSString *root)
{
	if (value == nil)
		return (nil);
	return ([value stringByReplacingOccurrencesOfString:root
	    withString:@"<TMP>"]);
}

static NSString *
XCSFPPVisible(NSString *value)
{
	NSString *result = value;

	result = [result stringByReplacingOccurrencesOfString:@"\r\n"
	    withString:@"\\r\\n"];
	result = [result stringByReplacingOccurrencesOfString:@"\n"
	    withString:@"\\n"];
	result = [result stringByReplacingOccurrencesOfString:@"\r"
	    withString:@"\\r"];
	result = [result stringByReplacingOccurrencesOfString:@"\t"
	    withString:@"\\t"];
	return (result);
}

static void
XCSFPPPrintString(const char *label, NSString *value, NSString *root)
{
	NSString *normalized = XCSFPPClean(value, root);

	printf("%s = <%s>\n", label,
	    (normalized != nil) ? [XCSFPPVisible(normalized) UTF8String] : "nil");
}

static void
XCSFPPWrite(NSString *root, NSString *name, NSString *contents)
{
	NSString *path = [root stringByAppendingPathComponent:name];

	[[NSFileManager defaultManager] createFileAtPath:path
	    contents:[contents dataUsingEncoding:NSUTF8StringEncoding]
	    attributes:nil];
}

static NSString *
XCSFPPKind(id statement)
{
	if ([statement isKindOfClass:[XCSimpleFilePreprocessorText class]])
		return (@"text");
	if ([statement isKindOfClass:[XCSimpleFilePreprocessorInclude class]])
		return (@"include");
	return (@"other");
}

static void
XCSFPPPrintRun(XCSimpleFilePreprocessor *preprocessor, NSString *root,
    NSString *name)
{
	NSString *path = [root stringByAppendingPathComponent:name];
	NSString *result = [preprocessor preprocessFileAtPath:path
	    encoding:NSUTF8StringEncoding];
	NSArray *files = [[[preprocessor filesProcessed] allObjects]
	    sortedArrayUsingSelector:@selector(compare:)];
	NSArray *errors = [preprocessor errors];
	char label[256];
	NSUInteger index;

	snprintf(label, sizeof(label), "%s.result", [name UTF8String]);
	XCSFPPPrintString(label, result, root);
	snprintf(label, sizeof(label), "%s.path", [name UTF8String]);
	XCSFPPPrintString(label, [preprocessor preprocessedFilePath], root);
	snprintf(label, sizeof(label), "%s.encoding", [name UTF8String]);
	printf("%s = <%lu>\n", label,
	    (unsigned long)[preprocessor fileEncoding]);
	snprintf(label, sizeof(label), "%s.contents", [name UTF8String]);
	XCSFPPPrintString(label, [preprocessor preprocessedFileContents], root);
	for (index = 0; index < [files count]; index++) {
		snprintf(label, sizeof(label), "%s.file[%lu]", [name UTF8String],
		    (unsigned long)index);
		XCSFPPPrintString(label, [files objectAtIndex:index], root);
	}
	for (index = 0; index < [errors count]; index++) {
		snprintf(label, sizeof(label), "%s.error[%lu]", [name UTF8String],
		    (unsigned long)index);
		XCSFPPPrintString(label, [errors objectAtIndex:index], root);
	}
}

static int
cmdXCSimpleFilePreprocessor(void)
{
	@autoreleasepool {
		NSFileManager *manager = [NSFileManager defaultManager];
		NSString *root = [[NSTemporaryDirectory()
		    stringByAppendingPathComponent:@"pbxmodel_xcsfpp"]
		    stringByStandardizingPath];
		XCSimpleFilePreprocessor *preprocessor;
		XCSimpleFilePreprocessor *other;
		XCSimpleFilePreprocessorText *text;
		XCSimpleFilePreprocessorText *crlf;
		XCSimpleFilePreprocessorInclude *include;
		XCSimpleFilePreprocessorParsedFile *parsed;
		NSArray *statements;
		NSArray *messages;
		XCSimpleFilePreprocessorInclude *parsedInclude;
		id statement;

		[manager removeItemAtPath:root error:NULL];
		[manager createDirectoryAtPath:root
		    withIntermediateDirectories:YES attributes:nil error:NULL];
		XCSFPPWrite(root, @"inc.h", @"INCLUDED\n");
		XCSFPPWrite(root, @"nonl.h", @"NONL");
		XCSFPPWrite(root, @"nested.h", @"#include \"inc.h\"\nBODY\n");
		XCSFPPWrite(root, @"main.c",
		    @"BEFORE\n#include \"inc.h\"\nAFTER\n");
		XCSFPPWrite(root, @"angles.c", @"#include <inc.h>\nTAIL\n");
		XCSFPPWrite(root, @"plain.c", @"ONE\nTWO\n");
		XCSFPPWrite(root, @"nonl.c", @"#include \"nonl.h\"\nAFTER\n");
		XCSFPPWrite(root, @"missing.c",
		    @"#include \"missing.h\"\nAFTER\n");
		XCSFPPWrite(root, @"import.c", @"#import \"inc.h\"\nTAIL\n");
		XCSFPPWrite(root, @"spaces.c", @"  #include \"inc.h\"\nTAIL\n");
		XCSFPPWrite(root, @"trailing.c",
		    @"#include \"inc.h\" // c\nTAIL\n");
		XCSFPPWrite(root, @"single.c", @"#include 'inc.h'\nTAIL\n");
		XCSFPPWrite(root, @"nospace.c", @"#include\"inc.h\"\nTAIL\n");
		XCSFPPWrite(root, @"hashspace.c", @"# include \"inc.h\"\nTAIL\n");
		XCSFPPWrite(root, @"crlf.c",
		    @"BEFORE\r\n#include \"inc.h\"\r\nAFTER\r\n");
		XCSFPPWrite(root, @"cycle.h", @"#include \"cycle.h\"\nBODY\n");
		XCSFPPWrite(root, @"cycle.c", @"#include \"cycle.h\"\nTAIL\n");

		preprocessor = [XCSimpleFilePreprocessor preprocessor];
		other = [XCSimpleFilePreprocessor preprocessor];
		printf("singleton = <%s>\n", (preprocessor == other) ? "YES" : "NO");
		TSTTPrintString("default.force",
		    [preprocessor forceIncludedFilesToEndWithNewline] ? @"YES" :
		    @"NO");
		TSTTPrintCount("default.paths.count",
		    [[preprocessor includeSearchPath] count]);

		text = [[XCSimpleFilePreprocessorText alloc]
		    initWithText:@"abc"];
		crlf = [[XCSimpleFilePreprocessorText alloc]
		    initWithText:@"def" lineEnding:@"\r\n"];
		XCSFPPPrintString("text.text", [text text], root);
		XCSFPPPrintString("crlf.text", [crlf text], root);

		include = [[XCSimpleFilePreprocessorInclude alloc]
		    initWithPathFragment:@"dir/file.h" lineNumber:7
		    lineEnding:@"\n" isOptional:YES];
		XCSFPPPrintString("include.pathFragment",
		    [include pathFragment], root);
		printf("include.lineNumber = <%ld>\n",
		    (long)[include lineNumber]);
		XCSFPPPrintString("include.lineEnding",
		    [include lineEnding], root);
		printf("include.isOptional = <%s>\n",
		    [include isOptional] ? "YES" : "NO");

		statements = @[text, include, crlf];
		messages = @[@"e1", @"e2"];
		parsed = [[XCSimpleFilePreprocessorParsedFile alloc]
		    initWithStatements:statements errorMessages:messages];
		TSTTPrintCount("parsedValue.statements.count",
		    [[parsed statements] count]);
		TSTTPrintCount("parsedValue.errors.count",
		    [[parsed errorMessages] count]);
		XCSFPPPrintString("parsedValue.error[0]",
		    [[parsed errorMessages] objectAtIndex:0], root);
		XCSFPPPrintString("parsedValue.error[1]",
		    [[parsed errorMessages] objectAtIndex:1], root);
		statement = [[parsed statements] objectAtIndex:0];
		XCSFPPPrintString("statement[0].kind", XCSFPPKind(statement), root);
		XCSFPPPrintString("statement.text",
		    [(XCSimpleFilePreprocessorText *)statement text], root);
		statement = [[parsed statements] objectAtIndex:1];
		XCSFPPPrintString("statement[1].kind", XCSFPPKind(statement), root);
		parsedInclude = (XCSimpleFilePreprocessorInclude *)statement;
		XCSFPPPrintString("statement.pathFragment",
		    [parsedInclude pathFragment], root);
		printf("statement.lineNumber = <%ld>\n",
		    (long)[parsedInclude lineNumber]);
		XCSFPPPrintString("statement.lineEnding",
		    [parsedInclude lineEnding], root);
		printf("statement.isOptional = <%s>\n",
		    [parsedInclude isOptional] ? "YES" : "NO");
		statement = [[parsed statements] objectAtIndex:2];
		XCSFPPPrintString("statement[2].kind", XCSFPPKind(statement), root);
		XCSFPPPrintString("statement.text",
		    [(XCSimpleFilePreprocessorText *)statement text], root);
		XCSFPPPrintString("joined.text",
		    [XCSimpleFilePreprocessorText
		    joinedTextStatementFromStatements:statements], root);

		XCSFPPPrintString("path.found",
		    [preprocessor _pathToIncludedFileNamed:@"inc.h"
		    usingSearchPath:@[root]], root);
		XCSFPPPrintString("path.missing",
		    [preprocessor _pathToIncludedFileNamed:@"missing.h"
		    usingSearchPath:@[root]], root);
		XCSFPPPrintString("path.no.paths",
		    [preprocessor _pathToIncludedFileNamed:@"inc.h"
		    usingSearchPath:@[]], root);

		[preprocessor setIncludeSearchPath:@[root]];
		TSTTPrintCount("paths.count",
		    [[preprocessor includeSearchPath] count]);
		XCSFPPPrintRun(preprocessor, root, @"main.c");
		XCSFPPPrintRun(preprocessor, root, @"plain.c");
		XCSFPPPrintRun(preprocessor, root, @"angles.c");
		XCSFPPPrintRun(preprocessor, root, @"nonl.c");
		XCSFPPPrintRun(preprocessor, root, @"missing.c");
		XCSFPPPrintRun(preprocessor, root, @"import.c");
		XCSFPPPrintRun(preprocessor, root, @"spaces.c");
		XCSFPPPrintRun(preprocessor, root, @"trailing.c");
		XCSFPPPrintRun(preprocessor, root, @"single.c");
		XCSFPPPrintRun(preprocessor, root, @"nospace.c");
		XCSFPPPrintRun(preprocessor, root, @"hashspace.c");
		XCSFPPPrintRun(preprocessor, root, @"crlf.c");
		XCSFPPPrintRun(preprocessor, root, @"cycle.c");

		[preprocessor setForceIncludedFilesToEndWithNewline:YES];
		printf("force = <YES>\n");
		XCSFPPPrintRun(preprocessor, root, @"nonl.c");
	}
	return (0);
}

static NSString *
XCRPRRepr(id object)
{
	if (object == nil)
		return (@"<nil>");
	if ([object isKindOfClass:[XCProjectRenameItem class]])
		return ([NSString stringWithFormat:@"item:%@",
		    XCRPRRepr([(XCProjectRenameItem *)object currentName])]);
	if ([object isKindOfClass:[NSAttributedString class]])
		return ([NSString stringWithFormat:@"attr:%@", [object string]]);
	if ([object isKindOfClass:[NSString class]])
		return ([NSString stringWithFormat:@"str:%@", object]);
	if ([object isKindOfClass:[NSNumber class]])
		return ([NSString stringWithFormat:@"num:%@", object]);
	if ([object isKindOfClass:[NSError class]])
		return ([NSString stringWithFormat:@"error:%@/%ld", [object domain],
		    (long)[object code]]);
	if ([object isKindOfClass:[NSArray class]]) {
		NSMutableArray *parts = [NSMutableArray array];

		for (id item in object)
			[parts addObject:XCRPRRepr(item)];
		return ([NSString stringWithFormat:@"array[%@]",
		    [parts componentsJoinedByString:@", "]]);
	}
	return ([NSString stringWithFormat:@"object:%@",
	    NSStringFromClass([object class])]);
}

static NSString *
XCRPRItemRepr(XCProjectRenameItem *item)
{
	return ([NSString stringWithFormat:
	    @"%@(current=%@, proposed=%@, parent=%@)",
	    NSStringFromClass([item class]), XCRPRRepr([item currentName]),
	    XCRPRRepr([item proposedName]),
	    XCRPRRepr([[item parent] currentName])]);
}

static NSString *
XCRPRItemsRepr(id items)
{
	if (items == nil)
		return (@"<nil>");
	if (![items isKindOfClass:[NSArray class]])
		return (XCRPRRepr(items));
	NSMutableArray *parts = [NSMutableArray array];

	for (XCProjectRenameItem *item in items)
		[parts addObject:XCRPRItemRepr(item)];
	return ([NSString stringWithFormat:@"items[%@]",
	    [parts componentsJoinedByString:@", "]]);
}

static void
XCRPRPrintState(NSString *label, XCProjectRenameItem *item)
{
	printf("%s parent=%s represented=%s renamer=%s renameable=%s project=%s target=%s\n",
	    [label UTF8String], [XCRPRRepr([item parent]) UTF8String],
	    [XCRPRRepr([item representedObject]) UTF8String],
	    [XCRPRRepr([item renamer]) UTF8String],
	    [XCRPRRepr([item renameableItem]) UTF8String],
	    [XCRPRRepr([item project]) UTF8String],
	    [XCRPRRepr([item target]) UTF8String]);
	printf("%s type=%s fileDataType=%s current=%s proposed=%s\n",
	    [label UTF8String], [XCRPRRepr([item type]) UTF8String],
	    [XCRPRRepr([item fileDataType]) UTF8String],
	    [XCRPRRepr([item currentName]) UTF8String],
	    [XCRPRRepr([item proposedName]) UTF8String]);
	printf("%s attributedCurrent=%s attributedProposed=%s image=%s error=%s\n",
	    [label UTF8String],
	    [XCRPRRepr([item attributedCurrentName]) UTF8String],
	    [XCRPRRepr([item attributedProposedName]) UTF8String],
	    [item image] != nil ? "image" : "<nil>",
	    [XCRPRRepr([item error]) UTF8String]);
	printf("%s children=%s configurations=%s enabled=%s shouldRename=%s\n",
	    [label UTF8String], [XCRPRItemsRepr([item children]) UTF8String],
	    [XCRPRRepr([item buildConfigurations]) UTF8String],
	    [item enabled] ? "YES" : "NO", [item shouldRename] ? "YES" : "NO");
	printf("%s currentRange=%s proposedRange=%s\n", [label UTF8String],
	    [XCRPRRepr([item currentNameMatchRange]) UTF8String],
	    [XCRPRRepr([item proposedNameMatchRange]) UTF8String]);
}

static void
XCRPRTry(NSString *label, void (^block)(void))
{
	@try {
		block();
		printf("%s = <ok>\n", [label UTF8String]);
	} @catch (NSException *exception) {
		printf("%s = <exception:%s>\n", [label UTF8String],
		    [[exception name] UTF8String]);
	}
}

static int
cmdXCProjectRename(void)
{
	@autoreleasepool {
		NSArray *classes = @[
		    @"XCProjectRenameItem", @"XCProjectRenameFileItem",
		    @"XCProjectRenameXibItem", @"XCProjectRenamePCHItem",
		    @"XCProjectRenameInfoPlistContentsItem",
		    @"XCProjectRenameInfoPlistItem", @"XCProjectRenameProductItem",
		    @"XCProjectRenameBuildSettingItem", @"XCProjectRenameTargetItem",
		    @"XCProjectRenameProjectItem",
		];

		printf("DEFAULTS\n");
		for (NSString *name in classes) {
			XCProjectRenameItem *object =
			    [[NSClassFromString(name) alloc] init];

			XCRPRPrintState(name, object);
			if ([object isKindOfClass:[XCProjectRenameBuildSettingItem class]])
				printf("%s.settingName = <%s>\n", [name UTF8String],
				    [XCRPRRepr([(XCProjectRenameBuildSettingItem *)
					object settingName]) UTF8String]);
		}

		printf("SETTERS\n");
		XCProjectRenameItem *item = [[XCProjectRenameItem alloc] init];
		XCProjectRenameItem *parent = [[XCProjectRenameItem alloc] init];
		XCProjectRenameItem *child = [[XCProjectRenameItem alloc] init];

		[parent setCurrentName:@"Parent"];
		[child setCurrentName:@"Child"];
		[item setParent:parent];
		[item setRepresentedObject:@"represented"];
		[item setRenamer:(id)@"renamer"];
		[item setRenameableItem:(id)@"renameable"];
		[item setProject:(id)@"project"];
		[item setTarget:(id)@"target"];
		[item setType:@"type"];
		[item setFileDataType:(id)@"fileDataType"];
		[item setCurrentName:@"OldName.m"];
		[item setAttributedCurrentName:[[NSAttributedString alloc]
		    initWithString:@"AttrCurrent"]];
		[item setAttributedProposedName:[[NSAttributedString alloc]
		    initWithString:@"AttrProposed"]];
		[item setImage:(id)@"image"];
		[item setError:[NSError errorWithDomain:@"probe" code:7 userInfo:nil]];
		[item setEnabled:NO];
		[item setShouldRename:NO];
		[item setBuildConfigurations:@[@"Debug", @"Release"]];
		[item setChildren:@[child]];
		[item setCurrentNameMatchRange:(id)@"currentRange"];
		[item setProposedNameMatchRange:(id)@"proposedRange"];
		XCRPRPrintState(@"setters", item);

		printf("NAME_FLOW\n");
		XCProjectRenameItem *flow = [[XCProjectRenameItem alloc] init];

		[flow setCurrentName:@"OnlyCurrent"];
		XCRPRPrintState(@"name.currentOnly", flow);
		[flow setAttributedCurrentName:[[NSAttributedString alloc]
		    initWithString:@"OnlyAttrCurrent"]];
		XCRPRPrintState(@"name.attrCurrent", flow);
		[flow setAttributedProposedName:[[NSAttributedString alloc]
		    initWithString:@"OnlyAttrProposed"]];
		XCRPRPrintState(@"name.attrProposed", flow);
		[flow setCurrentName:@"NewCurrent"];
		XCRPRPrintState(@"name.currentAgain", flow);

		printf("CHILDREN\n");
		XCProjectRenameItem *tree = [[XCProjectRenameItem alloc] init];
		XCProjectRenameItem *childA = [[XCProjectRenameItem alloc] init];
		XCProjectRenameItem *childB = [[XCProjectRenameItem alloc] init];

		[tree setCurrentName:@"Tree"];
		[childA setCurrentName:@"A"];
		[childB setCurrentName:@"B"];
		[tree addChild:childA];
		[tree addChild:childB];
		[tree addChild:childA];
		printf("children.add = <%s>\n",
		    [XCRPRItemsRepr([tree children]) UTF8String]);
		[tree removeChild:childA];
		printf("children.removeExisting = <%s>\n",
		    [XCRPRItemsRepr([tree children]) UTF8String]);
		[tree removeChild:childA];
		printf("children.removeMissing = <%s>\n",
		    [XCRPRItemsRepr([tree children]) UTF8String]);
		XCRPRTry(@"children.addNil", ^{ [tree addChild:nil]; });
		printf("children.afterAddNil = <%s>\n",
		    [XCRPRItemsRepr([tree children]) UTF8String]);
		XCRPRTry(@"children.removeNil", ^{ [tree removeChild:nil]; });
		printf("children.afterRemoveNil = <%s>\n",
		    [XCRPRItemsRepr([tree children]) UTF8String]);

		XCProjectRenameItem *configs = [[XCProjectRenameItem alloc] init];

		[configs addBuildConfiguration:@"Debug"];
		[configs addBuildConfigurations:@[@"Release", @"Profile"]];
		printf("configs.add = <%s>\n",
		    [XCRPRRepr([configs buildConfigurations]) UTF8String]);
		XCRPRTry(@"configs.addNil", ^{
		    [configs addBuildConfiguration:nil];
		});
		printf("configs.afterAddNil = <%s>\n",
		    [XCRPRRepr([configs buildConfigurations]) UTF8String]);
		XCRPRTry(@"configs.addArrayNil", ^{
		    [configs addBuildConfigurations:nil];
		});
		printf("configs.afterArrayNil = <%s>\n",
		    [XCRPRRepr([configs buildConfigurations]) UTF8String]);

		printf("UPDATE\n");
		NSArray *updates = @[
		    @[@"middle", @"AlphaBetaGamma", @"<nil>", @"X", @"Beta"],
		    @[@"missing", @"AlphaBetaGamma", @"<nil>", @"X", @"Z"],
		    @[@"empty", @"AlphaBetaGamma", @"<nil>", @"X", @""],
		    @[@"repeated", @"banana", @"<nil>", @"X", @"a"],
		    @[@"case", @"Alpha", @"<nil>", @"X", @"alpha"],
		    @[@"full", @"Old.m", @"<nil>", @"New.m", @"Old.m"],
		    @[@"prefixSuffix", @"OldFile.m", @"<nil>", @"NewFile.m", @"File"],
		    @[@"staleAttr", @"AlphaBeta", @"stale", @"X", @"Beta"],
		];
		for (NSArray *entry in updates) {
			XCProjectRenameItem *updateItem =
			    [[XCProjectRenameItem alloc] init];

			if (![entry[2] isEqualToString:@"<nil>"])
				[updateItem setAttributedProposedName:
				    [[NSAttributedString alloc]
				    initWithString:entry[2]]];
			[updateItem setCurrentName:entry[1]];
			[updateItem updateProposedNameWith:entry[3] fromName:entry[4]];
			printf("update.%s.proposed = <%s>\n", [entry[0] UTF8String],
			    [XCRPRRepr([updateItem proposedName]) UTF8String]);
			printf("update.%s.attr = <%s>\n", [entry[0] UTF8String],
			    [XCRPRRepr([updateItem attributedProposedName]) UTF8String]);
		}

		XCProjectRenameItem *nilProposed =
		    [[XCProjectRenameItem alloc] init];
		[nilProposed setCurrentName:@"AlphaBeta"];
		XCRPRTry(@"update.nilProposed", ^{
		    [nilProposed updateProposedNameWith:nil fromName:@"Beta"];
		});
		printf("update.nilProposed.proposed = <%s>\n",
		    [XCRPRRepr([nilProposed proposedName]) UTF8String]);
		XCProjectRenameItem *nilFrom = [[XCProjectRenameItem alloc] init];

		[nilFrom setCurrentName:@"AlphaBeta"];
		XCRPRTry(@"update.nilFrom", ^{
		    [nilFrom updateProposedNameWith:@"X" fromName:nil];
		});
		printf("update.nilFrom.proposed = <%s>\n",
		    [XCRPRRepr([nilFrom proposedName]) UTF8String]);

		XCProjectRenameItem *mutations = [[XCProjectRenameItem alloc] init];

		[mutations setCurrentName:@"AlphaBetaGamma"];
		[mutations updateProposedNameWith:@"X" fromName:@"Beta"];
		printf("update.after.proposed = <%s>\n",
		    [XCRPRRepr([mutations proposedName]) UTF8String]);
		[mutations setAttributedProposedName:[[NSAttributedString alloc]
		    initWithString:@"Y"]];
		printf("update.afterAttr.proposed = <%s>\n",
		    [XCRPRRepr([mutations proposedName]) UTF8String]);
		[mutations setCurrentName:@"Changed"];
		printf("update.afterCurrent.proposed = <%s>\n",
		    [XCRPRRepr([mutations proposedName]) UTF8String]);
		[mutations setAttributedCurrentName:[[NSAttributedString alloc]
		    initWithString:@"AttrCurrent"]];
		printf("update.afterAttrCurrent.current = <%s>\n",
		    [XCRPRRepr([mutations currentName]) UTF8String]);
		printf("update.afterAttrCurrent.proposed = <%s>\n",
		    [XCRPRRepr([mutations proposedName]) UTF8String]);

		printf("OPERATIONS\n");
		XCProjectRenameItem *operations = [[XCProjectRenameItem alloc] init];

		XCRPRTry(@"operations.validate", ^{ [operations validate]; });
		XCRPRTry(@"operations.cancel", ^{ [operations cancel]; });
		XCRPRTry(@"operations.rename", ^{ [operations rename]; });
		XCRPRPrintState(@"operations.after", operations);

		printf("SETTING_NAME\n");
		XCProjectRenameBuildSettingItem *setting =
		    [[XCProjectRenameBuildSettingItem alloc] init];

		[setting setSettingName:@"PRODUCT_NAME"];
		printf("setting.name = <%s>\n",
		    [XCRPRRepr([setting settingName]) UTF8String]);
	}
	return (0);
}

static int
cmdTSPropertyListDictionary(void)
{
	@autoreleasepool {
		NSDictionary *base = [NSDictionary dictionaryWithObjectsAndKeys:
		    @"value", @"str",
		    [NSData dataWithBytes:"abc" length:3], @"data",
		    [NSDictionary dictionaryWithObject:@"yes" forKey:@"inner"], @"dict",
		    [NSArray arrayWithObjects:@"one", @"two", nil], @"array",
		    [NSNumber numberWithInt:42], @"number", nil];
		TSPropertyListDictionary *d = [TSPropertyListDictionary
		    propertyListDictionaryWithDictionary:base];
		NSMutableArray *keys = [NSMutableArray array];
		for (id key in d)
			[keys addObject:key];
		[keys sortUsingSelector:@selector(compare:)];

		TSTTPrintCount("count", [d count]);
		TSTTPrintString("keys", [keys componentsJoinedByString:@","]);
		TSPLHPrintValue("object.str", [d objectForKey:@"str"]);
		TSPLHPrintValue("object.missing", [d objectOrNilForKey:@"missing"]);
		TSPLHTry("object.required.missing", ^{
		    (void)[d objectForKey:@"missing"];
		});
		TSPLHPrintValue("string.str", [d stringForKey:@"str"]);
		TSPLHPrintValue("string.optional.missing",
		    [d stringOrNilForKey:@"missing"]);
		TSPLHTry("string.required.missing", ^{
		    (void)[d stringForKey:@"missing"];
		});
		TSPLHTry("string.required.wrong", ^{
		    (void)[d stringForKey:@"number"];
		});
		TSPLHTry("string.optional.wrong", ^{
		    (void)[d stringOrNilForKey:@"number"];
		});
		TSPLHPrintValue("data.data", [d dataForKey:@"data"]);
		TSPLHPrintValue("dictionary.dict", [d dictionaryForKey:@"dict"]);
		TSPLHPrintValue("array.array", [d arrayForKey:@"array"]);
		TSPLHPrintValue("array.or.object.number",
		    [d arrayOrObjectOrNilForKey:@"number"]);
		TSPLHPrintValue("array.or.object.array",
		    [d arrayOrObjectOrNilForKey:@"array"]);
		TSPLHPrintValue("array.or.object.missing",
		    [d arrayOrObjectOrNilForKey:@"missing"]);

		[d setBundle:[NSBundle mainBundle]];
		TSTTPrintString("bundle.class",
		    NSStringFromClass([[d bundle] class]));
		[d setLocalizationDictionary:[NSDictionary
		    dictionaryWithObject:@"v" forKey:@"k"]];
		TSTTPrintCount("localization.count",
		    [[d localizationDictionary] count]);

		TSTTPrintString("type.string",
		    [d _localizedTypeNameForClass:[NSString class]]);
		TSTTPrintString("type.data",
		    [d _localizedTypeNameForClass:[NSData class]]);
		TSTTPrintString("type.dictionary",
		    [d _localizedTypeNameForClass:[NSDictionary class]]);
		TSTTPrintString("type.array",
		    [d _localizedTypeNameForClass:[NSArray class]]);
		TSTTPrintString("type.number",
		    [d _localizedTypeNameForClass:[NSNumber class]]);
		TSTTPrintString("type.nil",
		    [d _localizedTypeNameForClass:Nil]);

		TSPropertyListDictionary *parsed = [TSPropertyListDictionary
		    propertyListDictionaryWithContentsOfString:
		    @"{ str = value; array = ( one, two ); }"];
		TSTTPrintCount("parsed.count", [parsed count]);
		TSPLHPrintValue("parsed.str", [parsed stringForKey:@"str"]);
		TSPLHPrintValue("parsed.array", [parsed arrayForKey:@"array"]);
		TSPLHTry("parsed.top.wrong", ^{
		    (void)[TSPropertyListDictionary
		        propertyListDictionaryWithContentsOfString:@"( one, two )"];
		});
		TSPropertyListDictionary *empty = [[TSPropertyListDictionary alloc]
		    initWithDictionary:nil];
		TSTTPrintCount("empty.count", [empty count]);
	}
	return (0);
}

@interface LBSArchiveValue : NSObject
@property (nonatomic, copy) NSString *text;
- (SEL)selectorForArchiveMask:(NSInteger)mask;
@end

@implementation LBSArchiveValue
- (SEL)selectorForArchiveMask:(NSInteger)mask
{
	return ((mask & 4) != 0) ? @selector(decodeObjectForKey:) :
	    @selector(encodeObject:forKey:);
}
@end

@interface LBSBindingTarget : NSObject
@property (nonatomic, strong) id path;
@end

@implementation LBSBindingTarget
+ (NSString *)archiveNameForKey:(NSString *)key
{
	return ([@"archive_" stringByAppendingString:key]);
}

+ (BOOL)canArchiveAnyClassForKey:(NSString *)key
{
	return ([key isEqualToString:@"path"]);
}

+ (BOOL)relationshipIsWeak:(id)object forPListArchiver:(id)archiver
{
	(void)object;
	(void)archiver;
	return (NO);
}

+ (NSArray *)archivableKeysToBeSkippedByPListArchiver:(id)archiver
{
	(void)archiver;
	return (@[]);
}

+ (NSArray *)archivableWeakRelationshipsForPListArchiver:(id)archiver
{
	(void)archiver;
	return (@[]);
}
@end

@interface LBSSelectorTarget : NSObject
@end

@implementation LBSSelectorTarget
+ (NSString *)archiveNameForKey:(NSString *)key
{
	return ([@"archive_" stringByAppendingString:key]);
}

+ (BOOL)canArchiveAnyClassForKey:(NSString *)key
{
	(void)key;
	return (NO);
}

+ (BOOL)relationshipIsWeak:(id)object forPListArchiver:(id)archiver
{
	(void)object;
	(void)archiver;
	return (NO);
}

+ (NSArray *)archivableKeysToBeSkippedByPListArchiver:(id)archiver
{
	(void)archiver;
	return (@[]);
}

+ (NSArray *)archivableWeakRelationshipsForPListArchiver:(id)archiver
{
	(void)archiver;
	return (@[]);
}

- (id)path
{
	return (nil);
}

- (void)setPath:(id)path
{
	(void)path;
}
@end

@interface LBSBindingArchiver : NSObject
@property (nonatomic, strong) NSMutableDictionary *values;
@end

@implementation LBSBindingArchiver
- (instancetype)init
{
	if ((self = [super init]) != nil)
		_values = [[NSMutableDictionary alloc] init];
	return (self);
}

- (void)encodeObject:(id)value forKey:(NSString *)key
{
	if (value != nil && key != nil)
		[_values setObject:value forKey:key];
}

- (void)encodeString:(id)value forKey:(NSString *)key
{
	[self encodeObject:value forKey:key];
}
@end

@interface LBSBindingUnarchiver : NSObject
@property (nonatomic, strong) id archivedValue;
@property (nonatomic, strong) id decodedValue;
@end

@implementation LBSBindingUnarchiver
- (id)valueForKey:(NSString *)key
{
	(void)key;
	return (_archivedValue);
}

- (id)decodeObjectForKey:(NSString *)key
{
	(void)key;
	return (_decodedValue);
}
@end

@protocol LBSBindingArchiveProtocol <NSObject>
+ (id)bindingWithClass:(Class)cls
    key:(NSString *)key
    archiveMask:(NSInteger)mask;
- (int)archiveMask;
- (NSString *)key;
- (Class)targetClass;
- (BOOL)allowsAnyClass;
- (void)writeValueForObject:(id)object toPListArchiver:(id)archiver;
- (void)readValueForObject:(id)object fromPListUnarchiver:(id)unarchiver;
@end

static id
LBSBindingObjectIvar(id object, const char *name)
{
	Ivar ivar = class_getInstanceVariable([object class], name);

	if (ivar == NULL)
		return (nil);
	return (object_getIvar(object, ivar));
}

static const char *
LBSBindingSelectorIvar(id object, const char *name)
{
	Ivar ivar = class_getInstanceVariable([object class], name);
	SEL value;

	if (ivar == NULL)
		return ("-");
	value = *(SEL *)((char *)(__bridge void *)object + ivar_getOffset(ivar));
	return ((value != NULL) ? sel_getName(value) : "-");
}

static const char *
LBSBindingSafeUTF8(id object)
{
	return ((object != nil) ? [object UTF8String] : "-");
}

static void
LBSBindingDumpFactory(Class bindingClass, Class targetClass, NSArray *masks)
{
	@try {
		for (NSNumber *number in masks) {
			id binding = [(id<LBSBindingArchiveProtocol>)bindingClass
			    bindingWithClass:targetClass key:@"path"
			    archiveMask:[number integerValue]];
			id keyBinding = LBSBindingObjectIvar(binding,
			    "_keyBindingInternal");
			id<LBSBindingArchiveProtocol> typed = binding;

			printf("mask=%ld class=%s archiveMask=%d key=%s "
			    "allows=%d target=%s keyBindingClass=%s\n",
			    (long)[number integerValue],
			    class_getName([binding class]), [typed archiveMask],
			    LBSBindingSafeUTF8([typed key]),
			    (int)[typed allowsAnyClass],
			    class_getName([typed targetClass]),
			    ((keyBinding != nil) ? class_getName([keyBinding class]) :
			    "-"));
		}
	} @catch (NSException *exception) {
		printf("factory exception=%s: %s\n", [[exception name] UTF8String],
		    [[exception reason] UTF8String]);
	}
}

@interface PLATestObject : NSObject
+ (BOOL)hasUserKeys;
- (PBXObjectID *)objectID;
- (NSString *)classNameForPListArchive;
- (NSString *)fallbackClassNameForPListArchive;
- (void)writeToPListArchiver:(PBXPListArchiver *)archiver;
- (void)writeUserSettingsToPListArchiver:(PBXPListArchiver *)archiver;
@end

@implementation PLATestObject
+ (BOOL)hasUserKeys
{
	return (YES);
}
- (PBXObjectID *)objectID
{
	return ([[PBXObjectID alloc] initFromStringRepresentation:
	    @"000000000000000000000001"]);
}
- (NSString *)classNameForPListArchive
{
	return (@"PLAArchiveObject");
}
- (NSString *)fallbackClassNameForPListArchive
{
	return (@"PBXObject");
}
- (void)writeToPListArchiver:(PBXPListArchiver *)archiver
{
	[archiver encodeString:@"probe" forKey:@"name"];
	[archiver encodeInteger:7 forKey:@"count"];
}
- (void)writeUserSettingsToPListArchiver:(PBXPListArchiver *)archiver
{
	[archiver encodeString:@"setting" forKey:@"userKey"];
}
@end

static const char *
PLASafeUTF8(id object)
{
	return ((object != nil) ? [object UTF8String] : "(nil)");
}

static void
PLAPrintValue(id value)
{
	if (value == nil) {
		printf("(nil)");
		return;
	}
	if ([value isKindOfClass:[NSString class]]) {
		printf("\"%s\"", [value UTF8String]);
		return;
	}
	if ([value isKindOfClass:[NSArray class]]) {
		printf("[");
		for (NSUInteger i = 0; i < [value count]; i++) {
			if (i != 0)
				printf(", ");
			PLAPrintValue([value objectAtIndex:i]);
		}
		printf("]");
		return;
	}
	if ([value isKindOfClass:[NSDictionary class]]) {
		NSArray *keys = [[value allKeys]
		    sortedArrayUsingSelector:@selector(compare:)];

		printf("{");
		for (NSUInteger i = 0; i < [keys count]; i++) {
			id key = [keys objectAtIndex:i];

			if (i != 0)
				printf(", ");
			printf("%s: ", PLASafeUTF8(key));
			PLAPrintValue([value objectForKey:key]);
		}
		printf("}");
		return;
	}
	printf("%s", [[value description] UTF8String]);
}

static void
PLALine(NSString *label, id value)
{
	printf("%s = ", [label UTF8String]);
	PLAPrintValue(value);
	printf("\n");
}

static PBXPListArchiver *
PLAMakeArchiver(void)
{
	PBXPListArchiver *archiver = [[PBXPListArchiver alloc]
	    initWithRootObject:nil delegate:nil role:0];

	[archiver setValue:[NSMutableDictionary dictionary]
	    forKey:@"_currentArchiveDict"];
	return (archiver);
}

static PBXPListUnarchiver *
PLAMakeUnarchiver(NSDictionary *current)
{
	PBXPListUnarchiver *unarchiver = [[PBXPListUnarchiver alloc]
	    initWithPListArchive:@{@"archiveVersion": @"1", @"classes": @{},
	        @"objects": @{}, @"rootObject": @"nil"}];

	[unarchiver setValue:current forKey:@"_currentArchiveDict"];
	return (unarchiver);
}

static int
cmdPlistArchive(void)
{
	@autoreleasepool {
		printf("== factory ==\n");
		PLALine(@"archive", [PBXPListArchiver plistArchiveWithRootObject:nil
		    delegate:nil role:0]);

		printf("== scalars ==\n");
		@try {
			PBXPListArchiver *archiver = PLAMakeArchiver();

			[archiver encodeBoolean:YES forKey:@"yes"];
			[archiver encodeBoolean:NO forKey:@"no"];
			[archiver encodeCharacter:'A' forKey:@"char"];
			[archiver encodeInteger:-42 forKey:@"int"];
			[archiver encodeFloat:1.5f forKey:@"float"];
			[archiver encodeDouble:2.25 forKey:@"double"];
			[archiver encodeRange:NSMakeRange(3, 7) forKey:@"range"];
			[archiver encodeValue:@"text" forKey:@"value"];
			[archiver encodeString:@"text" forKey:@"string"];
			[archiver encodePListArray:@[@"a", @2] forKey:@"array"];
			[archiver encodePListDictionary:@{@"one": @2} forKey:@"dict"];
			PLALine(@"current", [archiver valueForKey:@"_currentArchiveDict"]);
		} @catch (NSException *exception) {
			printf("scalars exception=%s: %s\n",
			    [[exception name] UTF8String],
			    [[exception reason] UTF8String]);
		}

		printf("== objects ==\n");
		@try {
			PBXPListArchiver *archiver = PLAMakeArchiver();
			PLATestObject *object = [[PLATestObject alloc] init];

			[archiver encodeObject:object forKey:@"strong"];
			[archiver encodeObjectWeakly:object forKey:@"weak"];
			[archiver encodeObjectArray:@[object, object] forKey:@"array"];
			[archiver encodeObjectDictionary:@{@"one": object}
			    forKey:@"dict"];
			PLALine(@"current", [archiver valueForKey:@"_currentArchiveDict"]);
			PLALine(@"settings", [archiver userSettings]);
		} @catch (NSException *exception) {
			printf("objects exception=%s: %s\n",
			    [[exception name] UTF8String],
			    [[exception reason] UTF8String]);
		}

		printf("== root ==\n");
		@try {
			PBXPListArchiver *archiver = [[PBXPListArchiver alloc]
			    initWithRootObject:[[PLATestObject alloc] init]
			    delegate:nil role:0];

			PLALine(@"archive", [archiver plistArchive]);
			PLALine(@"settings", [archiver userSettings]);
		} @catch (NSException *exception) {
			printf("root exception=%s: %s\n",
			    [[exception name] UTF8String],
			    [[exception reason] UTF8String]);
		}

		printf("== decode ==\n");
		@try {
			NSDictionary *current = @{@"key": @"text", @"number": @"42",
			    @"numberValue": @42, @"bool": @"YES",
			    @"boolValue": @YES, @"char": @"65",
			    @"float": @"1.500000", @"double": @"2.250000",
			    @"range": @"3 7", @"array": @[@"a", @2],
			    @"dict": @{@"one": @2}};
			PBXPListUnarchiver *unarchiver = PLAMakeUnarchiver(current);

			PLALine(@"value", [unarchiver valueForKey:@"key"]);
			PLALine(@"missing", [unarchiver valueForKey:@"missing"]);
			PLALine(@"has", @([unarchiver hasValueForKey:@"key"]));
			PLALine(@"hasMissing", @([unarchiver hasValueForKey:@"missing"]));
			PLALine(@"object", [unarchiver decodeObjectForKey:@"key"]);
			PLALine(@"string", [unarchiver decodeStringForKey:@"key"]);
			PLALine(@"number", [unarchiver decodeNumberForKey:@"number"]);
			PLALine(@"numberValue", [unarchiver decodeNumberForKey:@"numberValue"]);
			PLALine(@"bool", @([unarchiver decodeBooleanForKey:@"bool"]));
			PLALine(@"boolValue", @([unarchiver decodeBooleanForKey:@"boolValue"]));
			PLALine(@"char", @([unarchiver decodeCharacterForKey:@"char"]));
			PLALine(@"int", @([unarchiver decodeIntegerForKey:@"number"]));
			PLALine(@"intValue", @([unarchiver decodeIntegerForKey:@"numberValue"]));
			PLALine(@"float", @([unarchiver decodeFloatForKey:@"float"]));
			PLALine(@"double", @([unarchiver decodeDoubleForKey:@"double"]));
			PLALine(@"range", NSStringFromRange([unarchiver decodeRangeForKey:@"range"]));
			PLALine(@"array", [unarchiver decodeMutablePListArrayForKey:@"array"]);
			PLALine(@"dict", [unarchiver decodeMutablePListDictionaryForKey:@"dict"]);
		} @catch (NSException *exception) {
			printf("decode exception=%s: %s\n",
			    [[exception name] UTF8String],
			    [[exception reason] UTF8String]);
		}
	}
	return (0);
}

static int
cmdArchiveBindings(void)
{
	@autoreleasepool {
		Class bindingClass = NSClassFromString(@"PBXArchiveBinding");

		if (bindingClass == Nil) {
			printf("class=missing\n");
			return (1);
		}
		printf("== factory ==\n");
		LBSBindingDumpFactory(bindingClass, [LBSBindingTarget class],
		    @[ @(-8), @(-4), @0, @1, @2, @3, @4, @5, @6, @7, @8, @16 ]);
		printf("== factory selector ==\n");
		LBSBindingDumpFactory(bindingClass, [LBSSelectorTarget class],
		    @[ @1, @5 ]);

		printf("== archiving ==\n");
		@try {
			LBSBindingTarget *target = [LBSBindingTarget new];
			LBSBindingArchiver *archiver = [LBSBindingArchiver new];
			LBSArchiveValue *value = [LBSArchiveValue new];
			id binding = [(id<LBSBindingArchiveProtocol>)bindingClass
			    bindingWithClass:[LBSBindingTarget class]
			    key:@"path" archiveMask:1];
			id stored;

			[value setText:@"hello"];
			[target setPath:value];
			[(id<LBSBindingArchiveProtocol>)binding
			    writeValueForObject:target toPListArchiver:archiver];
			stored = [[archiver values] objectForKey:@"archive_path"];
			printf("bindingClass=%s\n", class_getName([binding class]));
			printf("valueClass=%s\n", class_getName([value class]));
			printf("archiveSelector=%s\n",
			    LBSBindingSelectorIvar(binding, "_archiveSelector"));
			printf("archiveKey=%s\n",
			    LBSBindingSafeUTF8(LBSBindingObjectIvar(binding,
			    "_archiveKey")));
			printf("archiveValue=%s\n",
			    LBSBindingSafeUTF8([(LBSArchiveValue *)stored
			    text]));
		} @catch (NSException *exception) {
			printf("archiving exception=%s: %s\n",
			    [[exception name] UTF8String],
			    [[exception reason] UTF8String]);
		}

		printf("== unarchiving ==\n");
		@try {
			LBSBindingTarget *target = [LBSBindingTarget new];
			LBSBindingUnarchiver *unarchiver = [LBSBindingUnarchiver new];
			LBSArchiveValue *archived = [LBSArchiveValue new];
			id binding = [(id<LBSBindingArchiveProtocol>)bindingClass
			    bindingWithClass:[LBSBindingTarget class]
			    key:@"path" archiveMask:5];

			[archived setText:@"archived"];
			[unarchiver setArchivedValue:archived];
			[unarchiver setDecodedValue:@"decoded"];
			[(id<LBSBindingArchiveProtocol>)binding
			    readValueForObject:target
			    fromPListUnarchiver:unarchiver];
			printf("bindingClass=%s\n", class_getName([binding class]));
			printf("archivedClass=%s\n", class_getName([archived class]));
			printf("unarchiveSelector=%s\n",
			    LBSBindingSelectorIvar(binding, "_unarchiveSelector"));
			printf("archiveKey=%s\n",
			    LBSBindingSafeUTF8(LBSBindingObjectIvar(binding,
			    "_archiveKey")));
			printf("targetPath=%s\n", LBSBindingSafeUTF8([target path]));
		} @catch (NSException *exception) {
			printf("unarchiving exception=%s: %s\n",
			    [[exception name] UTF8String],
			    [[exception reason] UTF8String]);
		}
	}
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
		if (argc >= 2 && strcmp(argv[1], "macroevaluation") == 0)
			return (cmdMacroEvaluation());
		if (argc >= 2 && strcmp(argv[1], "objectgraphpath") == 0)
			return (cmdObjectGraphPath());
		if (argc >= 2 && strcmp(argv[1], "compatfeatures") == 0)
			return (cmdCompatibilityFeatures());
		if (argc >= 2 && strcmp(argv[1], "supportedversionranges") == 0)
			return (cmdSupportedVersionRanges());
		if (argc >= 2 && strcmp(argv[1], "propertyvalues") == 0)
			return (cmdPropertyValues());
		if (argc >= 2 && strcmp(argv[1], "propertyconditions") == 0)
			return (cmdPropertyConditions());
		if (argc >= 2 && strcmp(argv[1], "propertysupported") == 0)
			return (cmdPropertySupported());
		if (argc >= 2 && strcmp(argv[1], "plistwrappers") == 0)
			return (cmdPlistWrappers());
		if (argc >= 2 && strcmp(argv[1], "stringlist") == 0)
			return (cmdStringList());
		if (argc >= 2 && strcmp(argv[1], "tsstringbom") == 0)
			return (cmdTSStringBOM());
		if (argc >= 2 && strcmp(argv[1], "tsregularexpression") == 0)
			return (cmdTSRegularExpression());
		if (argc >= 2 && strcmp(argv[1], "tsfilemanager") == 0)
			return (cmdTSFileManager());
		if (argc >= 2 && strcmp(argv[1], "tstimedtrace") == 0)
			return (cmdTSTimedTrace());
		if (argc >= 2 && strcmp(argv[1], "tspropertylistdictionary") == 0)
			return (cmdTSPropertyListDictionary());
		if (argc >= 2 && strcmp(argv[1], "xcsfpp") == 0)
			return (cmdXCSimpleFilePreprocessor());
		if (argc >= 2 && strcmp(argv[1], "xcprojectrename") == 0)
			return (cmdXCProjectRename());
		if (argc >= 2 && strcmp(argv[1], "xcproducttypes") == 0)
			return (cmdXCProductTypes());
		if (argc >= 2 && strcmp(argv[1], "runtimevalues") == 0)
			return (cmdRuntimeValues());
		if (argc >= 2 && strcmp(argv[1], "buildconfigurations") == 0)
			return (cmdBuildConfigurations());
		if (argc >= 2 && strcmp(argv[1], "paths") == 0)
			return (cmdPaths());
		if (argc >= 2 && strcmp(argv[1], "targetdependencies") == 0)
			return (cmdTargetDependencies());
		if (argc >= 2 && strcmp(argv[1], "archivebindings") == 0)
			return (cmdArchiveBindings());
		if (argc >= 2 && strcmp(argv[1], "plistarchive") == 0)
			return (cmdPlistArchive());
		if (argc >= 2 && strcmp(argv[1], "applesave") == 0) {
			if (argc != 4 && argc != 5)
				usage();
			return (cmdAppleSave([NSString stringWithUTF8String:
			    argv[2]], [NSString stringWithUTF8String:argv[3]],
			    (argc == 5) ? [NSString stringWithUTF8String:
			    argv[4]] : nil));
		}
		if (argc < 3)
			usage();
		cmd = argv[1];

		if (strcmp(cmd, "roundtrip") == 0)
			return (cmdRoundtrip([NSString stringWithUTF8String:
			    argv[2]]));
		if (strcmp(cmd, "cat") == 0)
			return (cmdCat([NSString stringWithUTF8String:
			    argv[2]]));
		if (strcmp(cmd, "applearchive") == 0)
			return (cmdAppleArchive([NSString stringWithUTF8String:
			    argv[2]]));
		if (strcmp(cmd, "dump") == 0)
			return (cmdDump([NSString stringWithUTF8String:
			    argv[2]]));

		usage();
		return (2);
	}
}
