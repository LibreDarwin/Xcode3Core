/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsCore/XCCompatibilityFeature.h"

static XCCompatibilityFeature *
XCCompatibilityFeatureForName(NSString *name)
{
	static NSMutableDictionary *features;
	static dispatch_once_t once;

	dispatch_once(&once, ^{
		features = [NSMutableDictionary dictionary];
	});
	XCCompatibilityFeature *feature = [features objectForKey:name];
	if (feature == nil) {
		feature = [[XCCompatibilityFeature alloc] initWithName:name];
		[features setObject:feature forKey:name];
	}
	return (feature);
}

@implementation XCCompatibilityFeature {
	NSString *_name;
}

- (instancetype)initWithName:(NSString *)name
{
	self = [super init];
	if (self != nil)
		_name = [name copy];
	return (self);
}

- (NSString *)name
{
	return (_name);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@:%p:%@>",
	    NSStringFromClass([self class]), (void *)self, _name]);
}

- (NSUInteger)hash
{
	return ([_name hash]);
}

- (BOOL)isEqual:(id)object
{
	if (object == self)
		return (YES);
	if (![object isKindOfClass:[XCCompatibilityFeature class]])
		return (NO);
	return ([_name isEqualToString:[object name]]);
}

- (id)copyWithZone:(NSZone *)zone
{
	return ([[[self class] allocWithZone:zone] initWithName:_name]);
}

#define XCCompatibilityFeatureMethod(method, name) \
+ (instancetype)method \
{ \
	return (XCCompatibilityFeatureForName(name)); \
}

XCCompatibilityFeatureMethod(XCPerArchitectureSettingsFeature,
    @"Per-architecture build settings")
XCCompatibilityFeatureMethod(XCPerSDKSettingsFeature,
    @"Per-SDK build settings")
XCCompatibilityFeatureMethod(XCDataModelVersionGroupsFeature,
    @"Versioned data models")
XCCompatibilityFeatureMethod(XCParallelTargetBuildsFeature,
    @"Parallel target builds")
XCCompatibilityFeatureMethod(XCCompositeSDKsFeature, @"Composite SDKs")
XCCompatibilityFeatureMethod(XCWeakLinkFrameworkAttributeFeature,
    @"'Weak' library roles")
XCCompatibilityFeatureMethod(XCGCCUseStandardIncludeSearchingFeature,
    @"Use Standard System Header Directory Searching build settings")
XCCompatibilityFeatureMethod(XCGCCRecognizeBuiltinFunctionsFeature,
    @"Recognize Built-in Functions build settings")
XCCompatibilityFeatureMethod(XCGCCEnableLinkingWithSharedLibrariesFeature,
    @"Enable Linking With Shared Libraries build settings")
XCCompatibilityFeatureMethod(XCGCCGenerateIndirectFunctionCallsFeature,
    @"Generate Indirect Function Calls build settings")
XCCompatibilityFeatureMethod(XCGCCGenerateRegisterSubroutineFunctionCallsFeature,
    @"Generate Register Subroutine Function Calls build settings")
XCCompatibilityFeatureMethod(XCGCCKernelDevelopmentModeFeature,
    @"Kernel Development Mode build settings")
XCCompatibilityFeatureMethod(XCGCCGenerateFloatingPointLibraryCallsFeature,
    @"Generate Floating Point Library Calls build settings")
XCCompatibilityFeatureMethod(XCCodeSigningIdentityFeature,
    @"Code Signing Identity build settings")
XCCompatibilityFeatureMethod(XCCodeSigningEntitlementsFeature,
    @"Code Signing Entitlements build settings")
XCCompatibilityFeatureMethod(XCCodeSigningResourceRulesPathFeature,
    @"Code Signing Resource Rules Path build settings")
XCCompatibilityFeatureMethod(XCCodeSigningOtherFlagsFeature,
    @"Other Code Signing Flags build settings")
XCCompatibilityFeatureMethod(XCMultipleProjectRootsFeature,
    @"Multiple project roots")
XCCompatibilityFeatureMethod(XCProvisioningProfileFeature,
    @"Code Signing Provisioning Profile build settings")
XCCompatibilityFeatureMethod(XCBuildRuleCompilerFlagsFeature,
    @"Build rule compiler flags")
XCCompatibilityFeatureMethod(XCLocalSwiftPackageReferenceFeature,
    @"Local package reference")
XCCompatibilityFeatureMethod(XCRemoteSwiftPackageReferenceFeature,
    @"Remote package reference")
XCCompatibilityFeatureMethod(XCRegistrySwiftPackageReferenceFeature,
    @"Registry package reference")
