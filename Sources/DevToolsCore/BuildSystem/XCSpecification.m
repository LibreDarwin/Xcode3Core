/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsCore/BuildSystem/XCSpecification.h"

#import <os/lock.h>

#import "DevToolsCore/BuildSystem/XCSpecificationProxy.h"
#import "DevToolsSupport/TSPropertyListDictionary.h"

/*
 * Domain -> registry name -> identifier -> specification.
 *
 * Apple stores this in a file static NSMutableDictionary guarded by
 * XCGetRegistryDictionaryForForDomain(); we do the same.  XCSpecificationCache
 * is deliberately not implemented, so there is no cache tier here.
 */
static NSMutableDictionary *sSpecificationRegistries = nil;
static NSMutableArray *sAllRegisteredSpecifications = nil;
static NSMutableDictionary *sSpecTypeBaseClasses = nil;
static NSMutableDictionary *sPathExtensionToTypes = nil;
static os_unfair_lock sAllRegisteredSpecificationsLock = OS_UNFAIR_LOCK_INIT;

/* Apple's registry name for the per-domain registry dictionaries. */
NSMutableDictionary *XCGetRegistryDictionaryForForDomain(NSString *domain)
{
	NSMutableDictionary *registry;

	@synchronized ([XCSpecification class]) {
		if (sSpecificationRegistries == nil) {
			sSpecificationRegistries = [[NSMutableDictionary alloc] initWithCapacity:0];
		}
		registry = [sSpecificationRegistries objectForKey:domain];
		if (registry == nil) {
			registry = [NSMutableDictionary dictionary];
			[sSpecificationRegistries setObject:registry forKey:domain];
		}
	}
	return (registry);
}

@interface XCSpecification ()
+ (NSArray *)_includedDomainsForDomain:(NSString *)domain;
@end

@implementation XCSpecification

@dynamic aliases;
@dynamic version;
@dynamic displayName;
@dynamic displayDescription;

#pragma mark Class properties

+ (Class)specificationTypeBaseClass
{
	return ([XCSpecification class]);
}

+ (NSString *)specificationType
{
	return (@"Generic");
}

+ (NSString *)specificationRegistryName
{
	return ([self specificationType]);
}

+ (NSSet *)specificationTypePathExtensions
{
	return ([NSSet set]);
}

+ (NSString *)localizedSpecificationTypeName
{
	static NSBundle *sBundle = nil;

	if (sBundle == nil) {
		sBundle = [NSBundle bundleWithIdentifier:@"com.apple.Xcode.XcodeFoundation"];
	}
	return ([sBundle localizedStringForKey:[self specificationType] value:@"" table:@"PBXCore"]);
}

+ (BOOL)_booleanValueForValue:(id)value
{
	if (value == nil) {
		return (NO);
	}
	if ([value isKindOfClass:[NSString class]]) {
		if ([(NSString *)value compare:@"YES" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [(NSString *)value length])] == NSOrderedSame) {
			return (YES);
		}
		if ([(NSString *)value compare:@"Y" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [(NSString *)value length])] == NSOrderedSame) {
			return (YES);
		}
		return ([(NSString *)value integerValue] != 0);
	}
	if ([value isKindOfClass:[NSNumber class]]) {
		return ([(NSNumber *)value boolValue]);
	}
	return (NO);
}

+ (void)_getDomain:(NSString **)outDomain
	identifier:(NSString **)outIdentifier
    fromDomainPrefixedIdentifier:(NSString *)domainPrefixedIdentifier
{
	if (outDomain != NULL && outIdentifier != NULL) {
		NSRange colonRange = [domainPrefixedIdentifier rangeOfString:@":"];

		if (colonRange.location == NSNotFound) {
			*outIdentifier = domainPrefixedIdentifier;
		} else {
			*outDomain = [domainPrefixedIdentifier substringToIndex:colonRange.location];
			*outIdentifier = [domainPrefixedIdentifier substringFromIndex:NSMaxRange(colonRange)];
		}
	}
}

#pragma mark Registries

+ (NSMutableDictionary *)_typesToSpecTypeBaseClassesRegistry
{
	@synchronized ([XCSpecification class]) {
		if (sSpecTypeBaseClasses == nil) {
			sSpecTypeBaseClasses = [[NSMutableDictionary alloc] initWithCapacity:0x20];
			[sSpecTypeBaseClasses setObject:[XCSpecification class]
						 forKey:[XCSpecification specificationType]];
		}
	}
	return (sSpecTypeBaseClasses);
}

