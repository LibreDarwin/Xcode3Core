/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Items carrying platform filters (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXPLATFORMFILTERABLEITEM_H
#define DEVTOOLSCORE_PBXPLATFORMFILTERABLEITEM_H

#import "DevToolsCore/PBXProject.h"

@class NSSet;

/*
 * Base class for project items that restrict their build membership to a
 * set of platforms.  The legacy single-filter key ("platformFilter") is
 * kept alongside the modern list ("platformFilters") so either form can be
 * loaded and re-archived unchanged.
 */
@interface PBXPlatformFilterableItem : PBXProjectItem
{
	NSArray *_platformFilters;
	NSString *_platformFilter;
}
@property (nonatomic, copy) NSArray *platformFilters;
@property (nonatomic, readonly) BOOL hasUnknownPlatformFilters;

- (NSArray *)platformFilters;
- (void)setPlatformFilters:(NSArray *)filters;
- (NSString *)platformFilter;
- (void)setPlatformFilter:(NSString *)filter;
- (NSSet *)unknownPlatformFilters;
- (void)resetPlatformFilters;
- (NSSet *)_allPlatformFilters;
- (NSArray *)_platformFilters;
- (void)_setPlatformFilters:(NSArray *)filters;
- (NSString *)_platformFilter;
- (void)_setPlatformFilter:(NSString *)filter;
- (BOOL)shouldArchivePlatformFilters;
- (BOOL)shouldArchivePlatformFilter;
@end

#endif	/* DEVTOOLSCORE_PBXPLATFORMFILTERABLEITEM_H */
