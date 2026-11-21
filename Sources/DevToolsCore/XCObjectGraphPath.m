/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of XCObjectGraphPath.
 */

#import "DevToolsCore/XCObjectGraphPath.h"

@implementation XCObjectGraphPath {
	NSArray *_segmentGIDs;
	NSArray *_segmentNames;
}

- (id)initWithSegmentGIDs:(NSArray *)gids names:(NSArray *)names
{
	self = [super init];
	if (self != nil) {
		NSParameterAssert([gids count] == [names count]);
		_segmentGIDs = [gids copy];
		_segmentNames = [names copy];
	}
	return (self);
}

- (id)init
{
	return ([self initWithSegmentGIDs:@[] names:@[]]);
}

- (id)copyWithZone:(NSZone *)zone
{
	(void)zone;
	return (self);
}

- (XCObjectGraphPath *)pathByAddingSegmentWithGID:(id)gid name:(NSString *)name
{
	NSMutableArray *gids = [_segmentGIDs mutableCopy];
	NSMutableArray *names = [_segmentNames mutableCopy];
	XCObjectGraphPath *path;

	[gids addObject:gid];
	[names addObject:name];
	path = [[XCObjectGraphPath alloc] initWithSegmentGIDs:gids names:names];
	return (path);
}

- (NSUInteger)segmentCount
{
	return ([_segmentNames count]);
}

- (NSString *)segmentNameAtIndex:(NSUInteger)index
{
	return ([_segmentNames objectAtIndex:index]);
}

- (NSString *)stringRepresentation
{
	NSMutableArray *reversed = [NSMutableArray array];
	NSString *name;

	if ([_segmentNames count] == 0)
		return (nil);
	for (name in [_segmentNames reverseObjectEnumerator])
		[reversed addObject:name];
	return ([reversed componentsJoinedByString:@" of "]);
}

- (NSArray *)pathSegmentGIDs
{
	return (_segmentGIDs);
}

- (NSArray *)pathSegmentNames
{
	return (_segmentNames);
}

@end
