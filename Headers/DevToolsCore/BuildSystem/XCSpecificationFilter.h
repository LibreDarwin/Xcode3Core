/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCSpecificationFilter.
 *
 * An XCSpecificationFilter is a reusable predicate over XCSpecification
 * instances.  It is described by
 *
 *   - a specification class (every candidate must be a kind of it),
 *   - a flag saying whether specifications are included by default,
 *   - an explicit list of included specifications, and
 *   - an explicit list of excluded specifications.
 *
 * -includesSpecification: answers whether a candidate is accepted:
 * the candidate is accepted when it is a kind of any included specification
 * (or when the default is YES) and is not a kind of any excluded
 * specification.
 *
 * Apple validates method arguments with __DVTAssertionFailureHandler(); this
 * implementation raises NSInvalidArgumentException with the same message text
 * instead.  -init raises because instances must be created with a
 * specification class.
 */

#ifndef DEVTOOLSCORE_BUILDSYSTEM_XCSPECIFICATIONFILTER_H
#define DEVTOOLSCORE_BUILDSYSTEM_XCSPECIFICATIONFILTER_H

#import <Foundation/Foundation.h>

@class XCSpecification;

@interface XCSpecificationFilter : NSObject {
	Class _specClass;
	BOOL _includeAllSpecs;
	NSMutableArray *_includedSpecs;
	NSMutableArray *_excludedSpecs;
}

- (id)initWithSpecificationClass:(Class)specClass includeAllByDefault:(BOOL)includeAllByDefault;
- (id)initWithSpecificationClass:(Class)specClass;

- (NSArray *)includedSpecifications;
- (void)addIncludedSpecifications:(NSArray *)specifications;
- (void)addIncludedSpecification:(XCSpecification *)specification;

- (NSArray *)excludedSpecifications;
- (void)addExcludedSpecifications:(NSArray *)specifications;
- (void)addExcludedSpecification:(XCSpecification *)specification;
- (void)addExcludedSpecificationComposition:(XCSpecificationFilter *)composition;

- (BOOL)includesAllSpecifications;
- (BOOL)includesAnySpecifications;
- (BOOL)includesSpecification:(XCSpecification *)specification;

@end

#endif /* DEVTOOLSCORE_BUILDSYSTEM_XCSPECIFICATIONFILTER_H */
