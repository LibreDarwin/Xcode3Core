/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * The complete project-model object graph (DevToolsCore). */

#import "DevToolsCore/PBXProjectModel.h"
#import "DevToolsCore/PBXProject.h"
#import "DevToolsCore/PBXReference.h"
#import "DevToolsCore/PBXBuild.h"
#import "DevToolsCore/XCBuildConfiguration.h"

#import "DevToolsCore/ProjectModel/pbxproj.h"
#import "PBXPListCoding.h"

#include <stdlib.h>
#include <string.h>

static NSString *const PBXProjectModelErrorDomain =
    @"PBXProjectModelErrorDomain";

/* isa name -> concrete class.  Unmodeled classes fall back to PBXObject,
 * which preserves all of their keys verbatim in the extra dictionary. */
static NSDictionary *PBXProjectModelClassRegistry(void)
{
	static NSDictionary *registry = nil;

	if (registry == nil) {
		registry = @{
		    @"PBXProject" : [PBXProject class],
		    @"PBXGroup" : [PBXGroup class],
		    @"PBXVariantGroup" : [PBXVariantGroup class],
		    @"PBXFileReference" : [PBXFileReference class],
		    @"PBXReferenceProxy" : [PBXReferenceProxy class],
		    @"PBXBuildFile" : [PBXBuildFile class],
		    @"PBXCopyFilesBuildPhase" : [PBXCopyFilesBuildPhase class],
		    @"PBXShellScriptBuildPhase" : [PBXShellScriptBuildPhase class],
		    @"PBXHeadersBuildPhase" : [PBXHeadersBuildPhase class],
		    @"PBXSourcesBuildPhase" : [PBXSourcesBuildPhase class],
		    @"PBXFrameworksBuildPhase" : [PBXFrameworksBuildPhase class],
		    @"PBXResourcesBuildPhase" : [PBXResourcesBuildPhase class],
		    @"PBXRezBuildPhase" : [PBXRezBuildPhase class],
		    @"PBXAppleScriptBuildPhase" : [PBXAppleScriptBuildPhase class],
		    @"PBXJavaArchiveBuildPhase"
		    : [PBXJavaArchiveBuildPhase class],
		    @"PBXBuildRule" : [PBXBuildRule class],
		    @"PBXBuildStyle" : [PBXBuildStyle class],
		    @"PBXContainerItemProxy" : [PBXContainerItemProxy class],
		    @"PBXTargetDependency" : [PBXTargetDependency class],
		    @"PBXNativeTarget" : [PBXNativeTarget class],
		    @"PBXAggregateTarget" : [PBXAggregateTarget class],
		    @"PBXLegacyTarget" : [PBXLegacyTarget class],
		    @"PBXJambaseTarget" : [PBXJambaseTarget class],
		    @"PBXWrappedTarget" : [PBXWrappedTarget class],
		    @"PBXApplicationTarget" : [PBXApplicationTarget class],
		    @"PBXFrameworkTarget" : [PBXFrameworkTarget class],
		    @"PBXBundleTarget" : [PBXBundleTarget class],
		    @"PBXLibraryTarget" : [PBXLibraryTarget class],
		    @"PBXToolTarget" : [PBXToolTarget class],
		    @"PBXFrameworkReference" : [PBXFrameworkReference class],
		    @"PBXLibraryReference" : [PBXLibraryReference class],
		    @"PBXBundleReference" : [PBXBundleReference class],
		    @"PBXApplicationReference" : [PBXApplicationReference class],
		    @"PBXExecutableFileReference"
		    : [PBXExecutableFileReference class],
		    @"PBXFileSystemSynchronizedAbstractGroup"
		    : [PBXFileSystemSynchronizedAbstractGroup class],
		    @"PBXFileSystemSynchronizedRootGroup"
		    : [PBXFileSystemSynchronizedRootGroup class],
		    @"PBXFileSystemSynchronizedGroupAbstractMembershipExceptionSet"
		    : [PBXFileSystemSynchronizedGroupAbstractMembershipExceptionSet
		    class],
		    @"PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet"
		    : [PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet
		    class],
		    @"PBXFileSystemSynchronizedBuildFileExceptionSet"
		    : [PBXFileSystemSynchronizedBuildFileExceptionSet class],
		    @"XCRemoteSwiftPackageReference"
		    : [XCRemoteSwiftPackageReference class],
		    @"XCLocalSwiftPackageReference"
		    : [XCLocalSwiftPackageReference class],
		    @"XCSwiftPackageProductDependency"
		    : [XCSwiftPackageProductDependency class],
		    @"XCVersionGroup" : [XCVersionGroup class],
		    @"XCBuildConfiguration" : [XCBuildConfiguration class],
		    @"XCConfigurationList" : [XCConfigurationList class],
		};
	}
	return (registry);
}

