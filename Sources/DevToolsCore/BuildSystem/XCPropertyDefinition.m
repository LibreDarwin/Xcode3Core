/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of XCPropertyDefinition.  The implementation
 * models the xcspec-visible behavior: type selection from the Type key,
 * parsing of DefaultValue/Values/DisplayValues, command-line argument
 * metadata and the -description format used by DevToolsCore.
 */

#import "DevToolsCore/BuildSystem/XCPropertyDefinition.h"
#import "DevToolsCore/BuildSystem/XCPropertyDefinition_SupportedVersionRange.h"

#import <DVTFoundation/DVTVersion.h>
#import <objc/runtime.h>
#import <stdio.h>

#import <DVTMacroFoundation/DVTMacroDefinitionConditionParameter.h>
#import <DVTMacroFoundation/DVTMacroExpressionParser.h>

static NSMutableDictionary<NSString *, Class> *sPropertyTypesByName = nil;

static NSSet *
XCPropertySupportedVersionRanges(TSPropertyListDictionary *properties)
{
	NSArray *rawRanges = [properties arrayOrNilForKey:@"SupportedVersionRanges"];
	NSMutableSet *ranges;

	if (rawRanges == nil || [rawRanges count] == 0)
		return (nil);
	ranges = [NSMutableSet set];
	for (id entry in rawRanges) {
		NSString *startString;
		NSString *endString = nil;
		DVTVersion *start;
		DVTVersion *end = nil;
		XCPropertyDefinition_SupportedVersionRange *range;

		if ([entry isKindOfClass:[NSString class]]) {
			startString = entry;
		} else if ([entry isKindOfClass:[NSArray class]]) {
			if ([entry count] < 1 || [entry count] > 2)
				return (nil);
			if (![[entry objectAtIndex:0] isKindOfClass:[NSString class]])
				return (nil);
			startString = [entry objectAtIndex:0];
			if ([entry count] == 2) {
				if (![[entry objectAtIndex:1] isKindOfClass:
				    [NSString class]])
					return (nil);
				endString = [entry objectAtIndex:1];
			}
		} else {
			return (nil);
		}
		start = [DVTVersion versionWithStringValue:startString];
		if (endString != nil)
			end = [DVTVersion versionWithStringValue:endString];
		range = [[XCPropertyDefinition_SupportedVersionRange alloc]
		    initWithStartOfRange:start endOfRange:end];
		[ranges addObject:range];
	}
	return (([ranges count] == 0) ? nil : ranges);
}

static NSArray *
XCPropertyListWords(NSString *string)
{
	NSMutableArray *words = [NSMutableArray array];
	NSUInteger index = 0;
	NSUInteger length = [string length];

	while (index < length) {
		 NSMutableString *word = [NSMutableString string];
		unichar quote = 0;

		while (index < length &&
		    [[NSCharacterSet whitespaceAndNewlineCharacterSet]
			characterIsMember:[string characterAtIndex:index]])
			index++;
		if (index >= length)
			break;
		if ([string characterAtIndex:index] == '"' ||
		    [string characterAtIndex:index] == '\'') {
			quote = [string characterAtIndex:index];
			index++;
		}
		while (index < length) {
			unichar character = [string characterAtIndex:index];

			if (quote != 0) {
				if (character == quote) {
					index++;
					break;
				}
			} else if ([[NSCharacterSet whitespaceAndNewlineCharacterSet]
			    characterIsMember:character]) {
				break;
			}
			if (character == '\\' && index + 1 < length) {
				index++;
				character = [string characterAtIndex:index];
			}
			[word appendFormat:@"%C", character];
			index++;
		}
		[words addObject:word];
	}
	return (words);
}

@interface XCPropertyMacroBooleanExpression : XCPropertyMacroExpression
@end

@interface XCPropertyMacroStringConstantExpression : XCPropertyMacroExpression
- (instancetype)initWithString:(NSString *)string;
@end

@interface XCPropertyMacroTrueConstantExpression : XCPropertyMacroBooleanExpression
@end

@interface XCPropertyMacroFalseConstantExpression : XCPropertyMacroBooleanExpression
@end

@interface XCPropertyMacroBinaryBooleanExpression : XCPropertyMacroBooleanExpression
- (instancetype)initWithLeftExpression:(id)leftExpression
		       rightExpression:(id)rightExpression;
- (id)leftExpression;
- (id)rightExpression;
@end

@interface XCPropertyMacroEqualityExpression : XCPropertyMacroBinaryBooleanExpression
@end

@interface XCPropertyMacroInequalityExpression : XCPropertyMacroBinaryBooleanExpression
@end

@interface XCPropertyMacroLogicalANDExpression : XCPropertyMacroBinaryBooleanExpression
@end

@interface XCPropertyMacroLogicalORExpression : XCPropertyMacroBinaryBooleanExpression
@end

@interface XCPropertyMacroLogicalXORExpression : XCPropertyMacroBinaryBooleanExpression
@end

@interface XCPropertyMacroContainsExpression : XCPropertyMacroBinaryBooleanExpression
@end

@interface XCPropertyMacroLogicalNOTExpression : XCPropertyMacroBooleanExpression
- (instancetype)initWithExpression:(id)expression;
- (id)expression;
@end

