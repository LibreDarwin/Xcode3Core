/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Container classes and PBXProject (DevToolsCore). */

#import "DevToolsCore/PBXProject.h"
#import "DevToolsCore/PBXGroupEnumerator.h"
#import "DevToolsCore/PBXProjectModel.h"
#import "DevToolsCore/PBXReference.h"
#import "DevToolsCore/PBXTarget.h"
#import "DevToolsCore/XCBuildConfiguration.h"
#import "DevToolsCore/BuildSystem/XCSpecificationFilter.h"
#import "DevToolsCore/PBXFileType.h"

@interface PBXProject ()
- (void)_setAttribute:(id)value forKey:(NSString *)key;
@end

static NSMapTable *sResolvedPathToContainer = nil;

@implementation PBXContainer

+ (PBXContainer *)containerForResolvedAbsolutePath:(NSString *)path
{
	if (path == nil)
		return (nil);
	return ([sResolvedPathToContainer objectForKey:path]);
}

+ (void)setContainer:(PBXContainer *)container
    forResolvedAbsolutePath:(NSString *)path
{
	if (path == nil)
		return;
	if (sResolvedPathToContainer == nil)
		sResolvedPathToContainer = [NSMapTable strongToWeakObjectsMapTable];
	if (container != nil)
		[sResolvedPathToContainer setObject:container forKey:path];
	else
		[sResolvedPathToContainer removeObjectForKey:path];
}

+ (void)removeContainerForResolvedAbsolutePath:(NSString *)path
{
	if (path != nil && sResolvedPathToContainer != nil)
		[sResolvedPathToContainer removeObjectForKey:path];
}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		_uniqueIDsToContainerItems = [NSMapTable strongToStrongObjectsMapTable];
		_basePath = [[[NSFileManager defaultManager] currentDirectoryPath] copy];
	}
	return (self);
}

- (void)dealloc
{
	NSString *resolved = _resolvedAbsolutePath;

	if (resolved != nil) {
		PBXContainer *registered =
		    [[self class] containerForResolvedAbsolutePath:resolved];

		if (registered == self)
			[[self class] removeContainerForResolvedAbsolutePath:resolved];
	}
}

- (PBXGroup *)rootGroup
{
	return (_rootGroup);
}

- (void)setRootGroup:(PBXGroup *)group
{
	[self _setRootGroup:group];
}

- (void)_setRootGroup:(PBXGroup *)group
{
	_rootGroup = group;
}

- (NSArray *)comments
{
	return (_comments);
}

- (void)setComments:(NSArray *)comments
{
	_comments = comments;
}

- (NSString *)path
{
	return (_path);
}

- (void)setPath:(NSString *)path
{
	NSString *oldResolved = _resolvedAbsolutePath;

	if (oldResolved != nil &&
	    [[self class] containerForResolvedAbsolutePath:oldResolved] == self)
		[[self class] removeContainerForResolvedAbsolutePath:oldResolved];
	_path = [path copy];
	_resolvedAbsolutePath = nil;
}

- (NSString *)name
{
	if (_path == nil)
		return (nil);
	return ([_path lastPathComponent]);
}

- (NSString *)basePath
{
	return (_basePath);
}

- (void)setBasePath:(NSString *)path
{
	_basePath = [path copy];
	_resolvedAbsolutePath = nil;
}

- (NSString *)absolutePath
{
	if (_path == nil)
		return (nil);
	if ([_path isAbsolutePath])
		return (_path);
	if (_basePath == nil)
		return ([_path stringByStandardizingPath]);
	return ([[_basePath stringByAppendingPathComponent:_path]
	    stringByStandardizingPath]);
}

- (NSString *)resolvedAbsolutePath
{
	if (_resolvedAbsolutePath == nil) {
		NSString *absolute = [self absolutePath];

		if (absolute != nil) {
			_resolvedAbsolutePath =
			    [[absolute stringByResolvingSymlinksInPath] copy];
			[[self class] setContainer:self
			    forResolvedAbsolutePath:_resolvedAbsolutePath];
		}
	}
	return (_resolvedAbsolutePath);
}