@interface PBXProjectModel ()
- (BOOL)_loadFromRootDictionary:(OPPValue *)root error:(NSError **)error;
- (id)_resolveReference:(OPPValue *)value;
- (OPPValue *)_archiveRelationshipValue:(id)value;
- (OPPValue *)_archiveObject:(PBXObject *)object;
- (OPPValue *)_archiveObjectsDictionary;
@end

@implementation PBXProjectModel

+ (instancetype)modelWithContentsOfFile:(NSString *)path error:(NSError **)error
{
	PBXProjectModel *model = [[self alloc] init];
	NSData *data = [NSData dataWithContentsOfFile:path];
	OPPDocument *doc;
	char *err = NULL;

	if (data == nil) {
		if (error != NULL)
			*error = [NSError errorWithDomain:PBXProjectModelErrorDomain
			    code:1 userInfo:@{ NSLocalizedDescriptionKey :
			    [NSString stringWithFormat:@"unable to read %@", path] }];
		return (nil);
	}
	doc = opp_parse_buffer([data bytes], [data length], &err);
	if (doc == NULL) {
		if (error != NULL)
			*error = [NSError errorWithDomain:PBXProjectModelErrorDomain
			    code:2 userInfo:@{ NSLocalizedDescriptionKey :
			    [NSString stringWithUTF8String:err ?: "parse error"] }];
		free(err);
		return (nil);
	}
	if (![model _loadFromRootDictionary:doc->root error:error]) {
		opp_document_free(doc);
		return (nil);
	}
	opp_document_free(doc);
	return (model);
}

+ (instancetype)modelWithArchiveString:(NSString *)string error:(NSError **)error
{
	PBXProjectModel *model = [[self alloc] init];
	OPPDocument *doc;
	const char *utf8 = [string UTF8String];
	char *err = NULL;

	doc = opp_parse_buffer(utf8, (utf8 != NULL) ? strlen(utf8) : 0, &err);
	if (doc == NULL) {
		if (error != NULL)
			*error = [NSError errorWithDomain:PBXProjectModelErrorDomain
			    code:2 userInfo:@{ NSLocalizedDescriptionKey :
			    [NSString stringWithUTF8String:err ?: "parse error"] }];
		free(err);
		return (nil);
	}
	if (![model _loadFromRootDictionary:doc->root error:error]) {
		opp_document_free(doc);
		return (nil);
	}
	opp_document_free(doc);
	return (model);
}

