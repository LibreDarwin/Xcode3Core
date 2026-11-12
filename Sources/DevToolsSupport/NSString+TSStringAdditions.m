/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsSupport's
 * NSString (TSStringAdditions) byte-order-mark sniffing helpers. */

#import "DevToolsSupport/NSString+TSStringAdditions.h"

@implementation NSString (TSStringAdditions)

+ (BOOL)isFileUnicode:(NSString *)path fileData:(NSData *)fileData
{
	NSData *data = fileData;

	if (data == nil) {
		/* Apple maps the file with -initWithContentsOfMappedFile:; that
		 * selector is deprecated, so the mapped-read options are used. */
		data = [NSData dataWithContentsOfFile:path
					      options:NSDataReadingMappedIfSafe
						error:NULL];
	}
	if ([data length] < 2)
		return (NO);

	const unsigned char *bytes = [data bytes];

	if (bytes == NULL)
		return (NO);

	return ((bytes[0] == 0xFE && bytes[1] == 0xFF) ||
	    (bytes[0] == 0xFF && bytes[1] == 0xFE));
}

+ (BOOL)isFileUTF8WithBOM:(NSString *)path fileData:(NSData *)fileData
{
	NSData *data = fileData;

	if (data == nil) {
		/* Apple maps the file with -initWithContentsOfMappedFile:; that
		 * selector is deprecated, so the mapped-read options are used. */
		data = [NSData dataWithContentsOfFile:path
					      options:NSDataReadingMappedIfSafe
						error:NULL];
	}
	if ([data length] < 3)
		return (NO);

	const unsigned char *bytes = [data bytes];

	if (bytes == NULL)
		return (NO);

	return (bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF);
}

@end
