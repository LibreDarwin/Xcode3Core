/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of XCStringList.
 */

#import "DevToolsCore/XCStringList.h"

#include <fnmatch.h>
#include <string.h>

static BOOL
XCStringListIsWhitespace(unichar c)
{
	return (c < 128 && strchr(" \t\n\r\f\v", (int)c) != NULL);
}

static NSString *
XCStringListStringFromUTF8(const char *string, NSUInteger length)
{
	NSString *result;

	if (string == NULL || length == 0)
		return (@"");
	result = [[NSString alloc] initWithBytes:string length:length
	    encoding:NSUTF8StringEncoding];
	return (result != nil) ? result : @"";
}

static NSArray *
XCStringListStringsFromObjects(id __unsafe_unretained *objects, NSUInteger count)
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];

	for (NSUInteger i = 0; i < count; i++) {
		id object = objects[i];

		if (object == nil)
			[result addObject:@""];
		else if ([object isKindOfClass:[NSString class]])
			[result addObject:object];
		else
			[result addObject:[object description]];
	}
	return (result);
}

static NSArray *
XCStringListStringsFromRepresentation(NSString *representation)
{
	NSMutableArray *result = [NSMutableArray array];
	NSMutableString *token = [NSMutableString string];
	unichar quote = 0;
	BOOL inToken = NO;
	NSUInteger length = [representation length];

	for (NSUInteger i = 0; i < length; i++) {
		unichar c = [representation characterAtIndex:i];

		if (quote != 0) {
			if (c == quote)
				quote = 0;
			else
				[token appendFormat:@"%C", c];
			continue;
		}
		if (c == '\\') {
			inToken = YES;
			if (i + 1 < length)
				[token appendFormat:@"%C",
				    [representation characterAtIndex:++i]];
			else
				[token appendString:@"\\"];
			continue;
		}
		if (c == '\'' || c == '"') {
			quote = c;
			inToken = YES;
			continue;
		}
		if (XCStringListIsWhitespace(c)) {
			if (inToken) {
				[result addObject:[token copy]];
				[token setString:@""];
				inToken = NO;
			}
			continue;
		}
		inToken = YES;
		[token appendFormat:@"%C", c];
	}
	if (inToken)
		[result addObject:[token copy]];
	return (result);
}

static NSString *
XCStringListEscapedString(NSString *string)
{
	NSMutableString *result = [NSMutableString string];
	NSUInteger length = [string length];

	for (NSUInteger i = 0; i < length; i++) {
		unichar c = [string characterAtIndex:i];

		if (c == '\\')
			[result appendString:@"\\\\"];
		else if (XCStringListIsWhitespace(c)) {
			[result appendString:@"\\"];
			[result appendFormat:@"%C", c];
		} else
			[result appendFormat:@"%C", c];
	}
	return (result);
}

static BOOL
XCStringListMatchesPattern(NSString *pattern, const char *string)
{
	return (fnmatch([pattern fileSystemRepresentation], string, 0) == 0);
}

@implementation XCStringList {
	NSMutableArray *_strings;
}

+ (void)initialize
{
}

+ (XCStringList *)stringList
{
	return ([[XCStringList alloc] init]);
}

+ (XCStringList *)stringListWithString:(NSString *)string
{
	return ([[XCStringList alloc] initWithString:string]);
}

+ (XCStringList *)stringListFromArrayRepresentation:(NSArray *)array
{
	return ([[XCStringList alloc] initWithStringArray:array]);
}

+ (XCStringList *)stringListFromStringRepresentation:(NSString *)representation
{
	XCStringList *list = [[XCStringList alloc] init];
	NSArray *strings = XCStringListStringsFromRepresentation(representation);

	for (id string in strings)
		[list appendString:string];
	return (list);
}

+ (void)printStatistics
{
}

- (id)initWithStrings:(id __unsafe_unretained *)strings count:(NSUInteger)count
{
	self = [super init];
	if (self != nil)
		_strings = [XCStringListStringsFromObjects(strings, count) mutableCopy];
	return (self);
}

- (id)initWithStrings:(id)strings
{
	if ([strings isKindOfClass:[NSArray class]])
		return ([self initWithStringArray:strings]);
	return ([self initWithString:strings]);
}

- (id)initWithStringArray:(NSArray *)strings
{
	self = [super init];
	if (self != nil)
		_strings = [(strings != nil ? strings : @[]) mutableCopy];
	return (self);
}

- (id)initWithString:(NSString *)string
{
	return ([self initWithStringArray:
	    @[(string != nil ? (id)string : (id)@"")]]);
}

- (id)init
{
	return ([self initWithStringArray:@[]]);
}

- (id)copyWithZone:(NSZone *)zone
{
	XCStringList *copy;

	(void)zone;
	copy = [[XCStringList allocWithZone:zone] initWithStringArray:_strings];
	return (copy);
}

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:[XCStringList class]])
		return (NO);
	return ([_strings isEqualToArray:[object arrayRepresentation]]);
}