@interface XCPropertyMacroConditionalExpression : XCPropertyMacroExpression
- (instancetype)initWithConditionExpression:(id)conditionExpression
			      thenExpression:(id)thenExpression
			      elseExpression:(id)elseExpression;
@end

typedef struct {
	NSString *string;
	NSUInteger length;
	NSArray *tokens;
	NSUInteger index;
	NSError *__autoreleasing *error;
} XCPropertyMacroParserState;

static BOOL
XCPropertyMacroIsWhitespace(unichar character)
{
	return ([[NSCharacterSet whitespaceAndNewlineCharacterSet]
	    characterIsMember:character]);
}

static NSArray *
XCPropertyMacroTokenize(NSString *string)
{
	NSMutableArray *tokens = [NSMutableArray array];
	NSUInteger length = [string length];
	NSUInteger index = 0;

	while (index < length) {
		NSUInteger start;
		unichar character;
		NSString *text;
		NSString *type = @"text";

		while (index < length &&
		    XCPropertyMacroIsWhitespace([string characterAtIndex:index]))
			index++;
		if (index >= length)
			break;
		start = index;
		character = [string characterAtIndex:index];
		if (character == '(' &&
		    (index + 1 == length ||
		    XCPropertyMacroIsWhitespace(
			[string characterAtIndex:index + 1]))) {
			text = @"(";
			type = @"(";
			index++;
		} else if (character == ')') {
			text = @")";
			type = @")";
			index++;
		} else if (character == '=' && index + 1 < length &&
		    [string characterAtIndex:index + 1] == '=') {
			text = @"==";
			type = @"operator";
			index += 2;
		} else if (character == '!' && index + 1 < length &&
		    [string characterAtIndex:index + 1] == '=') {
			text = @"!=";
			type = @"operator";
			index += 2;
		} else if (character == '&' && index + 1 < length &&
		    [string characterAtIndex:index + 1] == '&') {
			text = @"&&";
			type = @"operator";
			index += 2;
		} else if (character == '|' && index + 1 < length &&
		    [string characterAtIndex:index + 1] == '|') {
			text = @"||";
			type = @"operator";
			index += 2;
		} else if (character == '!' || character == '?' ||
		    character == ':') {
			text = [string substringWithRange:NSMakeRange(index, 1)];
			type = @"operator";
			index++;
		} else if (character == '"' || character == '\'') {
			unichar quote = character;
			NSMutableString *word = [NSMutableString string];

			index++;
			while (index < length) {
				unichar current = [string characterAtIndex:index];

				if (current == quote) {
					index++;
					break;
				}
				if (current == '\\' && index + 1 < length) {
					index++;
					current = [string characterAtIndex:index];
				}
				[word appendFormat:@"%C", current];
				index++;
			}
			text = word;
		} else {
			NSMutableString *word = [NSMutableString string];

			while (index < length &&
			    !XCPropertyMacroIsWhitespace(
				[string characterAtIndex:index])) {
				[word appendFormat:@"%C",
				    [string characterAtIndex:index]];
				index++;
			}
			text = word;
		}
		[tokens addObject:@{
		    @"text": text,
		    @"type": type,
		    @"location": @(start),
		}];
	}
	return (tokens);
}

