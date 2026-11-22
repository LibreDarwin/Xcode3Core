/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of the private XCPropertyDefinition version
 * range object used by SupportedVersionRanges in .xcspec property lists.
 */

#ifndef DEVTOOLSCORE_BUILDSYSTEM_XCPROPERTYDEFINITION_SUPPORTEDVERSIONRANGE_H
#define DEVTOOLSCORE_BUILDSYSTEM_XCPROPERTYDEFINITION_SUPPORTEDVERSIONRANGE_H

#import <Foundation/Foundation.h>

@class DVTVersion;

NS_ASSUME_NONNULL_BEGIN

@interface XCPropertyDefinition_SupportedVersionRange : NSObject {
	DVTVersion *_startVersion;
	DVTVersion *_endVersion;
}

- (instancetype)initWithStartOfRange:(DVTVersion *)startVersion
			 endOfRange:(nullable DVTVersion *)endVersion;
- (BOOL)supportsVersion:(DVTVersion *)version;

@end

NS_ASSUME_NONNULL_END

#endif
