/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * The complete project-model object graph (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXPROJECTMODEL_H
#define DEVTOOLSCORE_PBXPROJECTMODEL_H

#import "DevToolsCore/PBXTarget.h"

/*
 * PBXProjectModel is the in-memory object graph decoded from a
 * project.pbxproj archive.  It owns the map of objectID -> PBXObject and the
 * archive metadata (archiveVersion, objectVersion) needed to re-encode.
 *
 * The graph is fully materialized: header attributes become ivars, identity
 * references become object pointers.  Keys not covered by a class's binding
 * table are retained verbatim so that unmodeled content survives a round-trip.
 */
@interface PBXProjectModel : NSObject
{
	PBXProject *_rootObject;
	NSMutableDictionary *_objects;
	NSString *_archiveVersion;
	NSString *_objectVersion;
	NSMutableDictionary *_rootExtras;
}

+ (instancetype)modelWithContentsOfFile:(NSString *)path error:(NSError **)error;
+ (instancetype)modelWithArchiveString:(NSString *)string error:(NSError **)error;

- (PBXProject *)rootObject;
- (NSDictionary *)objects;
- (PBXObject *)objectForID:(NSString *)objectID;
- (NSArray *)objectsOfClass:(Class)cls;
- (void)addObject:(PBXObject *)object;
- (void)removeObject:(PBXObject *)object;

- (NSString *)archiveVersion;
- (void)setArchiveVersion:(NSString *)version;
- (NSString *)objectVersion;
- (void)setObjectVersion:(NSString *)version;

/* Encode the graph back to OpenStep plist text (canonical Xcode layout). */
- (NSString *)archiveString;
- (BOOL)writeToFile:(NSString *)path error:(NSError **)error;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile;

@end

#endif	/* DEVTOOLSCORE_PBXPROJECTMODEL_H */
