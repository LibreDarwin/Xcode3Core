/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * PList archiver support for DevToolsCore. */

#ifndef DEVTOOLSCORE_PBXPLISTARCHIVER_H
#define DEVTOOLSCORE_PBXPLISTARCHIVER_H

#import <Foundation/Foundation.h>

@interface PBXPListArchiver : NSObject
{
	NSUInteger _role;
	NSMutableDictionary *_archiveDictionary;
	NSMutableDictionary *_currentArchiveDict;
	NSMutableDictionary *_classTable;
	NSMutableDictionary *_objectTable;
	NSMutableDictionary *_userSettingsTable;
	NSMutableArray *_userObjects;
	id _delegate;
	id _archiveFormat;
}

+ (NSDictionary *)plistArchiveWithRootObject:(id)root
    delegate:(id)delegate
    role:(NSUInteger)role;
+ (id)currentArchiveFormat;

- (instancetype)initWithRootObject:(id)root
    delegate:(id)delegate
    role:(NSUInteger)role;

- (NSDictionary *)plistArchive;
- (NSDictionary *)userSettings;
- (NSUInteger)role;
- (id)delegate;
- (void)setDelegate:(id)delegate;
- (id)archiveFormat;
- (BOOL)shouldUseJuly2024Formatting;
- (id)keptProxyItems;
- (void)setKeptProxyItems:(id)items;
- (BOOL)shouldArchiveReferenceProxy:(id)proxy;

- (void)encodeBoolean:(BOOL)value forKey:(NSString *)key;
- (void)encodeCharacter:(unichar)value forKey:(NSString *)key;
- (void)encodeInteger:(NSInteger)value forKey:(NSString *)key;
- (void)encodeFloat:(float)value forKey:(NSString *)key;
- (void)encodeDouble:(double)value forKey:(NSString *)key;
- (void)encodeRange:(NSRange)value forKey:(NSString *)key;
- (void)encodeValue:(id)value forKey:(NSString *)key;
- (void)encodeObject:(id)value forKey:(NSString *)key;
- (void)encodeObjectWeakly:(id)value forKey:(NSString *)key;
- (void)encodeObjectArray:(id)value forKey:(NSString *)key;
- (void)encodeObjectArrayWeakly:(id)value forKey:(NSString *)key;
- (void)encodeObjectDictionary:(id)value forKey:(NSString *)key;
- (void)encodeObjectDictionaryWeakly:(id)value forKey:(NSString *)key;
- (void)encodeString:(id)value forKey:(NSString *)key;
- (void)encodePListArray:(id)value forKey:(NSString *)key;
- (void)encodePListDictionary:(id)value forKey:(NSString *)key;

- (void)encodeBool:(BOOL)value forKey:(NSString *)key;
- (NSDictionary *)archive;

@end

@interface PBXPListUnarchiver : NSObject
{
	NSDictionary *_archiveDictionary;
	NSDictionary *_classTable;
	NSDictionary *_objectTable;
	id _container;
	NSMutableDictionary *_translatedGlobalIDs;
	NSDictionary *_userSettingsTable;
	NSDictionary *_contextInfo;
	id _rootObject;
	NSUInteger _archivedObjectVersion;
	NSDictionary *_currentArchiveDict;
	NSMutableDictionary *_substituteClassNames;
	NSMutableArray *_unarchivedObjects;
	NSMutableDictionary *_unarchivedObjectsByGID;
	id _delegate;
	id _errorHandler;
}

+ (id)unarchivedRootObjectFromPListArchive:(NSDictionary *)archive;
+ (void)setClassName:(NSString *)className
    decodedForArchiveClassName:(NSString *)archiveClassName;
+ (NSString *)classNameDecodedForArchiveClassName:(NSString *)archiveClassName;
+ (id)currentArchiveFormat;

- (instancetype)initWithPListArchive:(NSDictionary *)archive;

- (id)rootObject;
- (id)decodeRootObject;
- (id)valueForKey:(NSString *)key;
- (BOOL)hasValueForKey:(NSString *)key;
- (BOOL)decodeBooleanForKey:(NSString *)key;
- (unichar)decodeCharacterForKey:(NSString *)key;
- (NSInteger)decodeIntegerForKey:(NSString *)key;
- (float)decodeFloatForKey:(NSString *)key;
- (double)decodeDoubleForKey:(NSString *)key;
- (NSRange)decodeRangeForKey:(NSString *)key;
- (id)decodeObjectForKey:(NSString *)key;
- (id)decodeMutableObjectArrayForKey:(NSString *)key;
- (id)decodeMutableObjectDictionaryForKey:(NSString *)key;
- (id)decodeStringForKey:(NSString *)key;
- (id)decodeNumberForKey:(NSString *)key;
- (id)decodeMutablePListArrayForKey:(NSString *)key;
- (id)decodeMutablePListDictionaryForKey:(NSString *)key;

- (BOOL)decodeBoolForKey:(NSString *)key;

@end

#endif	/* DEVTOOLSCORE_PBXPLISTARCHIVER_H */
