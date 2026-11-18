/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of XCMacroExpansionScope.  The class supplies
 * the project-aware definition-level names used in scope descriptions; value
 * lookup and condition handling remain in DVTMacroExpansionScope.
 */

#import "DevToolsCore/XCMacroExpansionScope.h"

static NSArray *XCMacroExpansionDefinitionLevelNames(void)
{
	static NSArray *names = nil;

	if (names == nil) {
		names = @[
		    @"default toolchain override",
		    @"tool overrides",
		    @"overrides",
		    @"sdk overrides",
		    @"toolchain overrides",
		    @"project",
		    @"product",
		    @"sdk defaults",
		    @"toolchain defaults",
		    @"platform defaults",
		    @"tool defaults",
		    @"defaults",
		    @"environment",
		    @"metadata"
		];
	}
	return (names);
}

@implementation XCMacroExpansionScope

+ (long long)numberOfDefinitionLevels
{
	return ([XCMacroExpansionDefinitionLevelNames() count]);
}

+ (id)stringForDefinitionLevel:(long long)level
{
	NSArray *names = XCMacroExpansionDefinitionLevelNames();

	if (level >= 0 && (NSUInteger)level < [names count])
		return ([names objectAtIndex:(NSUInteger)level]);
	return ([NSString stringWithFormat:@"unknown level %llu",
	    (unsigned long long)level]);
}

- (id)initWithParentScope:(id)scope
      macroDefinitionTable:(id)table
           definitionLevel:(unsigned long long)level
      definitionLevelsToClear:(id)clear
      conditionParameterValues:(id)values
   conditionParameterFallbackValues:(id)fallbackValues
               expansionOptions:(unsigned long long)options
{
	self = [super initWithParentScope:scope macroDefinitionTable:table
	    definitionLevel:level definitionLevelsToClear:clear
	    conditionParameterValues:values
	    conditionParameterFallbackValues:fallbackValues
	    expansionOptions:options];
	return (self);
}

- (id)sdk
{
	return (_cachedSdk);
}

- (void)appendAdditionalContentToStringBuilder:(void *)builder
					indent:(unsigned long long)indent
{
	(void)builder;
	(void)indent;
}

@end
