/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef DEVTOOLSSUPPORT_TSREGULAREXPRESSION_H
#define DEVTOOLSSUPPORT_TSREGULAREXPRESSION_H

#import <Foundation/Foundation.h>

@interface TSRegularExpression : NSObject <NSCopying, NSCoding> {
	NSString *_expressionString;
	BOOL _ignoreCase;
	NSRegularExpression *_regularExpression;
}

- (id)initWithExpressionString:(id)string;
- (id)initWithExpressionString:(id)string ignoreCase:(BOOL)ignoreCase;
- (id)expressionString;
- (BOOL)matchesString:(id)string;
- (NSRange)rangeForSubexpressionAtIndex:(NSUInteger)index inString:(id)string;
- (id)substringForSubexpressionAtIndex:(NSUInteger)index inString:(id)string;

@end

#endif	/* DEVTOOLSSUPPORT_TSREGULAREXPRESSION_H */