- (void)invalidateAbsolutePathCache
{
	NSString *resolved = _resolvedAbsolutePath;

	if (resolved != nil &&
	    [[self class] containerForResolvedAbsolutePath:resolved] == self)
		[[self class] removeContainerForResolvedAbsolutePath:resolved];
	_resolvedAbsolutePath = nil;
	if (_rootGroup != nil)
		[_rootGroup setContainer:nil];
}

- (NSString *)stringByExpandingString:(NSString *)string
{
	return (string);
}

- (void)close
{
	[self invalidateAbsolutePathCache];
}

- (NSArray *)children
{
	return ([_rootGroup children]);
}

- (NSArray *)references
{
	NSMutableArray *references = [NSMutableArray array];
	PBXGroup *rootGroup = [self rootGroup];

	if (rootGroup != nil) {
		[rootGroup enumerateDescendantReferencesUsingBlock:
		    ^BOOL(PBXReference *reference) {
			[references addObject:reference];
			return (YES);
		}];
	}
	return (references);
}

- (void)addReference:(PBXReference *)reference
{
	if (reference == nil)
		return;
	if (_rootGroup == nil)
		_rootGroup = [PBXGroup groupWithName:[self name]];
	[_rootGroup addChild:reference];
	[self addItem:reference];
}

- (void)removeReference:(PBXReference *)reference
{
	if (reference == nil)
		return;
	[reference removeFromGroup];
	[self removeItem:reference];
}

- (void)addItem:(PBXObject *)item
{
	NSString *objectID;

	if (item == nil)
		return;
	objectID = [item objectID];
	if (objectID != nil)
		[_uniqueIDsToContainerItems setObject:item forKey:objectID];
	[item setContainer:self];
}

- (void)removeItem:(PBXObject *)item
{
	NSString *objectID;

	if (item == nil)
		return;
	objectID = [item objectID];
	if (objectID != nil &&
	    [_uniqueIDsToContainerItems objectForKey:objectID] == item)
		[_uniqueIDsToContainerItems removeObjectForKey:objectID];
	if ([item container] == self)
		[item setContainer:nil];
}

- (PBXObject *)itemForGlobalID:(NSString *)globalID
{
	PBXObject *item;

	if (globalID == nil)
		return (nil);
	item = [_uniqueIDsToContainerItems objectForKey:globalID];
	if (item != nil)
		return (item);
	item = [[self projectModel] objectForID:globalID];
	if (item != nil && [item container] == self)
		return (item);
	return (nil);
}

- (PBXObject *)itemForGlobalIDHexString:(NSString *)string
{
	return ([self itemForGlobalID:string]);
}

- (PBXReference *)referenceForPath:(NSString *)path
{
	PBXReference *reference;

	if (path == nil)
		return (nil);
	for (reference in [self references]) {
		NSString *referencePath = [reference path];

		if (referencePath == nil)
			continue;
		if ([referencePath isEqualToString:path])
			return (reference);
		if ([[reference absolutePath] isEqualToString:path])
			return (reference);
	}
	return (nil);
}

- (PBXFileReference *)fileReferenceForPath:(NSString *)path
{
	PBXReference *reference = [self referenceForPath:path];

	if ([reference isKindOfClass:[PBXFileReference class]])
		return ((PBXFileReference *)reference);
	return (nil);
}

- (BOOL)enumerateReferencesUsingBlock:(BOOL (^)(PBXReference *reference))block
{
	PBXGroup *rootGroup = [self rootGroup];

	if (rootGroup == nil)
		return (YES);
	return ([rootGroup enumerateDescendantReferencesUsingBlock:block]);
}

- (PBXGroupEnumerator *)groupEnumerator
{
	PBXGroup *rootGroup = [self rootGroup];

	if (_groupEnumerator == nil && rootGroup != nil)
		_groupEnumerator = [PBXGroupEnumerator enumeratorForGroup:rootGroup];
	return (_groupEnumerator);
}

- (void)_clearGroupEnumerator
{
	_groupEnumerator = nil;
}

