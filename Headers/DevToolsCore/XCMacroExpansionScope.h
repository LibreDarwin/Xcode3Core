/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCMacroExpansionScope.
 */

#ifndef DEVTOOLSCORE_XCMACROEXPANSIONSCOPE_H
#define DEVTOOLSCORE_XCMACROEXPANSIONSCOPE_H

#import <Foundation/Foundation.h>

#import <DVTMacroFoundation/DVTMacroExpansionScope.h>

@class XCSDKPackage;

@interface XCMacroExpansionScope : DVTMacroExpansionScope {
	XCSDKPackage *_cachedSdk;
}

@property (readonly) XCSDKPackage *sdk;

+ (long long)numberOfDefinitionLevels;
+ (id)stringForDefinitionLevel:(long long)level;

- (id)initWithParentScope:(id)scope
      macroDefinitionTable:(id)table
           definitionLevel:(unsigned long long)level
      definitionLevelsToClear:(id)clear
      conditionParameterValues:(id)values
   conditionParameterFallbackValues:(id)fallbackValues
               expansionOptions:(unsigned long long)options;
- (void)appendAdditionalContentToStringBuilder:(void *)builder
					indent:(unsigned long long)indent;

@end

#endif	/* DEVTOOLSCORE_XCMACROEXPANSIONSCOPE_H */
