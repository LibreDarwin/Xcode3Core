/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsCore/BuildSystem/XCSpecificationRegistry.h"

#import "DevToolsCore/BuildSystem/XCSpecification.h"

@implementation XCSpecificationRegistry

- (BOOL)registerSpecification:(XCSpecification *)specification
{
	if (![specification isKindOfClass:[XCSpecification class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   NSStringFromSelector(_cmd), NSStringFromClass([XCSpecification class]), specification];
	}

	return ([self registerObject:specification
		     collisionHandler:^BOOL(DVTRegistry *registry, id existingObject, id newObject) {
		(void)registry;
		(void)existingObject;
		(void)newObject;
		return (YES);
	}]);
}

- (XCSpecification *)specificationForIdentifier:(NSString *)identifier
{
	return ([self objectForIdentifier:identifier]);
}

- (NSArray *)allRegisteredSpecifications
{
	return ([self allRegisteredObjects]);
}

@end