- (NSUInteger)hash
{
	return ([_strings hash]);
}

- (NSUInteger)count
{
	return ([_strings count]);
}

- (void)getUTF8StringPtrs:(const char **)pointers
{
	for (NSUInteger i = 0; i < [_strings count]; i++)
		pointers[i] = [_strings[i] UTF8String];
}

- (void)enumerateUTF8StringsUsingBlock:(void (^)(const char *string))block
{
	for (NSString *string in _strings)
		block([string UTF8String]);
}

- (void)appendUTF8String:(const char *)string length:(NSUInteger)length
{
	[_strings addObject:XCStringListStringFromUTF8(string, length)];
}

- (void)appendUTF8String:(const char *)string
{
	[self appendUTF8String:string
	    length:(string != NULL) ? strlen(string) : 0];
}

- (void)appendUTF8Strings:(const char *)string
{
	if (string == NULL)
		return;
	while (*string != '\0') {
		[self appendUTF8String:string];
		string += strlen(string) + 1;
	}
}

- (void)appendStrings:(id __unsafe_unretained *)strings count:(NSUInteger)count
{
	[_strings addObjectsFromArray:
	    XCStringListStringsFromObjects(strings, count)];
}

- (void)appendString:(id)string
{
	[_strings addObject:(string != nil ? (id)string : (id)@"")];
}

- (void)appendStringList:(XCStringList *)list
{
	[_strings addObjectsFromArray:[list arrayRepresentation]];
}

- (void)appendElementsByTransferringFromStringList:(XCStringList *)list
{
	[self appendStringList:list];
}

- (void)prependUTF8String:(const char *)string length:(NSUInteger)length
{
	[_strings insertObject:XCStringListStringFromUTF8(string, length)
	    atIndex:0];
}

- (void)prependUTF8String:(const char *)string
{
	[self prependUTF8String:string
	    length:(string != NULL) ? strlen(string) : 0];
}

- (void)prependUTF8Strings:(const char *)string
{
	NSMutableArray *added = [NSMutableArray array];

	if (string == NULL)
		return;
	while (*string != '\0') {
		[added addObject:XCStringListStringFromUTF8(string, strlen(string))];
		string += strlen(string) + 1;
	}
	[_strings insertObjects:added atIndexes:
	    [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [added count])]];
}

- (void)removeUTF8String:(const char *)string length:(NSUInteger)length
{
	NSString *target = XCStringListStringFromUTF8(string, length);
	NSMutableArray *remaining = [NSMutableArray array];

	for (NSString *candidate in _strings) {
		if (![candidate isEqualToString:target])
			[remaining addObject:candidate];
	}
	[_strings setArray:remaining];
}

- (void)replaceUTF8String:(const char *)oldString length:(NSUInteger)oldLength
	withUTF8String:(const char *)newString length:(NSUInteger)newLength
{
	NSString *oldValue = XCStringListStringFromUTF8(oldString, oldLength);
	NSString *newValue = XCStringListStringFromUTF8(newString, newLength);

	for (NSUInteger i = 0; i < [_strings count]; i++) {
		if ([_strings[i] isEqualToString:oldValue])
			_strings[i] = newValue;
	}
}

- (BOOL)areStringPatternsMatchedByUTF8String:(const char *)string
{
	for (NSString *pattern in _strings) {
		if (XCStringListMatchesPattern(pattern, string))
			return (YES);
	}
	return (NO);
}

- (BOOL)areFilenamePatternsMatchedByUTF8String:(const char *)string
{
	const char *component = string;

	if (component == NULL)
		return (NO);
	while ((component = strchr(component, '/')) != NULL) {
		const char *suffix = component + 1;

		for (NSString *pattern in _strings) {
			if (XCStringListMatchesPattern(pattern, suffix))
				return (YES);
		}
		component = suffix;
	}
	return (NO);
}

- (NSString *)stringRepresentation
{
	NSMutableArray *parts = [NSMutableArray arrayWithCapacity:[_strings count]];

	for (NSString *string in _strings)
		[parts addObject:XCStringListEscapedString(string)];
	return ([parts componentsJoinedByString:@" "]);
}

- (NSArray *)arrayRepresentation
{
	return ([_strings copy]);
}

- (NSString *)stringRepresentationForDebugging
{
	NSMutableString *result = [NSMutableString stringWithString:@"["];

	for (NSUInteger i = 0; i < [_strings count]; i++) {
		NSString *string = _strings[i];
		NSUInteger length = [string lengthOfBytesUsingEncoding:
		    NSUTF8StringEncoding];

		if (i > 0)
			[result appendString:@"|"];
		[result appendFormat:@"%luL:%@", (unsigned long)length, string];
	}
	[result appendString:@"]"];
	return (result);
}

- (NSString *)description
{
	return ([self stringRepresentationForDebugging]);
}

@end
