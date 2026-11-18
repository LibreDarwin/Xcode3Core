/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Runtime-only project model value objects (DevToolsCore). */

#import "DevToolsCore/PBXExtendedWrapperPart.h"
#import "DevToolsCore/PBXFileSystemSynchronizedGroupRelativeReferenceID.h"

static NSString * const PBXLocalizedVariantPathPrefix = @"/Localized/";
static NSString * const PBXAtomicDictionaryChildrenKey =
    @"___PlistArchiveAtomicDictionaryChildren";

@protocol PBXFilePathProviding <NSObject>
- (id)path;
- (id)filePathForRelativePathString:(id)relativePath;
@end

@implementation PBXExtendedWrapperPart

- (instancetype)initWithBasedOnWrapperPart:(long long)part
    subPath:(NSString *)path
{
	self = [super init];
	if (self != nil) {
		_basedOnWrapperPart = part;
		_subPath = [path copy];
	}
	return (self);
}

- (long long)basedOnWrapperPart
{
	return (_basedOnWrapperPart);
}

- (NSString *)subPath
{
	return (_subPath);
}

@end

@implementation PBXFileSystemSynchronizedGroupRelativeReferenceID

@dynamic description;

+ (instancetype)referenceIDFromPropertyListRepresentation:(id)representation
    error:(NSError **)error
{
	if (![representation isKindOfClass:[NSString class]]) {
		if (error != NULL)
			*error = [NSError errorWithDomain:NSInvalidArgumentException
			    code:0 userInfo:nil];
		return (nil);
	}

	NSString *path = (NSString *)representation;
	BOOL variantGroup = NO;

	if ([path hasPrefix:PBXLocalizedVariantPathPrefix]) {
		variantGroup = YES;
		path = [path substringFromIndex:
		    [PBXLocalizedVariantPathPrefix length]];
	}
	return ([[self alloc] initWithRelativePath:path
	    isVariantGroup:variantGroup]);
}

+ (instancetype)requiredReferenceIDFromPropertyListRepresentation:
    (id)representation
{
	PBXFileSystemSynchronizedGroupRelativeReferenceID *identifier = [self
	    referenceIDFromPropertyListRepresentation:
	    representation error:NULL];

	if (identifier == nil)
		[NSException raise:NSInvalidArgumentException
		    format:@"invalid file-system synchronized group reference"];
	return (identifier);
}

+ (NSSet *)translateSetFromArchivedRepresentation:(id)representation
{
	if (![representation isKindOfClass:[NSArray class]])
		return (nil);

	NSMutableSet *result = [NSMutableSet setWithCapacity:
	    [representation count]];
	for (id value in (NSArray *)representation) {
		PBXFileSystemSynchronizedGroupRelativeReferenceID *identifier =
		    [self referenceIDFromPropertyListRepresentation:value
		    error:NULL];
		if (identifier != nil)
			[result addObject:identifier];
	}
	return (result);
}

+ (NSArray *)translateSetToArchivedRepresentation:(id)representation
{
	if (![representation isKindOfClass:[NSSet class]])
		return (nil);

	NSMutableArray *result = [NSMutableArray arrayWithCapacity:
	    [representation count]];
	for (id identifier in (NSSet *)representation) {
		NSString *value = nil;
		if ([identifier respondsToSelector:
		    @selector(propertyListRepresentation)])
			value = [identifier propertyListRepresentation];
		else
			value = [identifier description];
		if (value != nil)
			[result addObject:value];
	}
	return (result);
}

+ (NSDictionary *)translateDictionaryFromArchivedRepresentation:
    (id)representation
    valueTransformer:(PBXFileSystemSynchronizedGroupReferenceIDValueTransformer)
    transformer
{
	if (![representation isKindOfClass:[NSDictionary class]])
		return (nil);

	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:
	    [representation count]];
	for (id key in (NSDictionary *)representation) {
		id value = (transformer != nil) ? transformer([representation
		    objectForKey:key]) : [representation objectForKey:key];
		if ([key isEqual:PBXAtomicDictionaryChildrenKey]) {
			if (value != nil)
				[result setObject:value forKey:key];
			continue;
		}
		PBXFileSystemSynchronizedGroupRelativeReferenceID *identifier =
		    [self referenceIDFromPropertyListRepresentation:key
		    error:NULL];
		if (identifier != nil && value != nil)
			[result setObject:value forKey:identifier];
	}
	return (result);
}

