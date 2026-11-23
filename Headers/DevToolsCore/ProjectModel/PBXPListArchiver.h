/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Minimal PList archiver support for PBXArchiveBinding. */

#ifndef DEVTOOLSCORE_PBXPLISTARCHIVER_H
#define DEVTOOLSCORE_PBXPLISTARCHIVER_H

#import <Foundation/Foundation.h>

@interface PBXPListArchiver : NSObject
{
	id _rootObject;
	id _delegate;
	NSUInteger _role;
	NSMutableDictionary *_values;
}

- (instancetype)initWithRootObject:(id)root
    delegate:(id)delegate
    role:(NSUInteger)role;

- (void)encodeObject:(id)value forKey:(NSString *)key;
- (void)encodeString:(NSString *)value forKey:(NSString *)key;
- (void)encodeInteger:(NSInteger)value forKey:(NSString *)key;
- (void)encodeBool:(BOOL)value forKey:(NSString *)key;
- (void)encodeDouble:(double)value forKey:(NSString *)key;
- (NSDictionary *)archive;

@end

@interface PBXPListUnarchiver : NSObject
{
	NSDictionary *_archive;
}

- (instancetype)initWithPListArchive:(NSDictionary *)archive;

- (id)valueForKey:(NSString *)key;
- (id)decodeObjectForKey:(NSString *)key;
- (NSString *)decodeStringForKey:(NSString *)key;
- (NSInteger)decodeIntegerForKey:(NSString *)key;
- (BOOL)decodeBoolForKey:(NSString *)key;
- (double)decodeDoubleForKey:(NSString *)key;

@end

#endif /* DEVTOOLSCORE_PBXPLISTARCHIVER_H */