- (BOOL)isReadOnly
{
	return (NO);
}

- (BOOL)allowsEditingOfChildren
{
	return (YES);
}

- (BOOL)validateValueForRootGroup:(PBXGroup *)group error:(NSError **)error
{
	if (group != nil && ![group isKindOfClass:[PBXGroup class]]) {
		if (error != NULL)
			*error = [NSError errorWithDomain:NSCocoaErrorDomain
			    code:1680 userInfo:nil];
		return (NO);
	}
	return (YES);
}

@end

@implementation PBXContainerItem
@end

@implementation PBXProjectItem
@end

@implementation PBXProductDependency
@end

@implementation XCRemoteSwiftPackageReference

+ (NSArray *)archivableAttributes
{
	return (@[@"repositoryURL", @"requirement"]);
}

- (NSString *)repositoryURL
{
	return (_repositoryURL);
}

- (void)setRepositoryURL:(NSString *)url
{
	_repositoryURL = [url copy];
}

- (NSMutableDictionary *)requirement
{
	return (_requirement);
}

- (void)setRequirement:(NSDictionary *)requirement
{
	_requirement = (requirement != nil) ? [requirement mutableCopy] : nil;
}

@end

@implementation XCLocalSwiftPackageReference

+ (NSArray *)archivableAttributes
{
	return (@[@"relativePath"]);
}

- (NSString *)relativePath
{
	return (_relativePath);
}

- (void)setRelativePath:(NSString *)path
{
	_relativePath = [path copy];
}

@end

@implementation XCSwiftPackageProductDependency

+ (NSArray *)archivableAttributes
{
	return (@[@"productName"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"package"]);
}

- (NSString *)productName
{
	return (_productName);
}

- (void)setProductName:(NSString *)name
{
	_productName = [name copy];
}

- (XCRemoteSwiftPackageReference *)package
{
	return (_package);
}

- (void)setPackage:(XCRemoteSwiftPackageReference *)package
{
	_package = package;
}

@end

@implementation PBXProject

+ (NSString *)classNameForPListArchive
{
	return (@"PBXProject");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"attributes", @"buildIndependentTargetsInParallel",
	    @"compatibilityVersion", @"developmentRegion",
	    @"hasScannedForEncodings", @"knownRegions",
	    @"minimizedProjectReferenceProxies", @"preferredProjectObjectVersion",
	    @"projectDirPath", @"projectRoot", @"userBuildSettings"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"buildConfigurationList", @"mainGroup", @"packageReferences",
	    @"productRefGroup", @"projectReferences", @"targets"]);
}

- (NSString *)archiveComment
{
	return (@"Project object");
}

- (NSMutableDictionary *)attributes
{
	return (_attributes);
}

- (void)setAttributes:(NSDictionary *)attributes
{
	_attributes = (attributes != nil) ?
	    [attributes mutableCopy] : nil;
}

- (NSNumber *)buildIndependentTargetsInParallel
{
	return (_buildIndependentTargetsInParallel);
}

- (void)setBuildIndependentTargetsInParallel:(NSNumber *)flag
{
	_buildIndependentTargetsInParallel = flag;
}

- (NSArray *)targets
{
	return (_targets);
}

- (void)setTargets:(NSArray *)targets
{
	_targets = (targets != nil) ? [targets mutableCopy] : nil;
}

- (NSArray *)knownRegions
{
	return (_knownRegions);
}

- (void)setKnownRegions:(NSArray *)regions
{
	_knownRegions = (regions != nil) ? [regions mutableCopy] : nil;
}

- (PBXGroup *)mainGroup
{
	return (_mainGroup);
}

- (void)setMainGroup:(PBXGroup *)group
{
	_mainGroup = group;
}

- (PBXGroup *)productRefGroup
{
	return (_productRefGroup);
}

- (void)setProductRefGroup:(PBXGroup *)group
{
	_productRefGroup = group;
}

- (XCConfigurationList *)buildConfigurationList
{
	return (_buildConfigurationList);
}