- (BOOL)_loadFromRootDictionary:(OPPValue *)root error:(NSError **)error
{
	OPPValue *objects;
	const char *v;
	NSUInteger i;

	if (root == NULL || root->kind != OPP_DICT) {
		if (error != NULL)
			*error = [NSError errorWithDomain:PBXProjectModelErrorDomain
			    code:3 userInfo:@{ NSLocalizedDescriptionKey :
			    @"root is not a dictionary" }];
		return (NO);
	}
	_objects = [[NSMutableDictionary alloc] init];
	_rootExtras = [[NSMutableDictionary alloc] init];

	v = opp_scalar_get(root, "archiveVersion");
	_archiveVersion = [NSString stringWithUTF8String:(v != NULL ? v : "1")];
	v = opp_scalar_get(root, "objectVersion");
	_objectVersion = [NSString stringWithUTF8String:(v != NULL ? v : "56")];

	objects = opp_dict_get(root, "objects");
	if (objects != NULL && objects->kind == OPP_DICT) {
		NSDictionary *registry = PBXProjectModelClassRegistry();

		/* Pass 1: materialize every object so identity can be resolved. */
		for (i = 0; i < objects->nentry; i++) {
			OPPValue *value = objects->entries[i].value;
			const char *isaName = opp_scalar_get(value, "isa");
			Class cls = (isaName != NULL) ?
			    registry[[NSString stringWithUTF8String:isaName]] : Nil;
			PBXObject *object;

			if (cls == Nil)
				cls = [PBXObject class];
			object = [[cls alloc] init];
			[object setObjectID:
			    [NSString stringWithUTF8String:objects->entries[i].key]];
			if (isaName != NULL)
				[object setArchiveClassName:
				    [NSString stringWithUTF8String:isaName]];
			_objects[[object objectID]] = object;
		}

		/* Pass 2: bind attributes and relationships. */
		for (i = 0; i < objects->nentry; i++) {
			OPPValue *value = objects->entries[i].value;
			PBXObject *object = _objects[[NSString stringWithUTF8String:
			    objects->entries[i].key]];
			NSSet *relationships = [[object class] relationshipKeySet];
			NSUInteger j;

			for (j = 0; j < value->nentry; j++) {
				const char *field = value->entries[j].key;
				NSString *name = [NSString stringWithUTF8String:field];
				id converted;

				if (strcmp(field, "isa") == 0)
					continue;
				if ([relationships containsObject:name])
					converted = [self _resolveReference:
					    value->entries[j].value];
				else
					converted = PBXObjectFromOPPValue(
					    value->entries[j].value);
				if (converted == nil)
					continue;
				if (![object setArchiveValue:converted forKey:name]) {
					NSMutableDictionary *extra =
					    [NSMutableDictionary dictionaryWithDictionary:
					    [object extraArchivedValues]];
					extra[name] = converted;
					[object setExtraArchivedValues:extra];
				}
			}
		}
	}

	v = opp_scalar_get(root, "rootObject");
	if (v != NULL)
		_rootObject = _objects[[NSString stringWithUTF8String:v]];

	for (PBXObject *object in [_objects allValues])
		[object setContainer:(PBXContainer *)_rootObject];

	for (i = 0; i < root->nentry; i++) {
		const char *key = root->entries[i].key;
		id value;

		if (strcmp(key, "archiveVersion") == 0 ||
		    strcmp(key, "objectVersion") == 0 ||
		    strcmp(key, "objects") == 0 ||
		    strcmp(key, "rootObject") == 0 ||
		    strcmp(key, "classes") == 0)
			continue;
		value = PBXObjectFromOPPValue(root->entries[i].value);
		if (value != nil)
			_rootExtras[[NSString stringWithUTF8String:key]] = value;
	}
	{
		OPPValue *classes = opp_dict_get(root, "classes");

		if (classes != NULL)
			_rootExtras[@"classes"] = PBXObjectFromOPPValue(classes);
	}
	return (YES);
}

- (id)_resolveReference:(OPPValue *)value
{
	if (value == NULL)
		return (nil);
	switch (value->kind) {
	case OPP_STRING: {
		NSString *ref = [NSString stringWithUTF8String:value->str];
		PBXObject *target = _objects[ref];

		return ((target != nil) ? target : ref);
	}
	case OPP_ARRAY: {
		NSMutableArray *array = [NSMutableArray
		    arrayWithCapacity:value->nelem];
		NSUInteger i;

		for (i = 0; i < value->nelem; i++) {
			id element = [self _resolveReference:
			    value->elems[i].value];
			[array addObject:(element != nil) ? element :
			    [NSNull null]];
		}
		return (array);
	}
	default:
		return (PBXObjectFromOPPValue(value));
	}
}

- (PBXObject *)rootObject
{
	return (_rootObject);
}

- (NSDictionary *)objects
{
	return (_objects);
}

- (PBXObject *)objectForID:(NSString *)objectID
{
	return (_objects[objectID]);
}

- (NSArray *)objectsOfClass:(Class)cls
{
	NSMutableArray *result = [NSMutableArray array];

	for (PBXObject *object in [_objects allValues]) {
		if ([object isKindOfClass:cls])
			[result addObject:object];
	}
	return (result);
}

- (void)addObject:(PBXObject *)object
{
	if (object != nil && [object objectID] != nil)
		_objects[[object objectID]] = object;
}

- (void)removeObject:(PBXObject *)object
{
	if (object != nil && [object objectID] != nil)
		[_objects removeObjectForKey:[object objectID]];
}

- (NSString *)archiveVersion
{
	return (_archiveVersion);
}

- (void)setArchiveVersion:(NSString *)version
{
	_archiveVersion = [version copy];
}

- (NSString *)objectVersion
{
	return (_objectVersion);
}

- (void)setObjectVersion:(NSString *)version
{
	_objectVersion = [version copy];
}

- (OPPValue *)_archiveRelationshipValue:(id)value
{
	if ([value isKindOfClass:[PBXObject class]])
		return (opp_string_new([[value objectID] UTF8String]));
	if ([value isKindOfClass:[NSArray class]]) {
		OPPValue *array = opp_array_new();
		id element;

		for (element in (NSArray *)value)
			opp_array_append(array,
			    [self _archiveRelationshipValue:element]);
		return (array);
	}
	if (value == nil || value == [NSNull null])
		return (opp_string_new(""));
	return (PBXOPPValueFromObject(value));
}

