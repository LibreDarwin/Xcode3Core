/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsCore/BuildSystem/XCPropertyCategory.h"

#import "DevToolsSupport/TSPropertyListDictionary.h"

@implementation XCPropertyCategory

- (instancetype)init
{
	return ([self initWithName:@"" propertyNames:@[]]);
}

- (instancetype)initWithName:(NSString *)name
{
	return ([self initWithName:name propertyNames:@[]]);
}

- (instancetype)initWithName:(NSString *)name propertyNames:(NSArray *)names
{
	return ([self initWithName:name propertyNames:names stringsDictionary:nil]);
}

- (instancetype)initWithName:(NSString *)name
		   propertyNames:(NSArray *)names
		stringsDictionary:(NSDictionary *)strings
{
	self = [super init];
	if (self != nil) {
		_name = [name copy];
		_propertyNames = [names mutableCopy];
		if (_propertyNames == nil)
			_propertyNames = [NSMutableArray array];
		if ([strings isKindOfClass:[NSDictionary class]]) {
			NSString *localized = [strings objectForKey:_name];

			if ([localized isKindOfClass:[NSString class]])
				_localizedName = [localized copy];
			localized = [strings objectForKey:[_name stringByAppendingString:@".description"]];
			if ([localized isKindOfClass:[NSString class]])
				_localizedDescription = [localized copy];
		}
		if (_localizedName == nil)
			_localizedName = [_name copy];
	}
	return (self);
}

- (instancetype)initWithPropertyListDictionary:(TSPropertyListDictionary *)dictionary
{
	NSString *name;
	NSArray *options;

	if (![dictionary isKindOfClass:[NSDictionary class]])
		[NSException raise:NSInvalidArgumentException format:
		    @"%@ should be an instance inheriting from %@, but it is %@",
		    @"dictionary", [NSDictionary class], [dictionary class]];
	name = [dictionary stringOrNilForKey:@"Name"];
	options = [dictionary arrayOrNilForKey:@"Options"];
	if (options == nil)
		options = [dictionary arrayOrNilForKey:@"PropertyNames"];
	self = [self initWithName:name propertyNames:options
		   stringsDictionary:[dictionary localizationDictionary]];
	if (self != nil) {
		_iconName = [dictionary stringOrNilForKey:@"IconName"];
	}
	return (self);
}

- (id)copyWithZone:(NSZone *)zone
{
	XCPropertyCategory *copy = [[XCPropertyCategory allocWithZone:zone]
	    initWithName:_name propertyNames:_propertyNames stringsDictionary:nil];

	copy->_iconName = [_iconName copy];
	copy->_isUserDefined = _isUserDefined;
	copy->_localizedName = [_localizedName copy];
	copy->_localizedDescription = [_localizedDescription copy];
	return (copy);
}

- (NSString *)name
{
	return (_name);
}

- (NSArray *)propertyNames
{
	return (_propertyNames);
}

- (NSArray *)propertyDefinitionsWithLookupDictionary:(NSDictionary *)dictionary
{
	NSMutableArray *definitions = [NSMutableArray array];

	for (NSString *name in _propertyNames) {
		id definition = [dictionary objectForKey:name];

		if (definition != nil)
			[definitions addObject:definition];
	}
	return (definitions);
}

- (NSString *)iconName
{
	return (_iconName);
}

- (void)setIconName:(NSString *)name
{
	_iconName = [name copy];
}

- (BOOL)isUserDefined
{
	return (_isUserDefined);
}

- (void)setUserDefined:(BOOL)defined
{
	_isUserDefined = defined;
}

- (void)addOptionName:(NSString *)name
      aboveOptionName:(NSString *)above
      belowOptionName:(NSString *)below
{
	NSUInteger index;

	if (name == nil || [_propertyNames containsObject:name])
		return;
	if (above != nil) {
		index = [_propertyNames indexOfObject:above];
		if (index != NSNotFound) {
			[_propertyNames insertObject:name atIndex:index];
			return;
		}
	}
	if (below != nil) {
		index = [_propertyNames indexOfObject:below];
		if (index != NSNotFound) {
			[_propertyNames insertObject:name atIndex:index + 1];
			return;
		}
	}
	[_propertyNames addObject:name];
}

- (void)removeOptionName:(NSString *)name
{
	if (name != nil)
		[_propertyNames removeObject:name];
}

- (NSString *)localizedName
{
	return (_localizedName);
}

- (NSString *)localizedDescription
{
	return (_localizedDescription);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@:'%@':%@>",
	    NSStringFromClass([self class]), _name, _propertyNames]);
}

@end
