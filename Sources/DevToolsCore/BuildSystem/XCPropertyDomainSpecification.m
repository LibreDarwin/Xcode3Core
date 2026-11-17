/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsCore/BuildSystem/XCPropertyDomainSpecification.h"

#import "DevToolsCore/BuildSystem/XCPropertyCategory.h"
#import "DevToolsCore/BuildSystem/XCPropertyDefinition.h"
#import "DevToolsCore/BuildSystem/XCSpecificationProxy.h"
#import "DevToolsSupport/TSPropertyListDictionary.h"
#import <DVTMacroFoundation/DVTMacroDefinitionTable.h>
#import <DVTMacroFoundation/DVTMacroExpressionParser.h>
#import <DVTMacroFoundation/DVTMacroExpansionString_Literal.h>
#import <DVTMacroFoundation/NSString+DVTMacroExpansion.h>

static NSArray *
XCArrayOrEmpty(id value)
{
	if (value == nil)
		return (@[]);
	if ([value isKindOfClass:[NSArray class]])
		return (value);
	return ([NSArray arrayWithObject:value]);
}

static BOOL
XCNameIsDeleted(NSSet *deleted, NSString *name)
{
	return (name != nil && [deleted containsObject:name]);
}

static NSArray *
XCFilteredNames(NSArray *names, NSSet *deleted)
{
	NSMutableArray *result = [NSMutableArray array];

	for (NSString *name in names) {
		if (!XCNameIsDeleted(deleted, name))
			[result addObject:name];
	}
	return (result);
}

static NSArray *
XCFilteredCategories(NSArray *categories, NSSet *deleted)
{
	NSMutableArray *result = [NSMutableArray array];

	for (XCPropertyCategory *category in categories) {
		XCPropertyCategory *copy = [category copy];

		for (NSString *name in deleted)
			[copy removeOptionName:name];
		[result addObject:copy];
	}
	return (result);
}

static XCPropertyCategory *
XCCategoryNamed(NSMutableArray *categories, NSString *name)
{
	for (XCPropertyCategory *category in categories) {
		if ([[category name] isEqualToString:name])
			return (category);
	}
	return (nil);
}

static void
XCAddDefinitionToCategories(NSMutableArray *categories, XCPropertyDefinition *definition,
    NSSet *deleted)
{
	NSString *name = [definition name];
	NSString *categoryName = [definition category];
	XCPropertyCategory *category;

	if (name == nil || categoryName == nil || XCNameIsDeleted(deleted, name))
		return;
	category = XCCategoryNamed(categories, categoryName);
	if (category == nil) {
		category = [[XCPropertyCategory alloc] initWithName:categoryName
							 propertyNames:@[]];
		[categories addObject:category];
	}
	if (![[category propertyNames] containsObject:name])
		[category addOptionName:name aboveOptionName:nil belowOptionName:nil];
}

static id
XCDefaultMacroValue(id value)
{
	if ([value isKindOfClass:[NSString class]]) {
		id parsed = DVTMacroExpressionByParsingString(value);

		if ([value dvt_literalValueOfCommonString] != nil)
			return (parsed);
		return ([parsed isKindOfClass:[NSString class]]
		    ? [DVTMacroExpansionString_Literal newWithLiteralString:parsed]
		    : parsed);
	}
	if ([value isKindOfClass:[NSArray class]])
		return (DVTMacroExpressionByParsingStringArrayAsList(value));
	return (value);
}

static XCPropertyDomainSpecification *
XCLoadedDomainSpecification(id specification)
{
	if ([specification isKindOfClass:[XCSpecificationProxy class]]) {
		id loaded = [specification loadedSpecification];

		return ([loaded isKindOfClass:[XCPropertyDomainSpecification class]]
		    ? loaded : nil);
	}
	return ([specification isKindOfClass:[XCPropertyDomainSpecification class]]
	    ? specification : nil);
}

@implementation XCPropertyDomainSpecification

+ (void)initialize
{
	if (self == [XCPropertyDomainSpecification class])
		[XCSpecification registerSpecificationTypeBaseClass:self];
}

+ (Class)specificationTypeBaseClass
{
	return ([XCPropertyDomainSpecification class]);
}

+ (NSString *)specificationType
{
	return (@"PropertyDomain");
}

+ (NSString *)localizedSpecificationTypeName
{
	return (@"property domain");
}

+ (NSSet *)specificationTypePathExtensions
{
	return ([NSSet setWithObject:@"pbbsetspec"]);
}

+ (NSString *)specificationRegistryName
{
	return (@"PropertyDomain");
}

