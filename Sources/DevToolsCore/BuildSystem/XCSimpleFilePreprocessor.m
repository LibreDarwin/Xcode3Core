/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCSimpleFilePreprocessor. */

#import "DevToolsCore/BuildSystem/XCSimpleFilePreprocessor.h"

@implementation XCSimpleFilePreprocessorStatement
@end

@implementation XCSimpleFilePreprocessorText

- (id)initWithText:(NSString *)text
{
	return ([self initWithText:text lineEnding:nil]);
}

- (id)initWithText:(NSString *)text lineEnding:(NSString *)lineEnding
{
	self = [super init];
	if (self != nil) {
		_text = [text copy];
		if (_text != nil && lineEnding != nil)
			_text = [_text stringByAppendingString:lineEnding];
	}
	return (self);
}

- (NSString *)text
{
	return (_text);
}

+ (id)joinedTextStatementFromStatements:(NSArray *)statements
{
	NSMutableString *joined = [NSMutableString string];

	for (id statement in statements) {
		if ([statement isKindOfClass:[XCSimpleFilePreprocessorText class]]) {
			NSString *text = [(XCSimpleFilePreprocessorText *)statement text];

			if (text != nil)
				[joined appendString:text];
		}
	}
	return (joined);
}

@end

@implementation XCSimpleFilePreprocessorInclude

- (id)initWithPathFragment:(NSString *)fragment
                lineNumber:(NSInteger)lineNumber
                lineEnding:(NSString *)lineEnding
                 isOptional:(BOOL)optional
{
	self = [super init];
	if (self != nil) {
		_isOptional = optional;
		_pathFragment = [fragment copy];
		_lineEnding = [lineEnding copy];
		_lineNumber = lineNumber;
	}
	return (self);
}

- (NSString *)pathFragment
{
	return (_pathFragment);
}

- (BOOL)isOptional
{
	return (_isOptional);
}

- (NSString *)lineEnding
{
	return (_lineEnding);
}

- (NSInteger)lineNumber
{
	return (_lineNumber);
}

@end

@implementation XCSimpleFilePreprocessorParsedFile

- (id)initWithStatements:(NSArray *)statements
           errorMessages:(NSArray *)errorMessages
{
	self = [super init];
	if (self != nil) {
		_statements = [statements copy];
		_errorMessages = [errorMessages copy];
	}
	return (self);
}

- (NSArray *)statements
{
	return (_statements);
}

- (NSArray *)errorMessages
{
	return (_errorMessages);
}

@end

static BOOL
XCSFPPParseInclude(NSString *line, NSString **fragment, BOOL *malformed)
{
	NSUInteger length = [line length];
	NSUInteger index = 0;
	NSUInteger start;
	NSUInteger end;

	*fragment = nil;
	*malformed = NO;
	while (index < length) {
		unichar character = [line characterAtIndex:index];

		if (character != ' ' && character != '\t')
			break;
		index++;
	}
	if (index + 8 > length ||
	    [line compare:@"#include" options:0
	          range:NSMakeRange(index, 8)] != NSOrderedSame)
		return (NO);
	index += 8;
	while (index < length) {
		unichar character = [line characterAtIndex:index];

		if (character != ' ' && character != '\t')
			break;
		index++;
	}
	if (index >= length || [line characterAtIndex:index] != '"') {
		*malformed = YES;
		return (YES);
	}
	start = ++index;
	end = start;
	while (end < length && [line characterAtIndex:end] != '"')
		end++;
	if (end >= length) {
		*malformed = YES;
		return (YES);
	}
	*fragment = [line substringWithRange:NSMakeRange(start, end - start)];
	return (YES);
}

static void
XCSFPPAddError(NSMutableArray *errors, NSString *path, NSUInteger lineNumber,
    NSString *reason)
{
	[errors addObject:[NSString stringWithFormat:@"%@ line %lu: %@",
	    [path lastPathComponent], (unsigned long)lineNumber, reason]];
}

@implementation XCSimpleFilePreprocessor

+ (id)preprocessor
{
	return ([[self alloc] init]);
}