+ (NSMutableDictionary *)_pathExtensionsToTypesRegistry
{
	@synchronized ([XCSpecification class]) {
		if (sPathExtensionToTypes == nil) {
			sPathExtensionToTypes = [[NSMutableDictionary alloc] initWithCapacity:0x20];
		}
	}
	return (sPathExtensionToTypes);
}

+ (NSMutableDictionary *)specificationRegistryForDomain:(NSString *)domain
{
	NSMutableDictionary *registry = XCGetRegistryDictionaryForForDomain(domain);
	NSMutableDictionary *result = nil;
	NSString *registryName = [self specificationRegistryName];

	if (registry != nil) {
		result = [registry objectForKey:registryName];
		if (result == nil) {
			result = [NSMutableDictionary dictionary];
			[registry setObject:result forKey:registryName];
		}
	}
	return (result);
}

+ (void)registerSpecificationTypeBaseClass:(Class)specificationClass
{
	if (specificationClass == nil || ![specificationClass isSubclassOfClass:[XCSpecification class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be a subclass of %@, but it is %@",
				   @"specificationClass", NSStringFromClass([XCSpecification class]), NSStringFromClass(specificationClass)];
	}

	NSMutableDictionary *typesRegistry = [self _typesToSpecTypeBaseClassesRegistry];
	NSString *type = [specificationClass specificationType];

	if ([typesRegistry objectForKey:type] != nil) {
		/* Apple logs a warning here; duplicate registration is otherwise a no-op. */
	}
	[typesRegistry setObject:specificationClass forKey:type];

	/*
	 * Apple hard codes the Linker type to XCCommandLineToolSpecification so
	 * that .xcspec files can use Type = Linker before that subclass has
	 * registered itself.
	 */
	if ([type isEqualToString:@"Linker"] == NO) {
		Class linkerClass = NSClassFromString(@"XCCommandLineToolSpecification");

		if (linkerClass != Nil) {
			[typesRegistry setObject:linkerClass forKey:@"Linker"];
		}
	}

	NSMutableDictionary *pathExtensions = [self _pathExtensionsToTypesRegistry];

	for (NSString *extension in [[specificationClass specificationTypePathExtensions] allObjects]) {
		[pathExtensions setObject:type forKey:extension];
	}
}

+ (void)registerSpecificationOrProxy:(id)specification
{
	if (specification == nil) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be a non-nil specification or specification proxy, but it is %@",
				   @"specification", specification];
	}
	if (![specification isKindOfClass:[XCSpecification class]] && ![specification isKindOfClass:[XCSpecificationProxy class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"specification", NSStringFromClass([XCSpecification class]), specification];
	}

	NSString *identifier = [specification identifier];

	if (identifier == nil || [identifier length] == 0) {
		NSLog(@"couldn't register specification %@:  it has no identifier", specification);
		return;
	}

	NSString *domain = [specification domain];

	if (domain == nil) {
		domain = @"";
	}

	NSMutableDictionary *registry = [self specificationRegistryForDomain:domain];

	@synchronized (registry) {
		/* Apple logs a replacement warning at verbose level 2 or higher. */
		[registry setObject:specification forKey:identifier];
	}

	os_unfair_lock_lock(&sAllRegisteredSpecificationsLock);
	{
		if (sAllRegisteredSpecifications == nil) {
			sAllRegisteredSpecifications = [[NSMutableArray alloc] initWithCapacity:0];
		}
		[sAllRegisteredSpecifications addObject:specification];
	}
	os_unfair_lock_unlock(&sAllRegisteredSpecificationsLock);
}