XCCompatibilityFeatureMethod(XCSwiftPackageProductDependencyFeature,
    @"Package product dependency")
XCCompatibilityFeatureMethod(XCPackageProductDependenciesInBuildFilesFeature,
    @"Support for package product dependencies in build files")
XCCompatibilityFeatureMethod(XCScriptPhaseInputFileListFeature,
    @"Script phase .xcfilelist input support")
XCCompatibilityFeatureMethod(XCScriptPhaseOutputFileListFeature,
    @"Script phase .xcfilelist output support")
XCCompatibilityFeatureMethod(XCScriptPhaseDependencyFileFeature,
    @"Script phase dependencies file support")
XCCompatibilityFeatureMethod(XCScriptPhaseAlwaysOutOfDateFeature,
    @"Script phase always out of date support")
XCCompatibilityFeatureMethod(XCExtendedBuildFilePlatformFilterSupportFeature,
    @"Support for extended build file platform filtering")
XCCompatibilityFeatureMethod(XCInternalXROSPlatformFilterSupportFeature,
    @"XCInternalXROSPlatformFilterSupportFeature")
XCCompatibilityFeatureMethod(XCBuildRuleInputDependenciesFeature,
    @"Build rule input dependencies support")
XCCompatibilityFeatureMethod(XCBuildRuleArchitectureNeutralFlagFeature,
    @"Build rule architecture/variant-neutrality flag support")
XCCompatibilityFeatureMethod(XCBuildRuleFileListFeature,
    @"Build rule .xcfilelist support")
XCCompatibilityFeatureMethod(XCXCFrameworkSupportFeature,
    @"Support for xcframeworks in the new build system")
XCCompatibilityFeatureMethod(XCBuildFilePlatformFilterSupportFeature,
    @"Support for build file platform filtering")
XCCompatibilityFeatureMethod(XCBuildFileProductReferenceSupportFeature,
    @"Support for product references in build files")
XCCompatibilityFeatureMethod(XCProjectArchivingDelegateFeature,
    @"Support for invoking a delegate during project archiving")
XCCompatibilityFeatureMethod(XCXCFrameworkFileReferenceSignatureFeature,
    @"Support for archiving signature information on an XCFramework reference")
XCCompatibilityFeatureMethod(XCLocalizationStringCatalogVariantGroupFeature,
    @"Support for using String Catalogs with resources")
XCCompatibilityFeatureMethod(XCMinimizedProjectReferenceProxiesFeature,
    @"Support for minimizing archived cross project product references")
XCCompatibilityFeatureMethod(XCFileSystemSynchronizedGroupFeature,
    @"Support for buildable folders")
XCCompatibilityFeatureMethod(XCFileSystemSynchronizedGroupWithBuildPhaseExceptions,
    @"Support for buildable folders with content in non-default build phases")
XCCompatibilityFeatureMethod(XCConfigFilesAnchoredReferenceFeature,
    @"Support for buildable folders hosting xcconfig files")
XCCompatibilityFeatureMethod(XCFileSystemSynchronizedGroupVariantGroupExceptions,
    @"Support for buildable folders with exceptions for localized files")
XCCompatibilityFeatureMethod(
    XCFileSystemSynchronizedGroupNestedVariantGroupExceptions,
    @"Support for buildable folders with exceptions for localized files in nested groups")
XCCompatibilityFeatureMethod(
    XCFileSystemSynchronizedPlatformFilterInExceptionalBuildPhase,
    @"Support for buildable folders with platform filters in non-default build phases")
XCCompatibilityFeatureMethod(
    XCFileSystemSynchronizedExtraAttributesInDefaultBuildPhase,
    @"Support for buildable folders with build file attributes in default build phases")
XCCompatibilityFeatureMethod(
    XCFileSystemSynchronizedGroupWithReferencesWithAssetTags,
    @"Support for buildable folders with on demand resources tags")

#undef XCCompatibilityFeatureMethod

+ (instancetype)XCSwiftPackageTraitsFeature
{
	return ([[self alloc] initWithName:@"Package traits"]);
}

@end

@implementation XCCompatibilityFeatureUse {
	XCCompatibilityFeature *_feature;
	NSString *_path;
}

- (instancetype)initWithFeature:(XCCompatibilityFeature *)feature
    path:(NSString *)path
{
	self = [super init];
	if (self != nil) {
		_feature = feature;
		_path = [path copy];
	}
	return (self);
}

- (XCCompatibilityFeature *)feature
{
	return (_feature);
}

- (NSString *)path
{
	return (_path);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@:%p:%@>",
	    NSStringFromClass([self class]), (void *)self, [_feature name]]);
}

@end
