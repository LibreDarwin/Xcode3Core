/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCPropertyCategory.
 */

#ifndef DEVTOOLSCORE_BUILDSYSTEM_XCPROPERTYCATEGORY_H
#define DEVTOOLSCORE_BUILDSYSTEM_XCPROPERTYCATEGORY_H

#import <Foundation/Foundation.h>

@class TSPropertyListDictionary;

@interface XCPropertyCategory : NSObject <NSCopying> {
	NSString *_name;
	NSMutableArray *_propertyNames;
	NSString *_iconName;
	BOOL _isUserDefined;
	NSString *_localizedName;
	NSString *_localizedDescription;
}

- (instancetype)initWithName:(NSString *)name propertyNames:(NSArray *)names;
- (instancetype)initWithName:(NSString *)name
		   propertyNames:(NSArray *)names
		stringsDictionary:(NSDictionary *)strings;
- (instancetype)initWithPropertyListDictionary:(TSPropertyListDictionary *)dictionary;
- (instancetype)initWithName:(NSString *)name;
- (instancetype)init;

- (NSString *)name;
- (NSArray *)propertyNames;
- (NSArray *)propertyDefinitionsWithLookupDictionary:(NSDictionary *)dictionary;
- (NSString *)iconName;
- (void)setIconName:(NSString *)name;
- (BOOL)isUserDefined;
- (void)setUserDefined:(BOOL)defined;
- (void)addOptionName:(NSString *)name
      aboveOptionName:(NSString *)above
      belowOptionName:(NSString *)below;
- (void)removeOptionName:(NSString *)name;
- (NSString *)localizedName;
- (NSString *)localizedDescription;

@end

#endif	/* DEVTOOLSCORE_BUILDSYSTEM_XCPROPERTYCATEGORY_H */
