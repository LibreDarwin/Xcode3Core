/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsSupport/TSRegularExpression.h"

#import <objc/runtime.h>

@implementation TSRegularExpression

- (id)init
{
	return (nil);
}

- (id)initWithExpressionString:(id)string
{
	return ([self initWithExpressionString:string ignoreCase:NO]);
}

- (id)initWithExpressionString:(id)string ignoreCase:(BOOL)ignoreCase
{
	NSRegularExpression *regularExpression;
	NSRegularExpressionOptions options;

	self = [super init];
	if (self == nil)
		return (nil);
	if (![string isKindOfClass:[NSString class]] || [string length] == 0)
		return (nil);
	options = ignoreCase ? NSRegularExpressionCaseInsensitive : 0;
	regularExpression = [NSRegularExpression regularExpressionWithPattern:string
	    options:options error:NULL];
	if (regularExpression == nil)
		return (nil);
	_expressionString = [string copy];
	_ignoreCase = ignoreCase;
	_regularExpression = regularExpression;
	return (self);
}

- (id)expressionString
{
	return (_expressionString);
}

- (BOOL)matchesString:(id)string
{
	NSTextCheckingResult *match;

	if (![string isKindOfClass:[NSString class]])
		return (NO);
	match = [_regularExpression firstMatchInString:string options:0
	    range:NSMakeRange(0, [string length])];
	return (match != nil);
}

- (NSRange)rangeForSubexpressionAtIndex:(NSUInteger)index inString:(id)string
{
	NSTextCheckingResult *match;
	NSRange range;

	range = NSMakeRange(NSNotFound, 0);
	if (![string isKindOfClass:[NSString class]] ||
	    index > [_regularExpression numberOfCaptureGroups])
		return (range);
	match = [_regularExpression firstMatchInString:string options:0
	    range:NSMakeRange(0, [string length])];
	if (match == nil)
		return (range);
	return ([match rangeAtIndex:index]);
}

- (id)substringForSubexpressionAtIndex:(NSUInteger)index inString:(id)string
{
	NSRange range;

	if (![string isKindOfClass:[NSString class]])
		return (nil);
	range = [self rangeForSubexpressionAtIndex:index inString:string];
	if (range.location == NSNotFound)
		return (nil);
	return ([string substringWithRange:range]);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%s:%p:'%@'>",
	    class_getName([self class]), (__bridge void *)self, _expressionString]);
}

- (NSUInteger)hash
{
	return ([_expressionString hash]);
}

- (BOOL)isEqual:(id)object
{
	TSRegularExpression *other;

	if (self == object)
		return (YES);
	if (![object isKindOfClass:[TSRegularExpression class]])
		return (NO);
	other = object;
	return ([_expressionString isEqualToString:[other expressionString]]);
}

- (id)copyWithZone:(NSZone *)zone
{
	(void)zone;
	return (self);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (void)encodeWithCoder:(NSCoder *)coder
{
	BOOL ignoreCase = _ignoreCase;

	[coder encodeObject:_expressionString];
	[coder encodeValueOfObjCType:@encode(BOOL) at:&ignoreCase];
}

- (id)initWithCoder:(NSCoder *)decoder
{
	NSString *string;
	BOOL ignoreCase = NO;

	self = [super init];
	if (self == nil)
		return (nil);
	string = [decoder decodeObject];
	[decoder decodeValueOfObjCType:@encode(BOOL) at:&ignoreCase];
	return ([self initWithExpressionString:string ignoreCase:ignoreCase]);
}

#pragma clang diagnostic pop

@end
