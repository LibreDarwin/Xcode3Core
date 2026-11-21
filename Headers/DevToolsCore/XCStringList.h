/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCStringList.
 */

#ifndef DEVTOOLSCORE_XCSTRINGLIST_H
#define DEVTOOLSCORE_XCSTRINGLIST_H

#import <Foundation/Foundation.h>

@interface XCStringList : NSObject <NSCopying>
+ (void)initialize;
+ (XCStringList *)stringList;
+ (XCStringList *)stringListWithString:(NSString *)string;
+ (XCStringList *)stringListFromArrayRepresentation:(NSArray *)array;
+ (XCStringList *)stringListFromStringRepresentation:(NSString *)representation;
+ (void)printStatistics;
- (id)initWithStrings:(id __unsafe_unretained *)strings count:(NSUInteger)count;
- (id)initWithStrings:(id)strings;
- (id)initWithStringArray:(NSArray *)strings;
- (id)initWithString:(NSString *)string;
- (NSUInteger)count;
- (void)getUTF8StringPtrs:(const char **)pointers;
- (void)enumerateUTF8StringsUsingBlock:(void (^)(const char *string))block;
- (void)appendUTF8String:(const char *)string length:(NSUInteger)length;
- (void)appendUTF8String:(const char *)string;
- (void)appendUTF8Strings:(const char *)string;
- (void)appendStrings:(id __unsafe_unretained *)strings count:(NSUInteger)count;
- (void)appendString:(id)string;
- (void)appendStringList:(XCStringList *)list;
- (void)appendElementsByTransferringFromStringList:(XCStringList *)list;
- (void)prependUTF8String:(const char *)string length:(NSUInteger)length;
- (void)prependUTF8String:(const char *)string;
- (void)prependUTF8Strings:(const char *)string;
- (void)removeUTF8String:(const char *)string length:(NSUInteger)length;
- (void)replaceUTF8String:(const char *)oldString length:(NSUInteger)oldLength
	withUTF8String:(const char *)newString length:(NSUInteger)newLength;
- (BOOL)areStringPatternsMatchedByUTF8String:(const char *)string;
- (BOOL)areFilenamePatternsMatchedByUTF8String:(const char *)string;
- (NSString *)stringRepresentation;
- (NSArray *)arrayRepresentation;
- (NSString *)stringRepresentationForDebugging;
@end

#endif	/* DEVTOOLSCORE_XCSTRINGLIST_H */
