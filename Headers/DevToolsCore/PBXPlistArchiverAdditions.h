/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef DEVTOOLSCORE_PBXPLISTARCHIVERADDITIONS_H
#define DEVTOOLSCORE_PBXPLISTARCHIVERADDITIONS_H

#import <Foundation/Foundation.h>

@interface PBXPlistArchiverAlwaysQuotedString : NSString
+ (instancetype)wrapString:(NSString *)string;
- (instancetype)initWithString:(NSString *)string;
- (void)_appendPListDescriptionToUTF8Data:(NSMutableData *)data
    withIndentLevel:(NSUInteger)level;
@end

@interface PBXPListArchiverStringWithComment : NSString
- (instancetype)initWithString:(NSString *)string comment:(NSString *)comment;
- (void)_appendPListDescriptionToUTF8Data:(NSMutableData *)data
    withIndentLevel:(NSUInteger)level;
@end

@interface PBXPlistArchiverSingleLineArray : NSArray
+ (instancetype)wrapArray:(NSArray *)array;
- (instancetype)initWithArray:(NSArray *)array;
- (void)_appendPListDescriptionToUTF8Data:(NSMutableData *)data
    withIndentLevel:(NSUInteger)level;
@end

#endif	/* DEVTOOLSCORE_PBXPLISTARCHIVERADDITIONS_H */
