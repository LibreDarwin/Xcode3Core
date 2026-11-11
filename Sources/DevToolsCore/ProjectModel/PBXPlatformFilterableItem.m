/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Items carrying platform filters. */

#import "DevToolsCore/PBXPlatformFilterableItem.h"
#import "DevToolsCore/PBXPlatformFilter.h"

@implementation PBXPlatformFilterableItem

+ (NSArray *)archivableAttributes
{
	/* Concrete subclasses declare the keys in archive order so that
	 * round-tripping stays byte-identical. */
	return (@[]);
}

- (NSArray *)platformFilters
{
	return (_platformFilters);
}

- (void)setPlatformFilters:(NSArray *)filters
{
	_platformFilters = (filters != nil) ? [filters copy] : nil;
}

- (NSString *)platformFilter
{
	return (_platformFilter);
}

- (void)setPlatformFilter:(NSString *)filter
{
	_platformFilter = [filter copy];
}

- (NSArray *)_platformFilters
{
	return (_platformFilters);
}

- (void)_setPlatformFilters:(NSArray *)filters
{
	[self setPlatformFilters:filters];
}

- (NSString *)_platformFilter
{
	return (_platformFilter);
}

- (void)_setPlatformFilter:(NSString *)filter
{
	[self setPlatformFilter:filter];
}

- (NSSet *)_allPlatformFilters
{
	NSMutableSet *result = [NSMutableSet set];
	NSArray *values = _platformFilters;
	id value;

	if (values == nil && _platformFilter != nil)
		values = @[ _platformFilter ];
	for (value in values) {
		PBXPlatformFilter *filter = nil;

		if ([value isKindOfClass:[PBXPlatformFilter class]])
			filter = value;
		else if ([value isKindOfClass:[NSString class]])
			filter = [PBXPlatformFilter filterFromString:value];
		else if ([value isKindOfClass:[NSDictionary class]])
			filter = [PBXPlatformFilter filterFromDictionary:value];
		if (filter != nil)
			[result addObject:filter];
	}
	return (result);
}

- (NSSet *)unknownPlatformFilters
{
	NSMutableSet *known = [NSMutableSet set];
	NSMutableSet *unknown = [NSMutableSet set];
	PBXPlatformFilter *filter;

	for (filter in [PBXPlatformFilter allFilters])
		[known addObject:[filter friendlySerializableValue]];
	for (filter in [self _allPlatformFilters]) {
		NSString *value = [filter friendlySerializableValue];

		if (![known containsObject:value])
			[unknown addObject:value];
	}
	return (unknown);
}

- (BOOL)hasUnknownPlatformFilters
{
	return ([[self unknownPlatformFilters] count] != 0);
}

- (void)resetPlatformFilters
{
	_platformFilters = nil;
	_platformFilter = nil;
}

- (BOOL)shouldArchivePlatformFilters
{
	return (_platformFilters != nil);
}

- (BOOL)shouldArchivePlatformFilter
{
	return (_platformFilter != nil);
}

@end
