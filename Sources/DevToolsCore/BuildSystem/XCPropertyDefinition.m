/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of XCPropertyDefinition.  The implementation
 * models the xcspec-visible behavior: type selection from the Type key,
 * parsing of DefaultValue/Values/DisplayValues, command-line argument
 * metadata and the -description format used by DevToolsCore.
 */

#import "DevToolsCore/BuildSystem/XCPropertyDefinition.h"
#import "DevToolsCore/BuildSystem/XCPropertyDefinition_SupportedVersionRange.h"

#import <DVTFoundation/DVTVersion.h>
#import <objc/runtime.h>
#import <stdio.h>

#import <DVTMacroFoundation/DVTMacroExpressionParser.h>

static NSMutableDictionary<NSString *, Class> *sPropertyTypesByName = nil;

static NSSet *
XCPropertySupportedVersionRanges(TSPropertyListDictionary *properties)
{
	NSArray *rawRanges = [properties arrayOrNilForKey:@"SupportedVersionRanges"];
	NSMutableSet *ranges;

	if (rawRanges == nil || [rawRanges count] == 0)
		return (nil);
	ranges = [NSMutableSet set];
	for (id entry in rawRanges) {
		NSString *startString;
		NSString *endString = nil;
		DVTVersion *start;
		DVTVersion *end = nil;
		XCPropertyDefinition_SupportedVersionRange *range;

		if ([entry isKindOfClass:[NSString class]]) {
			startString = entry;
		} else if ([entry isKindOfClass:[NSArray class]]) {
			if ([entry count] < 1 || [entry count] > 2)
				return (nil);
			if (![[entry objectAtIndex:0] isKindOfClass:[NSString class]])
				return (nil);
			startString = [entry objectAtIndex:0];
			if ([entry count] == 2) {
				if (![[entry objectAtIndex:1] isKindOfClass:
				    [NSString class]])
					return (nil);
				endString = [entry objectAtIndex:1];
			}
		} else {
			return (nil);
		}
		start = [DVTVersion versionWithStringValue:startString];
		if (endString != nil)
			end = [DVTVersion versionWithStringValue:endString];
		range = [[XCPropertyDefinition_SupportedVersionRange alloc]
		    initWithStartOfRange:start endOfRange:end];
		[ranges addObject:range];
	}
	return (([ranges count] == 0) ? nil : ranges);
}

static NSArray *
XCPropertyListWords(NSString *string)
{
	NSMutableArray *words = [NSMutableArray array];
	NSUInteger index = 0;
	NSUInteger length = [string length];

	while (index < length) {
		 NSMutableString *word = [NSMutableString string];
		unichar quote = 0;

		while (index < length &&
		    [[NSCharacterSet whitespaceAndNewlineCharacterSet]
			characterIsMember:[string characterAtIndex:index]])
			index++;
		if (index >= length)
			break;
		if ([string characterAtIndex:index] == '"' ||
		    [string characterAtIndex:index] == '\'') {
			quote = [string characterAtIndex:index];
			index++;
		}
		while (index < length) {
			unichar character = [string characterAtIndex:index];

			if (quote != 0) {
				if (character == quote) {
					index++;
					break;
				}
			} else if ([[NSCharacterSet whitespaceAndNewlineCharacterSet]
			    characterIsMember:character]) {
				break;
			}
			if (character == '\\' && index + 1 < length) {
				index++;
				character = [string characterAtIndex:index];
			}
			[word appendFormat:@"%C", character];
			index++;
		}
		[words addObject:word];
	}
	return (words);
}

@implementation XCPropertyDefinition

+ (void)initialize
{
	if (self != [XCPropertyDefinition class])
		return;
	sPropertyTypesByName = [[NSMutableDictionary alloc] init];
	(void)XCPropertyTypeClassForIdentifier(@"string");
}

+ (NSString *)identifier
{
	return (@"string");
}

+ (NSString *)localizedName
{
	return (@"String");
}

+ (BOOL)isListType
{
	return (NO);
}

+ (Class)classForPropertyNamed:(NSString *)name typeString:(NSString *)type
{
	Class typeClass = nil;

	if (name != nil)
		typeClass = [sPropertyTypesByName objectForKey:name];
	if (typeClass == Nil)
		typeClass = XCPropertyTypeClassForIdentifier(type);
	return (typeClass);
}