+ (void)registerSpecificationOrProxy:(id)specification
{
	[super registerSpecificationOrProxy:specification];
}

+ (NSDictionary *)dictionaryOfallRegisteredPropertyDomainsInSpecificationDomain:(NSString *)domain
{
	NSMutableDictionary *registry = [self specificationRegistryForDomain:domain];

	return ((registry != nil) ? [registry copy] : [NSDictionary dictionary]);
}

+ (NSSet *)allRegisteredSpecificationDomains
{
	NSMutableSet *domains = [NSMutableSet set];

	for (id specification in [self allRegisteredSpecifications]) {
		Class baseClass = Nil;

		if ([specification isKindOfClass:[XCSpecificationProxy class]])
			baseClass = [specification specificationTypeBaseClass];
		else if ([specification isKindOfClass:[XCPropertyDomainSpecification class]])
			baseClass = [XCPropertyDomainSpecification class];

		if (baseClass != Nil &&
		    [baseClass isSubclassOfClass:[XCPropertyDomainSpecification class]])
			[domains addObject:([specification domain] ?: @"")];
	}
	return (domains);
}

+ (NSArray *)allRegisteredPropertyDomainsInSpecificationDomain:(NSString *)domain
{
	NSDictionary *registry = [self specificationRegistryForDomain:domain];

	return ((registry != nil) ? [registry allValues] : [NSArray array]);
}

+ (id)propertyDomainForIdentifier:(NSString *)identifier
	    inSpecificationDomain:(NSString *)domain
{
	return ([self specificationForIdentifier:identifier inDomain:domain]);
}

+ (NSArray *)allRegisteredPropertiesForName:(NSString *)name
{
	NSMutableArray *result = [NSMutableArray array];

	if (![name isKindOfClass:[NSString class]])
		return (result);
	for (id specification in [self allRegisteredSpecifications]) {
		XCPropertyDomainSpecification *domain = XCLoadedDomainSpecification(specification);
		id definition = [[domain directlyDeclaredBuildOptions] objectForKey:name];

		if (definition != nil)
			[result addObject:definition];
	}
	return (result);
}

- (instancetype)initWithPropertyListDictionary:(TSPropertyListDictionary *)dictionary
				      inDomain:(NSString *)domain
{
	id propertiesValue;
	NSMutableArray *properties = [NSMutableArray array];
	NSMutableDictionary *options = [NSMutableDictionary dictionary];
	NSMutableArray *commandLineNames = [NSMutableArray array];
	NSMutableSet *flavors = [NSMutableSet set];
	NSString *specificationForUserInterface;
	NSArray *categoryDictionaries;
	NSMutableArray *categories = [NSMutableArray array];

	self = [super initWithPropertyListDictionary:dictionary inDomain:domain];
	if (self == nil)
		return (nil);

	_deletedOptionNames = [NSSet setWithArray:
	    XCArrayOrEmpty([dictionary arrayOrNilForKey:@"DeletedProperties"])];
	propertiesValue = [dictionary objectOrNilForKey:@"Properties"];
	if (propertiesValue == nil)
		propertiesValue = [dictionary objectOrNilForKey:@"Options"];

	if ([propertiesValue isKindOfClass:[NSDictionary class]]) {
		NSArray *keys = [[propertiesValue allKeys]
		    sortedArrayUsingSelector:@selector(compare:)];

		for (NSString *key in keys) {
			id item = [propertiesValue objectForKey:key];
			TSPropertyListDictionary *propertyList;
			XCPropertyDefinition *definition;

			if ([item isKindOfClass:[TSPropertyListDictionary class]])
				propertyList = item;
			else
				propertyList = [TSPropertyListDictionary
				    propertyListDictionaryWithDictionary:item];
			if ([propertyList stringOrNilForKey:@"Name"] == nil) {
				NSMutableDictionary *mutable = [item mutableCopy];

				[mutable setObject:key forKey:@"Name"];
				propertyList = [TSPropertyListDictionary
				    propertyListDictionaryWithDictionary:mutable];
			}
			definition = [XCPropertyDefinition
			    propertyDefinitionFromPListDictionary:propertyList];
			[properties addObject:definition];
		}
	} else {
		for (id item in XCArrayOrEmpty(propertiesValue)) {
			TSPropertyListDictionary *propertyList;

			if ([item isKindOfClass:[TSPropertyListDictionary class]])
				propertyList = item;
			else
				propertyList = [TSPropertyListDictionary
				    propertyListDictionaryWithDictionary:item];
			[properties addObject:[XCPropertyDefinition
			    propertyDefinitionFromPListDictionary:propertyList]];
		}
	}

	for (XCPropertyDefinition *definition in properties) {
		NSString *name = [definition name];

		[definition setPropertyDomain:self];
		if (name == nil)
			continue;
		[options setObject:definition forKey:name];
		if ([definition canGenerateCommandLineArguments])
			[commandLineNames addObject:name];
		[flavors addObjectsFromArray:[[definition conditionFlavors] allObjects]];
	}
	_buildOptions = [options copy];
	_orderedBuildOptions = [properties copy];
	_optionNamesForCommandLine = [commandLineNames copy];
	[flavors addObjectsFromArray:
	    XCArrayOrEmpty([dictionary arrayOrNilForKey:@"OptionConditionFlavors"])];
	_buildOptionConditionFlavors = [flavors copy];

	categoryDictionaries = [dictionary arrayOrNilForKey:@"OptionCategories"];
	for (id item in XCArrayOrEmpty(categoryDictionaries)) {
		if ([item isKindOfClass:[XCPropertyCategory class]]) {
			[categories addObject:item];
			continue;
		}
		[categories addObject:[[XCPropertyCategory alloc]
		    initWithPropertyListDictionary:
			[TSPropertyListDictionary propertyListDictionaryWithDictionary:item]]];
	}
	_buildOptionCategories = [categories copy];

	specificationForUserInterface =
	    [dictionary stringOrNilForKey:@"SpecificationForUserInterface"];
	if (specificationForUserInterface != nil) {
		NSString *domainForUserInterface = nil;
		NSString *identifierForUserInterface = nil;

		[XCSpecification _getDomain:&domainForUserInterface
				 identifier:&identifierForUserInterface
		    fromDomainPrefixedIdentifier:specificationForUserInterface];
		if (identifierForUserInterface != nil) {
			XCPropertyDomainSpecification *specification = [[self class]
			    propertyDomainForIdentifier:identifierForUserInterface
				   inSpecificationDomain:(domainForUserInterface ?: @"")];

			if (specification != nil && specification != self)
				_specForUserInterface = specification;
		}
	}
	return (self);
}

