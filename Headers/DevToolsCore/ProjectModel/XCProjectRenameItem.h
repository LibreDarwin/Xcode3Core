/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCProjectRename value objects. */

#ifndef DEVTOOLSCORE_PROJECTMODEL_XCPROJECTRENAMEITEM_H
#define DEVTOOLSCORE_PROJECTMODEL_XCPROJECTRENAMEITEM_H

#import <Foundation/Foundation.h>

@class DVTFileDataType;
@class DVTRangeArray;
@class NSImage;
@class PBXProject;
@class PBXTarget;
@protocol IDEXcode3ProjectItemRenaming;
@protocol IDERenameableXcode3ProjectItem;

@interface XCProjectRenameItem : NSObject
{
    XCProjectRenameItem *_parent;
    id _representedObject;
    id<IDEXcode3ProjectItemRenaming> _renamer;
    id<IDERenameableXcode3ProjectItem> _renameableItem;
    PBXProject *_project;
    PBXTarget *_target;
    NSMutableArray *_buildConfigurations;
    NSString *_type;
    DVTFileDataType *_fileDataType;
    NSString *_currentName;
    NSString *_proposedName;
    NSAttributedString *_attributedCurrentName;
    NSAttributedString *_attributedProposedName;
    NSImage *_image;
    NSMutableArray *_children;
    NSError *_error;
    BOOL _enabled;
    BOOL _shouldRename;
    BOOL _requiresUniqueChildNames;
    BOOL _renameChildren;
    DVTRangeArray *_currentNameMatchRange;
    DVTRangeArray *_proposedNameMatchRange;
}
- (id)init;
- (void)addChild:(XCProjectRenameItem *)child;
- (void)removeChild:(XCProjectRenameItem *)child;
- (void)addBuildConfiguration:(id)configuration;
- (void)addBuildConfigurations:(NSArray *)configurations;
- (void)updateProposedNameWith:(NSString *)proposed
                      fromName:(NSString *)fromName;
- (void)cancel;
- (void)rename;
- (void)validate;
- (XCProjectRenameItem *)parent;
- (void)setParent:(XCProjectRenameItem *)parent;
- (id)representedObject;
- (void)setRepresentedObject:(id)object;
- (id<IDEXcode3ProjectItemRenaming>)renamer;
- (void)setRenamer:(id<IDEXcode3ProjectItemRenaming>)renamer;
- (id<IDERenameableXcode3ProjectItem>)renameableItem;
- (void)setRenameableItem:(id<IDERenameableXcode3ProjectItem>)item;
- (PBXProject *)project;
- (void)setProject:(PBXProject *)project;
- (PBXTarget *)target;
- (void)setTarget:(PBXTarget *)target;
- (NSString *)type;
- (void)setType:(NSString *)type;
- (DVTFileDataType *)fileDataType;
- (void)setFileDataType:(DVTFileDataType *)type;
- (NSString *)currentName;
- (void)setCurrentName:(NSString *)name;
- (NSString *)proposedName;
- (NSAttributedString *)attributedCurrentName;
- (void)setAttributedCurrentName:(NSAttributedString *)name;
- (NSAttributedString *)attributedProposedName;
- (void)setAttributedProposedName:(NSAttributedString *)name;
- (NSImage *)image;
- (void)setImage:(NSImage *)image;
- (NSArray *)children;
- (void)setChildren:(NSArray *)children;
- (NSError *)error;
- (void)setError:(NSError *)error;
- (BOOL)enabled;
- (void)setEnabled:(BOOL)enabled;
- (BOOL)shouldRename;
- (void)setShouldRename:(BOOL)rename;
- (NSArray *)buildConfigurations;
- (void)setBuildConfigurations:(NSArray *)configurations;
- (DVTRangeArray *)currentNameMatchRange;
- (void)setCurrentNameMatchRange:(DVTRangeArray *)range;
- (DVTRangeArray *)proposedNameMatchRange;
- (void)setProposedNameMatchRange:(DVTRangeArray *)range;
@end

@interface XCProjectRenameFileItem : XCProjectRenameItem
- (void)renamedFileAtPath:(NSString *)path
                       to:(NSString *)newPath
                    error:(NSError **)error;
@end

@interface XCProjectRenameXibItem : XCProjectRenameItem
@end

@interface XCProjectRenamePCHItem : XCProjectRenameItem
@end

@interface XCProjectRenameInfoPlistContentsItem : XCProjectRenameItem
- (NSString *)_alterReverseDNSString:(NSString *)string
              byReplacingCurrentValue:(NSString *)current
                         withNewValue:(NSString *)replacement;
@end

@interface XCProjectRenameInfoPlistItem : XCProjectRenameItem
- (void)renamedFileAtPath:(NSString *)path
                       to:(NSString *)newPath
                    error:(NSError **)error;
@end

@interface XCProjectRenameProductItem : XCProjectRenameItem
@end

@interface XCProjectRenameBuildSettingItem : XCProjectRenameItem
{
    NSString *_settingName;
}
- (NSString *)settingName;
- (void)setSettingName:(NSString *)name;
@end

@interface XCProjectRenameTargetItem : XCProjectRenameItem
- (NSArray *)products;
- (NSArray *)prefixFiles;
@end

@interface XCProjectRenameProjectItem : XCProjectRenameItem
@end

#endif	/* DEVTOOLSCORE_PROJECTMODEL_XCPROJECTRENAMEITEM_H */
