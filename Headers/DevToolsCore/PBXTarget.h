/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Target and proxy/dependency classes (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXTARGET_H
#define DEVTOOLSCORE_PBXTARGET_H

#import "DevToolsCore/PBXBuild.h"
#import "DevToolsCore/XCBuildConfiguration.h"

@class PBXProject, PBXFileReference;

/* A proxy for an object in another container (used by cross-project deps). */
@interface PBXContainerItemProxy : PBXProjectItem
{
	PBXContainer *_containerPortal;
	NSString *_proxyType;
	NSString *_remoteGlobalIDString;
	NSString *_remoteInfo;
}
- (PBXContainer *)containerPortal;
- (void)setContainerPortal:(PBXContainer *)container;
- (NSString *)proxyType;
- (void)setProxyType:(NSString *)type;
- (NSString *)remoteGlobalIDString;
- (void)setRemoteGlobalIDString:(NSString *)identifier;
- (NSString *)remoteInfo;
- (void)setRemoteInfo:(NSString *)info;
@end

/* A dependency of one target on another. */
@interface PBXTargetDependency : PBXProjectItem
{
	PBXTarget *_target;
	PBXContainerItemProxy *_targetProxy;
	NSString *_name;
}
- (PBXTarget *)target;
- (void)setTarget:(PBXTarget *)target;
- (PBXContainerItemProxy *)targetProxy;
- (void)setTargetProxy:(PBXContainerItemProxy *)proxy;
- (NSString *)name;
- (void)setName:(NSString *)name;
@end

/* Base class for the buildable targets of a project. */
@interface PBXTarget : PBXProjectItem
{
	NSString *_name;
	NSString *_productName;
	NSString *_productInstallPath;
	NSString *_productType;
	NSString *_buildArgumentsString;
	NSString *_buildToolPath;
	NSString *_buildWorkingDirectory;
	NSNumber *_passBuildSettingsInEnvironment;
	PBXFileReference *_productReference;
	PBXReference *_productReferenceProxy;
	XCConfigurationList *_buildConfigurationList;
	NSMutableArray *_buildPhases;
	NSMutableArray *_buildRules;
	NSMutableArray *_dependencies;
	NSMutableArray *_packageProductDependencies;
	NSMutableArray *_fileSystemSynchronizedGroups;
}
- (NSString *)name;
- (void)setName:(NSString *)name;
- (NSString *)productName;
- (void)setProductName:(NSString *)name;
- (NSString *)productType;
- (void)setProductType:(NSString *)type;
- (PBXFileReference *)productReference;
- (void)setProductReference:(PBXFileReference *)reference;
- (XCConfigurationList *)buildConfigurationList;
- (void)setBuildConfigurationList:(XCConfigurationList *)list;
- (NSArray *)buildPhases;
- (void)setBuildPhases:(NSArray *)phases;
- (NSArray *)dependencies;
- (void)setDependencies:(NSArray *)dependencies;
- (NSArray *)buildRules;
- (void)setBuildRules:(NSArray *)rules;
- (NSString *)displayName;
@end

@interface PBXNativeTarget : PBXTarget @end

@interface PBXAggregateTarget : PBXTarget @end

@interface PBXLegacyTarget : PBXTarget
@end

/*
 * Project Builder era concrete target kinds.  They are retained (as thin
 * subclasses) so that isa names from older archives round-trip unchanged.
 */
@interface PBXJambaseTarget : PBXTarget @end

@interface PBXWrappedTarget : PBXJambaseTarget @end

@interface PBXApplicationTarget : PBXWrappedTarget @end

@interface PBXFrameworkTarget : PBXWrappedTarget @end

@interface PBXBundleTarget : PBXWrappedTarget @end

@interface PBXLibraryTarget : PBXJambaseTarget @end

@interface PBXToolTarget : PBXJambaseTarget @end

#endif	/* DEVTOOLSCORE_PBXTARGET_H */

@interface PBXStandaloneTarget : PBXJambaseTarget @end
@interface PBXExternalTarget : PBXTarget @end