- (XCPropertyDomainSpecification *)_superPropertyDomain
{
	return (XCLoadedDomainSpecification([self superSpecification]));
}

- (void)_ensureFlattened
{
	XCPropertyDomainSpecification *superDomain = [self _superPropertyDomain];
	NSMutableDictionary *options = [NSMutableDictionary dictionary];
	NSMutableArray *ordered = [NSMutableArray array];
	NSMutableArray *commandLineNames = [NSMutableArray array];
	NSMutableArray *categories = [NSMutableArray array];
	NSMutableSet *seenNames = [NSMutableSet set];

	if (superDomain != nil) {
		[options addEntriesFromDictionary:[superDomain buildOptions]];
		[ordered addObjectsFromArray:[superDomain orderedBuildOptions]];
		[commandLineNames addObjectsFromArray:
		    [superDomain namesOfFlattenedOptionsForCommandLine]];
	}
	[options addEntriesFromDictionary:_buildOptions];
	[ordered addObjectsFromArray:_orderedBuildOptions];
	for (NSString *name in _optionNamesForCommandLine) {
		if (![commandLineNames containsObject:name])
			[commandLineNames addObject:name];
	}
	for (NSString *name in _deletedOptionNames) {
		[options removeObjectForKey:name];
		[commandLineNames removeObject:name];
	}
	NSMutableArray *filteredOrdered = [NSMutableArray array];

	for (XCPropertyDefinition *definition in ordered) {
		if (!XCNameIsDeleted(_deletedOptionNames, [definition name]))
			[filteredOrdered addObject:definition];
	}
	ordered = filteredOrdered;

	if ([_buildOptionCategories count] > 0) {
		[categories addObjectsFromArray:
		    XCFilteredCategories(_buildOptionCategories, _deletedOptionNames)];
		for (XCPropertyDefinition *definition in ordered) {
			NSString *name = [definition name];

			if (name == nil || [seenNames containsObject:name])
				continue;
			[seenNames addObject:name];
			XCAddDefinitionToCategories(categories, definition,
			    _deletedOptionNames);
		}
	} else {
		if (superDomain != nil) {
			[categories addObjectsFromArray:XCFilteredCategories(
			    [superDomain flattenedOptionCategories], _deletedOptionNames)];
		}
		for (XCPropertyDefinition *definition in _orderedBuildOptions)
			XCAddDefinitionToCategories(categories, definition,
			    _deletedOptionNames);
	}

	_flattenedBuildOptions = [options copy];
	_flattenedOrderedBuildOptions = [ordered copy];
	_flattenedOptionNamesForCommandLine = [commandLineNames copy];
	_flattenedOptionCategories = [categories copy];
}

