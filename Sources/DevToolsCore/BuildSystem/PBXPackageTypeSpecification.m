/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsCore/PBXPackageTypeSpecification.h"

#import <DVTMacroFoundation/DVTMacroDefinitionTable.h>

#import "DevToolsCore/PBXFileType.h"

@implementation PBXPackageTypeSpecification

+ (void)initialize
{
	if (self == [PBXPackageTypeSpecification class]) {
		[XCSpecification registerSpecificationTypeBaseClass:self];
	}
}

+ (Class)specificationTypeBaseClass
{
	return (self);
}

+ (NSString *)specificationType
{
	return (@"PackageType");
}

+ (NSString *)localizedSpecificationTypeName
{
	return (@"package type");
}

+ (NSSet *)specificationTypePathExtensions
{
	return ([NSSet setWithObject:@"pbpackspec"]);
}

+ (NSString *)specificationRegistryName
{
	return ([self specificationType]);
}

- (id)initWithPropertyListDictionary:(id)dictionary inDomain:(id)domain
{
	self = [super initWithPropertyListDictionary:dictionary inDomain:domain];
	if (self == nil) {
		return (nil);
	}

	NSString *identifier = [self identifier];
	NSString *label = [NSString stringWithFormat:@"// package type %@ default macros", identifier];
	DVTMacroDefinitionTable *ownMacros = [[DVTMacroDefinitionTable alloc] initWithLabel:label];
	NSDictionary *settings = [self _objectForKeyIgnoringInheritance:@"DefaultBuildSettings"];

	for (NSString *name in [[settings allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
		[ownMacros setStringValue:[settings objectForKey:name]
			       forMacroName:name
				conditionSet:nil];
	}
	[ownMacros setLiteralValue:identifier
			forMacroName:@"PACKAGE_TYPE"
			 conditionSet:nil];
	[ownMacros makeImmutable];
	_defaultMacros = ownMacros;

	DVTMacroDefinitionTable *flattened = [[DVTMacroDefinitionTable alloc] initWithLabel:label];
	PBXPackageTypeSpecification *superSpecification = (PBXPackageTypeSpecification *)[self superSpecification];

	if ([superSpecification isKindOfClass:[PBXPackageTypeSpecification class]]) {
		[flattened setMacroNamesAndValuesFromMacroDefinitionTable:[superSpecification defaultMacros]];
	}
	[flattened setMacroNamesAndValuesFromMacroDefinitionTable:ownMacros];
	[flattened makeImmutable];
	_flattenedDefaultMacros = flattened;

	NSDictionary *productReference = [self dictionaryForKey:@"ProductReference"];
	_productReferenceFileTypeIdentifier = [[productReference objectForKey:@"FileType"] copy];
	_productReferenceName = [[productReference objectForKey:@"Name"] copy];
	_productReferenceIsLaunchable = [XCSpecification _booleanValueForValue:
	    [productReference objectForKey:@"IsLaunchable"]];
	return (self);
}

- (id)defaultMacros
{
	if (_flattenedDefaultMacros != nil) {
		return (_flattenedDefaultMacros);
	}
	return (_defaultMacros);
}

- (id)productReferenceFileType
{
	if (_productReferenceFileType == nil && _productReferenceFileTypeIdentifier != nil) {
		_productReferenceFileType = (PBXFileType *)[PBXFileType specificationForIdentifier:
		    _productReferenceFileTypeIdentifier];
	}
	return (_productReferenceFileType);
}

- (id)productReferenceName
{
	return (_productReferenceName);
}

- (BOOL)productReferenceIsLaunchable
{
	return (_productReferenceIsLaunchable);
}

@end
