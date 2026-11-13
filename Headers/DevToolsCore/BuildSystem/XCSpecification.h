/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCSpecification.
 *
 * XCSpecification models a single entry from a .xcspec property list.  The
 * class keeps two registries:
 *
 *   - a per-domain registry dictionary keyed by registry name and then by
 *     specification identifier (see XCGetRegistryDictionaryForForDomain()),
 *   - a flat array of every specification that has ever been registered.
 *
 * Apple validates method arguments with __DVTAssertionFailureHandler(); this
 * implementation raises NSInvalidArgumentException with the same message text
 * instead.
 *
 * Deviations from Apple's implementation, all invisible to the archive
 * pipeline:
 *
 *   - the two-level lookup cache used by +specificationForIdentifier:inDomain:
 *     is not implemented (results are identical, only slower),
 *   - domain composition (the Xcode.XCSpecDomainComposition extension point) is
 *     replaced by trimming trailing dot separated components, so that
 *     "com.apple.buildsettings.ios" inherits from "com.apple.buildsettings"
 *     and then from the default domain,
 *   - XCSpecificationCache backed proxies are not supported, and
 *   - +registerSpecificationsFromDVTPlugInsForDomains:skippingDomains: is a
 *     no-op because this tree does not implement the plug-in system.
 *
 * The specification loaders reproduce Apple's return convention: they return
 * an array of NSError objects, one per property list element that could not be
 * registered; successfully registered specifications are only recorded in the
 * registries.  Directory scanning uses the DVTFilePath and DVTPlugInManager
 * shims of this tree, and the verbose _kXCSpecificationLoading_LogAspect
 * diagnostics are not reproduced.
 */

#ifndef DEVTOOLSCORE_BUILDSYSTEM_XCSPECIFICATION_H
#define DEVTOOLSCORE_BUILDSYSTEM_XCSPECIFICATION_H

#import <Foundation/Foundation.h>

#import "DVTFoundation/DVTRegistrable.h"

@class DVTVersion, NSBundle, TSPropertyListDictionary;

@interface XCSpecification : NSObject <DVTRegistrable> {
    NSString *_identifier;
    XCSpecification *_superSpecification;
    NSDictionary *_properties;
    TSPropertyListDictionary *_tsProperties;
    NSDictionary *_localizationDictionary;
    NSBundle *_bundle;
    NSString *_domain;
}

@property (readonly) NSString *identifier;
@property (readonly) NSArray *aliases;
@property (readonly) DVTVersion *version;
@property (readonly) NSString *displayName;
@property (readonly) NSString *displayDescription;

/* Class methods */
+ (Class)specificationTypeBaseClass;
+ (NSString *)specificationType;
+ (NSString *)localizedSpecificationTypeName;
+ (NSSet *)specificationTypePathExtensions;
+ (NSString *)specificationRegistryName;

+ (void)_recursivelyEnumerateSpecificationsInStartDomain:(NSString *)startDomain
					   currentDomain:(NSString *)currentDomain
					registryNameOrNil:(NSString *)registryName
			       specificationIdentifierOrNil:(NSString *)identifier
					  seenDomains:(NSMutableSet *)seenDomains
				      seenIdentifiers:(NSMutableSet *)seenIdentifiers
					       stopPtr:(BOOL *)stopPtr
					    usingBlock:(void (^)(NSString *domain, XCSpecification *specification, BOOL *stop))block;
+ (void)_enumerateAllSpecificationsInDomain:(NSString *)domain
			 registryNameOrNil:(NSString *)registryName
		    specificationIdentifierOrNil:(NSString *)identifier
			  includingDefault:(BOOL)includingDefault
				   usingBlock:(void (^)(NSString *domain, XCSpecification *specification, BOOL *stop))block;
+ (void)enumerateSpecificationsInDomain:(NSString *)domain
		       includingDefault:(BOOL)includingDefault
			    usingBlock:(void (^)(NSString *domain, XCSpecification *specification, BOOL *stop))block;

+ (NSMutableDictionary *)specificationRegistryForDomain:(NSString *)domain;
+ (NSMutableDictionary *)_typesToSpecTypeBaseClassesRegistry;
+ (NSMutableDictionary *)_pathExtensionsToTypesRegistry;
+ (void)registerSpecificationTypeBaseClass:(Class)specificationClass;
+ (void)registerSpecificationOrProxy:(id)specification;

+ (NSError *)registerSpecificationProxyFromPropertyList:(TSPropertyListDictionary *)propertyList
					       inDomain:(NSString *)domain
			       outSpecificationOrProxy:(id *)outSpecificationOrProxy;
+ (NSError *)registerSpecificationProxyFromPropertyList:(TSPropertyListDictionary *)propertyList;

