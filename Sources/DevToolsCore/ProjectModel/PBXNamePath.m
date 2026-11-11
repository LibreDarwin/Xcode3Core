/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Name paths and anchored references. */

#import "DevToolsCore/PBXAnchoredReference.h"
#import "DevToolsCore/PBXNamePath.h"
#import "DevToolsCore/PBXReference.h"

@implementation PBXNamePathComponent

+ (instancetype)parentReference
{
	return ([[self alloc] initWithName:@".."
	    type:PBXNamePathComponentTypeParent]);
}

+ (instancetype)selfReference
{
	return ([[self alloc] initWithName:@"."
	    type:PBXNamePathComponentTypeSelf]);
}

+ (instancetype)componentForSlashSeparatedComponent:(NSString *)component
{
	if ([component isEqualToString:@".."])
		return ([self parentReference]);
	if ([component isEqualToString:@"."])
		return ([self selfReference]);
	return ([[self alloc] initWithName:component
	    type:PBXNamePathComponentTypeName]);
}

+ (instancetype)componentWithPlistRepresentation:(id)representation
{
	if ([representation isKindOfClass:[NSString class]])
		return ([self componentForSlashSeparatedComponent:representation]);
	if ([representation isKindOfClass:[NSDictionary class]]) {
		NSString *type = [representation objectForKey:@"type"];
		NSString *name = [representation objectForKey:@"name"];

		if ([type isEqualToString:@"parent"])
			return ([self parentReference]);
		if ([type isEqualToString:@"self"])
			return ([self selfReference]);
		if (name != nil)
			return ([[self alloc] initWithName:name
			    type:PBXNamePathComponentTypeName]);
	}
	return (nil);
}

- (instancetype)initWithName:(NSString *)name
{
	return ([self initWithName:name type:PBXNamePathComponentTypeName]);
}

- (instancetype)initWithName:(NSString *)name
    type:(PBXNamePathComponentType)type
{
	self = [super init];
	if (self != nil) {
		_name = [name copy];
		_componentType = type;
	}
	return (self);
}

- (NSUInteger)componentType
{
	return (_componentType);
}

- (NSString *)name
{
	return (_name);
}

- (NSString *)componentDisplayName
{
	switch (_componentType) {
	case PBXNamePathComponentTypeParent:
		return (@"..");
	case PBXNamePathComponentTypeSelf:
		return (@".");
	default:
		return (_name);
	}
}

- (NSString *)pathComponentLikeRepresentation
{
	return ([self componentDisplayName]);
}

- (NSString *)representationInSlashSeparatedPath
{
	return ([self componentDisplayName]);
}

- (BOOL)representableInSlashSeparatorPath
{
	if (_componentType != PBXNamePathComponentTypeName)
		return (YES);
	if ([_name length] == 0 || [_name isEqualToString:@"."] ||
	    [_name isEqualToString:@".."])
		return (NO);
	return ([_name rangeOfString:@"/"].location == NSNotFound);
}

- (id)plistDictionaryRepresentation
{
	switch (_componentType) {
	case PBXNamePathComponentTypeParent:
		return (@{@"type": @"parent"});
	case PBXNamePathComponentTypeSelf:
		return (@{@"type": @"self"});
	default:
		return (@{@"name": (_name != nil) ? _name : @""});
	}
}

- (id)copyWithZone:(NSZone *)zone
{
	(void)zone;
	return (self);
}

- (BOOL)isEqualToNamePathComponent:(PBXNamePathComponent *)component
{
	if (_componentType != [component componentType])
		return (NO);
	return ([[self componentDisplayName]
	    isEqualToString:[component componentDisplayName]]);
}

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:[PBXNamePathComponent class]])
		return (NO);
	return ([self isEqualToNamePathComponent:object]);
}

- (NSUInteger)hash
{
	return ([[self componentDisplayName] hash]);
}

- (NSString *)description
{
	return ([self componentDisplayName]);
}

@end

@implementation PBXNamePath

+ (instancetype)emptyPath
{
	static PBXNamePath *empty = nil;

	if (empty == nil)
		empty = [[self alloc] initWithComponents:@[]];
	return (empty);
}

+ (instancetype)namePathFromPlistRepresentation:(id)representation
{
	NSMutableArray *components = [NSMutableArray array];
	id item;

	if (![representation isKindOfClass:[NSArray class]])
		return (nil);
	for (item in representation) {
		PBXNamePathComponent *component =
		    [PBXNamePathComponent componentWithPlistRepresentation:item];

		if (component == nil)
			return (nil);
		[components addObject:component];
	}
	return ([[self alloc] initWithComponents:components]);
}

