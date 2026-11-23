/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Archive binding base class for the project-model object graph. */

#ifndef DEVTOOLSCORE_PBXARCHIVEBINDING_H
#define DEVTOOLSCORE_PBXARCHIVEBINDING_H

#import <Foundation/Foundation.h>

@class NSKeyBinding;

@interface PBXArchiveBinding : NSObject
{
@protected
	NSKeyBinding *_keyBindingInternal;
	NSString *_key;
	NSString *_archiveKey;
	NSInteger _archiveMask;
	BOOL _allowsAnyClass;
}

+ (instancetype)bindingWithClass:(Class)targetClass
    key:(NSString *)key
    archiveMask:(NSInteger)mask;

- (instancetype)initWithKeyBinding:(NSKeyBinding *)binding
    archiveMask:(NSInteger)mask;

- (NSInteger)archiveMask;
- (NSString *)key;
- (Class)targetClass;
- (BOOL)allowsAnyClass;
- (void)setAllowsAnyClass:(BOOL)flag;

@end

#endif /* DEVTOOLSCORE_PBXARCHIVEBINDING_H */