- (void)setBuildConfigurationList:(XCConfigurationList *)list
{
	_buildConfigurationList = list;
}

- (NSString *)compatibilityVersion
{
	return (_compatibilityVersion);
}

- (void)setCompatibilityVersion:(NSString *)version
{
	_compatibilityVersion = [version copy];
}

- (NSString *)developmentRegion
{
	return (_developmentRegion);
}

- (void)setDevelopmentRegion:(NSString *)region
{
	_developmentRegion = [region copy];
}

- (NSString *)projectDirPath
{
	return (_projectDirPath);
}

- (void)setProjectDirPath:(NSString *)path
{
	_projectDirPath = [path copy];
}

- (NSString *)projectRoot
{
	return (_projectRoot);
}

- (void)setProjectRoot:(NSString *)root
{
	_projectRoot = [root copy];
}

- (NSNumber *)hasScannedForEncodings
{
	return (_hasScannedForEncodings);
}

- (void)setHasScannedForEncodings:(NSNumber *)flag
{
	_hasScannedForEncodings = flag;
}

- (NSNumber *)minimizedProjectReferenceProxies
{
	return (_minimizedProjectReferenceProxies);
}

- (void)setMinimizedProjectReferenceProxies:(NSNumber *)flag
{
	_minimizedProjectReferenceProxies = flag;
}

- (NSNumber *)preferredProjectObjectVersion
{
	return (_preferredProjectObjectVersion);
}

- (void)setPreferredProjectObjectVersion:(NSNumber *)version
{
	_preferredProjectObjectVersion = version;
}

- (NSArray *)packageReferences
{
	return (_packageReferences);
}

- (void)setPackageReferences:(NSArray *)refs
{
	_packageReferences = (refs != nil) ? [refs mutableCopy] : nil;
}

- (NSArray *)projectReferences
{
	return (_projectReferences);
}

- (void)setProjectReferences:(NSArray *)refs
{
	_projectReferences = (refs != nil) ? [refs mutableCopy] : nil;
}

- (NSMutableDictionary *)userBuildSettings
{
	return (_userBuildSettings);
}

- (void)setUserBuildSettings:(NSDictionary *)settings
{
	_userBuildSettings = (settings != nil) ?
	    [settings mutableCopy] : nil;
}

+ (NSArray *)defaultKnownRegions
{
	return (@[@"en", @"Base"]);
}

+ (NSArray *)defaultKnownPlatforms
{
	return (@[@"macosx", @"iphoneos", @"iphonesimulator"]);
}

+ (NSString *)projectWrapperExtension
{
	return (@"xcodeproj");
}

+ (BOOL)isProjectWrapperExtension:(NSString *)extension
{
	return ([extension caseInsensitiveCompare:@"xcodeproj"] ==
	    NSOrderedSame);
}

+ (NSArray *)knownProjectWrapperExtensions
{
	return (@[@"xcodeproj"]);
}

#pragma mark File types

/*
 * The five class methods below build (once) the specification filters that
 * describe which file types each kind of build phase accepts.  They are
 * cached in static variables, exactly like Apple's implementation.
 *
 * Deviation: Apple assumes the file-type specifications have already been
 * loaded, so it passes every looked-up specification straight to the filter.
 * A standalone tool may run without any .xcspec files, so a lookup that
 * yields nil is skipped instead of raising.
 */

static void AddIncluded(XCSpecificationFilter *filter, NSString *identifier)
{
	XCSpecification *specification =
	    [PBXFileType specificationForIdentifier:identifier];

	if (specification != nil)
		[filter addIncludedSpecification:specification];
}

static void AddExcluded(XCSpecificationFilter *filter, NSString *identifier)
{
	XCSpecification *specification =
	    [PBXFileType specificationForIdentifier:identifier];

	if (specification != nil)
		[filter addExcludedSpecification:specification];
}

