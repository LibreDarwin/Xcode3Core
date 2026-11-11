/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Group enumeration (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXGROUPENUMERATOR_H
#define DEVTOOLSCORE_PBXGROUPENUMERATOR_H

#import <Foundation/Foundation.h>

@class PBXGroup;

/* Depth-first enumerator over a group and all of its descendants. */
@interface PBXGroupEnumerator : NSEnumerator <NSCopying, NSFastEnumeration>
{
	NSMutableArray *_objects;
	NSUInteger _index;
	NSUInteger _mutations;
}
+ (SEL)traversalSelector;
+ (instancetype)enumeratorForGroup:(PBXGroup *)group;
+ (instancetype)enumeratorForGroup:(PBXGroup *)group
    startingAtItem:(id)item;
- (instancetype)initWithRootArray:(NSArray *)array nextObject:(id)object;
- (void)rewind;
- (NSArray *)allObjects;
- (NSUInteger)numberOfObjects;
- (void)setNextObject:(id)object;
- (id)previousObject;
- (id)firstObject;
- (id)lastObject;
@end

#endif	/* DEVTOOLSCORE_PBXGROUPENUMERATOR_H */
