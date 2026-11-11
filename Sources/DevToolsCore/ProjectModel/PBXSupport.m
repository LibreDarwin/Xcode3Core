/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Platform filters, object identifiers and group enumeration. */

#import "DevToolsCore/PBXGroupEnumerator.h"
#import "DevToolsCore/PBXObjectID.h"
#import "DevToolsCore/PBXPlatformFilter.h"
#import "DevToolsCore/PBXReference.h"

@implementation PBXPlatformFilter

+ (NSDictionary *)filterDescriptionToPlatformName
{
	return (@{@"iOS": @"ios", @"macOS": @"macos", @"tvOS": @"tvos",
	    @"watchOS": @"watchos", @"bridgeOS": @"bridgeos",
	    @"visionOS": @"xros", @"DriverKit": @"driverkit"});
}

+ (NSArray *)allFilters
{
	static NSArray *filters = nil;

	if (filters == nil) {
		NSMutableArray *array = [NSMutableArray array];
		NSArray *platforms = @[@"ios", @"macos", @"tvos", @"watchos",
		    @"bridgeos", @"xros", @"driverkit"];
		NSArray *environments = @[@"simulator", @"maccatalyst",
		    @"marketing"];
		NSString *platform;

		for (platform in platforms) {
			NSString *environment;

			[array addObject:[[self alloc] initWithPlatform:platform
			    environment:nil]];
			for (environment in environments) {
				[array addObject:[[self alloc]
				    initWithPlatform:platform
				    environment:environment]];
			}
		}
		filters = [array copy];
	}
	return (filters);
}

- (instancetype)initWithPlatform:(NSString *)platform
    environment:(NSString *)environment
{
	return ([self initWithPlatform:platform environment:environment
	    displayName:nil impliedByPlatform:nil]);
}

- (instancetype)initWithPlatform:(NSString *)platform
    environment:(NSString *)environment displayName:(NSString *)name
{
	return ([self initWithPlatform:platform environment:environment
	    displayName:name impliedByPlatform:nil]);
}

- (instancetype)initWithPlatform:(NSString *)platform
    environment:(NSString *)environment
    impliedByPlatform:(NSString *)implied
{
	return ([self initWithPlatform:platform environment:environment
	    displayName:nil impliedByPlatform:implied]);
}

- (instancetype)initWithPlatform:(NSString *)platform
    environment:(NSString *)environment displayName:(NSString *)name
    impliedByPlatform:(NSString *)implied
{
	self = [super init];
	if (self != nil) {
		_platform = [platform copy];
		_environment = [environment copy];
		_displayName = [name copy];
		_impliedByPlatform = [implied copy];
	}
	return (self);
}

+ (instancetype)filterFromDictionary:(NSDictionary *)dictionary
{
	NSString *platform = [dictionary objectForKey:@"platform"];
	NSString *environment = [dictionary objectForKey:@"environment"];

	if (platform == nil)
		platform = [dictionary objectForKey:@"platformName"];
	if (platform == nil)
		return (nil);
	return ([[self alloc] initWithPlatform:platform
	    environment:environment]);
}

+ (instancetype)filterFromString:(NSString *)string
{
	NSRange dash;

	if ([string length] == 0)
		return (nil);
	dash = [string rangeOfString:@"-"];
	if (dash.location == NSNotFound)
		return ([[self alloc] initWithPlatform:string
		    environment:nil]);
	return ([[self alloc]
	    initWithPlatform:[string substringToIndex:dash.location]
	    environment:[string substringFromIndex:dash.location + 1]]);
}

+ (NSArray *)friendlySerializableValuesFromFilters:(NSArray *)filters
{
	NSMutableArray *values = [NSMutableArray array];
	PBXPlatformFilter *filter;

	for (filter in filters) {
		if ([filter isKindOfClass:[PBXPlatformFilter class]])
			[values addObject:[filter friendlySerializableValue]];
	}
	return (values);
}

+ (NSArray *)filtersFromFriendlySerializableValue:(NSString *)value
{
	PBXPlatformFilter *filter = [self filterFromString:value];

	return ((filter != nil) ? @[ filter ] : @[]);
}

+ (NSArray *)filtersFromFriendlySerializableValues:(NSArray *)values
{
	NSMutableArray *filters = [NSMutableArray array];
	id value;

	for (value in values) {
		if ([value isKindOfClass:[PBXPlatformFilter class]])
			[filters addObject:value];
		else if ([value isKindOfClass:[NSString class]])
			[filters addObjectsFromArray:
			    [self filtersFromFriendlySerializableValue:value]];
	}
	return (filters);
}

- (NSString *)platform
{
	return (_platform);
}

- (NSString *)environment
{
	return (_environment);
}

- (NSString *)impliedByPlatform
{
	return (_impliedByPlatform);
}

- (NSString *)friendlySerializableValue
{
	if ([_environment length] == 0)
		return (_platform);
	return ([NSString stringWithFormat:@"%@-%@", _platform,
	    _environment]);
}

- (NSString *)displayName
{
	if (_displayName != nil)
		return (_displayName);
	if (_environment != nil)
		return ([NSString stringWithFormat:@"%@ (%@)", _platform,
		    _environment]);
	return (_platform);
}

