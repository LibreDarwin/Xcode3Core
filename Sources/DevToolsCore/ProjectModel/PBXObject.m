/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Base class for the project-model object graph (DevToolsCore). */

#import "DevToolsCore/PBXObject.h"

@implementation PBXObject

+ (NSString *)classNameForPListArchive
{
	return (NSStringFromClass(self));
}

+ (NSArray *)archivableAttributes
{
	return (@[]);
}

+ (NSArray *)archivableRelationships
{
	return (@[]);
}

/* Collect each class's own binding table along the PBXObject hierarchy
 * (base first) so subclasses only declare their own additions. */
+ (NSArray *)archivableKeys
{
	NSMutableArray *chain = [NSMutableArray array];
	NSMutableArray *keys = [NSMutableArray array];
	Class c = self;

	while (c != Nil && [c isSubclassOfClass:[PBXObject class]]) {
		[chain insertObject:c atIndex:0];
		c = [c superclass];
	}
	for (c in chain) {
		[keys addObjectsFromArray:[c archivableAttributes]];
		[keys addObjectsFromArray:[c archivableRelationships]];
	}
	return (keys);
}

+ (NSSet *)relationshipKeySet
{
	NSMutableSet *set = [NSMutableSet set];
	Class c = self;

	while (c != Nil && [c isSubclassOfClass:[PBXObject class]]) {
		[set addObjectsFromArray:[c archivableRelationships]];
		c = [c superclass];
	}
	return (set);
}

- (id)init
{
	if ((self = [super init]) != nil) {
		_extra = [[NSMutableDictionary alloc] init];
	}
	return (self);
}

- (void)dealloc
{
	/* ARC: no explicit [super dealloc]; ivars released automatically. */
}

- (NSString *)objectID
{
	return (_globalID);
}

- (void)setObjectID:(NSString *)objectID
{
	_globalID = [objectID copy];
}

- (PBXContainer *)container
{
	return (_container);
}

- (void)setContainer:(PBXContainer *)container
{
	_container = container;
}

- (NSString *)classNameForPListArchive
{
	return (_archiveClassName ?: [[self class] classNameForPListArchive]);
}

- (NSString *)archiveClassName
{
	return (_archiveClassName);
}

- (void)setArchiveClassName:(NSString *)name
{
	_archiveClassName = [name copy];
}

- (NSString *)archiveComment
{
	return (nil);
}

- (NSDictionary *)extraArchivedValues
{
	return (_extra);
}

- (void)setExtraArchivedValues:(NSDictionary *)values
{
	_extra = (values != nil) ? [values mutableCopy] :
	    [[NSMutableDictionary alloc] init];
}

- (id)archiveValueForKey:(NSString *)key
{
	@try {
		return ([self valueForKey:key]);
	} @catch (NSException *e) {
		return (nil);
	}
}

- (BOOL)setArchiveValue:(id)value forKey:(NSString *)key
{
	@try {
		[self setValue:value forKey:key];
		return (YES);
	} @catch (NSException *ex) {
		return (NO);
	}
}

- (NSString *)longDescription
{
	return ([NSString stringWithFormat:@"<%@ %@>",
	    [self classNameForPListArchive], _globalID ?: @"(new)"]);
}

- (NSString *)description
{
	return ([self longDescription]);
}

@end
