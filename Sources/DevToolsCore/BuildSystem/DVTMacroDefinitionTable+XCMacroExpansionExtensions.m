/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of the XCMacroExpansionExtensions category on
 * DVTMacroDefinitionTable.  The category supplies the project-archive form of
 * build settings and the value conversion helpers used when loading one.
 */

#import "DevToolsCore/BuildSystem/DVTMacroDefinitionTable+XCMacroExpansionExtensions.h"

#import "DevToolsCore/BuildSystem/XCPropertyDefinition.h"

#import <DVTFoundation/DVTFoundationClassAdditions.h>

#import <DVTMacroFoundation/DVTMacroDefinitionConditionSet.h>
#import <DVTMacroFoundation/DVTMacroExpansion-Protocol.h>
#import <DVTMacroFoundation/DVTMacroExpressionParser.h>

static NSSet *XCProjectArchivingSplitSettingNames(void)
{
	static NSSet *names = nil;

	if (names == nil) {
		names = [NSSet setWithObjects:
		    @"ALTERNATE_PERMISSIONS_FILES",
		    @"ARCHS",
		    @"BUILD_VARIANTS",
		    @"EXCLUDED_SOURCE_FILE_NAMES",
		    @"FRAMEWORK_SEARCH_PATHS",
		    @"GCC_PREPROCESSOR_DEFINITIONS",
		    @"GCC_PREPROCESSOR_DEFINITIONS_NOT_USED_IN_PRECOMPS",
		    @"HEADER_SEARCH_PATHS",
		    @"INCLUDED_SOURCE_FILE_NAMES",
		    @"INFOPLIST_PREPROCESSOR_DEFINITIONS",
		    @"LD_DYLIB_ALLOWABLE_CLIENTS",
		    @"LD_RUNPATH_SEARCH_PATHS",
		    @"LIBRARY_SEARCH_PATHS",
		    @"LOCALIZED_STRING_MACRO_NAMES",
		    @"OTHER_CFLAGS",
		    @"OTHER_CPLUSPLUSFLAGS",
		    @"OTHER_LDFLAGS",
		    @"REZ_SEARCH_PATHS",
		    @"SECTORDER_FLAGS",
		    @"SYSTEM_FRAMEWORK_SEARCH_PATHS",
		    @"SYSTEM_HEADER_SEARCH_PATHS",
		    @"USER_HEADER_SEARCH_PATHS",
		    @"WARNING_CFLAGS", nil];
	}
	return (names);
}

static NSString *XCBaseMacroName(NSString *name)
{
	NSRange bracket = [name rangeOfString:@"["];

	if (bracket.location == NSNotFound)
		return (name);
	return ([name substringToIndex:bracket.location]);
}

static NSArray *XCArchiveValueComponents(NSString *string)
{
	NSMutableArray *components = [NSMutableArray array];
	NSUInteger length = [string length];
	NSUInteger tokenStart = NSNotFound;
	unichar quote = 0;
	BOOL escaped = NO;

	for (NSUInteger index = 0; index < length; index++) {
		unichar character = [string characterAtIndex:index];

		if (escaped) {
			escaped = NO;
			continue;
		}
		if (character == '\\') {
			if (tokenStart == NSNotFound)
				tokenStart = index;
			escaped = YES;
			continue;
		}
		if (quote != 0) {
			if (character == quote)
				quote = 0;
			continue;
		}
		if (character == '\'' || character == '"') {
			if (tokenStart == NSNotFound)
				tokenStart = index;
			quote = character;
			continue;
		}
		if ([[NSCharacterSet whitespaceAndNewlineCharacterSet]
			characterIsMember:character]) {
			if (tokenStart != NSNotFound) {
				NSRange range = NSMakeRange(tokenStart, index - tokenStart);
				[components addObject:[string substringWithRange:range]];
				tokenStart = NSNotFound;
			}
			continue;
		}
		if (tokenStart == NSNotFound)
			tokenStart = index;
	}
	if (tokenStart != NSNotFound) {
		NSRange range = NSMakeRange(tokenStart, length - tokenStart);
		[components addObject:[string substringWithRange:range]];
	}
	return (components);
}

static NSString *XCArchiveStringForm(id value)
{
	if ([value isKindOfClass:[NSArray class]])
		return ([value dvt_stringByConcatenatingAsCommandLineArguments]);
	if ([value respondsToSelector:@selector(count)] &&
	    [value respondsToSelector:@selector(objectAtIndex:)]) {
		NSUInteger count = [value count];
		NSMutableArray *strings = [NSMutableArray arrayWithCapacity:count];

		for (NSUInteger index = 0; index < count; index++) {
			id element = [value objectAtIndex:index];
			NSString *string = [element respondsToSelector:@selector(dvt_stringForm)]
			    ? [element dvt_stringForm] : [element description];
			[strings addObject:string];
		}
		return ([strings dvt_stringByConcatenatingAsCommandLineArguments]);
	}
	return ([value respondsToSelector:@selector(dvt_stringForm)]
	    ? [value dvt_stringForm] : [value description]);
}