- (NSDictionary *)dictionaryForm
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

	if (_platform != nil)
		[dictionary setObject:_platform forKey:@"platform"];
	if (_environment != nil)
		[dictionary setObject:_environment forKey:@"environment"];
	return (dictionary);
}

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:[PBXPlatformFilter class]])
		return (NO);
	return ([[self friendlySerializableValue]
	    isEqualToString:[object friendlySerializableValue]]);
}

- (NSUInteger)hash
{
	return ([[self friendlySerializableValue] hash]);
}

- (NSComparisonResult)compare:(PBXPlatformFilter *)other
{
	return ([[self friendlySerializableValue]
	    compare:[other friendlySerializableValue]]);
}

- (NSString *)description
{
	return ([self friendlySerializableValue]);
}

@end

@implementation PBXObjectID

- (instancetype)init
{
	return ([self initFromStringRepresentation:@""]);
}

- (instancetype)initFromStringRepresentation:(NSString *)representation
{
	self = [super init];
	if (self != nil)
		_stringRepresentation = [representation copy];
	return (self);
}

- (NSString *)stringRepresentation
{
	return (_stringRepresentation);
}

- (NSUInteger)length
{
	return ([_stringRepresentation length]);
}

- (unichar)characterAtIndex:(NSUInteger)index
{
	return ([_stringRepresentation characterAtIndex:index]);
}

- (void)getCharacters:(unichar *)buffer range:(NSRange)range
{
	[_stringRepresentation getCharacters:buffer range:range];
}

- (id)copyWithZone:(NSZone *)zone
{
	(void)zone;
	return (self);
}

- (BOOL)isEqual:(id)object
{
	if ([object isKindOfClass:[PBXObjectID class]])
		return ([_stringRepresentation
		    isEqualToString:[object stringRepresentation]]);
	if ([object isKindOfClass:[NSString class]])
		return ([_stringRepresentation isEqualToString:object]);
	return (NO);
}

- (NSUInteger)hash
{
	return ([_stringRepresentation hash]);
}

- (NSComparisonResult)compare:(id)string options:(NSStringCompareOptions)mask
    range:(NSRange)range
{
	return ([_stringRepresentation compare:string options:mask
	    range:range]);
}

- (const char *)_fastCStringContents:(BOOL)nullTerminated
{
	(void)nullTerminated;
	return (NULL);
}

- (NSString *)description
{
	return (_stringRepresentation);
}

@end

static void CollectGroupItems(id item, NSMutableArray *array)
{
	id child;

	[array addObject:item];
	if (![item isKindOfClass:[PBXGroup class]])
		return;
	for (child in [(PBXGroup *)item children])
		CollectGroupItems(child, array);
}

@implementation PBXGroupEnumerator

+ (SEL)traversalSelector
{
	return (@selector(children));
}

+ (instancetype)enumeratorForGroup:(PBXGroup *)group
{
	return ([[self alloc] initWithRootArray:@[ group ] nextObject:nil]);
}

+ (instancetype)enumeratorForGroup:(PBXGroup *)group
    startingAtItem:(id)item
{
	return ([[self alloc] initWithRootArray:@[ group ]
	    nextObject:item]);
}

- (instancetype)initWithRootArray:(NSArray *)array nextObject:(id)object
{
	self = [super init];
	if (self != nil) {
		NSMutableArray *objects = [NSMutableArray array];
		id root;

		for (root in array)
			CollectGroupItems(root, objects);
		_objects = objects;
		_index = 0;
		if (object != nil)
			[self setNextObject:object];
	}
	return (self);
}

- (id)copyWithZone:(NSZone *)zone
{
	PBXGroupEnumerator *copy = [[PBXGroupEnumerator allocWithZone:zone]
	    initWithRootArray:@[] nextObject:nil];

	copy->_objects = [_objects mutableCopy];
	copy->_index = _index;
	return (copy);
}

- (id)nextObject
{
	if (_index >= [_objects count])
		return (nil);
	return (_objects[_index++]);
}

- (void)rewind
{
	_index = 0;
}

- (NSArray *)allObjects
{
	return ([_objects copy]);
}

- (NSUInteger)numberOfObjects
{
	return ([_objects count]);
}

- (void)setNextObject:(id)object
{
	NSUInteger index = [_objects indexOfObjectIdenticalTo:object];

	if (index == NSNotFound)
		index = [_objects indexOfObject:object];
	_index = (index == NSNotFound) ? [_objects count] : index;
}

- (id)previousObject
{
	if (_index == 0)
		return (nil);
	return (_objects[--_index]);
}

- (id)firstObject
{
	return ([_objects firstObject]);
}

- (id)lastObject
{
	return ([_objects lastObject]);
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
    objects:(id __unsafe_unretained [])buffer count:(NSUInteger)length
{
	NSUInteger start;
	NSUInteger count;
	NSUInteger i;

	if (state->state == 0)
		state->state = _index + 1;
	start = state->state - 1;
	count = [_objects count];
	if (start >= count)
		return (0);
	if (count - start < length)
		length = count - start;
	for (i = 0; i < length; i++)
		buffer[i] = _objects[start + i];
	state->itemsPtr = buffer;
	state->mutationsPtr = (unsigned long *)&_mutations;
	state->state = start + length + 1;
	return (length);
}

@end