static id
XCPropertyMacroFail(XCPropertyMacroParserState *state, NSString *message)
{
	if (state->error != NULL) {
		*state->error = [NSError errorWithDomain:
		    @"XCPropertyMacroExpressionErrorDomain"
		    code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
	}
	return (nil);
}

static NSDictionary *
XCPropertyMacroPeek(XCPropertyMacroParserState *state)
{
	if (state->index >= [state->tokens count])
		return (nil);
	return ([state->tokens objectAtIndex:state->index]);
}

static NSString *
XCPropertyMacroPeekText(XCPropertyMacroParserState *state)
{
	NSDictionary *token = XCPropertyMacroPeek(state);

	return ((token != nil) ? [token objectForKey:@"text"] : nil);
}

static NSString *
XCPropertyMacroPeekType(XCPropertyMacroParserState *state)
{
	NSDictionary *token = XCPropertyMacroPeek(state);

	return ((token != nil) ? [token objectForKey:@"type"] : nil);
}

static NSUInteger
XCPropertyMacroPeekLocation(XCPropertyMacroParserState *state)
{
	NSDictionary *token = XCPropertyMacroPeek(state);

	return ((token != nil)
	    ? [[token objectForKey:@"location"] unsignedIntegerValue]
	    : state->length);
}

static BOOL
XCPropertyMacroConsume(XCPropertyMacroParserState *state, NSString *text)
{
	if (![[XCPropertyMacroPeekText(state) description]
	    isEqualToString:text])
		return (NO);
	state->index++;
	return (YES);
}

static id XCPropertyMacroParseConditional(XCPropertyMacroParserState *state);

static id
XCPropertyMacroParsePrimary(XCPropertyMacroParserState *state)
{
	NSString *text = XCPropertyMacroPeekText(state);
	NSString *type = XCPropertyMacroPeekType(state);

	if (text == nil)
		return (nil);
	if ([type isEqualToString:@"("]) {
		id expression;

		state->index++;
		expression = XCPropertyMacroParseConditional(state);
		if (state->error != NULL && *state->error != nil)
			return (nil);
		if (!XCPropertyMacroConsume(state, @")")) {
			NSString *found = XCPropertyMacroPeekText(state);

			return (XCPropertyMacroFail(state, [NSString
			    stringWithFormat:
			    @"expected ')' but found '%@' at offset %lu",
			    ((found != nil) ? found : @""),
			    (unsigned long)XCPropertyMacroPeekLocation(state)]));
		}
		return (expression);
	}
	if ([text hasPrefix:@"("] && ![text isEqualToString:@"("])
		return (XCPropertyMacroFail(state, [NSString stringWithFormat:
		    @"expected ')' but found '' at offset %lu",
		    (unsigned long)state->length]));
	state->index++;
	return ([[XCPropertyMacroStringConstantExpression alloc]
	    initWithString:text]);
}

static id
XCPropertyMacroParseUnary(XCPropertyMacroParserState *state)
{
	if (XCPropertyMacroConsume(state, @"!")) {
		id expression = XCPropertyMacroParseUnary(state);

		if (state->error != NULL && *state->error != nil)
			return (nil);
		return ([[XCPropertyMacroLogicalNOTExpression alloc]
		    initWithExpression:expression]);
	}
	return (XCPropertyMacroParsePrimary(state));
}

static id
XCPropertyMacroParseContains(XCPropertyMacroParserState *state)
{
	id expression = XCPropertyMacroParseUnary(state);

	while ([[XCPropertyMacroPeekText(state) description]
	    isEqualToString:@"contains"]) {
		id right;

		state->index++;
		right = XCPropertyMacroParseUnary(state);
		if (state->error != NULL && *state->error != nil)
			return (nil);
		expression = [[XCPropertyMacroContainsExpression alloc]
		    initWithLeftExpression:expression rightExpression:right];
	}
	return (expression);
}

static id
XCPropertyMacroParseEquality(XCPropertyMacroParserState *state)
{
	id expression = XCPropertyMacroParseContains(state);

	for (;;) {
		NSString *text = XCPropertyMacroPeekText(state);
		id right;

		if (![text isEqualToString:@"=="] &&
		    ![text isEqualToString:@"!="])
			break;
		state->index++;
		right = XCPropertyMacroParseContains(state);
		if (state->error != NULL && *state->error != nil)
			return (nil);
		if ([text isEqualToString:@"=="])
			expression = [[XCPropertyMacroEqualityExpression alloc]
			    initWithLeftExpression:expression
			    rightExpression:right];
		else
			expression = [[XCPropertyMacroInequalityExpression alloc]
			    initWithLeftExpression:expression
			    rightExpression:right];
	}
	return (expression);
}

static id
XCPropertyMacroParseLogicalAND(XCPropertyMacroParserState *state)
{
	id expression = XCPropertyMacroParseEquality(state);

	while ([[XCPropertyMacroPeekText(state) description]
	    isEqualToString:@"&&"]) {
		id right;

		state->index++;
		right = XCPropertyMacroParseEquality(state);
		if (state->error != NULL && *state->error != nil)
			return (nil);
		expression = [[XCPropertyMacroLogicalANDExpression alloc]
		    initWithLeftExpression:expression rightExpression:right];
	}
	return (expression);
}

static id
XCPropertyMacroParseLogicalOR(XCPropertyMacroParserState *state)
{
	id expression = XCPropertyMacroParseLogicalAND(state);

	while ([[XCPropertyMacroPeekText(state) description]
	    isEqualToString:@"||"]) {
		id right;

		state->index++;
		right = XCPropertyMacroParseLogicalAND(state);
		if (state->error != NULL && *state->error != nil)
			return (nil);
		expression = [[XCPropertyMacroLogicalORExpression alloc]
		    initWithLeftExpression:expression rightExpression:right];
	}
	return (expression);
}

static id
XCPropertyMacroParseConditional(XCPropertyMacroParserState *state)
{
	id condition = XCPropertyMacroParseLogicalOR(state);
	id thenExpression;
	id elseExpression;

	if (state->error != NULL && *state->error != nil)
		return (nil);
	if (!XCPropertyMacroConsume(state, @"?"))
		return (condition);
	thenExpression = XCPropertyMacroParseConditional(state);
	if (state->error != NULL && *state->error != nil)
		return (nil);
	if (!XCPropertyMacroConsume(state, @":")) {
		NSString *found = XCPropertyMacroPeekText(state);

		return (XCPropertyMacroFail(state, [NSString stringWithFormat:
		    @"expected ':' but found '%@' at offset %lu",
		    ((found != nil) ? found : @""),
		    (unsigned long)XCPropertyMacroPeekLocation(state)]));
	}
	elseExpression = XCPropertyMacroParseConditional(state);
	if (state->error != NULL && *state->error != nil)
		return (nil);
	return ([[XCPropertyMacroConditionalExpression alloc]
	    initWithConditionExpression:condition
	    thenExpression:thenExpression elseExpression:elseExpression]);
}

static id
XCPropertyMacroParseExpression(NSString *string, NSError **error)
{
	XCPropertyMacroParserState state;
	id expression;

	if (error != NULL)
		*error = nil;
	if (string == nil)
		string = @"";
	state.string = string;
	state.length = [string length];
	state.tokens = XCPropertyMacroTokenize(string);
	state.index = 0;
	state.error = error;
	if ([state.tokens count] == 0)
		return ([[XCPropertyMacroStringConstantExpression alloc]
		    initWithString:@""]);
	expression = XCPropertyMacroParseConditional(&state);
	if (error != NULL && *error != nil)
		return (nil);
	if (state.index < [state.tokens count]) {
		NSString *found = XCPropertyMacroPeekText(&state);

		return (XCPropertyMacroFail(&state, [NSString stringWithFormat:
		    @"expected operator or end-of-string, but found '%@' "
		    @"at offset %lu", found,
		    (unsigned long)XCPropertyMacroPeekLocation(&state)]));
	}
	return (expression);
}

static NSString *
XCPropertyMacroExpandLiteral(NSString *string, id scope)
{
	NSMutableString *result = [NSMutableString string];
	NSUInteger index = 0;
	NSUInteger length = [string length];

	if (scope == nil)
		return (nil);
	while (index < length) {
		NSRange open = [string rangeOfString:@"$(" options:0
		    range:NSMakeRange(index, length - index)];

		if (open.location == NSNotFound) {
			[result appendString:[string substringFromIndex:index]];
			break;
		}
		[result appendString:[string substringWithRange:
		    NSMakeRange(index, open.location - index)]];
		{
			NSRange close = [string rangeOfString:@")" options:0
			    range:NSMakeRange(NSMaxRange(open),
				length - NSMaxRange(open))];

			if (close.location == NSNotFound) {
				[result appendString:[string
				    substringFromIndex:open.location]];
				break;
			}
			{
				NSString *name = [string substringWithRange:
				    NSMakeRange(NSMaxRange(open),
					close.location - NSMaxRange(open))];
				id value = nil;

				if ([scope respondsToSelector:
				    @selector(evaluatedStringValueForMacroNamed:)])
					value = [scope performSelector:
					    @selector(evaluatedStringValueForMacroNamed:)
					    withObject:name];
				if (value != nil)
					[result appendString:
					    [value description]];
				else
					[result appendFormat:@"$(%@)", name];
			}
			index = NSMaxRange(close);
		}
	}
	return (result);
}

static NSString *
XCPropertyMacroEvaluateString(id expression, id scope)
{
	id value = [expression evaluateWithMacroExpansionScope:scope];

	return ([value isKindOfClass:[NSString class]] ? value : nil);
}

static BOOL
XCPropertyMacroEvaluateBoolean(id expression, id scope)
{
	return ([expression evaluateAsBooleanWithMacroExpansionScope:scope]);
}

@implementation XCPropertyMacroExpression

+ (id)propertyMacroExpressionFromString:(NSString *)string
				  error:(NSError **)error
{
	return (XCPropertyMacroParseExpression(string, error));
}

- (id)evaluateWithMacroExpansionScope:(id)scope
{
	(void)scope;
	return (nil);
}

- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope
{
	(void)scope;
	return (NO);
}

@end

@implementation XCPropertyMacroBooleanExpression
@end

@implementation XCPropertyMacroStringConstantExpression {
	NSString *_value;
}

- (instancetype)initWithString:(NSString *)string
{
	self = [super init];
	if (self != nil)
		_value = [string copy];
	return (self);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"'%@'", _value]);
}

