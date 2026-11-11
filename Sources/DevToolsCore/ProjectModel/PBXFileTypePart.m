/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * File-type identifiers (DevToolsCore). */

#import "DevToolsCore/PBXFileTypePart.h"

@implementation PBXFileTypePart

- (instancetype)init
{
	self = [super init];
	[NSException raise:NSInvalidArgumentException
	    format:@"method %@ is inappropriate for instances of %@",
	    NSStringFromSelector(_cmd), NSStringFromClass([self class])];
	return (self);
}

- (NSString *)identifier
{
	return (_identifier);
}

- (PBXFileTypePart *)superpart
{
	return (_superpart);
}

- (void)setSuperpart:(PBXFileTypePart *)superpart
{
	if (superpart != nil &&
	    ![superpart isKindOfClass:[PBXFileTypePart class]])
		[NSException raise:NSInvalidArgumentException
		    format:@"superpart must be a PBXFileTypePart, not %@",
		    NSStringFromClass([superpart class])];
	_superpart = superpart;
}

- (NSArray *)subparts
{
	return (_subparts);
}

- (BOOL)isPlainFile
{
	return (NO);
}

- (BOOL)isFolder
{
	return (NO);
}

- (BOOL)isSymbolicLink
{
	return (NO);
}

@end