static id XCArchiveStringValue(DVTMacroDefinitionTable *table, NSString *name,
    id value)
{
	NSString *string = XCArchiveStringForm(value);
	id archiveValue = string;

	if ([table _xc_shouldSplitValueOfListSettingNamed:name
		whenArchivingToFormat:nil]) {
		NSArray *components = XCArchiveValueComponents(string);
		if ([components count] > 1)
			archiveValue = components;
	}
	if ([name isEqualToString:@"SDKROOT"])
		archiveValue = [table _xc_absoluteArchiveRepresentationForSDKROOTValue:archiveValue];
	return (archiveValue);
}

static void XCCallErrorHandler(void (^handler)(id error))
{
	if (handler == nil)
		return;
	handler([NSError errorWithDomain:@"" code:0 userInfo:nil]);
}

static id XCValueForSetting(id value, void (^handler)(id error))
{
	if (value == nil || CFGetTypeID((__bridge CFTypeRef)value) == CFStringGetTypeID() ||
	    CFGetTypeID((__bridge CFTypeRef)value) == CFArrayGetTypeID())
		return (value);
	if ([value conformsToProtocol:@protocol(DVTMacroExpansion)])
		return (value);
	XCCallErrorHandler(handler);
	[NSException raise:NSInvalidArgumentException
		    format:@"value must be nil, string or array, but is %@", value];
	return (nil);
}

static NSString *XCRequiredMacroName(id name, void (^handler)(id error))
{
	if ([name isKindOfClass:[NSString class]] && [name length] > 0)
		return (name);
	XCCallErrorHandler(handler);
	[NSException raise:NSInvalidArgumentException format:@"invalid macro name"];
	return (nil);
}

@implementation DVTMacroDefinitionTable (XCMacroExpansionExtensions)

+ (id)_xc_unarchivedRepresentationForSDKROOTValue:(id)value
{
	return (value);
}

+ (void)_xc_unarchiveArchsStandardSettingsUsingDict:(id)dictionary
{
	id archs = [dictionary objectForKey:@"ARCHS"];

	if (archs == nil)
		return;
	if ([archs isKindOfClass:[NSArray class]]) {
		NSLog(@"Xcode project unarchiving: ARCHS is unexpectedly an array. "
		    @"Skipping backwards compatibility translation.");
		return;
	}
}

+ (id)xc_macroDefinitionTableFromDictionaryRepresentationForProjectArchiving:(id)archiving
    usingPropertyDefinitionsFromSpecificationDomain:(id)domain
{
	NSMutableDictionary *dictionary = [archiving mutableCopy];
	id sdkroot = [dictionary objectForKey:@"SDKROOT"];

	[[self class] _xc_unarchiveArchsStandardSettingsUsingDict:dictionary];
	if (sdkroot != nil)
		[dictionary setObject:[[self class] _xc_unarchivedRepresentationForSDKROOTValue:sdkroot]
			       forKey:@"SDKROOT"];

	DVTMacroDefinitionTable *table = [DVTMacroDefinitionTable newWithLabel:@"Xcode project unarchiving"];
	[table xc_setMacroNamesAndValuesFromDictionary:dictionary
usingPropertyDefinitionsFromSpecificationDomain:domain
					 errorHandler:^(id error) {
		(void)error;
	}];
	return (table);
}

- (BOOL)_xc_shouldSplitValueOfListSettingNamed:(id)name
			  whenArchivingToFormat:(id)format
{
	(void)format;
	return ([name isKindOfClass:[NSString class]] &&
	    [XCProjectArchivingSplitSettingNames() containsObject:name]);
}

- (void)_xc_archiveArchsStandardSettingsUsingDict:(id)dictionary
{
	id archs = [dictionary objectForKey:@"ARCHS"];

	if (archs == nil)
		return;
	if ([archs isKindOfClass:[NSArray class]]) {
		NSLog(@"Xcode project archiving: ARCHS is unexpectedly an array. "
		    @"Skipping backwards compatibility translation.");
		return;
	}

	NSString *string = [archs isKindOfClass:[NSString class]]
	    ? archs : [archs description];
	NSArray *components = XCArchiveValueComponents(string);
	[self setValue:components forMacroName:@"ARCHS" conditionSet:nil];
}

