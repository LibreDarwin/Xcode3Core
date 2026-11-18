/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef DEVTOOLSCORE_PBXPACKAGETYPESPECIFICATION_H
#define DEVTOOLSCORE_PBXPACKAGETYPESPECIFICATION_H

#import <Foundation/Foundation.h>

#import "DevToolsCore/BuildSystem/XCSpecification.h"

@class DVTMacroDefinitionTable, PBXFileType;

@interface PBXPackageTypeSpecification : XCSpecification
{
	DVTMacroDefinitionTable *_defaultMacros;
	DVTMacroDefinitionTable *_flattenedDefaultMacros;
	NSString *_productReferenceFileTypeIdentifier;
	PBXFileType *_productReferenceFileType;
	NSString *_productReferenceName;
	BOOL _productReferenceIsLaunchable;
}

+ (Class)specificationTypeBaseClass;
+ (NSString *)specificationType;
+ (NSString *)localizedSpecificationTypeName;
+ (NSSet *)specificationTypePathExtensions;
+ (NSString *)specificationRegistryName;

- (id)initWithPropertyListDictionary:(id)dictionary inDomain:(id)domain;
- (id)defaultMacros;
- (id)productReferenceFileType;
- (id)productReferenceName;
- (BOOL)productReferenceIsLaunchable;

@end

#endif	/* DEVTOOLSCORE_PBXPACKAGETYPESPECIFICATION_H */