- (id)evaluateWithMacroExpansionScope:(id)scope
{
	return (XCPropertyMacroExpandLiteral(_value, scope));
}

- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope
{
	NSString *value = [self evaluateWithMacroExpansionScope:scope];

	return (value != nil && [value length] != 0 &&
	    ![value isEqualToString:@"NO"]);
}

@end

@implementation XCPropertyMacroTrueConstantExpression

- (NSString *)description
{
	return (@"'YES'");
}

- (id)evaluateWithMacroExpansionScope:(id)scope
{
	(void)scope;
	return (@"YES");
}

- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope
{
	(void)scope;
	return (YES);
}

@end

@implementation XCPropertyMacroFalseConstantExpression

- (NSString *)description
{
	return (@"'NO'");
}

- (id)evaluateWithMacroExpansionScope:(id)scope
{
	(void)scope;
	return (@"NO");
}

- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope
{
	(void)scope;
	return (NO);
}

@end

@implementation XCPropertyMacroBinaryBooleanExpression {
	id _leftExpression;
	id _rightExpression;
}

- (instancetype)initWithLeftExpression:(id)leftExpression
		       rightExpression:(id)rightExpression
{
	self = [super init];
	if (self != nil) {
		_leftExpression = leftExpression;
		_rightExpression = rightExpression;
	}
	return (self);
}

- (id)leftExpression
{
	return (_leftExpression);
}

- (id)rightExpression
{
	return (_rightExpression);
}

@end

@implementation XCPropertyMacroEqualityExpression

- (NSString *)description
{
	return ([NSString stringWithFormat:@"(%@ EQ %@)",
	    [self leftExpression], [self rightExpression]]);
}

- (id)evaluateWithMacroExpansionScope:(id)scope
{
	NSString *left = XCPropertyMacroEvaluateString(
	    [self leftExpression], scope);
	NSString *right = XCPropertyMacroEvaluateString(
	    [self rightExpression], scope);
	BOOL equal = (left != nil && right != nil &&
	    [left isEqualToString:right]);

	return (equal ? @"YES" : @"NO");
}

- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope
{
	return ([[self evaluateWithMacroExpansionScope:scope]
	    isEqualToString:@"YES"]);
}

@end

@implementation XCPropertyMacroInequalityExpression

- (NSString *)description
{
	return ([NSString stringWithFormat:@"(%@ NEQ %@)",
	    [self leftExpression], [self rightExpression]]);
}

- (id)evaluateWithMacroExpansionScope:(id)scope
{
	NSString *left = XCPropertyMacroEvaluateString(
	    [self leftExpression], scope);
	NSString *right = XCPropertyMacroEvaluateString(
	    [self rightExpression], scope);
	BOOL equal = (left != nil && right != nil &&
	    [left isEqualToString:right]);

	return (equal ? @"NO" : @"YES");
}

- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope
{
	return ([[self evaluateWithMacroExpansionScope:scope]
	    isEqualToString:@"YES"]);
}

@end

@implementation XCPropertyMacroLogicalANDExpression

- (NSString *)description
{
	return ([NSString stringWithFormat:@"(%@ AND %@)",
	    [self leftExpression], [self rightExpression]]);
}

- (id)evaluateWithMacroExpansionScope:(id)scope
{
	BOOL value = XCPropertyMacroEvaluateBoolean([self leftExpression],
	    scope) && XCPropertyMacroEvaluateBoolean([self rightExpression],
	    scope);

	return (value ? @"YES" : @"NO");
}

- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope
{
	return ([[self evaluateWithMacroExpansionScope:scope]
	    isEqualToString:@"YES"]);
}

@end

@implementation XCPropertyMacroLogicalORExpression

- (NSString *)description
{
	return ([NSString stringWithFormat:@"(%@ OR %@)",
	    [self leftExpression], [self rightExpression]]);
}

- (id)evaluateWithMacroExpansionScope:(id)scope
{
	BOOL value = XCPropertyMacroEvaluateBoolean([self leftExpression],
	    scope) || XCPropertyMacroEvaluateBoolean([self rightExpression],
	    scope);

	return (value ? @"YES" : @"NO");
}

- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope
{
	return ([[self evaluateWithMacroExpansionScope:scope]
	    isEqualToString:@"YES"]);
}

@end

@implementation XCPropertyMacroLogicalXORExpression

- (NSString *)description
{
	return ([NSString stringWithFormat:@"(%@ XOR %@)",
	    [self leftExpression], [self rightExpression]]);
}

- (id)evaluateWithMacroExpansionScope:(id)scope
{
	BOOL value = XCPropertyMacroEvaluateBoolean([self leftExpression],
	    scope) != XCPropertyMacroEvaluateBoolean([self rightExpression],
	    scope);

	return (value ? @"YES" : @"NO");
}

- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope
{
	return ([[self evaluateWithMacroExpansionScope:scope]
	    isEqualToString:@"YES"]);
}

@end

@implementation XCPropertyMacroContainsExpression

- (NSString *)description
{
	return ([NSString stringWithFormat:@"(%@ CONTAINS %@)",
	    [self leftExpression], [self rightExpression]]);
}

- (id)evaluateWithMacroExpansionScope:(id)scope
{
	NSString *left = XCPropertyMacroEvaluateString(
	    [self leftExpression], scope);
	NSString *right = XCPropertyMacroEvaluateString(
	    [self rightExpression], scope);
	BOOL value = (left == nil || right == nil ||
	    [left rangeOfString:right].location != NSNotFound);

	return (value ? @"YES" : @"NO");
}

- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope
{
	return ([[self evaluateWithMacroExpansionScope:scope]
	    isEqualToString:@"YES"]);
}

@end

@implementation XCPropertyMacroLogicalNOTExpression {
	id _expression;
}

- (instancetype)initWithExpression:(id)expression
{
	self = [super init];
	if (self != nil)
		_expression = expression;
	return (self);
}

- (id)expression
{
	return (_expression);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"(NOT %@)", _expression]);
}

- (id)evaluateWithMacroExpansionScope:(id)scope
{
	BOOL value = !XCPropertyMacroEvaluateBoolean(_expression, scope);

	return (value ? @"YES" : @"NO");
}

- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope
{
	return (!XCPropertyMacroEvaluateBoolean(_expression, scope));
}

@end

@implementation XCPropertyMacroConditionalExpression {
	id _conditionExpression;
	id _thenExpression;
	id _elseExpression;
}

- (instancetype)initWithConditionExpression:(id)conditionExpression
			      thenExpression:(id)thenExpression
			      elseExpression:(id)elseExpression
{
	self = [super init];
	if (self != nil) {
		_conditionExpression = conditionExpression;
		_thenExpression = thenExpression;
		_elseExpression = elseExpression;
	}
	return (self);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"(%@ ? %@ : %@)",
	    _conditionExpression, _thenExpression, _elseExpression]);
}

- (id)evaluateWithMacroExpansionScope:(id)scope
{
	id expression = (XCPropertyMacroEvaluateBoolean(_conditionExpression,
	    scope) ? _thenExpression : _elseExpression);

	return ([expression evaluateWithMacroExpansionScope:scope]);
}

