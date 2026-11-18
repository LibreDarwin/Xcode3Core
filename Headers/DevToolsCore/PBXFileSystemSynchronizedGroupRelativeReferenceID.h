/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * File-system synchronized group reference identifiers (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXFILESYSTEMSYNCHRONIZEDGROUPRELATIVEREFERENCEID_H
#define DEVTOOLSCORE_PBXFILESYSTEMSYNCHRONIZEDGROUPRELATIVEREFERENCEID_H

#import <Foundation/Foundation.h>

typedef id (^PBXFileSystemSynchronizedGroupReferenceIDValueTransformer)(id value);

@interface PBXFileSystemSynchronizedGroupRelativeReferenceID : NSObject <NSCopying>
{
	NSString *_relativePath;
	BOOL _variantGroup;
}
@property (nonatomic, readonly, copy) NSString *description;
@property (nonatomic, readonly, copy) NSString *propertyListRepresentation;
@property (nonatomic, readonly) BOOL isVariantGroup;
@property (nonatomic, readonly) BOOL isNestedVariantGroup;

+ (instancetype)referenceIDFromPropertyListRepresentation:(id)representation
    error:(NSError **)error;
+ (instancetype)requiredReferenceIDFromPropertyListRepresentation:
    (id)representation;
+ (NSSet *)translateSetFromArchivedRepresentation:(id)representation;
+ (NSArray *)translateSetToArchivedRepresentation:(id)representation;
+ (NSDictionary *)translateDictionaryFromArchivedRepresentation:
    (id)representation
    valueTransformer:(PBXFileSystemSynchronizedGroupReferenceIDValueTransformer)
    transformer;
+ (NSDictionary *)translateDictionaryToArchivedRepresentation:(id)representation
    archiveEachValueOnSingleLine:(BOOL)singleLine
    valueTransformer:(PBXFileSystemSynchronizedGroupReferenceIDValueTransformer)
    transformer;

- (instancetype)initWithRelativePath:(NSString *)path
    isVariantGroup:(BOOL)variantGroup;
- (instancetype)initWithReference:(id)reference parentID:(id)identifier;
- (BOOL)isEqualToFileSystemSynchronizedGroupReferenceID:
    (PBXFileSystemSynchronizedGroupRelativeReferenceID *)identifier;
- (NSString *)filePathForBasePath:(id)basePath;
@end

#endif	/* DEVTOOLSCORE_PBXFILESYSTEMSYNCHRONIZEDGROUPRELATIVEREFERENCEID_H */
