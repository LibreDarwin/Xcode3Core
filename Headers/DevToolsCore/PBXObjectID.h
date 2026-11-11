/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Object identifiers (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXOBJECTID_H
#define DEVTOOLSCORE_PBXOBJECTID_H

#import <Foundation/Foundation.h>

/* A 96-bit object identifier rendered as a 24-character hex string. */
@interface PBXObjectID : NSString <NSCopying>
{
	NSString *_stringRepresentation;
}
@property (nonatomic, readonly) NSString *stringRepresentation;

- (instancetype)initFromStringRepresentation:(NSString *)representation;
@end

#endif	/* DEVTOOLSCORE_PBXOBJECTID_H */
