/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Platform filters (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXPLATFORMFILTER_H
#define DEVTOOLSCORE_PBXPLATFORMFILTER_H

#import <Foundation/Foundation.h>

@class PBXReference, PBXTarget;

/*
 * A platform (and optional environment) that a build file applies to.
 * The serialized "friendly" form is "platform" or "platform-environment",
 * e.g. "ios", "ios-simulator", "ios-maccatalyst".
 */
@interface PBXPlatformFilter : NSObject
{
	NSString *_platform;
	NSString *_environment;
	NSString *_impliedByPlatform;
	NSString *_displayName;
}
@property (nonatomic, readonly) NSString *platform;
@property (nonatomic, readonly) NSString *environment;
@property (nonatomic, readonly) NSString *impliedByPlatform;
@property (nonatomic, readonly) NSString *friendlySerializableValue;
@property (nonatomic, readonly) NSString *displayName;

+ (NSDictionary *)filterDescriptionToPlatformName;
+ (NSArray *)allFilters;
+ (instancetype)filterFromDictionary:(NSDictionary *)dictionary;
+ (instancetype)filterFromString:(NSString *)string;
+ (NSArray *)friendlySerializableValuesFromFilters:(NSArray *)filters;
+ (NSArray *)filtersFromFriendlySerializableValue:(NSString *)value;
+ (NSArray *)filtersFromFriendlySerializableValues:(NSArray *)values;

- (instancetype)initWithPlatform:(NSString *)platform
    environment:(NSString *)environment;
- (instancetype)initWithPlatform:(NSString *)platform
    environment:(NSString *)environment displayName:(NSString *)name;
- (instancetype)initWithPlatform:(NSString *)platform
    environment:(NSString *)environment
    impliedByPlatform:(NSString *)implied;
- (instancetype)initWithPlatform:(NSString *)platform
    environment:(NSString *)environment displayName:(NSString *)name
    impliedByPlatform:(NSString *)implied;
- (NSDictionary *)dictionaryForm;
- (NSComparisonResult)compare:(PBXPlatformFilter *)other;
@end

#endif	/* DEVTOOLSCORE_PBXPLATFORMFILTER_H */
