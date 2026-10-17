/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Base class for the project-model object graph (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXOBJECT_H
#define DEVTOOLSCORE_PBXOBJECT_H

#import <Foundation/Foundation.h>

@class PBXContainer;

/*
 * PBXObject is the root of the archived object graph.  Subclasses declare
 * their archived state through +archivableAttributes / +archivableRelationships
 * (Apple's binding-table convention): attributes hold scalars, strings, arrays
 * or dictionaries, relationships hold references to other PBXObjects.
 *
 * Keys not covered by a binding table are preserved verbatim in the "extra"
 * dictionary so that unmodeled classes and unknown keys survive a round-trip.
 */
@interface PBXObject : NSObject
{
	NSString *_globalID;
	PBXContainer *_container;
	NSMutableDictionary *_extra;
}

/* Class name written as the "isa" value (defaults to the class name). */
+ (NSString *)classNameForPListArchive;

/* Ordered binding tables.  Keys are archive keys and are exposed through KVC
 * as instance variables named "_<key>". */
+ (NSArray *)archivableAttributes;
+ (NSArray *)archivableRelationships;

/* The unterminated keys above, in canonical archive order. */
+ (NSArray *)archivableKeys;
+ (NSSet *)relationshipKeySet;

/* Object identity (the key in the "objects" dictionary). */
- (NSString *)objectID;
- (void)setObjectID:(NSString *)objectID;

/* Owning container (project), not archived. */
- (PBXContainer *)container;
- (void)setContainer:(PBXContainer *)container;

- (NSString *)classNameForPListArchive;

/* Comment Xcode writes after a reference to this object (may be nil). */
- (NSString *)archiveComment;

/* Unmodeled archive keys, preserved verbatim across a round-trip. */
- (NSDictionary *)extraArchivedValues;
- (void)setExtraArchivedValues:(NSDictionary *)values;

/* Generic archive key access (KVC, tolerating missing ivars). */
- (id)archiveValueForKey:(NSString *)key;
- (BOOL)setArchiveValue:(id)value forKey:(NSString *)key;

- (NSString *)longDescription;

@end

#endif	/* DEVTOOLSCORE_PBXOBJECT_H */