+ (NSDictionary *)translateDictionaryToArchivedRepresentation:(id)representation
    archiveEachValueOnSingleLine:(BOOL)singleLine
    valueTransformer:(PBXFileSystemSynchronizedGroupReferenceIDValueTransformer)
    transformer
{
	if (![representation isKindOfClass:[NSDictionary class]])
		return (nil);

	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:
	    [representation count] + 1];
	for (id identifier in (NSDictionary *)representation) {
		NSString *key = nil;
		if ([identifier respondsToSelector:
		    @selector(propertyListRepresentation)])
			key = [identifier propertyListRepresentation];
		else
			key = [identifier description];
		id value = (transformer != nil) ? transformer([representation
		    objectForKey:identifier]) : [representation
		    objectForKey:identifier];
		if (key != nil && value != nil)
			[result setObject:value forKey:key];
	}
	if (singleLine)
		[result setObject:@"YES" forKey:PBXAtomicDictionaryChildrenKey];
	return (result);
}

- (instancetype)initWithRelativePath:(NSString *)path
    isVariantGroup:(BOOL)variantGroup
{
	self = [super init];
	if (self != nil) {
		NSString *relativePath = (path != nil) ? path : @"";
		if (variantGroup && [relativePath hasPrefix:
		    PBXLocalizedVariantPathPrefix])
			relativePath = [relativePath substringFromIndex:
			    [PBXLocalizedVariantPathPrefix length]];
		_relativePath = [relativePath copy];
		_variantGroup = variantGroup;
	}
	return (self);
}

- (instancetype)initWithReference:(id)reference parentID:(id)identifier
{
	(void)identifier;
	NSString *path = nil;
	if ([reference respondsToSelector:@selector(path)])
		path = [(id<PBXFilePathProviding>)reference path];
	if (path == nil)
		path = [reference description];
	return ([self initWithRelativePath:path isVariantGroup:NO]);
}

- (id)copyWithZone:(NSZone *)zone
{
	(void)zone;
	return (self);
}

- (NSString *)description
{
	return ([self propertyListRepresentation]);
}

- (NSString *)propertyListRepresentation
{
	if (_variantGroup)
		return ([PBXLocalizedVariantPathPrefix
		    stringByAppendingString:_relativePath]);
	return (_relativePath);
}

- (BOOL)isVariantGroup
{
	return (_variantGroup);
}

- (BOOL)isNestedVariantGroup
{
	return (_variantGroup);
}

- (NSUInteger)hash
{
	return ([_relativePath hash]);
}

- (BOOL)isEqual:(id)object
{
	if (object == self)
		return (YES);
	if (![object isKindOfClass:[PBXFileSystemSynchronizedGroupRelativeReferenceID
	    class]])
		return (NO);
	return ([self isEqualToFileSystemSynchronizedGroupReferenceID:object]);
}

- (BOOL)isEqualToFileSystemSynchronizedGroupReferenceID:
    (PBXFileSystemSynchronizedGroupRelativeReferenceID *)identifier
{
	if (identifier == nil)
		return (NO);
	return (_variantGroup == identifier->_variantGroup &&
	    [_relativePath isEqualToString:identifier->_relativePath]);
}

- (NSString *)filePathForBasePath:(id)basePath
{
	if ([basePath respondsToSelector:
	    @selector(filePathForRelativePathString:)])
		return ([(id<PBXFilePathProviding>)basePath
		    filePathForRelativePathString:[self
		    propertyListRepresentation]]);
	return (nil);
}

@end
