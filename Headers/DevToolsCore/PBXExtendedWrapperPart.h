/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Extended wrapper part value objects (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXEXTENDEDWRAPPERPART_H
#define DEVTOOLSCORE_PBXEXTENDEDWRAPPERPART_H

#import <Foundation/Foundation.h>

@interface PBXExtendedWrapperPart : NSObject
{
	long long _basedOnWrapperPart;
	NSString *_subPath;
}
@property (nonatomic, readonly) long long basedOnWrapperPart;
@property (nonatomic, readonly, copy) NSString *subPath;

- (instancetype)initWithBasedOnWrapperPart:(long long)part
    subPath:(NSString *)path;
@end

#endif	/* DEVTOOLSCORE_PBXEXTENDEDWRAPPERPART_H */