+ (instancetype)relativeNamePathFrom:(PBXReference *)from
    to:(PBXReference *)to
{
	NSMutableArray *fromChain = [NSMutableArray array];
	NSMutableArray *toChain = [NSMutableArray array];
	NSMutableArray *components = [NSMutableArray array];
	PBXReference *item;
	NSUInteger fromIndex = NSNotFound;
	NSUInteger commonInTo = NSNotFound;
	NSUInteger i;

	for (item = from; item != nil; item = [item group])
		[fromChain addObject:item];
	for (item = to; item != nil; item = [item group])
		[toChain addObject:item];
	for (i = 0; i < [fromChain count] && fromIndex == NSNotFound; i++) {
		NSUInteger j = [toChain indexOfObjectIdenticalTo:fromChain[i]];

		if (j != NSNotFound) {
			fromIndex = i;
			commonInTo = j;
		}
	}
	if (fromIndex == NSNotFound) {
		NSString *name = [to displayName];

		if (name == nil)
			return ([self emptyPath]);
		return ([[self alloc] initWithComponents:
		    @[[[PBXNamePathComponent alloc] initWithName:name]]]);
	}
	for (i = 0; i < fromIndex; i++)
		[components addObject:[PBXNamePathComponent parentReference]];
	for (i = commonInTo; i > 0; i--) {
		NSString *name = [toChain[i - 1] displayName];

		if (name == nil)
			name = @"";
		[components addObject:[[PBXNamePathComponent alloc]
		    initWithName:name]];
	}
	return ([[self alloc] initWithComponents:components]);
}

- (instancetype)initWithComponents:(NSArray *)components
{
	self = [super init];
	if (self != nil)
		_components = [components copy];
	return (self);
}

- (NSArray *)components
{
	return (_components);
}

- (BOOL)hasContent
{
	return ([_components count] != 0);
}

- (NSString *)displablePath
{
	return ([self pathLikeRepresentation]);
}

- (NSString *)pathLikeRepresentation
{
	NSMutableArray *parts = [NSMutableArray array];
	PBXNamePathComponent *component;

	for (component in _components)
		[parts addObject:[component representationInSlashSeparatedPath]];
	return ([parts componentsJoinedByString:@"/"]);
}

- (id)plistRepresentation
{
	NSMutableArray *array = [NSMutableArray array];
	PBXNamePathComponent *component;

	for (component in _components)
		[array addObject:[component plistDictionaryRepresentation]];
	return (array);
}

- (PBXReference *)resolveFromAnchor:(PBXReference *)anchor
{
	PBXReference *current = anchor;
	PBXNamePathComponent *component;

	for (component in _components) {
		switch ([component componentType]) {
		case PBXNamePathComponentTypeParent:
			current = [current group];
			break;
		case PBXNamePathComponentTypeSelf:
			break;
		default: {
			PBXReference *child;
			PBXReference *match = nil;

			if (![current isGroup])
				return (nil);
			for (child in [current children]) {
				NSString *name = [component name];

				if ([[child displayName] isEqualToString:name] ||
				    [[child name] isEqualToString:name]) {
					match = child;
					break;
				}
			}
			current = match;
			break;
		}
		}
		if (current == nil)
			return (nil);
	}
	return (current);
}

- (id)copyWithZone:(NSZone *)zone
{
	(void)zone;
	return (self);
}

- (BOOL)isEqualToNamePath:(PBXNamePath *)path
{
	return ([_components isEqualToArray:[path components]]);
}

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:[PBXNamePath class]])
		return (NO);
	return ([self isEqualToNamePath:object]);
}

- (NSUInteger)hash
{
	return ([_components hash]);
}

- (NSString *)description
{
	return ([self pathLikeRepresentation]);
}

@end

@implementation PBXAnchoredReference

- (instancetype)initWithAnchor:(PBXReference *)anchor
    relativeNamePath:(PBXNamePath *)path
{
	self = [super init];
	if (self != nil) {
		_anchor = anchor;
		_relativeNamePath = (path != nil) ? path : [PBXNamePath emptyPath];
	}
	return (self);
}

- (instancetype)initWithReference:(PBXReference *)reference
    inferringAnchor:(BOOL)infer
{
	PBXReference *anchor = [reference group];
	PBXNamePath *path;

	if (!infer || anchor == nil)
		return ([self initWithAnchor:reference
		    relativeNamePath:[PBXNamePath emptyPath]]);
	path = [[PBXNamePath alloc] initWithComponents:
	    @[[[PBXNamePathComponent alloc]
	    initWithName:[reference displayName]]]];
	return ([self initWithAnchor:anchor relativeNamePath:path]);
}

- (PBXReference *)anchor
{
	return (_anchor);
}

- (PBXNamePath *)relativeNamePath
{
	return (_relativeNamePath);
}

- (BOOL)hasRelativePortion
{
	return ([_relativeNamePath hasContent]);
}

- (NSString *)singlePathComponentDisplayName
{
	NSArray *components = [_relativeNamePath components];

	if ([components count] != 1)
		return (nil);
	if ([[components objectAtIndex:0] componentType] !=
	    PBXNamePathComponentTypeName)
		return (nil);
	return ([[components objectAtIndex:0] name]);
}

- (PBXReference *)resolveReference
{
	return ([_relativeNamePath resolveFromAnchor:_anchor]);
}

- (id)copyWithZone:(NSZone *)zone
{
	(void)zone;
	return (self);
}

- (BOOL)isEqualToAnchoredReference:(PBXAnchoredReference *)reference
{
	if (_anchor != [reference anchor])
		return (NO);
	return ([_relativeNamePath
	    isEqualToNamePath:[reference relativeNamePath]]);
}

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:[PBXAnchoredReference class]])
		return (NO);
	return ([self isEqualToAnchoredReference:object]);
}

- (NSUInteger)hash
{
	return (((NSUInteger)_anchor) ^ [_relativeNamePath hash]);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"%@:%@",
	    [_anchor displayName], [_relativeNamePath pathLikeRepresentation]]);
}

@end