- (BOOL)evaluateAsBooleanWithMacroExpansionScope:(id)scope
{
	id expression = (XCPropertyMacroEvaluateBoolean(_conditionExpression,
	    scope) ? _thenExpression : _elseExpression);

	return (XCPropertyMacroEvaluateBoolean(expression, scope));
}

@end

static NSSet *
XCPropertyConditionFlavors(NSArray *names)
{
	NSMutableSet *flavors = [NSMutableSet set];

	for (NSString *name in names) {
		DVTMacroDefinitionConditionParameter *parameter =
		    [DVTMacroDefinitionConditionParameter
			conditionParameterNamed:name];

		if (parameter != nil)
			[flavors addObject:parameter];
	}
	return (flavors);
}

@implementation XCPropertyDefinition

+ (void)initialize
{
	if (self != [XCPropertyDefinition class])
		return;
	sPropertyTypesByName = [[NSMutableDictionary alloc] init];
	(void)XCPropertyTypeClassForIdentifier(@"string");
}

+ (NSString *)identifier
{
	return (@"string");
}

+ (NSString *)localizedName
{
	return (@"String");
}

+ (BOOL)isListType
{
	return (NO);
}

+ (Class)classForPropertyNamed:(NSString *)name typeString:(NSString *)type
{
	Class typeClass = nil;

	if (name != nil)
		typeClass = [sPropertyTypesByName objectForKey:name];
	if (typeClass == Nil)
		typeClass = XCPropertyTypeClassForIdentifier(type);
	return (typeClass);
}

+ (instancetype)propertyDefinitionFromPListDictionary:(TSPropertyListDictionary *)dictionary
{
	NSString *name;
	NSString *type;
	Class typeClass;
	id definition;

	if (![dictionary isKindOfClass:[NSDictionary class]])
		[NSException raise:NSInvalidArgumentException format:
		    @"%@ should be an instance inheriting from %@, but it is %@",
		    dictionary, [NSDictionary class], [dictionary class]];
	name = [dictionary stringOrNilForKey:@"Name"];
	type = [dictionary stringOrNilForKey:@"Type"];
	typeClass = [self classForPropertyNamed:name typeString:type];
	definition = [[typeClass alloc] initFromPListDictionary:dictionary];
	return (definition);
}

+ (id)_parsedDefaultValueForString:(NSString *)string
{
	if (![string isKindOfClass:[NSString class]])
		return (nil);
	return (DVTMacroExpressionByParsingString(string));
}

+ (instancetype)stringPropertyDefinitionWithName:(NSString *)name
				    defaultValue:(id)value
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

	[dictionary setObject:name forKey:@"Name"];
	[dictionary setObject:@"String" forKey:@"Type"];
	if (value != nil)
		[dictionary setObject:[value description] forKey:@"DefaultValue"];
	return ([self propertyDefinitionFromPListDictionary:
	    [TSPropertyListDictionary propertyListDictionaryWithDictionary:dictionary]]);
}

+ (NSArray *)dbgAllPropertyDefinitions
{
	return (@[]);
}

+ (void)_addPropertyDefinitionsInSpecificationDomain:(id)domain
					  toDictionary:(NSMutableDictionary *)dictionary
{
	(void)domain;
	(void)dictionary;
}

+ (NSArray *)allPropertyDefinitionsInAllSpecificationDomains
{
	return (@[]);
}

+ (NSArray *)baseDefinitionsForAllPropertyDefinitionsInAllSpecificationDomains
{
	return (@[]);
}

+ (Class)typeOfPropertyNamed:(NSString *)name
{
	return ([sPropertyTypesByName objectForKey:name]);
}

+ (BOOL)registerPropertyType:(Class)type forPropertyNamed:(NSString *)name
{
	if (![name isKindOfClass:[NSString class]] || type == Nil)
		return (NO);
	[sPropertyTypesByName setObject:type forKey:name];
	return (YES);
}

+ (BOOL)unregisterPropertyTypeForPropertyNamed:(NSString *)name
{
	if (![name isKindOfClass:[NSString class]])
		return (NO);
	if ([sPropertyTypesByName objectForKey:name] == nil)
		return (NO);
	[sPropertyTypesByName removeObjectForKey:name];
	return (YES);
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_typeClass = [XCStringPropertyDefinition class];
		_uiTypeClass = _typeClass;
		_localizedAllowedValues = @[];
	}
	return (self);
}

- (instancetype)initWithName:(NSString *)name
		      uiType:(id)type
	       allowedValues:(NSArray *)values
		 defaultValue:(id)value
	isAppleInternalOnly:(BOOL)only
		     isBasic:(BOOL)basic
	 commandLineArguments:(NSArray *)arguments
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

	[dictionary setObject:name forKey:@"Name"];
	[dictionary setObject:[[self class] identifier] forKey:@"Type"];
	if (type != nil) {
		if (object_getClass(type) != Nil &&
		    [type isKindOfClass:[NSString class]])
			[dictionary setObject:type forKey:@"UIType"];
		else
			[dictionary setObject:[type identifier] forKey:@"UIType"];
	}
	if (values != nil)
		[dictionary setObject:values forKey:@"AllowedValues"];
	if (value != nil)
		[dictionary setObject:[value description] forKey:@"DefaultValue"];
	if (only)
		[dictionary setObject:@"YES" forKey:@"AppleInternalOnly"];
	if (basic)
		[dictionary setObject:@"YES" forKey:@"Basic"];
	if (arguments != nil)
		[dictionary setObject:arguments forKey:@"CommandLineArgs"];
	return ([self initFromPListDictionary:
	    [TSPropertyListDictionary propertyListDictionaryWithDictionary:dictionary]]);
}