+ (id)headerFileTypes
{
	static XCSpecificationFilter *headerFileTypes = nil;

	if (headerFileTypes == nil) {
		headerFileTypes = [[XCSpecificationFilter alloc]
		    initWithSpecificationClass:[PBXFileType class]];
		AddIncluded(headerFileTypes, @"sourcecode.c.h");
		AddIncluded(headerFileTypes, @"sourcecode.cpp.h");
		AddIncluded(headerFileTypes, @"text.apinotes");
	}
	return (headerFileTypes);
}

+ (id)sourceFileTypes
{
	static XCSpecificationFilter *sourceFileTypes = nil;

	if (sourceFileTypes == nil) {
		sourceFileTypes = [[XCSpecificationFilter alloc]
		    initWithSpecificationClass:[PBXFileType class]];
		AddIncluded(sourceFileTypes, @"sourcecode");
		AddIncluded(sourceFileTypes, @"text.xml.ibArchivingDescription");
		AddIncluded(sourceFileTypes, @"text.xml.ibCodingDescription");
		AddIncluded(sourceFileTypes, @"folder.mlpackage");
		AddIncluded(sourceFileTypes, @"folder.documentationcatalog");
		AddIncluded(sourceFileTypes, @"file.referenceobject");
		AddIncluded(sourceFileTypes, @"folder.fmadapter");
		[sourceFileTypes addExcludedSpecificationComposition:[self headerFileTypes]];
		[sourceFileTypes addExcludedSpecificationComposition:[self rezzableFileTypes]];
		AddExcluded(sourceFileTypes, @"sourcecode.scpt");
		AddExcluded(sourceFileTypes, @"sourcecode.glsl");
		AddExcluded(sourceFileTypes, @"sourcecode.javascript");
		AddExcluded(sourceFileTypes, @"sourcecode.typescript");
		AddExcluded(sourceFileTypes, @"net.daringfireball.markdown");
		AddExcluded(sourceFileTypes, @"sourcecode.module-map");
		AddExcluded(sourceFileTypes, @"sourcecode.text-based-dylib-definition");
	}
	return (sourceFileTypes);
}

+ (id)rezzableFileTypes
{
	static XCSpecificationFilter *rezzableFileTypes = nil;

	if (rezzableFileTypes == nil) {
		rezzableFileTypes = [[XCSpecificationFilter alloc]
		    initWithSpecificationClass:[PBXFileType class]];
		AddIncluded(rezzableFileTypes, @"sourcecode.rez");
		AddIncluded(rezzableFileTypes, @"archive.rsrc");
	}
	return (rezzableFileTypes);
}

+ (id)linkableFileTypes
{
	static XCSpecificationFilter *linkableFileTypes = nil;

	if (linkableFileTypes == nil) {
		linkableFileTypes = [[XCSpecificationFilter alloc]
		    initWithSpecificationClass:[PBXFileType class]];
		AddIncluded(linkableFileTypes, @"wrapper.framework");
		AddIncluded(linkableFileTypes, @"wrapper.xcframework");
		AddIncluded(linkableFileTypes, @"archive.ar");
		AddIncluded(linkableFileTypes, @"compiled.mach-o.dylib");
		AddIncluded(linkableFileTypes, @"compiled.mach-o.objfile");
		AddIncluded(linkableFileTypes, @"sourcecode.text-based-dylib-definition");
		AddIncluded(linkableFileTypes, @"archive.jar");
		AddIncluded(linkableFileTypes, @"archive.war");
		AddIncluded(linkableFileTypes, @"archive.ear");
	}
	return (linkableFileTypes);
}

+ (id)appleScriptFileTypes
{
	static XCSpecificationFilter *appleScriptFileTypes = nil;

	if (appleScriptFileTypes == nil) {
		appleScriptFileTypes = [[XCSpecificationFilter alloc]
		    initWithSpecificationClass:[PBXFileType class]];
		AddIncluded(appleScriptFileTypes, @"sourcecode.applescript");
		AddIncluded(appleScriptFileTypes, @"sourcecode.scpt");
	}
	return (appleScriptFileTypes);
}

+ (NSString *)projectFilePathWithPath:(NSString *)path
    hasArchivingDelegate:(BOOL)delegate
{
	return ([path stringByAppendingPathComponent:@"project.pbxproj"]);
}

