/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCProjectRename value objects. */

#import "DevToolsCore/ProjectModel/XCProjectRenameItem.h"

@implementation XCProjectRenameItem

- (id)init
{
	self = [super init];
	if (self != nil) {
		_enabled = YES;
		_shouldRename = YES;
	}
	return (self);
}

- (void)addChild:(XCProjectRenameItem *)child
{
	if (_children == nil)
		_children = [NSMutableArray array];
	[_children addObject:child];
	[child setParent:self];
}

- (void)removeChild:(XCProjectRenameItem *)child
{
	if (_children == nil)
		return;
	[_children removeObject:child];
	if ([child parent] == self)
		[child setParent:nil];
}

- (void)addBuildConfiguration:(id)configuration
{
	if (_buildConfigurations == nil)
		_buildConfigurations = [NSMutableArray array];
	[_buildConfigurations addObject:configuration];
}

- (void)addBuildConfigurations:(NSArray *)configurations
{
	if (configurations == nil)
		return;
	if (_buildConfigurations == nil)
		_buildConfigurations = [NSMutableArray array];
	[_buildConfigurations addObjectsFromArray:configurations];
}

- (void)updateProposedNameWith:(NSString *)proposed
    fromName:(NSString *)fromName
{
	if (proposed == nil || fromName == nil)
		[NSException raise:NSInvalidArgumentException
		    format:@"nil proposed name or source name"];
	_proposedName = [_currentName stringByReplacingOccurrencesOfString:fromName
	    withString:proposed];
}

- (void)cancel
{
}

- (void)rename
{
}

- (void)validate
{
}

- (XCProjectRenameItem *)parent
{
	return (_parent);
}

- (void)setParent:(XCProjectRenameItem *)parent
{
	_parent = parent;
}

- (id)representedObject
{
	return (_representedObject);
}

- (void)setRepresentedObject:(id)object
{
	_representedObject = object;
}

- (id<IDEXcode3ProjectItemRenaming>)renamer
{
	return (_renamer);
}

- (void)setRenamer:(id<IDEXcode3ProjectItemRenaming>)renamer
{
	_renamer = renamer;
}

- (id<IDERenameableXcode3ProjectItem>)renameableItem
{
	return (_renameableItem);
}

- (void)setRenameableItem:(id<IDERenameableXcode3ProjectItem>)item
{
	_renameableItem = item;
}

- (PBXProject *)project
{
	return (_project);
}

- (void)setProject:(PBXProject *)project
{
	_project = project;
}

- (PBXTarget *)target
{
	return (_target);
}

- (void)setTarget:(PBXTarget *)target
{
	_target = target;
}

- (NSString *)type
{
	return (_type);
}

- (void)setType:(NSString *)type
{
	_type = [type copy];
}

- (DVTFileDataType *)fileDataType
{
	return (_fileDataType);
}

- (void)setFileDataType:(DVTFileDataType *)type
{
	_fileDataType = type;
}

- (NSString *)currentName
{
	return (_currentName);
}

- (void)setCurrentName:(NSString *)name
{
	_currentName = [name copy];
}

- (NSString *)proposedName
{
	return (_proposedName);
}

- (NSAttributedString *)attributedCurrentName
{
	return (_attributedCurrentName);
}

- (void)setAttributedCurrentName:(NSAttributedString *)name
{
	_attributedCurrentName = [name copy];
}

- (NSAttributedString *)attributedProposedName
{
	return (_attributedProposedName);
}

- (void)setAttributedProposedName:(NSAttributedString *)name
{
	_attributedProposedName = [name copy];
}

- (NSImage *)image
{
	return (_image);
}

- (void)setImage:(NSImage *)image
{
	_image = image;
}

- (NSArray *)children
{
	return (_children);
}

- (void)setChildren:(NSArray *)children
{
	_children = (NSMutableArray *)children;
}

- (NSError *)error
{
	return (_error);
}

- (void)setError:(NSError *)error
{
	_error = error;
}

- (BOOL)enabled
{
	return (_enabled);
}

- (void)setEnabled:(BOOL)enabled
{
	_enabled = enabled;
}

- (BOOL)shouldRename
{
	return (_shouldRename);
}

- (void)setShouldRename:(BOOL)rename
{
	_shouldRename = rename;
}

- (NSArray *)buildConfigurations
{
	return (_buildConfigurations);
}

- (void)setBuildConfigurations:(NSArray *)configurations
{
	_buildConfigurations = (NSMutableArray *)configurations;
}

- (DVTRangeArray *)currentNameMatchRange
{
	return (_currentNameMatchRange);
}

- (void)setCurrentNameMatchRange:(DVTRangeArray *)range
{
	_currentNameMatchRange = range;
}

- (DVTRangeArray *)proposedNameMatchRange
{
	return (_proposedNameMatchRange);
}

- (void)setProposedNameMatchRange:(DVTRangeArray *)range
{
	_proposedNameMatchRange = range;
}

@end

@implementation XCProjectRenameFileItem

- (void)rename
{
}

- (void)renamedFileAtPath:(NSString *)path to:(NSString *)newPath
    error:(NSError **)error
{
	(void)path;
	(void)newPath;
	(void)error;
}

- (void)validate
{
}

@end

@implementation XCProjectRenameXibItem

- (void)rename
{
}

@end

@implementation XCProjectRenamePCHItem

- (void)updateProposedNameWith:(NSString *)proposed fromName:(NSString *)fromName
{
	[super updateProposedNameWith:proposed fromName:fromName];
}

- (void)rename
{
}

- (void)renamedFileAtPath:(NSString *)path to:(NSString *)newPath
    error:(NSError **)error
{
	(void)path;
	(void)newPath;
	(void)error;
}

- (void)validate
{
}

@end

@implementation XCProjectRenameInfoPlistContentsItem

- (NSString *)_alterReverseDNSString:(NSString *)string
    byReplacingCurrentValue:(NSString *)current withNewValue:(NSString *)replacement
{
	(void)current;
	(void)replacement;
	return (string);
}

- (void)rename
{
}

@end

@implementation XCProjectRenameInfoPlistItem

- (void)rename
{
}

- (void)renamedFileAtPath:(NSString *)path to:(NSString *)newPath
    error:(NSError **)error
{
	(void)path;
	(void)newPath;
	(void)error;
}

- (void)validate
{
}

@end

@implementation XCProjectRenameProductItem

- (void)rename
{
}

@end

@implementation XCProjectRenameBuildSettingItem

- (void)rename
{
}

- (NSString *)settingName
{
	return (_settingName);
}

- (void)setSettingName:(NSString *)name
{
	_settingName = [name copy];
}

@end

@implementation XCProjectRenameTargetItem

- (void)rename
{
}

- (NSArray *)products
{
	return (nil);
}

- (NSArray *)prefixFiles
{
	return (nil);
}

@end

@implementation XCProjectRenameProjectItem

- (void)rename
{
}

- (void)validate
{
}

@end
