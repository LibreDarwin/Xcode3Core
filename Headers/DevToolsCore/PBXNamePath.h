/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Name-path references (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXNAMEPATH_H
#define DEVTOOLSCORE_PBXNAMEPATH_H

#import <Foundation/Foundation.h>

@class PBXReference;

typedef NS_ENUM(NSUInteger, PBXNamePathComponentType) {
	PBXNamePathComponentTypeName = 0,
	PBXNamePathComponentTypeParent = 1,
	PBXNamePathComponentTypeSelf = 2,
};

/* One component of a name path: a name, ".." (parent) or "." (self). */
@interface PBXNamePathComponent : NSObject <NSCopying>
{
	NSString *_name;
	PBXNamePathComponentType _componentType;
}
@property (nonatomic, readonly) NSUInteger componentType;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *componentDisplayName;
@property (nonatomic, readonly) NSString *pathComponentLikeRepresentation;

+ (instancetype)parentReference;
+ (instancetype)selfReference;
+ (instancetype)componentForSlashSeparatedComponent:(NSString *)component;
+ (instancetype)componentWithPlistRepresentation:(id)representation;
- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithName:(NSString *)name
    type:(PBXNamePathComponentType)type;
- (BOOL)isEqualToNamePathComponent:(PBXNamePathComponent *)component;
- (NSString *)representationInSlashSeparatedPath;
- (BOOL)representableInSlashSeparatorPath;
- (id)plistDictionaryRepresentation;
@end

/* An ordered list of name path components. */
@interface PBXNamePath : NSObject <NSCopying>
{
	NSArray *_components;
}
@property (nonatomic, readonly) NSArray *components;
@property (nonatomic, readonly) BOOL hasContent;
@property (nonatomic, readonly) NSString *displablePath;
@property (nonatomic, readonly) NSString *pathLikeRepresentation;

+ (instancetype)emptyPath;
+ (instancetype)namePathFromPlistRepresentation:(id)representation;
+ (instancetype)relativeNamePathFrom:(PBXReference *)from
    to:(PBXReference *)to;
- (instancetype)initWithComponents:(NSArray *)components;
- (BOOL)isEqualToNamePath:(PBXNamePath *)path;
- (id)plistRepresentation;
- (PBXReference *)resolveFromAnchor:(PBXReference *)anchor;
@end

#endif	/* DEVTOOLSCORE_PBXNAMEPATH_H */