- (void)_setAttribute:(id)value forKey:(NSString *)key
{
	if (key == nil)
		return;
	if (_attributes == nil)
		_attributes = [[NSMutableDictionary alloc] init];
	if (value != nil)
		[_attributes setObject:value forKey:key];
	else
		[_attributes removeObjectForKey:key];
}

- (NSString *)name
{
	if (_path != nil)
		return ([[_path lastPathComponent]
		    stringByDeletingPathExtension]);
	if ([_projectDirPath length] > 0)
		return ([_projectDirPath lastPathComponent]);
	return (nil);
}

- (NSString *)path
{
	return (_path);
}

- (void)setPath:(NSString *)path
{
	[super setPath:path];
}

- (NSString *)projectDirectory
{
	return (_path != nil ? [_path stringByDeletingLastPathComponent] :
	    nil);
}

- (NSString *)lastUpgradeCheck
{
	return ([_attributes objectForKey:@"LastUpgradeCheck"]);
}

- (void)setLastUpgradeCheck:(NSString *)check
{
	[self _setAttribute:check forKey:@"LastUpgradeCheck"];
}

- (NSString *)organizationName
{
	return ([_attributes objectForKey:@"ORGANIZATIONNAME"]);
}

- (void)setOrganizationName:(NSString *)name
{
	[self _setAttribute:name forKey:@"ORGANIZATIONNAME"];
}

- (NSString *)classPrefix
{
	return ([_attributes objectForKey:@"CLASSPREFIX"]);
}

- (void)setClassPrefix:(NSString *)prefix
{
	[self _setAttribute:prefix forKey:@"CLASSPREFIX"];
}

- (NSArray *)knownAssetTags
{
	return ([_attributes objectForKey:@"KnownAssetTags"]);
}

- (void)addKnownAssetTag:(NSString *)tag
{
	NSMutableArray *tags;

	if (tag == nil)
		return;
	tags = [[self knownAssetTags] mutableCopy];
	if (tags == nil)
		tags = [[NSMutableArray alloc] init];
	if (![tags containsObject:tag])
		[tags addObject:tag];
	[self _setAttribute:tags forKey:@"KnownAssetTags"];
}

- (void)removeKnownAssetTag:(NSString *)tag
{
	NSMutableArray *tags;

	if (tag == nil)
		return;
	tags = [[self knownAssetTags] mutableCopy];
	if (tags == nil)
		return;
	[tags removeObject:tag];
	[self _setAttribute:tags forKey:@"KnownAssetTags"];
}

- (PBXTarget *)targetNamed:(NSString *)name
{
	PBXTarget *target;

	if (name == nil)
		return (nil);
	for (target in _targets) {
		if ([target isKindOfClass:[PBXTarget class]] &&
		    [[target name] isEqualToString:name])
			return (target);
	}
	return (nil);
}

- (PBXTarget *)targetWithGlobalID:(NSString *)identifier
{
	id object;

	if (identifier == nil)
		return (nil);
	object = [[self projectModel] objectForID:identifier];
	if ([object isKindOfClass:[PBXTarget class]])
		return (object);
	return (nil);
}

- (void)insertTargets:(NSArray *)targets atIndex:(NSUInteger)index
{
	PBXTarget *target;

	if (_targets == nil)
		_targets = [[NSMutableArray alloc] init];
	if (index > [_targets count])
		index = [_targets count];
	for (target in targets) {
		if (![target isKindOfClass:[PBXTarget class]])
			continue;
		[_targets insertObject:target atIndex:index++];
	}
}

- (void)addTarget:(PBXTarget *)target
{
	if (target == nil)
		return;
	if (_targets == nil)
		_targets = [[NSMutableArray alloc] init];
	[_targets addObject:target];
}

- (void)removeTarget:(PBXTarget *)target
{
	if (target == nil || _targets == nil)
		return;
	[_targets removeObject:target];
}

