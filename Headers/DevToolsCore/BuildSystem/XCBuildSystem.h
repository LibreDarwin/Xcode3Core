/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * BuildSystem base classes (DevToolsCore). */

#ifndef DEVTOOLSCORE_BUILDSYSTEM_XCBUILDSYSTEM_H
#define DEVTOOLSCORE_BUILDSYSTEM_XCBUILDSYSTEM_H

#import <Foundation/Foundation.h>

@interface XCBuildSystem : NSObject

- (BOOL)buildWithOptions:(NSDictionary *)options error:(NSError **)error;

@end

#endif	/* DEVTOOLSCORE_BUILDSYSTEM_XCBUILDSYSTEM_H */
