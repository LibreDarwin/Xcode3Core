/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCObjectGraphPath.
 */

#ifndef DEVTOOLSCORE_XCOBJECTGRAPHPATH_H
#define DEVTOOLSCORE_XCOBJECTGRAPHPATH_H

#import <Foundation/Foundation.h>

@interface XCObjectGraphPath : NSObject <NSCopying>
- (id)initWithSegmentGIDs:(NSArray *)gids names:(NSArray *)names;
- (XCObjectGraphPath *)pathByAddingSegmentWithGID:(id)gid name:(NSString *)name;
- (NSUInteger)segmentCount;
- (NSString *)segmentNameAtIndex:(NSUInteger)index;
- (NSString *)stringRepresentation;
- (NSArray *)pathSegmentGIDs;
- (NSArray *)pathSegmentNames;
@end

#endif	/* DEVTOOLSCORE_XCOBJECTGRAPHPATH_H */
