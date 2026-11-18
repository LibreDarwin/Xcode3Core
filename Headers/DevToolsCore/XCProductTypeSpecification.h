/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef DEVTOOLSCORE_XCPRODUCTTYPESPECIFICATION_H
#define DEVTOOLSCORE_XCPRODUCTTYPESPECIFICATION_H

#import <Foundation/Foundation.h>

#import "DevToolsCore/BuildSystem/XCSpecification.h"

@class DVTMacroDefinitionTable, NSArray, NSDictionary, NSSet;

@interface XCProductTypeSpecification : XCSpecification
{
	DVTMacroDefinitionTable *_defaultMacros;
	DVTMacroDefinitionTable *_flattenedDefaultMacros;
	DVTMacroDefinitionTable *_overridingMacros;
	DVTMacroDefinitionTable *_flattenedOverridingMacros;
	NSSet *_allowedBuildPhaseClasses;
	NSSet *_allowedBuildPhaseIdentifiers;
	NSDictionary *_allowedFileTypesByBuildPhaseIdentifier;
	NSArray *_packageTypes;
	NSDictionary *_defaultEntitlements;
}

@property (readonly) BOOL wantsSimpleTargetEditing;
@property (readonly) BOOL wantsInfoEditorHidden;
@property (readonly) BOOL areCapabilitiesSupported;
@property (readonly) BOOL validateEmbeddedBinaries;
@property (readonly) BOOL wantsBundleIdentifierEditing;
@property (readonly) BOOL wantsSigningEditing;
@property (readonly) BOOL isUnitTest;
@property (readonly) BOOL isUITest;
@property (readonly) BOOL isMultiDeviceUITest;
@property (readonly) BOOL isExternalTest;
@property (readonly) BOOL supportsHostingTests;
@property (readonly) BOOL supportsBeingUITestTarget;
@property (readonly) BOOL allowEmbedding;
@property (readonly) NSArray *platforms;

+ (Class)specificationTypeBaseClass;
+ (NSString *)specificationType;
+ (NSString *)localizedSpecificationTypeName;
+ (NSSet *)specificationTypePathExtensions;
+ (NSString *)specificationRegistryName;

- (id)initWithPropertyListDictionary:(id)dictionary inDomain:(id)domain;
- (id)defaultTargetName;
- (id)defaultMacros;
- (id)overridingMacros;
- (id)allowedBuildPhaseClasses;
- (BOOL)allowsBuildPhaseWithIdentifier:(id)identifier;
- (id)allowedFileTypesForBuildPhaseIdentifier:(id)identifier;
- (id)packageTypes;
- (id)defaultPackageType;
- (BOOL)hasInfoPlist;
- (id)infoPlistAdditions;
- (BOOL)canEmbedCompilerSanitizerLibraries;
- (id)runpathSearchPathForEmbeddedFrameworks;
- (BOOL)isEmbeddable;
- (id)buildPhaseInjectionsWhenEmbedding;
- (id)requiredBuiltProductsDir;
- (id)additionalEntitlementsForMacroExpansionScope:(id)scope;
- (id)macroExpansionScopeByAddingMacroDefinitionTablesToScope:(id)scope;

@end

@interface XCStandaloneExecutableProductType : XCProductTypeSpecification
@end

@interface PBXBundleProductType : XCProductTypeSpecification
@end

@interface PBXApplicationProductType : PBXBundleProductType
@end

@interface PBXFrameworkProductType : PBXBundleProductType
@end

@interface XCStaticFrameworkProductType : PBXFrameworkProductType
@end

@interface XCKernelExtensionProductType : PBXBundleProductType
@end

@interface PBXXCTestBundleProductType : PBXBundleProductType
- (id)_XCTRunnerInfoPlistReplacements;
- (id)_XCTRunnerInfoPlistPreprocessorDefinitions;
- (id)_XCTRunnerBundleIdentifierWithMacroExpansionScope:(id)scope;
- (void)_addSettingsForXCTRunnerToMacroDefinitionTable:(id)table
					  usingScope:(id)scope;
- (id)_adjustedTestHostFromOriginalTestHost:(id)host
       addingOverridesToMacroDefinitionTable:(id)table
			      macroExpansionScope:(id)scope;
- (id)_pluginDirectoryForTestHost:(id)host
		 macroExpansionScope:(id)scope;
- (void)_addSettingsForTestHost:(id)host
	  toMacroDefinitionTable:(id)table
		     usingScope:(id)scope;
- (void)_addAdditionalTestingSearchPathsToMacroDefinitionTable:(id)table
						     usingScope:(id)scope;
- (id)additionalEntitlementsForMacroExpansionScope:(id)scope;
- (id)macroExpansionScopeByAddingMacroDefinitionTablesToScope:(id)scope;
@end

@interface PBXStaticLibraryProductType : XCStandaloneExecutableProductType
@end

@interface PBXDynamicLibraryProductType : XCStandaloneExecutableProductType
@end

@interface PBXToolProductType : XCStandaloneExecutableProductType
@end

#endif	/* DEVTOOLSCORE_XCPRODUCTTYPESPECIFICATION_H */