- (id)_xc_absoluteArchiveRepresentationForSDKROOTValue:(id)value
{
	return (value);
}

- (id)xc_dictionaryRepresentationForProjectArchiving
{
	NSDictionary *representation = [self dictionaryRepresentation];
	NSMutableDictionary *result = [NSMutableDictionary
	    dictionaryWithCapacity:[representation count]];

	[representation enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
		(void)stop;
		NSString *name = XCBaseMacroName(key);
		[result setObject:XCArchiveStringValue(self, name, value) forKey:key];
	}];
	return ([result copy]);
}

- (void)_xc_setValue:(id)value
	 forMacroName:(id)name
	  conditionSet:(DVTMacroDefinitionConditionSet *)conditionSet
	  errorHandler:(void (^)(id error))handler
{
	NSString *macroName = XCRequiredMacroName(name, handler);
	id settingValue = XCValueForSetting(value, handler);

	if ([settingValue isKindOfClass:[NSArray class]])
		[self setValue:settingValue forMacroName:macroName conditionSet:conditionSet];
	else
		[self parseAndSetValue:settingValue forMacroName:macroName conditionSet:conditionSet];
}

- (void)_xc_setValue:(id)value
	 forMacroName:(id)name
	 errorHandler:(void (^)(id error))handler
{
	[self _xc_setValue:value forMacroName:name conditionSet:nil errorHandler:handler];
}

- (void)xc_setValue:(id)value
	 forMacroName:(id)name
	  conditionSet:(DVTMacroDefinitionConditionSet *)conditionSet
usingPropertyDefinitionsFromSpecificationDomain:(id)domain
	 errorHandler:(void (^)(id error))handler
{
	(void)domain;
	[self _xc_setValue:value forMacroName:name conditionSet:conditionSet errorHandler:handler];
}

- (void)xc_setValue:(id)value
	 forMacroName:(id)name
	  conditionSet:(DVTMacroDefinitionConditionSet *)conditionSet
	 errorHandler:(void (^)(id error))handler
{
	[self xc_setValue:value forMacroName:name conditionSet:conditionSet
usingPropertyDefinitionsFromSpecificationDomain:nil
	 errorHandler:handler];
}

- (void)xc_setValue:(id)value
	 forMacroName:(id)name
usingPropertyDefinitionsFromSpecificationDomain:(id)domain
	 errorHandler:(void (^)(id error))handler
{
	[self xc_setValue:value forMacroName:name conditionSet:nil
usingPropertyDefinitionsFromSpecificationDomain:domain
	 errorHandler:handler];
}

- (void)xc_setValue:(id)value
	 forMacroName:(id)name
	 errorHandler:(void (^)(id error))handler
{
	[self xc_setValue:value forMacroName:name conditionSet:nil
usingPropertyDefinitionsFromSpecificationDomain:nil
	 errorHandler:handler];
}

- (void)xc_setMacroNamesAndValuesFromDictionary:(id)dictionary
usingPropertyDefinitionsFromSpecificationDomain:(id)domain
	 errorHandler:(void (^)(id error))handler
{
	if (dictionary == nil)
		return;
	if (![dictionary isKindOfClass:[NSDictionary class]]) {
		XCCallErrorHandler(handler);
		[NSException raise:NSInvalidArgumentException format:@"dict should be a dictionary"];
		return;
	}

	[dictionary enumerateKeysAndObjectsUsingBlock:^(id macroName, id value, BOOL *stop) {
		(void)stop;
		NSString *baseName = nil;
		DVTMacroDefinitionConditionSet *conditionSet =
		    [DVTMacroDefinitionConditionSet conditionSetFromStringRepresentation:macroName
									 getBaseMacroName:&baseName
											error:NULL];
		[self xc_setValue:value forMacroName:baseName conditionSet:conditionSet
usingPropertyDefinitionsFromSpecificationDomain:domain
				 errorHandler:handler];
	}];
}

- (void)xc_setMacroNamesAndValuesFromDictionary:(id)dictionary
	 errorHandler:(void (^)(id error))handler
{
	[self xc_setMacroNamesAndValuesFromDictionary:dictionary
usingPropertyDefinitionsFromSpecificationDomain:nil
					 errorHandler:handler];
}

- (void)xc_addPropertyDefinitionDefaultValues:(id)values
{
	for (id definition in values) {
		id defaultValue = [definition defaultValue];
		if (defaultValue == nil)
			continue;
		[self setValue:defaultValue forMacroName:[definition name] conditionSet:nil];
	}
}

@end
