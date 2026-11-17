/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCMacroExpansionExtensions
 * category on DVTMacroDefinitionTable.
 */

#ifndef DEVTOOLSCORE_BUILDSYSTEM_DVTMACRODEFINITIONTABLE_XCMACROEXPANSIONEXTENSIONS_H
#define DEVTOOLSCORE_BUILDSYSTEM_DVTMACRODEFINITIONTABLE_XCMACROEXPANSIONEXTENSIONS_H

#import <Foundation/Foundation.h>

#import <DVTMacroFoundation/DVTMacroDefinitionTable.h>

@class DVTMacroDefinitionConditionSet;

@interface DVTMacroDefinitionTable (XCMacroExpansionExtensions)

+ (id)_xc_unarchivedRepresentationForSDKROOTValue:(id)value;
+ (void)_xc_unarchiveArchsStandardSettingsUsingDict:(id)dictionary;
+ (id)xc_macroDefinitionTableFromDictionaryRepresentationForProjectArchiving:(id)archiving
    usingPropertyDefinitionsFromSpecificationDomain:(id)domain;

- (BOOL)_xc_shouldSplitValueOfListSettingNamed:(id)name
                          whenArchivingToFormat:(id)format;
- (void)_xc_archiveArchsStandardSettingsUsingDict:(id)dictionary;
- (id)_xc_absoluteArchiveRepresentationForSDKROOTValue:(id)value;
- (id)xc_dictionaryRepresentationForProjectArchiving;

- (void)_xc_setValue:(id)value
         forMacroName:(id)name
          conditionSet:(DVTMacroDefinitionConditionSet *)conditionSet
          errorHandler:(void (^)(id error))handler;
- (void)_xc_setValue:(id)value
         forMacroName:(id)name
         errorHandler:(void (^)(id error))handler;
- (void)xc_setValue:(id)value
         forMacroName:(id)name
          conditionSet:(DVTMacroDefinitionConditionSet *)conditionSet
usingPropertyDefinitionsFromSpecificationDomain:(id)domain
         errorHandler:(void (^)(id error))handler;
- (void)xc_setValue:(id)value
         forMacroName:(id)name
          conditionSet:(DVTMacroDefinitionConditionSet *)conditionSet
         errorHandler:(void (^)(id error))handler;
- (void)xc_setValue:(id)value
         forMacroName:(id)name
usingPropertyDefinitionsFromSpecificationDomain:(id)domain
         errorHandler:(void (^)(id error))handler;
- (void)xc_setValue:(id)value
         forMacroName:(id)name
         errorHandler:(void (^)(id error))handler;
- (void)xc_setMacroNamesAndValuesFromDictionary:(id)dictionary
usingPropertyDefinitionsFromSpecificationDomain:(id)domain
         errorHandler:(void (^)(id error))handler;
- (void)xc_setMacroNamesAndValuesFromDictionary:(id)dictionary
         errorHandler:(void (^)(id error))handler;
- (void)xc_addPropertyDefinitionDefaultValues:(id)values;

@end

#endif	/* DEVTOOLSCORE_BUILDSYSTEM_DVTMACRODEFINITIONTABLE_XCMACROEXPANSIONEXTENSIONS_H */
