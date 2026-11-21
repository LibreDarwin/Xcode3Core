/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsCore/PBXPlistArchiverAdditions.h"

#include <string.h>

static BOOL
PBXPlistStringIsUnquoted(NSString *string)
{
	NSUInteger length = [string length];

	if (length == 0)
		return (NO);
	for (NSUInteger i = 0; i < length; i++) {
		unichar c = [string characterAtIndex:i];

		if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
		    (c >= '0' && c <= '9') || c == '_' || c == '$' ||
		    c == '.' || c == '/')
			continue;
		return (NO);
	}
	return (YES);
}

static void
PBXPlistAppendBytes(NSMutableData *data, const char *bytes)
{
	[data appendBytes:bytes length:strlen(bytes)];
}

static void
PBXPlistAppendString(NSMutableData *data, NSString *string)
{
	PBXPlistAppendBytes(data, [string UTF8String]);
}

static void
PBXPlistAppendQuotedString(NSMutableData *data, NSString *string)
{
	[data appendBytes:"\"" length:1];
	for (NSUInteger i = 0; i < [string length]; i++) {
		unichar c = [string characterAtIndex:i];

		switch (c) {
		case '"':
			PBXPlistAppendBytes(data, "\\\"");
			break;
		case '\\':
			PBXPlistAppendBytes(data, "\\\\");
			break;
		case '\n':
			PBXPlistAppendBytes(data, "\\n");
			break;
		case '\r':
			PBXPlistAppendBytes(data, "\\r");
			break;
		case '\t':
			PBXPlistAppendBytes(data, "\\t");
			break;
		default:
			PBXPlistAppendString(data, [NSString stringWithFormat:@"%C", c]);
			break;
		}
	}
	[data appendBytes:"\"" length:1];
}

static void
PBXPlistAppendComment(NSMutableData *data, NSString *comment)
{
	if (comment == nil)
		return;
	NSRange range = [comment rangeOfString:@"*/"];

	PBXPlistAppendBytes(data, " /* ");
	while (range.location != NSNotFound) {
		PBXPlistAppendString(data,
		    [comment substringToIndex:range.location]);
		PBXPlistAppendBytes(data, "(*)/");
		comment = [comment substringFromIndex:range.location + 2];
		range = [comment rangeOfString:@"*/"];
	}
	PBXPlistAppendString(data, comment);
	PBXPlistAppendBytes(data, " */");
}

static void
PBXPlistAppendDescription(id object, NSMutableData *data, NSUInteger level)
{
	if ([object respondsToSelector:
	    @selector(_appendPListDescriptionToUTF8Data:withIndentLevel:)]) {
		[object _appendPListDescriptionToUTF8Data:data
		    withIndentLevel:level];
		return;
	}
	if ([object isKindOfClass:[NSString class]]) {
		NSString *string = object;

		if (PBXPlistStringIsUnquoted(string))
			PBXPlistAppendString(data, string);
		else
			PBXPlistAppendQuotedString(data, string);
		return;
	}
	if ([object isKindOfClass:[NSNumber class]]) {
		PBXPlistAppendString(data, [object description]);
		return;
	}
	if ([object isKindOfClass:[NSArray class]]) {
		[data appendBytes:"(" length:1];
		for (id element in (NSArray *)object) {
			PBXPlistAppendDescription(element, data, level);
			PBXPlistAppendBytes(data, ", ");
		}
		[data appendBytes:")" length:1];
		return;
	}
	PBXPlistAppendString(data, [object description]);
}

@implementation PBXPlistArchiverAlwaysQuotedString {
	NSString *_string;
}

+ (instancetype)wrapString:(NSString *)string
{
	return ([[self alloc] initWithString:string]);
}

- (instancetype)initWithString:(NSString *)string
{
	self = [super init];
	if (self != nil)
		_string = [(string != nil ? string : @"") copy];
	return (self);
}

- (NSUInteger)length
{
	return ([_string length]);
}

- (unichar)characterAtIndex:(NSUInteger)index
{
	return ([_string characterAtIndex:index]);
}

- (NSString *)description
{
	return ([_string copy]);
}

- (id)copyWithZone:(NSZone *)zone
{
	return ([[[self class] allocWithZone:zone] initWithString:_string]);
}

- (id)replacementObjectForCoder:(NSCoder *)coder
{
	(void)coder;
	return (self);
}

- (NSUInteger)hash
{
	return ([_string hash]);
}

- (BOOL)isEqual:(id)object
{
	if (object == self)
		return (YES);
	if (![object isKindOfClass:[NSString class]])
		return (NO);
	return ([_string isEqualToString:object]);
}

- (void)_appendPListDescriptionToUTF8Data:(NSMutableData *)data
    withIndentLevel:(NSUInteger)level
{
	(void)level;
	PBXPlistAppendQuotedString(data, _string);
}

@end

@implementation PBXPListArchiverStringWithComment {
	NSString *_string;
	NSString *_comment;
}

- (instancetype)initWithString:(NSString *)string comment:(NSString *)comment
{
	self = [super init];
	if (self != nil) {
		_string = [(string != nil ? string : @"") copy];
		_comment = [comment copy];
	}
	return (self);
}

- (NSUInteger)length
{
	return ([_string length]);
}

- (unichar)characterAtIndex:(NSUInteger)index
{
	return ([_string characterAtIndex:index]);
}

- (NSString *)description
{
	return ([_string copy]);
}

- (id)copyWithZone:(NSZone *)zone
{
	return ([[[self class] allocWithZone:zone] initWithString:_string
	    comment:_comment]);
}

- (id)replacementObjectForCoder:(NSCoder *)coder
{
	(void)coder;
	return (self);
}

- (NSUInteger)hash
{
	return ([_string hash]);
}

- (BOOL)isEqual:(id)object
{
	if (object == self)
		return (YES);
	if (![object isKindOfClass:[NSString class]])
		return (NO);
	return ([_string isEqualToString:object]);
}

- (void)_appendPListDescriptionToUTF8Data:(NSMutableData *)data
    withIndentLevel:(NSUInteger)level
{
	(void)level;
	if (PBXPlistStringIsUnquoted(_string))
		PBXPlistAppendString(data, _string);
	else
		PBXPlistAppendQuotedString(data, _string);
	PBXPlistAppendComment(data, _comment);
}

@end

@implementation PBXPlistArchiverSingleLineArray {
	NSArray *_array;
}

+ (instancetype)wrapArray:(NSArray *)array
{
	return ([[self alloc] initWithArray:array]);
}

- (instancetype)initWithArray:(NSArray *)array
{
	self = [super init];
	if (self != nil)
		_array = [(array != nil ? array : @[]) copy];
	return (self);
}

- (NSUInteger)count
{
	return ([_array count]);
}

- (id)objectAtIndex:(NSUInteger)index
{
	return ([_array objectAtIndex:index]);
}

- (id)copyWithZone:(NSZone *)zone
{
	return ([[[self class] allocWithZone:zone] initWithArray:_array]);
}

- (id)replacementObjectForCoder:(NSCoder *)coder
{
	(void)coder;
	return (self);
}

- (void)_appendPListDescriptionToUTF8Data:(NSMutableData *)data
    withIndentLevel:(NSUInteger)level
{
	[data appendBytes:"(" length:1];
	for (id object in _array) {
		PBXPlistAppendDescription(object, data, level);
		PBXPlistAppendBytes(data, ", ");
	}
	[data appendBytes:")" length:1];
}

@end
