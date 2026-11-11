/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * File-type identifiers (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXFILETYPEPART_H
#define DEVTOOLSCORE_PBXFILETYPEPART_H

#import <Foundation/Foundation.h>

/*
 * A node in the dotted identifier of a file type (for example the "c" part of
 * "sourcecode.c.objc").  DevToolsCore only ships the abstract base class: it
 * cannot be instantiated and the kind predicates default to NO.
 */
@interface PBXFileTypePart : NSObject
{
	NSString *_identifier;
	PBXFileTypePart *_superpart;
	NSMutableArray *_subparts;
}
- (instancetype)init;
- (NSString *)identifier;
- (PBXFileTypePart *)superpart;
- (void)setSuperpart:(PBXFileTypePart *)superpart;
- (NSArray *)subparts;
- (BOOL)isPlainFile;
- (BOOL)isFolder;
- (BOOL)isSymbolicLink;
@end

#endif	/* DEVTOOLSCORE_PBXFILETYPEPART_H */
