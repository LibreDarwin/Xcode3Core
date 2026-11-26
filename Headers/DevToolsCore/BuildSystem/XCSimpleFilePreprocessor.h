/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCSimpleFilePreprocessor. */

#ifndef DEVTOOLSCORE_BUILDSYSTEM_XCSIMPLEFILEPREPROCESSOR_H
#define DEVTOOLSCORE_BUILDSYSTEM_XCSIMPLEFILEPREPROCESSOR_H

#import <Foundation/Foundation.h>

@interface XCSimpleFilePreprocessorStatement : NSObject
@end

@interface XCSimpleFilePreprocessorText : XCSimpleFilePreprocessorStatement
{
    NSString *_text;
}
- (id)initWithText:(NSString *)text;
- (id)initWithText:(NSString *)text lineEnding:(NSString *)lineEnding;
- (NSString *)text;
+ (id)joinedTextStatementFromStatements:(NSArray *)statements;
@end

@interface XCSimpleFilePreprocessorInclude : XCSimpleFilePreprocessorStatement
{
    BOOL _isOptional;
    NSString *_pathFragment;
    NSString *_lineEnding;
    NSInteger _lineNumber;
}
- (id)initWithPathFragment:(NSString *)fragment
                lineNumber:(NSInteger)lineNumber
                lineEnding:(NSString *)lineEnding
                 isOptional:(BOOL)optional;
- (NSString *)pathFragment;
- (BOOL)isOptional;
- (NSString *)lineEnding;
- (NSInteger)lineNumber;
@end

@interface XCSimpleFilePreprocessorParsedFile : NSObject
{
    NSArray *_statements;
    NSArray *_errorMessages;
}
- (id)initWithStatements:(NSArray *)statements
           errorMessages:(NSArray *)errorMessages;
- (NSArray *)statements;
- (NSArray *)errorMessages;
@end

@interface XCSimpleFilePreprocessor : NSObject
{
    BOOL _forceIncludeFilesToEndWithNewline;
    NSArray *_includeSearchPath;
    NSString *_filePath;
    NSStringEncoding _encoding;
    NSString *_result;
    NSMutableSet *_filesProcessed;
    NSMutableArray *_errors;
}
+ (id)preprocessor;
- (BOOL)forceIncludedFilesToEndWithNewline;
- (void)setForceIncludedFilesToEndWithNewline:(BOOL)flag;
- (NSArray *)includeSearchPath;
- (void)setIncludeSearchPath:(NSArray *)paths;
- (NSString *)_pathToIncludedFileNamed:(NSString *)name
                        usingSearchPath:(NSArray *)paths;
- (NSString *)_preprocessFileAtPath:(NSString *)path
                          seenFiles:(NSMutableSet *)seenFiles;
- (NSString *)preprocessFileAtPath:(NSString *)path
                          encoding:(NSStringEncoding)encoding;
- (NSString *)preprocessedFilePath;
- (NSStringEncoding)fileEncoding;
- (NSString *)preprocessedFileContents;
- (NSSet *)filesProcessed;
- (NSArray *)errors;
@end

#endif	/* DEVTOOLSCORE_BUILDSYSTEM_XCSIMPLEFILEPREPROCESSOR_H */
