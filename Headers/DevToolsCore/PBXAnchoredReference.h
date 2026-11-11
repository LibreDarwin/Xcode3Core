/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Anchored references (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXANCHOREDREFERENCE_H
#define DEVTOOLSCORE_PBXANCHOREDREFERENCE_H

#import <Foundation/Foundation.h>

@class PBXNamePath, PBXReference;

/* A reference expressed as a name path relative to an anchor reference. */
@interface PBXAnchoredReference : NSObject <NSCopying>
{
	PBXReference *_anchor;
	PBXNamePath *_relativeNamePath;
}
@property (nonatomic, readonly) PBXReference *anchor;
@property (nonatomic, readonly) PBXNamePath *relativeNamePath;
@property (nonatomic, readonly) BOOL hasRelativePortion;
@property (nonatomic, readonly) NSString *singlePathComponentDisplayName;

- (instancetype)initWithAnchor:(PBXReference *)anchor
    relativeNamePath:(PBXNamePath *)path;
- (instancetype)initWithReference:(PBXReference *)reference
    inferringAnchor:(BOOL)infer;
- (BOOL)isEqualToAnchoredReference:(PBXAnchoredReference *)reference;
- (PBXReference *)resolveReference;
@end

#endif	/* DEVTOOLSCORE_PBXANCHOREDREFERENCE_H */
