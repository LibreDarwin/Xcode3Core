/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsSupport's TSPropertyListDictionary.
 */

#ifndef DEVTOOLSSUPPORT_TSPROPERTYLISTDICTIONARY_H
#define DEVTOOLSSUPPORT_TSPROPERTYLISTDICTIONARY_H

#import <Foundation/Foundation.h>

@class NSBundle;

@interface TSPropertyListDictionary : NSDictionary {
    NSDictionary *_dict;
    NSString *_localizedDesc;
    NSBundle *_bundle;
    NSDictionary *_localizationDict;
}

+ (id)propertyListDictionaryWithDictionary:(id)dictionary;
+ (id)propertyListDictionaryWithContentsOfString:(id)string;

- (id)_localizedTypeNameForClass:(Class)aClass;
- (id)initWithDictionary:(id)dictionary;
- (id)initWithContentsOfString:(id)string;
- (id)initWithContentsOfFile:(id)file encoding:(unsigned long long)encoding;
- (id)bundle;
- (void)setBundle:(id)bundle;
- (id)localizationDictionary;
- (void)setLocalizationDictionary:(id)dictionary;
- (unsigned long long)count;
- (id)keyEnumerator;
- (id)objectForKey:(id)key;
- (id)objectOrNilForKey:(id)key;
- (id)stringForKey:(id)key;
- (id)stringOrNilForKey:(id)key;
- (id)dataForKey:(id)key;
- (id)dictionaryForKey:(id)key;
- (id)dictionaryOrNilForKey:(id)key;
- (id)arrayForKey:(id)key;
- (id)arrayOrNilForKey:(id)key;
- (id)arrayOrObjectOrNilForKey:(id)key;

@end

#endif	/* DEVTOOLSSUPPORT_TSPROPERTYLISTDICTIONARY_H */