+ (NSError *)registerSpecificationProxyFromPropertyList:(TSPropertyListDictionary *)propertyList
					       inDomain:(NSString *)domain
			       outSpecificationOrProxy:(id *)outSpecificationOrProxy
{
	if (propertyList == nil || ![propertyList isKindOfClass:[TSPropertyListDictionary class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"propertyList", NSStringFromClass([TSPropertyListDictionary class]), propertyList];
	}

	NSString *type = [propertyList stringForKey:@"Type"];
	Class specificationTypeBaseClass = [[self _typesToSpecTypeBaseClassesRegistry] objectForKey:type];

	if (specificationTypeBaseClass != nil) {
		XCSpecificationProxy *proxy = [[XCSpecificationProxy alloc] initWithSpecificationTypeBaseClass:specificationTypeBaseClass
												   propertyList:propertyList
												       inDomain:domain];

		if (outSpecificationOrProxy != NULL) {
			*outSpecificationOrProxy = proxy;
		}
		[specificationTypeBaseClass registerSpecificationOrProxy:proxy];
		return (nil);
	}

	NSString *format = [[NSBundle bundleWithIdentifier:@"com.apple.Xcode.DevToolsCore"]
			    localizedStringForKey:@"couldn't register specification: unknown type '%@'"
					    value:@""
					    table:@"PBXCore"];

	if (format == nil) {
		format = @"couldn't register specification: unknown type '%@'";
	}

	NSString *localizedDescription = [NSString stringWithFormat:format, type];

	return ([NSError errorWithDomain:@"XCSpecificationErrorDomain"
				    code:0
				userInfo:[NSDictionary dictionaryWithObject:localizedDescription
								     forKey:NSLocalizedDescriptionKey]]);
}

+ (NSError *)registerSpecificationProxyFromPropertyList:(TSPropertyListDictionary *)propertyList
{
	return ([self registerSpecificationProxyFromPropertyList:propertyList inDomain:@"" outSpecificationOrProxy:NULL]);
}

#pragma mark Enumeration

+ (void)_recursivelyEnumerateSpecificationsInStartDomain:(NSString *)startDomain
					   currentDomain:(NSString *)currentDomain
					registryNameOrNil:(NSString *)registryName
			       specificationIdentifierOrNil:(NSString *)identifier
					  seenDomains:(NSMutableSet *)seenDomains
				      seenIdentifiers:(NSMutableSet *)seenIdentifiers
					       stopPtr:(BOOL *)stopPtr
					    usingBlock:(void (^)(NSString *domain, XCSpecification *specification, BOOL *stop))block
{
	(void)startDomain;

	if (stopPtr != NULL && *stopPtr) {
		return;
	}
	if (currentDomain == nil) {
		currentDomain = @"";
	}
	if ([seenDomains containsObject:currentDomain]) {
		return;
	}
	[seenDomains addObject:currentDomain];

	NSMutableDictionary *domainRegistry = XCGetRegistryDictionaryForForDomain(currentDomain);
	NSDictionary *specifications = nil;

	if (domainRegistry != nil) {
		if (registryName != nil) {
			specifications = [domainRegistry objectForKey:registryName];
		} else {
			NSMutableDictionary *merged = [NSMutableDictionary dictionary];

			for (NSDictionary *subRegistry in [domainRegistry allValues]) {
				[merged addEntriesFromDictionary:subRegistry];
			}
			specifications = merged;
		}
	}

	for (NSString *candidateIdentifier in specifications) {
		if (stopPtr != NULL && *stopPtr) {
			return;
		}
		if ([seenIdentifiers containsObject:candidateIdentifier]) {
			continue;
		}
		if (identifier != nil && [identifier isEqualToString:candidateIdentifier] == NO) {
			continue;
		}
		[seenIdentifiers addObject:candidateIdentifier];
		block(currentDomain, [specifications objectForKey:candidateIdentifier], stopPtr);
	}

	for (NSString *includedDomain in [self _includedDomainsForDomain:currentDomain]) {
		[self _recursivelyEnumerateSpecificationsInStartDomain:startDomain
							 currentDomain:includedDomain
						      registryNameOrNil:registryName
						 specificationIdentifierOrNil:identifier
							    seenDomains:seenDomains
							seenIdentifiers:seenIdentifiers
								 stopPtr:stopPtr
							      usingBlock:block];
	}
}

/*
 * Apple builds this mapping from the Xcode.XCSpecDomainComposition extension
 * point (DVTDestinationPathToBundlePathRegistry / DVTPlugInManager).  This tree
 * does not implement the plug-in system, so a domain inherits from its parent
 * domains by trimming trailing dot separated components.
 */
+ (NSArray *)_includedDomainsForDomain:(NSString *)domain
{
	NSMutableArray *result = [NSMutableArray array];
	NSString *current = domain;

	while (current != nil && [current length] > 0) {
		NSRange dotRange = [current rangeOfString:@"." options:NSBackwardsSearch];

		if (dotRange.location == NSNotFound) {
			current = @"";
		} else {
			current = [current substringToIndex:dotRange.location];
		}
		if (![result containsObject:current]) {
			[result addObject:current];
		}
	}
	return (result);
}

+ (void)_enumerateAllSpecificationsInDomain:(NSString *)domain
			 registryNameOrNil:(NSString *)registryName
		    specificationIdentifierOrNil:(NSString *)identifier
			  includingDefault:(BOOL)includingDefault
				   usingBlock:(void (^)(NSString *domain, XCSpecification *specification, BOOL *stop))block
{
	NSMutableSet *seenDomains = [NSMutableSet set];
	NSMutableSet *seenIdentifiers = [NSMutableSet set];
	BOOL stop = NO;

	if (domain == nil) {
		domain = @"";
	}

	[self _recursivelyEnumerateSpecificationsInStartDomain:domain
						currentDomain:domain
					     registryNameOrNil:registryName
					specificationIdentifierOrNil:identifier
						   seenDomains:seenDomains
					       seenIdentifiers:seenIdentifiers
							stopPtr:&stop
						     usingBlock:block];

	if (includingDefault && ![domain isEqualToString:@""]) {
		[self _recursivelyEnumerateSpecificationsInStartDomain:@""
							currentDomain:@""
						     registryNameOrNil:registryName
						specificationIdentifierOrNil:identifier
							   seenDomains:seenDomains
						       seenIdentifiers:seenIdentifiers
								stopPtr:&stop
							     usingBlock:block];
	}
}

+ (void)enumerateSpecificationsInDomain:(NSString *)domain
		       includingDefault:(BOOL)includingDefault
			    usingBlock:(void (^)(NSString *domain, XCSpecification *specification, BOOL *stop))block
{
	[self _enumerateAllSpecificationsInDomain:domain
			      registryNameOrNil:[self specificationRegistryName]
		     specificationIdentifierOrNil:nil
			       includingDefault:includingDefault
				    usingBlock:block];
}

+ (id)specificationForIdentifier:(NSString *)identifier inDomain:(NSString *)domain
{
	if (identifier == nil || ![identifier isKindOfClass:[NSString class]] || [identifier length] == 0) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be a non-empty string, but it is %@", @"identifier", identifier];
	}
	if (domain != nil && ![domain isKindOfClass:[NSString class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be a string, but it is %@", @"domain", domain];
	}
	if (domain == nil) {
		domain = @"";
	}

	__block id result = nil;

	[self _enumerateAllSpecificationsInDomain:domain
			      registryNameOrNil:[self specificationRegistryName]
		     specificationIdentifierOrNil:identifier
			       includingDefault:YES
				    usingBlock:^(NSString *specificationDomain, XCSpecification *specification, BOOL *stop) {
		(void)specificationDomain;
		result = specification;
		*stop = YES;
	}];
	return (result);
}

+ (id)specificationForIdentifier:(NSString *)identifier
{
	return ([self specificationForIdentifier:identifier inDomain:@""]);
}

+ (NSArray *)specificationsForIdentifiers:(NSArray *)identifiers inDomain:(NSString *)domain
{
	if (identifiers == nil || ![identifiers isKindOfClass:[NSArray class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an array, but it is %@", @"identifiers", identifiers];
	}

	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[identifiers count]];

	for (NSString *identifier in identifiers) {
		id specification = [self specificationForIdentifier:identifier inDomain:domain];

		if (specification != nil) {
			[result addObject:specification];
		}
	}
	return (result);
}

+ (NSArray *)specificationsForIdentifiers:(NSArray *)identifiers
{
	return ([self specificationsForIdentifiers:identifiers inDomain:@""]);
}

+ (NSArray *)registeredSpecificationsInDomain:(NSString *)domain
{
	NSMutableArray *result = [NSMutableArray array];

	[self enumerateSpecificationsInDomain:domain
			     includingDefault:YES
				  usingBlock:^(NSString *specificationDomain, XCSpecification *specification, BOOL *stop) {
		(void)specificationDomain;
		(void)stop;
		[result addObject:specification];
	}];
	return (result);
}

+ (NSArray *)registeredSpecifications
{
	return ([self registeredSpecificationsInDomain:@""]);
}

+ (NSArray *)_subSpecificationsOfSpecification:(XCSpecification *)specification inDomain:(NSString *)domain
{
	NSMutableArray *result = [NSMutableArray array];

	for (XCSpecification *candidate in [self registeredSpecificationsInDomain:domain]) {
		if ([candidate superSpecification] == specification) {
			[result addObject:candidate];
		}
	}
	return (result);
}

+ (NSArray *)registeredBaseSpecificationsInDomain:(NSString *)domain
{
	return ([self _subSpecificationsOfSpecification:nil inDomain:domain]);
}

+ (NSArray *)registeredBaseSpecifications
{
	return ([self registeredBaseSpecificationsInDomain:@""]);
}

+ (NSArray *)allRegisteredSpecifications
{
	os_unfair_lock_lock(&sAllRegisteredSpecificationsLock);
	NSArray *result = (sAllRegisteredSpecifications != nil) ? [sAllRegisteredSpecifications copy] : [NSArray array];
	os_unfair_lock_unlock(&sAllRegisteredSpecificationsLock);
	return (result);
}

+ (NSString *)specificationTypeForPathExtension:(NSString *)pathExtension
{
	return ([[self _pathExtensionsToTypesRegistry] objectForKey:pathExtension]);
}

+ (Class)specificationBaseClassForType:(NSString *)type
{
	return ([[self _typesToSpecTypeBaseClassesRegistry] objectForKey:type]);
}

#pragma mark Directory registration

+ (BOOL)_shouldRecurseIntoDirectoryNamed:(NSString *)name ofType:(NSString *)type
{
	if (name == nil || ![name isKindOfClass:[NSString class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be a string, but it is %@", @"name", name];
	}
	if (type == nil || ![type isKindOfClass:[NSString class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be a string, but it is %@", @"type", type];
	}

	if ([type isEqualToString:NSFileTypeDirectory]) {
		if ([name hasSuffix:@".lproj"]) {
			return (NO);
		}
		return (YES);
	}
	return (NO);
}

+ (void)_tryRegisterLocalizationDictionaryForSpecification:(XCSpecification *)specification bundle:(NSBundle *)bundle
{
	if (bundle == nil) {
		return;
	}

	NSString *identifier = [specification identifier];

	if (identifier == nil) {
		return;
	}

	NSString *path = [bundle pathForResource:identifier ofType:@"strings"];

	if (path == nil) {
		return;
	}

	NSDictionary *strings = [NSDictionary dictionaryWithContentsOfFile:path];

	if (strings != nil) {
		[[specification tsProperties] setLocalizationDictionary:strings];
	}
}

+ (NSArray *)_registerSpecificationProxiesOfType:(NSString *)type
			      fromDictionaryOrArray:(id)dictionaryOrArray
				     inDirectory:(NSString *)directory
					  bundle:(NSBundle *)bundle
			       sourceDescription:(NSString *)sourceDescription
					inDomain:(NSString *)domain
{
	(void)type;
	(void)directory;

	NSMutableArray *result = [NSMutableArray array];

	if ([dictionaryOrArray isKindOfClass:[NSArray class]]) {
		for (id item in dictionaryOrArray) {
			[result addObjectsFromArray:[self _registerSpecificationProxiesOfType:type
									 fromDictionaryOrArray:item
											inDirectory:directory
											     bundle:bundle
								      sourceDescription:sourceDescription
										       inDomain:domain]];
		}
	} else if ([dictionaryOrArray isKindOfClass:[TSPropertyListDictionary class]]) {
		TSPropertyListDictionary *propertyList = dictionaryOrArray;

		if (bundle != nil) {
			[propertyList setBundle:bundle];
		}

		id specification = nil;
		NSError *error = [self registerSpecificationProxyFromPropertyList:propertyList
									 inDomain:domain
							 outSpecificationOrProxy:&specification];

		if (error != nil) {
			NSLog(@"%@: %@", sourceDescription, [error localizedDescription]);
		} else if (specification != nil) {
			[self _tryRegisterLocalizationDictionaryForSpecification:specification bundle:bundle];
			[result addObject:specification];
		}
	}
	return (result);
}

+ (NSArray *)registerSpecificationProxiesFromPropertyListsInDirectory:(NSString *)directory
							 recursively:(BOOL)recursively
							    inDomain:(NSString *)domain
							    inBundle:(NSBundle *)bundle
{
	NSMutableArray *result = [NSMutableArray array];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *contents = [fileManager contentsOfDirectoryAtPath:directory error:NULL];

	for (NSString *name in contents) {
		NSString *fullPath = [directory stringByAppendingPathComponent:name];
		NSDictionary *attributes = [fileManager attributesOfItemAtPath:fullPath error:NULL];
		NSString *fileType = [attributes fileType];

		if ([fileType isEqualToString:NSFileTypeDirectory]) {
			if (recursively && [self _shouldRecurseIntoDirectoryNamed:name ofType:fileType]) {
				[result addObjectsFromArray:[self registerSpecificationProxiesFromPropertyListsInDirectory:fullPath
														   recursively:recursively
														      inDomain:domain
														      inBundle:bundle]];
			}
			continue;
		}

		if ([[fullPath pathExtension] caseInsensitiveCompare:@"xcspec"] != NSOrderedSame) {
			continue;
		}

		TSPropertyListDictionary *propertyList = [[TSPropertyListDictionary alloc] initWithContentsOfFile:fullPath
													  encoding:NSUTF8StringEncoding];

		if (propertyList == nil) {
			continue;
		}

		[result addObjectsFromArray:[self _registerSpecificationProxiesOfType:nil
								 fromDictionaryOrArray:propertyList
									    inDirectory:directory
										 bundle:bundle
								  sourceDescription:fullPath
									       inDomain:domain]];
	}
	return (result);
}

+ (NSArray *)registerSpecificationProxiesFromPropertyListsInDirectory:(NSString *)directory
							 recursively:(BOOL)recursively
							    inDomain:(NSString *)domain
{
	return ([self registerSpecificationProxiesFromPropertyListsInDirectory:directory
								  recursively:recursively
								     inDomain:domain
								     inBundle:nil]);
}

+ (NSArray *)registerSpecificationProxiesFromPropertyListsInDirectory:(NSString *)directory
							 recursively:(BOOL)recursively
{
	return ([self registerSpecificationProxiesFromPropertyListsInDirectory:directory
								  recursively:recursively
								     inDomain:@""
								     inBundle:nil]);
}

+ (void)registerSpecificationsFromDVTPlugInsForDomains:(NSArray *)domains skippingDomains:(NSArray *)skippedDomains
{
	/*
	 * Apple asks DVTPlugInManager for every plug-in that contributes to one of
	 * the requested domains and registers the .xcspec files it ships.  This
	 * tree does not implement the plug-in system, so there is nothing to do.
	 */
	(void)domains;
	(void)skippedDomains;
}

#pragma mark Life cycle

- (id)init
{
	self = [super init];
	if (self != nil) {
		[NSException raise:NSInvalidArgumentException
			    format:@"method %@ is inappropriate for instances of %@",
				   NSStringFromSelector(_cmd), NSStringFromClass([self class])];
	}
	return (self);
}

- (id)initWithPropertyListDictionary:(TSPropertyListDictionary *)propertyList inDomain:(NSString *)domain
{
	if (propertyList != nil && ![propertyList isKindOfClass:[TSPropertyListDictionary class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"propertyList", NSStringFromClass([TSPropertyListDictionary class]), propertyList];
	}

	self = [super init];
	if (self != nil) {
		NSString *identifier = [propertyList stringOrNilForKey:@"Identifier"];

		if (identifier == nil || [identifier length] == 0) {
			[NSException raise:NSInvalidArgumentException
				    format:@"malformed specification of %3$@ %1$@ -- the '%2$@' key must be non-empty",
					   identifier, @"Identifier", NSStringFromClass([self class])];
		}
		_identifier = [identifier copy];

		NSString *specificationDomain = [propertyList stringOrNilForKey:@"Domain"];

		_domain = [(specificationDomain != nil ? specificationDomain : domain) copy];

		NSString *basedOn = [propertyList stringOrNilForKey:@"BasedOn"];

		if (basedOn != nil) {
			NSString *superDomain = nil;
			NSString *superIdentifier = nil;

			[[self class] _getDomain:&superDomain
				      identifier:&superIdentifier
				 fromDomainPrefixedIdentifier:basedOn];

			_superSpecification = [[[self class] specificationForIdentifier:superIdentifier
									       inDomain:superDomain] loadedSpecification];

			if (_superSpecification == nil) {
				NSLog(@"warning: specification %@ in domain %@ is based on unknown specification %@",
				      _identifier, _domain, basedOn);
			}
		}

		_properties = [[NSDictionary alloc] initWithDictionary:propertyList];
		_tsProperties = propertyList;
		_bundle = [propertyList bundle];

		NSDictionary *superLocalizationDictionary = [_superSpecification localizationDictionary];

		if (superLocalizationDictionary == nil) {
			superLocalizationDictionary = [NSDictionary dictionary];
		}

		NSMutableDictionary *localizationDictionary = [[propertyList localizationDictionary] mutableCopy];

		if (localizationDictionary == nil) {
			localizationDictionary = [[NSMutableDictionary alloc] initWithCapacity:0];
		}

		for (NSString *key in [NSArray arrayWithObjects:@"Name", @"Description", nil]) {
			if ([localizationDictionary objectForKey:key] == nil) {
				NSString *value = [self stringForKey:key];

				if (value != nil) {
					[localizationDictionary setObject:value forKey:key];
				}
			}
		}

		NSMutableDictionary *mergedLocalizationDictionary = [superLocalizationDictionary mutableCopy];

		[mergedLocalizationDictionary addEntriesFromDictionary:localizationDictionary];
		_localizationDictionary = [mergedLocalizationDictionary copy];
	}
	return (self);
}

- (id)initWithPropertyListDictionary:(TSPropertyListDictionary *)propertyList
{
	return ([self initWithPropertyListDictionary:propertyList inDomain:@""]);
}

- (id)initAsMissingSpecificationProxyWithIdentifier:(NSString *)identifier
					       name:(NSString *)name
					description:(NSString *)description
					   inDomain:(NSString *)domain
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:0x10];

	[dictionary setObject:[[self class] specificationType] forKey:@"Type"];
	[dictionary setObject:identifier forKey:@"Identifier"];
	[dictionary setObject:@"YES" forKey:@"IsMissing"];

	if (name != nil && [name length] > 0) {
		[dictionary setObject:name forKey:@"Name"];
	} else {
		[dictionary setObject:identifier forKey:@"Name"];
	}
	if (description != nil) {
		[dictionary setObject:description forKey:@"Description"];
	}

	TSPropertyListDictionary *propertyList = [TSPropertyListDictionary propertyListDictionaryWithDictionary:dictionary];

	return ([self initWithPropertyListDictionary:propertyList inDomain:domain]);
}

- (void)dealloc
{
#if !__has_feature(objc_arc)
	[_identifier release];
	[_superSpecification release];
	[_properties release];
	[_tsProperties release];
	[_localizationDictionary release];
	[_bundle release];
	[_domain release];
	[super dealloc];
#endif
}

- (void)awakeAfterInitialization
{
}

#pragma mark Accessors

- (NSString *)identifier
{
	return (_identifier);
}

- (XCSpecification *)superSpecification
{
	return ([_superSpecification loadedSpecification]);
}

- (NSArray *)subSpecificationsInDomain:(NSString *)domain
{
	return ([[self class] _subSpecificationsOfSpecification:self inDomain:domain]);
}

- (NSArray *)subSpecifications
{
	return ([self subSpecificationsInDomain:@""]);
}

- (NSNumber *)kindOfSpecificationDistance:(XCSpecification *)specification
{
	if (specification == nil) {
		return (nil);
	}
	if (![specification isKindOfClass:[XCSpecification class]] && ![specification isKindOfClass:[XCSpecificationProxy class]]) {
		return (nil);
	}

	NSUInteger distance = 0;
	XCSpecification *current = self;

	while (current != nil) {
		if ([[current identifier] isEqualToString:[specification identifier]]) {
			return ([NSNumber numberWithUnsignedInteger:distance]);
		}
		current = [current superSpecification];
		distance++;
	}
	return (nil);
}

- (BOOL)isKindOfSpecification:(XCSpecification *)specification
{
	return ([self kindOfSpecificationDistance:specification] != nil);
}

- (BOOL)isAbstract
{
	return ([[self _objectForKeyIgnoringInheritance:@"IsAbstract"] boolValue]);
}

- (BOOL)showOnlySelfDefinedPropertiesInBuildSettingsGUI
{
	return (NO);
}

- (BOOL)isNotYetLoadedSpecificationProxy
{
	return (NO);
}

- (XCSpecification *)loadedSpecification
{
	return (self);
}

- (BOOL)isMissingSpecificationProxy
{
	return ([[self _objectForKeyIgnoringInheritance:@"IsMissing"] boolValue]);
}

- (NSString *)type
{
	return ([[self class] specificationType]);
}

- (NSDictionary *)properties
{
	return (_properties);
}

- (TSPropertyListDictionary *)tsProperties
{
	return (_tsProperties);
}

- (NSDictionary *)localizationDictionary
{
	return (_localizationDictionary);
}

- (NSBundle *)bundle
{
	return (_bundle);
}

- (NSString *)domain
{
	return (_domain);
}

- (NSString *)name
{
	return ([self stringForKey:@"Name"]);
}

- (NSString *)localizedDescription
{
	return ([self stringForKey:@"Description"]);
}

- (NSComparisonResult)identifierCompare:(id)other
{
	if (![other isKindOfClass:[XCSpecification class]] && ![other isKindOfClass:[XCSpecificationProxy class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"other", NSStringFromClass([XCSpecification class]), other];
	}
	return ([[self identifier] compare:[other identifier]]);
}

- (NSComparisonResult)nameCompare:(id)other
{
	if (![other isKindOfClass:[XCSpecification class]] && ![other isKindOfClass:[XCSpecificationProxy class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"other", NSStringFromClass([XCSpecification class]), other];
	}
	return ([[self name] compare:[other name]]);
}

- (id)_objectForKeyIgnoringInheritance:(NSString *)key
{
	return ([_properties objectForKey:key]);
}

- (id)objectForKey:(NSString *)key
{
	id result = [self _objectForKeyIgnoringInheritance:key];

	if (result == nil) {
		result = [[self superSpecification] objectForKey:key];
	}
	return (result);
}

- (id)valueForUndefinedKey:(NSString *)key
{
	return ([_properties objectForKey:key]);
}

- (NSString *)stringForKey:(NSString *)key
{
	id value = [self objectForKey:key];

	if (value == nil) {
		return (nil);
	}
	if (![value isKindOfClass:[NSString class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   key, NSStringFromClass([NSString class]), value];
	}
	return (value);
}

- (NSArray *)arrayForKey:(NSString *)key
{
	id value = [self objectForKey:key];

	if (value == nil) {
		return (nil);
	}
	if (![value isKindOfClass:[NSArray class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   key, NSStringFromClass([NSArray class]), value];
	}
	return (value);
}

- (NSDictionary *)dictionaryForKey:(NSString *)key
{
	id value = [self objectForKey:key];

	if (value == nil) {
		return (nil);
	}
	if (![value isKindOfClass:[NSDictionary class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   key, NSStringFromClass([NSDictionary class]), value];
	}
	return (value);
}

- (NSData *)dataForKey:(NSString *)key
{
	id value = [self objectForKey:key];

	if (value == nil) {
		return (nil);
	}
	if (![value isKindOfClass:[NSData class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   key, NSStringFromClass([NSData class]), value];
	}
	return (value);
}

- (NSInteger)integerForKey:(NSString *)key
{
	id value = [self objectForKey:key];

	if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
		return ([value integerValue]);
	}
	return (0);
}

- (float)floatForKey:(NSString *)key
{
	id value = [self objectForKey:key];

	if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
		return ([value floatValue]);
	}
	return (0.0f);
}

- (double)doubleForKey:(NSString *)key
{
	id value = [self objectForKey:key];

	if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) {
		return ([value doubleValue]);
	}
	return (0.0);
}

- (BOOL)boolForKey:(NSString *)key
{
	return ([[self class] _booleanValueForValue:[self objectForKey:key]]);
}

- (id)arrayOrStringForKey:(NSString *)key
{
	id value = [self objectForKey:key];

	if (value == nil) {
		return (nil);
	}
	if ([value isKindOfClass:[NSString class]]) {
		return ([NSArray arrayWithObject:value]);
	}
	if ([value isKindOfClass:[NSArray class]]) {
		return (value);
	}
	[NSException raise:NSInvalidArgumentException
		    format:@"%@ should be an instance inheriting from %@, but it is %@",
			   key, NSStringFromClass([NSArray class]), value];
	return (nil);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@:%p:'%@'%@:%@>",
		   NSStringFromClass([self class]),
		   self,
		   _identifier,
		   ([self isMissingSpecificationProxy] ? @":MISSING" : @""),
		   (([_domain length] > 0) ? _domain : @"Default")]);
}

@end
