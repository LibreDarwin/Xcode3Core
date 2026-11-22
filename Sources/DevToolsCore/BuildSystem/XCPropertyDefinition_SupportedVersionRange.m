/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * An absent end version means "this version and later"; Apple renders that
 * range as "start+" in -description.  Equality and hashing are inherited from
 * NSObject, matching the private class's pointer identity behavior.
 */

#import "DevToolsCore/BuildSystem/XCPropertyDefinition_SupportedVersionRange.h"

#import <DVTFoundation/DVTVersion.h>

@implementation XCPropertyDefinition_SupportedVersionRange

- (instancetype)initWithStartOfRange:(DVTVersion *)startVersion
			 endOfRange:(DVTVersion *)endVersion
{
	NSParameterAssert(startVersion != nil);
	NSParameterAssert([startVersion isKindOfClass:[DVTVersion class]]);
	NSParameterAssert(endVersion == nil ||
	    [endVersion isKindOfClass:[DVTVersion class]]);

	self = [super init];
	if (self != nil) {
		_startVersion = [startVersion copy];
		_endVersion = [endVersion copy];
	}
	return (self);
}

- (BOOL)supportsVersion:(DVTVersion *)version
{
	if (![version isEqualToOrNewerThanVersion:_startVersion])
		return (NO);
	if (_endVersion == nil)
		return (YES);
	return ([_endVersion isEqualToOrNewerThanVersion:version]);
}

- (NSString *)description
{
	if (_endVersion == nil)
		return ([NSString stringWithFormat:@"%@+", [_startVersion stringValue]]);
	return ([NSString stringWithFormat:@"%@-%@",
	    [_startVersion stringValue], [_endVersion stringValue]]);
}

@end