- (BOOL)forceIncludedFilesToEndWithNewline
{
	return (_forceIncludeFilesToEndWithNewline);
}

- (void)setForceIncludedFilesToEndWithNewline:(BOOL)flag
{
	_forceIncludeFilesToEndWithNewline = flag;
}

- (NSArray *)includeSearchPath
{
	return (_includeSearchPath);
}

- (void)setIncludeSearchPath:(NSArray *)paths
{
	_includeSearchPath = [paths copy];
}

- (NSString *)_pathToIncludedFileNamed:(NSString *)name
                        usingSearchPath:(NSArray *)paths
{
	NSFileManager *manager = [NSFileManager defaultManager];

	if (name == nil || [name length] == 0)
		return (nil);
	for (NSString *directory in paths) {
		NSString *candidate = [directory stringByAppendingPathComponent:name];

		if ([manager fileExistsAtPath:candidate])
			return (candidate);
	}
	return (nil);
}

- (NSString *)_preprocessFileAtPath:(NSString *)path
                          seenFiles:(NSMutableSet *)seenFiles
{
	NSString *contents = [NSString stringWithContentsOfFile:path
	    encoding:_encoding error:NULL];
	NSMutableString *result = [NSMutableString string];
	NSUInteger location = 0;
	NSUInteger length;
	NSUInteger lineNumber = 1;

	if (contents == nil) {
		XCSFPPAddError(_errors, path, 1, @"Unable to read file");
		return (@"");
	}
	[_filesProcessed addObject:path];
	[seenFiles addObject:path];
	length = [contents length];
	while (location < length) {
		NSRange newline = [contents rangeOfString:@"\n"
		    options:0 range:NSMakeRange(location, length - location)];
		NSString *line;
		NSString *ending;
		NSUInteger next;
		NSString *fragment;
		BOOL malformed;
		BOOL include;

		if (newline.location != NSNotFound) {
			NSUInteger end = newline.location;

			if (end > location &&
			    [contents characterAtIndex:end - 1] == '\r') {
				end--;
				ending = @"\r\n";
			} else {
				ending = @"\n";
			}
			line = [contents substringWithRange:NSMakeRange(location,
			    end - location)];
			next = newline.location + 1;
		} else {
			line = [contents substringFromIndex:location];
			ending = @"";
			next = length;
		}

		include = XCSFPPParseInclude(line, &fragment, &malformed);
		if (!include) {
			[result appendString:line];
			[result appendString:ending];
		} else if (malformed) {
			XCSFPPAddError(_errors, path, lineNumber,
			    @"Unable to parse included filename");
			[result appendString:ending];
		} else {
			NSString *included = [self _pathToIncludedFileNamed:fragment
			    usingSearchPath:_includeSearchPath];

			if (included == nil) {
				XCSFPPAddError(_errors, path, lineNumber,
				    [NSString stringWithFormat:
				    @"Unable to find included file \"%@\"", fragment]);
				[result appendString:ending];
			} else if (![seenFiles containsObject:included]) {
				NSString *expanded = [self _preprocessFileAtPath:included
				    seenFiles:seenFiles];

				[result appendString:expanded];
				if (_forceIncludeFilesToEndWithNewline &&
				    ![expanded hasSuffix:@"\n"])
					[result appendString:@"\n"];
			}
		}
		location = next;
		lineNumber++;
	}
	return (result);
}

- (NSString *)preprocessFileAtPath:(NSString *)path
                          encoding:(NSStringEncoding)encoding
{
	_filePath = [path copy];
	_encoding = encoding;
	_filesProcessed = [NSMutableSet set];
	_errors = [NSMutableArray array];
	_result = [self _preprocessFileAtPath:path
	    seenFiles:[NSMutableSet set]];
	return (_result);
}

- (NSString *)preprocessedFilePath
{
	return (_filePath);
}

- (NSStringEncoding)fileEncoding
{
	return (_encoding);
}

- (NSString *)preprocessedFileContents
{
	return (_result);
}

- (NSSet *)filesProcessed
{
	return (_filesProcessed);
}

- (NSArray *)errors
{
	return (_errors);
}

@end