+ (NSArray *)_registerSpecificationProxiesOfType:(NSString *)type
			      fromDictionaryOrArray:(id)dictionaryOrArray
				     inDirectory:(NSString *)directory
					  bundle:(NSBundle *)bundle
			       sourceDescription:(NSString *)sourceDescription
					inDomain:(NSString *)domain;
+ (void)_tryRegisterLocalizationDictionaryForSpecification:(TSPropertyListDictionary *)specification bundle:(NSBundle *)bundle;
+ (BOOL)_shouldRecurseIntoDirectoryNamed:(NSString *)name ofType:(NSString *)type;
+ (NSArray *)registerSpecificationProxiesFromPropertyListsInDirectory:(NSString *)directory
							 recursively:(BOOL)recursively
							    inDomain:(NSString *)domain
							    inBundle:(NSBundle *)bundle;
+ (NSArray *)registerSpecificationProxiesFromPropertyListsInDirectory:(NSString *)directory
							 recursively:(BOOL)recursively
							    inDomain:(NSString *)domain;
+ (NSArray *)registerSpecificationProxiesFromPropertyListsInDirectory:(NSString *)directory
							 recursively:(BOOL)recursively;
+ (void)registerSpecificationsFromDVTPlugInsForDomains:(NSArray *)domains skippingDomains:(NSArray *)skippedDomains;

+ (void)_getDomain:(NSString **)outDomain
	identifier:(NSString **)outIdentifier
    fromDomainPrefixedIdentifier:(NSString *)domainPrefixedIdentifier;

+ (id)specificationForIdentifier:(NSString *)identifier inDomain:(NSString *)domain;
+ (id)specificationForIdentifier:(NSString *)identifier;
+ (NSArray *)specificationsForIdentifiers:(NSArray *)identifiers inDomain:(NSString *)domain;
+ (NSArray *)specificationsForIdentifiers:(NSArray *)identifiers;

+ (NSArray *)registeredSpecificationsInDomain:(NSString *)domain;
+ (NSArray *)registeredSpecifications;
+ (NSArray *)_subSpecificationsOfSpecification:(XCSpecification *)specification inDomain:(NSString *)domain;
+ (NSArray *)registeredBaseSpecificationsInDomain:(NSString *)domain;
+ (NSArray *)registeredBaseSpecifications;
+ (NSArray *)allRegisteredSpecifications;

+ (NSString *)specificationTypeForPathExtension:(NSString *)pathExtension;
+ (Class)specificationBaseClassForType:(NSString *)type;
+ (BOOL)_booleanValueForValue:(id)value;

/* Instance methods */
- (id)initWithPropertyListDictionary:(TSPropertyListDictionary *)propertyList inDomain:(NSString *)domain;
- (id)initWithPropertyListDictionary:(TSPropertyListDictionary *)propertyList;
- (id)initAsMissingSpecificationProxyWithIdentifier:(NSString *)identifier
					       name:(NSString *)name
					description:(NSString *)description
					   inDomain:(NSString *)domain;
- (id)init;
- (void)awakeAfterInitialization;

- (XCSpecification *)superSpecification;
- (NSArray *)subSpecificationsInDomain:(NSString *)domain;
- (NSArray *)subSpecifications;
- (NSNumber *)kindOfSpecificationDistance:(XCSpecification *)specification;
- (BOOL)isKindOfSpecification:(XCSpecification *)specification;

- (BOOL)isAbstract;
- (BOOL)showOnlySelfDefinedPropertiesInBuildSettingsGUI;
- (BOOL)isNotYetLoadedSpecificationProxy;
- (XCSpecification *)loadedSpecification;
- (BOOL)isMissingSpecificationProxy;

- (NSString *)type;
- (NSDictionary *)properties;
- (TSPropertyListDictionary *)tsProperties;
- (NSDictionary *)localizationDictionary;
- (NSBundle *)bundle;
- (NSString *)domain;
- (NSString *)name;
- (NSString *)localizedDescription;

- (NSComparisonResult)identifierCompare:(id)other;
- (NSComparisonResult)nameCompare:(id)other;

- (id)_objectForKeyIgnoringInheritance:(NSString *)key;
- (id)objectForKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key;
- (NSArray *)arrayForKey:(NSString *)key;
- (NSDictionary *)dictionaryForKey:(NSString *)key;
- (NSData *)dataForKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;
- (float)floatForKey:(NSString *)key;
- (double)doubleForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (id)arrayOrStringForKey:(NSString *)key;
- (id)valueForUndefinedKey:(NSString *)key;

@end

#endif	/* DEVTOOLSCORE_BUILDSYSTEM_XCSPECIFICATION_H */
