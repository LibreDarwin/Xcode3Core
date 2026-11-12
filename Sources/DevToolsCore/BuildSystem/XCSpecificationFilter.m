/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCSpecificationFilter.
 */

#import "DevToolsCore/BuildSystem/XCSpecificationFilter.h"

#import "DevToolsCore/BuildSystem/XCSpecification.h"

@interface XCSpecificationFilter ()
- (void)_addSpecification:(XCSpecification *)specification toList:(NSMutableArray *)list;
@end

@implementation XCSpecificationFilter

#pragma mark Life cycle

- (id)init
{
	[NSException raise:NSInvalidArgumentException
		    format:@"method %@ is inappropriate for instances of %@",
			   NSStringFromSelector(_cmd), NSStringFromClass([self class])];
	return (nil);
}

- (id)initWithSpecificationClass:(Class)specClass includeAllByDefault:(BOOL)includeAllByDefault
{
	self = [super init];
	if (self != nil) {
		_specClass = specClass;
		_includeAllSpecs = includeAllByDefault;
		_includedSpecs = [[NSMutableArray alloc] init];
		_excludedSpecs = [[NSMutableArray alloc] init];
	}
	return (self);
}

- (id)initWithSpecificationClass:(Class)specClass
{
	return ([self initWithSpecificationClass:specClass includeAllByDefault:NO]);
}

#pragma mark Included specifications

- (NSArray *)includedSpecifications
{
	return (_includedSpecs);
}

- (void)addIncludedSpecifications:(NSArray *)specifications
{
	for (XCSpecification *specification in specifications) {
		if (specification == nil || ![specification isKindOfClass:_specClass]) {
			[NSException raise:NSInvalidArgumentException
				    format:@"%@ should be an instance inheriting from %@, but it is %@",
					   @"specification", NSStringFromClass(_specClass), specification];
		}
		[self _addSpecification:specification toList:_includedSpecs];
	}
}

- (void)addIncludedSpecification:(XCSpecification *)specification
{
	[self addIncludedSpecifications:[NSArray arrayWithObject:specification]];
}

#pragma mark Excluded specifications

- (NSArray *)excludedSpecifications
{
	return (_excludedSpecs);
}

- (void)addExcludedSpecifications:(NSArray *)specifications
{
	for (XCSpecification *specification in specifications) {
		if (specification == nil || ![specification isKindOfClass:_specClass]) {
			[NSException raise:NSInvalidArgumentException
				    format:@"%@ should be an instance inheriting from %@, but it is %@",
					   @"specification", NSStringFromClass(_specClass), specification];
		}
		[self _addSpecification:specification toList:_excludedSpecs];
	}
}

- (void)addExcludedSpecification:(XCSpecification *)specification
{
	[self addExcludedSpecifications:[NSArray arrayWithObject:specification]];
}

- (void)addExcludedSpecificationComposition:(XCSpecificationFilter *)composition
{
	if (composition == nil || ![composition isKindOfClass:[XCSpecificationFilter class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"composition", NSStringFromClass([XCSpecificationFilter class]), composition];
	}

	for (XCSpecification *specification in [composition includedSpecifications]) {
		[self addExcludedSpecification:specification];
	}
	for (XCSpecification *specification in [composition excludedSpecifications]) {
		[self addIncludedSpecification:specification];
	}
}

#pragma mark Querying

- (BOOL)includesAllSpecifications
{
	return (_includeAllSpecs && [_excludedSpecs count] == 0);
}

- (BOOL)includesAnySpecifications
{
	return (_includeAllSpecs ? YES : [_includedSpecs count] != 0);
}

- (BOOL)includesSpecification:(XCSpecification *)specification
{
	BOOL include = _includeAllSpecs;
	NSMutableArray *matchingIncludedSpecifications = nil;

	for (XCSpecification *includedSpecification in _includedSpecs) {
		if (![specification isKindOfSpecification:includedSpecification]) {
			continue;
		}
		if (matchingIncludedSpecifications == nil) {
			matchingIncludedSpecifications = [NSMutableArray array];
		}
		[matchingIncludedSpecifications addObject:includedSpecification];
		include = YES;
	}
	if (!include) {
		return (NO);
	}

	for (XCSpecification *excludedSpecification in _excludedSpecs) {
		BOOL rescued = NO;

		if (![specification isKindOfSpecification:excludedSpecification]) {
			continue;
		}
		for (XCSpecification *includedSpecification in
		    matchingIncludedSpecifications) {
			if (includedSpecification == excludedSpecification ||
			    [includedSpecification isKindOfSpecification:
			    excludedSpecification]) {
				rescued = YES;
				break;
			}
		}
		if (!rescued) {
			return (NO);
		}
	}

	return (YES);
}

#pragma mark Private methods

- (void)_addSpecification:(XCSpecification *)specification toList:(NSMutableArray *)list
{
	NSMutableArray *removedSpecifications = [NSMutableArray array];
	BOOL shouldAdd = YES;

	for (XCSpecification *existingSpecification in list) {
		if ([specification isKindOfSpecification:existingSpecification]) {
			shouldAdd = NO;
		} else if ([existingSpecification isKindOfSpecification:specification]) {
			[removedSpecifications addObject:existingSpecification];
		}
	}
	if (shouldAdd) {
		[list addObject:specification];
	}
	[list removeObjectsInArray:removedSpecifications];
}

#pragma mark NSObject overrides

- (NSString *)description
{
	NSMutableString *description = [NSMutableString string];

	[description appendFormat:@"<%@:%p:%@:", NSStringFromClass([self class]), self,
			      NSStringFromClass(_specClass)];
	[description appendFormat:@"includesAllByDefault=%@\n", (_includeAllSpecs ? @"YES" : @"NO")];
	[description appendFormat:@"includedSpecs = %@\n", [_includedSpecs description]];
	[description appendFormat:@"excludedSpecs = %@\n", [_excludedSpecs description]];
	[description appendFormat:@">"];

	return (description);
}

@end