+ (instancetype)propertyDefinitionFromPListDictionary:(TSPropertyListDictionary *)dictionary
{
	NSString *name;
	NSString *type;
	Class typeClass;
	id definition;

	if (![dictionary isKindOfClass:[NSDictionary class]])
		[NSException raise:NSInvalidArgumentException format:
		    @"%@ should be an instance inheriting from %@, but it is %@",
		    dictionary, [NSDictionary class], [dictionary class]];
	name = [dictionary stringOrNilForKey:@"Name"];
	type = [dictionary stringOrNilForKey:@"Type"];
	typeClass = [self classForPropertyNamed:name typeString:type];
	definition = [[typeClass alloc] initFromPListDictionary:dictionary];
	return (definition);
}

+ (id)_parsedDefaultValueForString:(NSString *)string
{
	if (![string isKindOfClass:[NSString class]])
		return (nil);
	return (DVTMacroExpressionByParsingString(string));
}

+ (instancetype)stringPropertyDefinitionWithName:(NSString *)name
				    defaultValue:(id)value
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

	[dictionary setObject:name forKey:@"Name"];
	[dictionary setObject:@"String" forKey:@"Type"];
	if (value != nil)
		[dictionary setObject:[value description] forKey:@"DefaultValue"];
	return ([self propertyDefinitionFromPListDictionary:
	    [TSPropertyListDictionary propertyListDictionaryWithDictionary:dictionary]]);
}

+ (NSArray *)dbgAllPropertyDefinitions
{
	return (@[]);
}

+ (void)_addPropertyDefinitionsInSpecificationDomain:(id)domain
					  toDictionary:(NSMutableDictionary *)dictionary
{
	(void)domain;
	(void)dictionary;
}

+ (NSArray *)allPropertyDefinitionsInAllSpecificationDomains
{
	return (@[]);
}

+ (NSArray *)baseDefinitionsForAllPropertyDefinitionsInAllSpecificationDomains
{
	return (@[]);
}

+ (Class)typeOfPropertyNamed:(NSString *)name
{
	return ([sPropertyTypesByName objectForKey:name]);
}

+ (BOOL)registerPropertyType:(Class)type forPropertyNamed:(NSString *)name
{
	if (![name isKindOfClass:[NSString class]] || type == Nil)
		return (NO);
	[sPropertyTypesByName setObject:type forKey:name];
	return (YES);
}

+ (BOOL)unregisterPropertyTypeForPropertyNamed:(NSString *)name
{
	if (![name isKindOfClass:[NSString class]])
		return (NO);
	if ([sPropertyTypesByName objectForKey:name] == nil)
		return (NO);
	[sPropertyTypesByName removeObjectForKey:name];
	return (YES);
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_typeClass = [XCStringPropertyDefinition class];
		_uiTypeClass = _typeClass;
		_localizedAllowedValues = @[];
	}
	return (self);
}

- (instancetype)initWithName:(NSString *)name
		      uiType:(id)type
	       allowedValues:(NSArray *)values
		 defaultValue:(id)value
	isAppleInternalOnly:(BOOL)only
		     isBasic:(BOOL)basic
	 commandLineArguments:(NSArray *)arguments
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

	[dictionary setObject:name forKey:@"Name"];
	[dictionary setObject:[[self class] identifier] forKey:@"Type"];
	if (type != nil) {
		if (object_getClass(type) != Nil &&
		    [type isKindOfClass:[NSString class]])
			[dictionary setObject:type forKey:@"UIType"];
		else
			[dictionary setObject:[type identifier] forKey:@"UIType"];
	}
	if (values != nil)
		[dictionary setObject:values forKey:@"AllowedValues"];
	if (value != nil)
		[dictionary setObject:[value description] forKey:@"DefaultValue"];
	if (only)
		[dictionary setObject:@"YES" forKey:@"AppleInternalOnly"];
	if (basic)
		[dictionary setObject:@"YES" forKey:@"Basic"];
	if (arguments != nil)
		[dictionary setObject:arguments forKey:@"CommandLineArgs"];
	return ([self initFromPListDictionary:
	    [TSPropertyListDictionary propertyListDictionaryWithDictionary:dictionary]]);
}

- (instancetype)initWithName:(NSString *)name
	       allowedValues:(NSArray *)values
		 defaultValue:(id)value
	isAppleInternalOnly:(BOOL)only
		     isBasic:(BOOL)basic
	 commandLineArguments:(NSArray *)arguments
{
	return ([self initWithName:name
			   uiType:nil
		    allowedValues:values
		      defaultValue:value
	     isAppleInternalOnly:only
			  isBasic:basic
	      commandLineArguments:arguments]);
}