- (instancetype)initWithName:(NSString *)name
	       allowedValues:(NSArray *)values
		 defaultValue:(id)value
	isAppleInternalOnly:(BOOL)only
		     isBasic:(BOOL)basic
	 commandLineArguments:(NSArray *)arguments
{
	return ([self initWithName:name
			   uiType:nil
		    allowedValues:values
		      defaultValue:value
	     isAppleInternalOnly:only
			  isBasic:basic
	      commandLineArguments:arguments]);
}

- (instancetype)initFromPListDictionary:(TSPropertyListDictionary *)dictionary
{
	NSArray *values;
	NSArray *displayValues;
	NSString *typeString;
	NSString *uiTypeString;

	if (![dictionary isKindOfClass:[NSDictionary class]])
		[NSException raise:NSInvalidArgumentException format:
		    @"%@ should be an instance inheriting from %@, but it is %@",
		    dictionary, [NSDictionary class], [dictionary class]];
	self = [self init];
	if (self == nil)
		return (nil);

	_properties = dictionary;
	_supportedVersionRanges = XCPropertySupportedVersionRanges(dictionary);
	_name = [dictionary stringOrNilForKey:@"Name"];
	typeString = [dictionary stringOrNilForKey:@"Type"];
	_typeClass = [[self class] classForPropertyNamed:_name typeString:typeString];
	uiTypeString = [dictionary stringOrNilForKey:@"UIType"];
	_uiTypeClass = ((uiTypeString != nil)
	    ? XCPropertyTypeClassForIdentifier(uiTypeString) : _typeClass);

	values = [dictionary arrayOrNilForKey:@"Values"];
	if (values == nil)
		values = [dictionary arrayOrNilForKey:@"AllowedValues"];
	_allowedValues = [values copy];
	displayValues = [dictionary arrayOrNilForKey:@"DisplayValues"];
	if ([_typeClass isEqual:[XCEnumerationPropertyDefinition class]]) {
		_localizedAllowedValues = (_allowedValues != nil)
		    ? _allowedValues : @[];
	} else if (displayValues != nil)
		_localizedAllowedValues = [displayValues copy];
	else if ([self isListType])
		_localizedAllowedValues = @[];
	else if ([_typeClass isEqual:[XCBooleanPropertyDefinition class]] &&
	    _allowedValues == nil)
		_localizedAllowedValues = @[@"Yes", @"No"];
	else if (_allowedValues != nil)
		_localizedAllowedValues = _allowedValues;
	else
		_localizedAllowedValues = @[];

	_defaultString = [dictionary stringOrNilForKey:@"DefaultValue"];
	if (_defaultString != nil) {
		if ([[self class] isListType])
			_defaultValue = DVTMacroExpressionByParsingStringAsList(_defaultString);
		else
			_defaultValue = (id <DVTMacroExpansion>)_defaultString;
	}

	_category = [dictionary stringOrNilForKey:@"Category"];
	_localizedName = [dictionary stringOrNilForKey:@"DisplayName"];
	if (_localizedName == nil)
		_localizedName = _name;
	_localizedDescription = [dictionary stringOrNilForKey:@"Description"];
	_definitionLocationDescription = [dictionary stringOrNilForKey:@"DefinitionLocationDescription"];
	_commandLineArgs = [dictionary arrayOrNilForKey:@"CommandLineArgs"];
	_commandLineFlag = [dictionary stringOrNilForKey:@"CommandLineFlag"];
	_commandLinePrefixFlag = [dictionary stringOrNilForKey:@"CommandLinePrefixFlag"];
	_additionalBuildSettings = [dictionary dictionaryOrNilForKey:@"AdditionalBuildSettings"];
	_conditionFlavors = XCPropertyConditionFlavors(
	    [dictionary arrayOrNilForKey:@"ConditionFlavors"] ?: @[]);
	{
		NSString *condition = [dictionary stringOrNilForKey:@"Condition"];

		if (condition != nil) {
			NSError *error = nil;

			_conditionExpression = [XCPropertyMacroExpression
			    propertyMacroExpressionFromString:condition
			    error:&error];
		}
	}
	_isAppleInternalOnly = [[dictionary stringOrNilForKey:@"AppleInternalOnly"] boolValue];
	_isBasic = [[dictionary stringOrNilForKey:@"Basic"] boolValue];
	_uiShouldRemoveIfEmpty = [[dictionary stringOrNilForKey:@"UIRemoveIfEmpty"] boolValue];
	return (self);
}

- (Class <XCPropertyTypes>)type
{
	return ((Class <XCPropertyTypes>)_typeClass);
}

- (Class <XCPropertyTypes>)uiType
{
	return ((Class <XCPropertyTypes>)_uiTypeClass);
}

- (BOOL)isListType
{
	return ([_typeClass isListType]);
}

- (NSString *)typeString
{
	return ([_typeClass identifier]);
}

- (NSString *)uiTypeString
{
	return ([_uiTypeClass identifier]);
}