- (NSDictionary *)directlyDeclaredBuildOptions
{
	return (_buildOptions);
}

- (NSDictionary *)buildOptions
{
	if (_flattenedBuildOptions == nil)
		[self _ensureFlattened];
	return (_flattenedBuildOptions);
}

- (id)buildOptionNamed:(NSString *)name
{
	return ([[self buildOptions] objectForKey:name]);
}

- (NSArray *)orderedBuildOptions
{
	if (_flattenedOrderedBuildOptions == nil)
		[self _ensureFlattened];
	return (_flattenedOrderedBuildOptions);
}

- (NSArray *)orderedSelfDefinedBuildOptions
{
	NSMutableArray *result = [NSMutableArray array];

	for (XCPropertyDefinition *definition in _orderedBuildOptions) {
		if (!XCNameIsDeleted(_deletedOptionNames, [definition name]))
			[result addObject:definition];
	}
	return (result);
}

- (NSArray *)buildOptionCategories
{
	NSArray *ownCategories = XCFilteredCategories(_buildOptionCategories,
	    _deletedOptionNames);

	if ([ownCategories count] > 0)
		return (ownCategories);
	return (XCFilteredCategories([[self _superPropertyDomain] buildOptionCategories]
	    ?: @[], _deletedOptionNames));
}

- (NSArray *)flattenedOptionCategories
{
	if (_flattenedOptionCategories == nil)
		[self _ensureFlattened];
	return (_flattenedOptionCategories);
}

- (NSArray *)namesOfBuildOptionsForCommandLine
{
	return (XCFilteredNames(_optionNamesForCommandLine, _deletedOptionNames));
}

- (NSArray *)namesOfFlattenedOptionsForCommandLine
{
	if (_flattenedOptionNamesForCommandLine == nil)
		[self _ensureFlattened];
	return (_flattenedOptionNamesForCommandLine);
}

- (NSSet *)buildOptionConditionFlavors
{
	NSMutableSet *flavors = [NSMutableSet setWithSet:_buildOptionConditionFlavors];
	XCPropertyDomainSpecification *superDomain = [self _superPropertyDomain];

	if (superDomain != nil)
		[flavors unionSet:[superDomain buildOptionConditionFlavors]];
	return (flavors);
}

- (XCPropertyDomainSpecification *)specificationToShowInUserInterface
{
	return (_specForUserInterface ?: self);
}

- (void)_addToDefaultMacros:(DVTMacroDefinitionTable *)macros
{
	DVTMacroDefinitionTable *defaults = [self defaultMacrosForAllOptions];

	[defaults enumerateMacroNamesAndValuesUsingBlock:^(id name, id conditionSet,
	    id value, BOOL *stop) {
		(void)stop;
		[macros setValue:value forMacroName:name conditionSet:conditionSet];
	}];
}

- (DVTMacroDefinitionTable *)defaultMacrosForAllOptions
{
	if (_flattenedDefaultValuesTable == nil) {
		NSString *label = [NSString stringWithFormat:@"default macros for <%@:%@>",
		    ([self domain] ?: @""), [self identifier]];
		DVTMacroDefinitionTable *table = [DVTMacroDefinitionTable newWithLabel:label];
		XCPropertyDomainSpecification *superDomain = [self _superPropertyDomain];
		DVTMacroDefinitionTable *superDefaults = [superDomain defaultMacrosForAllOptions];

		[superDefaults enumerateMacroNamesAndValuesUsingBlock:^(id name,
		    id conditionSet, id value, BOOL *stop) {
			(void)stop;
			if (!XCNameIsDeleted(_deletedOptionNames, name))
				[table setValue:XCDefaultMacroValue(value)
				     forMacroName:name conditionSet:conditionSet];
		}];
		for (XCPropertyDefinition *definition in _orderedBuildOptions) {
			NSString *name = [definition name];
			id value = [definition defaultValue];

			if (name != nil && value != nil &&
			    !XCNameIsDeleted(_deletedOptionNames, name))
				[table setValue:XCDefaultMacroValue(value)
				     forMacroName:name conditionSet:nil];
		}
		[table makeImmutable];
		_flattenedDefaultValues = table;
		_flattenedDefaultValuesTable = table;
		_defaultOptionValues = table;
	}
	return (_flattenedDefaultValuesTable);
}

@end