- (instancetype)initFromPListDictionary:(TSPropertyListDictionary *)dictionary
{
	NSArray *values;
	NSArray *displayValues;
	NSString *typeString;
	NSString *uiTypeString;

	if (![dictionary isKindOfClass:[NSDictionary class]])
		[NSException raise:NSInvalidArgumentException format:
		    @"%@ should be an instance inheriting from %@, but it is %@",
		    dictionary, [NSDictionary class], [dictionary class]];
	self = [self init];
	if (self == nil)
		return (nil);

	_properties = dictionary;
	_supportedVersionRanges = XCPropertySupportedVersionRanges(dictionary);
	_name = [dictionary stringOrNilForKey:@"Name"];
	typeString = [dictionary stringOrNilForKey:@"Type"];
	_typeClass = [[self class] classForPropertyNamed:_name typeString:typeString];
	uiTypeString = [dictionary stringOrNilForKey:@"UIType"];
	_uiTypeClass = ((uiTypeString != nil)
	    ? XCPropertyTypeClassForIdentifier(uiTypeString) : _typeClass);

	values = [dictionary arrayOrNilForKey:@"Values"];
	if (values == nil)
		values = [dictionary arrayOrNilForKey:@"AllowedValues"];
	_allowedValues = [values copy];
	displayValues = [dictionary arrayOrNilForKey:@"DisplayValues"];
	if ([_typeClass isEqual:[XCEnumerationPropertyDefinition class]]) {
		_localizedAllowedValues = (_allowedValues != nil)
		    ? _allowedValues : @[];
	} else if (displayValues != nil)
		_localizedAllowedValues = [displayValues copy];
	else if ([self isListType])
		_localizedAllowedValues = @[];
	else if ([_typeClass isEqual:[XCBooleanPropertyDefinition class]] &&
	    _allowedValues == nil)
		_localizedAllowedValues = @[@"Yes", @"No"];
	else if (_allowedValues != nil)
		_localizedAllowedValues = _allowedValues;
	else
		_localizedAllowedValues = @[];

	_defaultString = [dictionary stringOrNilForKey:@"DefaultValue"];
	if (_defaultString != nil) {
		if ([[self class] isListType])
			_defaultValue = DVTMacroExpressionByParsingStringAsList(_defaultString);
		else
			_defaultValue = (id <DVTMacroExpansion>)_defaultString;
	}

	_category = [dictionary stringOrNilForKey:@"Category"];
	_localizedName = [dictionary stringOrNilForKey:@"DisplayName"];
	if (_localizedName == nil)
		_localizedName = _name;
	_localizedDescription = [dictionary stringOrNilForKey:@"Description"];
	_definitionLocationDescription = [dictionary stringOrNilForKey:@"DefinitionLocationDescription"];
	_commandLineArgs = [dictionary arrayOrNilForKey:@"CommandLineArgs"];
	_commandLineFlag = [dictionary stringOrNilForKey:@"CommandLineFlag"];
	_commandLinePrefixFlag = [dictionary stringOrNilForKey:@"CommandLinePrefixFlag"];
	_additionalBuildSettings = [dictionary dictionaryOrNilForKey:@"AdditionalBuildSettings"];
	_conditionFlavors = [NSSet setWithArray:
	    ([dictionary arrayOrNilForKey:@"ConditionFlavors"]
	    ?: [dictionary arrayOrNilForKey:@"OptionConditionFlavors"]
	    ?: @[])];
	_isAppleInternalOnly = [[dictionary stringOrNilForKey:@"AppleInternalOnly"] boolValue];
	_isBasic = [[dictionary stringOrNilForKey:@"Basic"] boolValue];
	_uiShouldRemoveIfEmpty = [[dictionary stringOrNilForKey:@"UIRemoveIfEmpty"] boolValue];
	return (self);
}

- (Class <XCPropertyTypes>)type
{
	return ((Class <XCPropertyTypes>)_typeClass);
}

- (Class <XCPropertyTypes>)uiType
{
	return ((Class <XCPropertyTypes>)_uiTypeClass);
}

- (BOOL)isListType
{
	return ([_typeClass isListType]);
}

- (NSString *)typeString
{
	return ([_typeClass identifier]);
}

- (NSString *)uiTypeString
{
	return ([_uiTypeClass identifier]);
}

- (NSArray *)allowedValuesInTarget:(id)target
{
	(void)target;
	return (_allowedValues);
}

- (NSArray *)localizedAllowedValuesInTarget:(id)target
{
	(void)target;
	return (_localizedAllowedValues);
}

- (NSDictionary *)additionalBuildSettings
{
	return (_additionalBuildSettings);
}

- (NSSet *)supportedArchitectures
{
	return ([NSSet setWithArray:
	    ([_properties arrayOrNilForKey:@"SupportedArchs"] ?: @[])]);
}