- (OPPValue *)_archiveObject:(PBXObject *)object
{
	OPPValue *dict = opp_dict_new();
	NSSet *relationships = [[object class] relationshipKeySet];
	NSArray *keys = [[object class] archivableKeys];
	NSString *key;

	opp_dict_set(dict, "isa",
	    opp_string_new([[object classNameForPListArchive] UTF8String]));
	for (key in keys) {
		id value = [object archiveValueForKey:key];

		if (value == nil)
			continue;
		if ([relationships containsObject:key]) {
			NSString *comment = [value isKindOfClass:[PBXObject class]] ?
			    [value archiveComment] : nil;

			opp_dict_set(dict, [key UTF8String],
			    [self _archiveRelationshipValue:value]);
			if (comment != nil)
				opp_dict_set_comment(dict, [key UTF8String],
				    NULL, [comment UTF8String]);
		} else {
			opp_dict_set(dict, [key UTF8String],
			    PBXOPPValueFromObject(value));
		}
	}
	for (key in [[[object extraArchivedValues] allKeys]
	    sortedArrayUsingSelector:@selector(compare:)]) {
		opp_dict_set(dict, [key UTF8String],
		    PBXOPPValueFromObject([[object extraArchivedValues]
		    objectForKey:key]));
	}
	return (dict);
}

- (OPPValue *)_archiveObjectsDictionary
{
	OPPValue *objects = opp_dict_new();
	NSArray *all = [[_objects allValues] sortedArrayUsingComparator:
	    ^NSComparisonResult(PBXObject *a, PBXObject *b) {
		NSString *ia = [a classNameForPListArchive];
		NSString *ib = [b classNameForPListArchive];
		NSComparisonResult r = [ia compare:ib];

		if (r != NSOrderedSame)
			return (r);
		return ([[a objectID] compare:[b objectID]]);
	}];
	PBXObject *object;

	for (object in all) {
		opp_dict_append(objects, [[object objectID] UTF8String],
		    [self _archiveObject:object]);
	}
	return (objects);
}

- (NSString *)archiveString
{
	OPPValue *root = opp_dict_new();
	OPPDocument *doc;
	char *err = NULL;
	char *text;
	size_t length = 0;
	NSString *result;
	NSString *key;
	id classesValue = _rootExtras[@"classes"];

	opp_dict_set(root, "archiveVersion",
	    opp_string_new([(_archiveVersion ?: @"1") UTF8String]));
	opp_dict_set(root, "classes", (classesValue != nil) ?
	    PBXOPPValueFromObject(classesValue) : opp_dict_new());
	opp_dict_set(root, "objectVersion",
	    opp_string_new([(_objectVersion ?: @"56") UTF8String]));
	opp_dict_set(root, "objects", [self _archiveObjectsDictionary]);
	if (_rootObject != nil) {
		NSString *comment = [_rootObject archiveComment];

		opp_dict_set(root, "rootObject",
		    opp_string_new([[_rootObject objectID] UTF8String]));
		if (comment != nil)
			opp_dict_set_comment(root, "rootObject", NULL,
			    [comment UTF8String]);
	}
	for (key in [[_rootExtras allKeys]
	    sortedArrayUsingSelector:@selector(compare:)]) {
		if ([key isEqualToString:@"classes"])
			continue;
		opp_dict_set(root, [key UTF8String],
		    PBXOPPValueFromObject(_rootExtras[key]));
	}

	doc = opp_document_new(root);
	text = opp_write_document(doc, &length, &err);
	opp_document_free(doc);
	if (text == NULL)
		return (nil);
	result = [NSString stringWithUTF8String:text];
	free(text);
	return (result);
}

- (BOOL)writeToFile:(NSString *)path error:(NSError **)error
{
	NSString *string = [self archiveString];

	if (string == nil) {
		if (error != NULL)
			*error = [NSError errorWithDomain:PBXProjectModelErrorDomain
			    code:4 userInfo:@{ NSLocalizedDescriptionKey :
			    @"unable to archive object graph" }];
		return (NO);
	}
	return ([string writeToFile:path atomically:YES
	    encoding:NSUTF8StringEncoding error:error]);
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
	NSString *string = [self archiveString];

	if (string == nil)
		return (NO);
	return ([string writeToFile:path atomically:useAuxiliaryFile
	    encoding:NSUTF8StringEncoding error:NULL]);
}

@end
