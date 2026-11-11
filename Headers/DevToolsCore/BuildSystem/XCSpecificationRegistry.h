/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCSpecificationRegistry.
 *
 * XCSpecificationRegistry is a thin DVTRegistry subclass.  Note that the
 * domain based lookup used by +[XCSpecification specificationForIdentifier:
 * inDomain:] does not go through this class; it uses the plain
 * NSMutableDictionary returned by XCGetRegistryDictionaryForForDomain().
 */

#ifndef DEVTOOLSCORE_BUILDSYSTEM_XCSPECIFICATIONREGISTRY_H
#define DEVTOOLSCORE_BUILDSYSTEM_XCSPECIFICATIONREGISTRY_H

#import <Foundation/Foundation.h>

#import "DVTFoundation/DVTRegistry.h"

@class XCSpecification;

@interface XCSpecificationRegistry : DVTRegistry

- (XCSpecification *)specificationForIdentifier:(NSString *)identifier;
- (NSArray *)allRegisteredSpecifications;
- (BOOL)registerSpecification:(XCSpecification *)specification;

@end

#endif	/* DEVTOOLSCORE_BUILDSYSTEM_XCSPECIFICATIONREGISTRY_H */
