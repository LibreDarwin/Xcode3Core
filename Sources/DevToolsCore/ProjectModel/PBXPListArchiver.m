/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Minimal PList archiver support for PBXArchiveBinding. */

#import "DevToolsCore/ProjectModel/PBXPListArchiver.h"

@implementation PBXPListArchiver

- (instancetype)initWithRootObject:(id)root
    delegate:(id)delegate
    role:(NSUInteger)role
{
	if ((self = [super init]) != nil) {
		_rootObject = root;
		_delegate = delegate;
		_role = role;
		_values = [[NSMutableDictionary alloc] init];
	}
	return (self);
}

- (void)encodeObject:(id)value forKey:(NSString *)key
{
	if (key == nil)
		return;
	if (value == nil)
		value = [NSNull null];
	[_values setObject:value forKey:key];
}

- (void)encodeString:(NSString *)value forKey:(NSString *)key
{
	[self encodeObject:value forKey:key];
}

- (void)encodeInteger:(NSInteger)value forKey:(NSString *)key
{
	[self encodeObject:@(value) forKey:key];
}

- (void)encodeBool:(BOOL)value forKey:(NSString *)key
{
	[self encodeObject:@(value) forKey:key];
}

- (void)encodeDouble:(double)value forKey:(NSString *)key
{
	[self encodeObject:@(value) forKey:key];
}

- (NSDictionary *)archive
{
	return ([_values copy]);
}

@end

@implementation PBXPListUnarchiver

- (instancetype)initWithPListArchive:(NSDictionary *)archive
{
	if ((self = [super init]) != nil)
		_archive = [archive copy];
	return (self);
}

- (id)valueForKey:(NSString *)key
{
	if (key == nil)
		return (nil);
	return ([_archive objectForKey:key]);
}

- (id)decodeObjectForKey:(NSString *)key
{
	id value = [self valueForKey:key];

	if (value == [NSNull null])
		return (nil);
	return (value);
}

- (NSString *)decodeStringForKey:(NSString *)key
{
	return ([self decodeObjectForKey:key]);
}

- (NSInteger)decodeIntegerForKey:(NSString *)key
{
	id value = [self decodeObjectForKey:key];

	return ([value respondsToSelector:@selector(integerValue)] ?
	    [value integerValue] : 0);
}

- (BOOL)decodeBoolForKey:(NSString *)key
{
	id value = [self decodeObjectForKey:key];

	return ([value respondsToSelector:@selector(boolValue)] ?
	    [value boolValue] : NO);
}

- (double)decodeDoubleForKey:(NSString *)key
{
	id value = [self decodeObjectForKey:key];

	return ([value respondsToSelector:@selector(doubleValue)] ?
	    [value doubleValue] : 0.0);
}

@end