- (NSSet *)supportedArchitecturesInDomain:(id)domain
			 withMacroExpansionScope:(id)scope
{
	(void)domain;
	(void)scope;
	return ([self supportedArchitectures]);
}

- (BOOL)supportsArchitecture:(NSString *)architecture
		    inDomain:(id)domain
	 withMacroExpansionScope:(id)scope
{
	return ([[self supportedArchitecturesInDomain:domain
				 withMacroExpansionScope:scope]
	    containsObject:architecture]);
}

- (NSSet *)supportedFileTypes
{
	return ([NSSet setWithArray:
	    ([_properties arrayOrNilForKey:@"SupportedFileTypes"] ?: @[])]);
}

- (BOOL)supportsFileType:(NSString *)type
{
	return ([[self supportedFileTypes] containsObject:type]);
}

- (BOOL)hasSupportedVersionRanges
{
	return (_supportedVersionRanges != nil);
}

- (BOOL)supportsVersion:(id)version
{
	for (XCPropertyDefinition_SupportedVersionRange *range in _supportedVersionRanges) {
		if ([range supportsVersion:version])
			return (YES);
	}
	return (_supportedVersionRanges == nil);
}

- (XCPropertyDomainSpecification *)propertyDomain
{
	return (_domain);
}

- (void)setPropertyDomain:(XCPropertyDomainSpecification *)domain
{
	_domain = domain;
}

- (NSSet *)conditionFlavors
{
	return (_conditionFlavors);
}

- (BOOL)isAppleInternalOnly
{
	return (_isAppleInternalOnly);
}

- (BOOL)isBasic
{
	return (_isBasic);
}

- (BOOL)canGenerateCommandLineArguments
{
	return (YES);
}

- (id)commandArgumentGenerationInfo
{
	if (_commandLineArgs != nil)
		return (_commandLineArgs);
	if (_commandLineFlag != nil)
		return (@{@"": @[], @"<<otherwise>>": @[_commandLineFlag, @"$(value)"]});
	if (_commandLinePrefixFlag != nil)
		return (@{@"": @[], @"<<otherwise>>":
		    [_commandLinePrefixFlag stringByAppendingString:@"$(value)"]});
	return (nil);
}

- (id)conditionExpression
{
	return (nil);
}

- (NSString *)nameOfOptionToPrecedeOnCommandLine
{
	return ([_properties stringOrNilForKey:@"NameOfOptionToPrecedeOnCommandLine"]);
}

- (NSString *)nameOfOptionToSucceedOnCommandLine
{
	return ([_properties stringOrNilForKey:@"NameOfOptionToSucceedOnCommandLine"]);
}

- (NSString *)nameOfOptionToPrecedeInUserInterface
{
	return ([_properties stringOrNilForKey:@"NameOfOptionToPrecedeInUserInterface"]);
}

- (NSString *)nameOfOptionToSucceedInUserInterface
{
	return ([_properties stringOrNilForKey:@"NameOfOptionToSucceedInUserInterface"]);
}

- (BOOL)uiShouldRemoveIfEmptyValue
{
	return (_uiShouldRemoveIfEmpty);
}

- (BOOL)isUserDefined
{
	return (_isUserDefined);
}

- (void)setUserDefined:(BOOL)defined
{
	_isUserDefined = defined;
}

- (TSPropertyListDictionary *)properties
{
	return (_properties);
}

- (id)valueForUndefinedKey:(NSString *)key
{
	return ([_properties objectOrNilForKey:key]);
}

- (NSString *)definitionLocationDescription
{
	return (_definitionLocationDescription);
}

- (void)setDefinitionLocationDescription:(NSString *)description
{
	_definitionLocationDescription = [description copy];
}

- (NSString *)categoryNameForUserInterface
{
	return (_category);
}

- (BOOL)propertyIsEnabledWithMacroExpansionScope:(id)scope
{
	(void)scope;
	return ([self conditionExpression] == nil);
}

- (NSString *)description
{
	NSString *allowed = ((_allowedValues != nil)
	    ? [_allowedValues description] : @"-");
	id defaultDescription = _defaultString;

	if ([self isListType] && _defaultString != nil)
		defaultDescription = [XCPropertyListWords(_defaultString) description];

	return ([NSString stringWithFormat:@"<%@:'%@':%@:%@:'%@'>",
	    NSStringFromClass([self class]), _name, [self typeString],
	    allowed, defaultDescription]);
}

- (void)printToStdout
{
	printf("%s\n", [[self description] UTF8String]);
}

@end