static void VisitTarget(PBXTarget *target, NSMutableSet *visited,
    NSMutableArray *order, NSSet *targetSet)
{
	PBXTargetDependency *dependency;

	if ([visited containsObject:target])
		return;
	[visited addObject:target];
	for (dependency in [target dependencies]) {
		PBXTarget *depTarget = [dependency target];

		if (depTarget != nil && [targetSet containsObject:depTarget])
			VisitTarget(depTarget, visited, order, targetSet);
	}
	[order addObject:target];
}

- (NSArray *)allTargetsInDependencyOrder
{
	NSMutableArray *order = [NSMutableArray array];
	NSMutableSet *visited = [NSMutableSet set];
	NSSet *targetSet = [NSSet setWithArray:_targets ?: @[]];
	PBXTarget *target;

	for (target in _targets) {
		if ([target isKindOfClass:[PBXTarget class]])
			VisitTarget(target, visited, order, targetSet);
	}
	return (order);
}

- (void)addRegion:(NSString *)region
{
	if (region == nil)
		return;
	if (_knownRegions == nil)
		_knownRegions = [[NSMutableArray alloc] init];
	if (![_knownRegions containsObject:region])
		[_knownRegions addObject:region];
}

- (void)removeRegion:(NSString *)region
{
	if (region == nil)
		return;
	[_knownRegions removeObject:region];
}

- (NSArray *)knownPlatforms
{
	return (_knownPlatforms);
}

- (void)addPlatform:(NSString *)platform
{
	if (platform == nil)
		return;
	if (_knownPlatforms == nil)
		_knownPlatforms = [[NSMutableArray alloc] init];
	if (![_knownPlatforms containsObject:platform])
		[_knownPlatforms addObject:platform];
}

- (PBXGroup *)productReferenceGroup
{
	return (_productRefGroup);
}

- (void)setProductReferenceGroup:(PBXGroup *)group
{
	_productRefGroup = group;
}

- (BOOL)shouldArchiveDevelopmentRegion
{
	return (YES);
}

- (BOOL)shouldArchiveKnownRegions
{
	return (YES);
}

- (BOOL)shouldArchiveKnownPlatforms
{
	return (NO);
}

- (BOOL)shouldArchiveAttributes
{
	return (YES);
}

- (void)addTopLevelItem:(PBXObject *)item
{
	if (item == nil)
		return;
	if ([_mainGroup respondsToSelector:@selector(addItem:)])
		[_mainGroup performSelector:@selector(addItem:) withObject:item];
}

- (NSUInteger)preferredInsertionIndexForAppendingTopLevelItems
{
	if ([_mainGroup respondsToSelector:@selector(itemCount)])
		return ([_mainGroup itemCount]);
	return (0);
}

- (void)addProjectReference:(PBXReference *)reference
{
	if (reference == nil)
		return;
	if (_projectReferences == nil)
		_projectReferences = [[NSMutableArray alloc] init];
	if (![_projectReferences containsObject:reference])
		[_projectReferences addObject:reference];
}

- (void)removeProjectReference:(PBXReference *)reference
{
	if (reference == nil)
		return;
	[_projectReferences removeObject:reference];
}

- (void)insertPackageReferences:(NSArray *)references atIndex:(NSUInteger)index
{
	PBXReference *reference;

	if (_packageReferences == nil)
		_packageReferences = [[NSMutableArray alloc] init];
	if (index > [_packageReferences count])
		index = [_packageReferences count];
	for (reference in references) {
		[_packageReferences insertObject:reference atIndex:index++];
	}
}

- (void)addPackageReference:(PBXReference *)reference
{
	if (reference == nil)
		return;
	if (_packageReferences == nil)
		_packageReferences = [[NSMutableArray alloc] init];
	[_packageReferences addObject:reference];
}

- (void)removePackageReference:(PBXReference *)reference
{
	if (reference == nil)
		return;
	[_packageReferences removeObject:reference];
}

- (NSString *)defaultConfigurationName
{
	return ([_buildConfigurationList defaultConfigurationName]);
}

- (void)setDefaultConfigurationName:(NSString *)name
{
	[_buildConfigurationList setDefaultConfigurationName:name];
}

@end
