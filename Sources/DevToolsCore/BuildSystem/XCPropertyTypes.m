/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Concrete XCPropertyTypes classes.  Apple registers these from
 * XCPropertyDefinition's +initialize; the identifiers, localized names and
 * list flags below are taken from probes against DevToolsCore.
 */

#import "DevToolsCore/BuildSystem/XCPropertyDefinition.h"

#define XC_DEFINE_PROPERTY_TYPE(CLASS, ID, LOCALIZED, LIST)	\
    @implementation CLASS					\
    + (NSString *)identifier { return (ID); }			\
    + (NSString *)localizedName { return (LOCALIZED); }		\
    + (BOOL)isListType { return (LIST); }			\
    @end

XC_DEFINE_PROPERTY_TYPE(XCStringPropertyDefinition, @"string", @"String", NO)
XC_DEFINE_PROPERTY_TYPE(XCStringListPropertyDefinition, @"stringlist", @"String List", YES)
XC_DEFINE_PROPERTY_TYPE(XCPathPropertyDefinition, @"path", @"Path", NO)
XC_DEFINE_PROPERTY_TYPE(XCPathListPropertyDefinition, @"pathlist", @"Path List", YES)
XC_DEFINE_PROPERTY_TYPE(XCEnumerationPropertyDefinition, @"enum", @"Enumeration (String)", NO)
XC_DEFINE_PROPERTY_TYPE(XCSDKRootPropertyDefinition, @"sdkroot", @"SDK Identifier or Path", NO)
XC_DEFINE_PROPERTY_TYPE(XCCompilerVersionPropertyDefinition, @"compilerversion", @"Compiler Version", NO)
XC_DEFINE_PROPERTY_TYPE(XCBooleanPropertyDefinition, @"bool", @"Boolean", NO)
XC_DEFINE_PROPERTY_TYPE(XCArchitectureListPropertyDefinition, @"architectures", @"Architectures", YES)
XC_DEFINE_PROPERTY_TYPE(XCDeploymentTargetPropertyDefinition, @"deploymenttarget", @"Platform Deployment Target", NO)
XC_DEFINE_PROPERTY_TYPE(XCSupportedPlatformsPropertyDefinition, @"supportedplatforms", @"Platform Identifier List", YES)
XC_DEFINE_PROPERTY_TYPE(XCCodeSignIdentityPropertyDefinition, @"codesignidentity", @"Code Signing Identity", NO)
XC_DEFINE_PROPERTY_TYPE(XCCodeSignStylePropertyDefinition, @"codesignstyle", @"Code Sign Style", NO)
XC_DEFINE_PROPERTY_TYPE(XCDevelopmentTeamPropertyDefinition, @"developmentteam", @"Development Team", NO)
XC_DEFINE_PROPERTY_TYPE(XCOpenCLArchitecturesPropertyDefinition, @"openclarchitectures", @"OpenCL Architectures", YES)
XC_DEFINE_PROPERTY_TYPE(XCProvisioningProfilePropertyDefinition, @"provisioningprofile", @"Provisioning Profile", NO)
XC_DEFINE_PROPERTY_TYPE(XCProvisioningProfileSpecifierPropertyDefinition, @"provisioningprofilespecifier", @"Provisioning Profile Specifier", NO)
XC_DEFINE_PROPERTY_TYPE(XCSwiftVersionPropertyDefinition, @"swiftversion", @"Swift Language Version", NO)
XC_DEFINE_PROPERTY_TYPE(XCTargetedDeviceFamilyPropertyDefinition, @"targeteddevicefamily", @"Targeted Device Families", NO)

static NSDictionary<NSString *, Class> *
XCPropertyTypeRegistry(void)
{
	static NSDictionary<NSString *, Class> *registry = nil;
	static dispatch_once_t once;

	dispatch_once(&once, ^{
		NSArray *classes = @[
		    [XCStringPropertyDefinition class],
		    [XCStringListPropertyDefinition class],
		    [XCPathPropertyDefinition class],
		    [XCPathListPropertyDefinition class],
		    [XCEnumerationPropertyDefinition class],
		    [XCSDKRootPropertyDefinition class],
		    [XCCompilerVersionPropertyDefinition class],
		    [XCBooleanPropertyDefinition class],
		    [XCArchitectureListPropertyDefinition class],
		    [XCDeploymentTargetPropertyDefinition class],
		    [XCSupportedPlatformsPropertyDefinition class],
		    [XCCodeSignIdentityPropertyDefinition class],
		    [XCCodeSignStylePropertyDefinition class],
		    [XCDevelopmentTeamPropertyDefinition class],
		    [XCOpenCLArchitecturesPropertyDefinition class],
		    [XCProvisioningProfilePropertyDefinition class],
		    [XCProvisioningProfileSpecifierPropertyDefinition class],
		    [XCSwiftVersionPropertyDefinition class],
		    [XCTargetedDeviceFamilyPropertyDefinition class],
		];
		NSMutableDictionary *byIdentifier = [NSMutableDictionary dictionary];

		for (Class typeClass in classes)
			[byIdentifier setObject:typeClass forKey:[typeClass identifier]];
		[byIdentifier setObject:[XCBooleanPropertyDefinition class] forKey:@"boolean"];
		[byIdentifier setObject:[XCEnumerationPropertyDefinition class] forKey:@"enumeration"];
		registry = [byIdentifier copy];
	});
	return (registry);
}

Class
XCPropertyTypeClassForIdentifier(NSString *identifier)
{
	NSString *key;
	Class typeClass;

	if (![identifier isKindOfClass:[NSString class]])
		return ([XCStringPropertyDefinition class]);
	key = [[identifier lowercaseString] stringByTrimmingCharactersInSet:
	    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
	typeClass = [XCPropertyTypeRegistry() objectForKey:key];
	return ((typeClass != Nil) ? typeClass : [XCStringPropertyDefinition class]);
}
