/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsSupport's
 * NSString (TSStringAdditions) byte-order-mark sniffing helpers.
 *
 * Only the two class methods that DevToolsCore's PBXFileType uses are
 * reconstructed; the remaining TSStringAdditions API is unrelated to the
 * archive pipeline and is not implemented. */

#ifndef DEVTOOLSSUPPORT_NSSTRING_TSSTRINGADDITIONS_H
#define DEVTOOLSSUPPORT_NSSTRING_TSSTRINGADDITIONS_H

#import <Foundation/Foundation.h>

@interface NSString (TSStringAdditions)

/* Returns YES when the file's first bytes are a Unicode byte-order mark
 * (FE FF or FF FE).  When fileData is nil the file is mapped and read. */
+ (BOOL)isFileUnicode:(NSString *)path fileData:(NSData *)fileData;

/* Returns YES when the file's first bytes are a UTF-8 byte-order mark
 * (EF BB BF).  When fileData is nil the file is mapped and read. */
+ (BOOL)isFileUTF8WithBOM:(NSString *)path fileData:(NSData *)fileData;

@end

#endif	/* DEVTOOLSSUPPORT_NSSTRING_TSSTRINGADDITIONS_H */
