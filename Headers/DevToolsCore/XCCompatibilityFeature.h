/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef DEVTOOLSCORE_XCCOMPATIBILITYFEATURE_H
#define DEVTOOLSCORE_XCCOMPATIBILITYFEATURE_H

#import <Foundation/Foundation.h>

@interface XCCompatibilityFeature : NSObject <NSCopying>
- (instancetype)initWithName:(NSString *)name;
- (NSString *)name;
+ (instancetype)XCPerArchitectureSettingsFeature;
+ (instancetype)XCPerSDKSettingsFeature;
+ (instancetype)XCDataModelVersionGroupsFeature;
+ (instancetype)XCParallelTargetBuildsFeature;
+ (instancetype)XCCompositeSDKsFeature;
+ (instancetype)XCWeakLinkFrameworkAttributeFeature;
+ (instancetype)XCGCCUseStandardIncludeSearchingFeature;
+ (instancetype)XCGCCRecognizeBuiltinFunctionsFeature;
+ (instancetype)XCGCCEnableLinkingWithSharedLibrariesFeature;
+ (instancetype)XCGCCGenerateIndirectFunctionCallsFeature;
+ (instancetype)XCGCCGenerateRegisterSubroutineFunctionCallsFeature;
+ (instancetype)XCGCCKernelDevelopmentModeFeature;
+ (instancetype)XCGCCGenerateFloatingPointLibraryCallsFeature;
+ (instancetype)XCCodeSigningIdentityFeature;
+ (instancetype)XCCodeSigningEntitlementsFeature;
+ (instancetype)XCCodeSigningResourceRulesPathFeature;
+ (instancetype)XCCodeSigningOtherFlagsFeature;
+ (instancetype)XCMultipleProjectRootsFeature;
+ (instancetype)XCProvisioningProfileFeature;
+ (instancetype)XCBuildRuleCompilerFlagsFeature;
+ (instancetype)XCLocalSwiftPackageReferenceFeature;
+ (instancetype)XCRemoteSwiftPackageReferenceFeature;
+ (instancetype)XCRegistrySwiftPackageReferenceFeature;
+ (instancetype)XCSwiftPackageTraitsFeature;
+ (instancetype)XCSwiftPackageProductDependencyFeature;
+ (instancetype)XCPackageProductDependenciesInBuildFilesFeature;
+ (instancetype)XCScriptPhaseInputFileListFeature;
+ (instancetype)XCScriptPhaseOutputFileListFeature;
+ (instancetype)XCScriptPhaseDependencyFileFeature;
+ (instancetype)XCScriptPhaseAlwaysOutOfDateFeature;
+ (instancetype)XCExtendedBuildFilePlatformFilterSupportFeature;
+ (instancetype)XCInternalXROSPlatformFilterSupportFeature;
+ (instancetype)XCBuildRuleInputDependenciesFeature;
+ (instancetype)XCBuildRuleArchitectureNeutralFlagFeature;
+ (instancetype)XCBuildRuleFileListFeature;
+ (instancetype)XCXCFrameworkSupportFeature;
+ (instancetype)XCBuildFilePlatformFilterSupportFeature;
+ (instancetype)XCBuildFileProductReferenceSupportFeature;
+ (instancetype)XCProjectArchivingDelegateFeature;
+ (instancetype)XCXCFrameworkFileReferenceSignatureFeature;
+ (instancetype)XCLocalizationStringCatalogVariantGroupFeature;
+ (instancetype)XCMinimizedProjectReferenceProxiesFeature;
+ (instancetype)XCFileSystemSynchronizedGroupFeature;
+ (instancetype)XCFileSystemSynchronizedGroupWithBuildPhaseExceptions;
+ (instancetype)XCConfigFilesAnchoredReferenceFeature;
+ (instancetype)XCFileSystemSynchronizedGroupVariantGroupExceptions;
+ (instancetype)XCFileSystemSynchronizedGroupNestedVariantGroupExceptions;
+ (instancetype)XCFileSystemSynchronizedPlatformFilterInExceptionalBuildPhase;
+ (instancetype)XCFileSystemSynchronizedExtraAttributesInDefaultBuildPhase;
+ (instancetype)XCFileSystemSynchronizedGroupWithReferencesWithAssetTags;
@end

@interface XCCompatibilityFeatureUse : NSObject
- (instancetype)initWithFeature:(XCCompatibilityFeature *)feature
    path:(NSString *)path;
- (XCCompatibilityFeature *)feature;
- (NSString *)path;
@end

#endif	/* DEVTOOLSCORE_XCCOMPATIBILITYFEATURE_H */