- (NSArray *)allowedValuesInTarget:(id)target
{
	(void)target;
	return (_allowedValues);
}

- (NSArray *)localizedAllowedValuesInTarget:(id)target
{
	(void)target;
	return (_localizedAllowedValues);
}

- (NSDictionary *)additionalBuildSettings
{
	return (_additionalBuildSettings);
}

- (NSSet *)supportedArchitectures
{
	return ([NSSet setWithArray:
	    ([_properties arrayOrNilForKey:@"Architectures"] ?: @[])]);
}

- (NSSet *)supportedArchitecturesInDomain:(id)domain
			 withMacroExpansionScope:(id)scope
{
	(void)domain;
	(void)scope;
	return ([self supportedArchitectures]);
}

- (BOOL)supportsArchitecture:(NSString *)architecture
		    inDomain:(id)domain
	 withMacroExpansionScope:(id)scope
{
	if ([_properties objectOrNilForKey:@"Architectures"] == nil)
		return (YES);
	return ([[self supportedArchitecturesInDomain:domain
				 withMacroExpansionScope:scope]
	    containsObject:architecture]);
}

- (NSSet *)supportedFileTypes
{
	return ([NSSet setWithArray:
	    ([_properties arrayOrNilForKey:@"FileTypes"] ?: @[])]);
}

- (BOOL)supportsFileType:(NSString *)type
{
	return ([[self supportedFileTypes] containsObject:type]);
}

- (BOOL)hasSupportedVersionRanges
{
	return (_supportedVersionRanges != nil);
}

- (BOOL)supportsVersion:(id)version
{
	for (XCPropertyDefinition_SupportedVersionRange *range in _supportedVersionRanges) {
		if ([range supportsVersion:version])
			return (YES);
	}
	return (_supportedVersionRanges == nil);
}

- (XCPropertyDomainSpecification *)propertyDomain
{
	return (_domain);
}

- (void)setPropertyDomain:(XCPropertyDomainSpecification *)domain
{
	_domain = domain;
}

- (NSSet *)conditionFlavors
{
	return (_conditionFlavors);
}

- (BOOL)isAppleInternalOnly
{
	return (_isAppleInternalOnly);
}

- (BOOL)isBasic
{
	return (_isBasic);
}

- (BOOL)canGenerateCommandLineArguments
{
	return (YES);
}

- (id)commandArgumentGenerationInfo
{
	if (_commandLineArgs != nil)
		return (_commandLineArgs);
	if (_commandLineFlag != nil)
		return (@{@"": @[], @"<<otherwise>>": @[_commandLineFlag, @"$(value)"]});
	if (_commandLinePrefixFlag != nil)
		return (@{@"": @[], @"<<otherwise>>":
		    [_commandLinePrefixFlag stringByAppendingString:@"$(value)"]});
	return (nil);
}

- (id)conditionExpression
{
	return (_conditionExpression);
}

- (NSString *)nameOfOptionToPrecedeOnCommandLine
{
	return ([_properties stringOrNilForKey:@"NameOfOptionToPrecedeOnCommandLine"]);
}

- (NSString *)nameOfOptionToSucceedOnCommandLine
{
	return ([_properties stringOrNilForKey:@"NameOfOptionToSucceedOnCommandLine"]);
}

- (NSString *)nameOfOptionToPrecedeInUserInterface
{
	return ([_properties stringOrNilForKey:@"NameOfOptionToPrecedeInUserInterface"]);
}

- (NSString *)nameOfOptionToSucceedInUserInterface
{
	return ([_properties stringOrNilForKey:@"NameOfOptionToSucceedInUserInterface"]);
}

- (BOOL)uiShouldRemoveIfEmptyValue
{
	return (_uiShouldRemoveIfEmpty);
}

- (BOOL)isUserDefined
{
	return (_isUserDefined);
}

- (void)setUserDefined:(BOOL)defined
{
	_isUserDefined = defined;
}

- (TSPropertyListDictionary *)properties
{
	return (_properties);
}

- (id)valueForUndefinedKey:(NSString *)key
{
	return ([_properties objectOrNilForKey:key]);
}

- (NSString *)definitionLocationDescription
{
	return (_definitionLocationDescription);
}

- (void)setDefinitionLocationDescription:(NSString *)description
{
	_definitionLocationDescription = [description copy];
}

- (NSString *)categoryNameForUserInterface
{
	return (_category);
}

- (BOOL)propertyIsEnabledWithMacroExpansionScope:(id)scope
{
	if (_conditionExpression == nil)
		return (YES);
	return ([_conditionExpression
	    evaluateAsBooleanWithMacroExpansionScope:scope]);
}

- (NSString *)description
{
	NSString *allowed = ((_allowedValues != nil)
	    ? [_allowedValues description] : @"-");
	id defaultDescription = _defaultString;

	if ([self isListType] && _defaultString != nil)
		defaultDescription = [XCPropertyListWords(_defaultString) description];

	return ([NSString stringWithFormat:@"<%@:'%@':%@:%@:'%@'>",
	    NSStringFromClass([self class]), _name, [self typeString],
	    allowed, defaultDescription]);
}

- (void)printToStdout
{
	printf("%s\n", [[self description] UTF8String]);
}

@end
