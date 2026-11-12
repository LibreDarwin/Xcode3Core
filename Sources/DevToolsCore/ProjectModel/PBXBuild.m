/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Build-file, build-phase and build-rule classes (DevToolsCore). */

#import "DevToolsCore/PBXBuild.h"
#import "DevToolsCore/PBXFileType.h"
#import "DevToolsCore/PBXProject.h"
#import "DevToolsCore/BuildSystem/XCSpecificationFilter.h"

@implementation PBXBuildFile

+ (NSString *)classNameForPListArchive
{
	return (@"PBXBuildFile");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"settings", @"platformFilter", @"platformFilters",
	    @"assetTags"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"fileRef", @"productRef"]);
}

- (PBXFileReference *)fileRef
{
	return (_fileRef);
}

- (void)setFileRef:(PBXFileReference *)reference
{
	_fileRef = reference;
}

- (PBXReference *)productRef
{
	return (_productRef);
}

- (void)setProductRef:(PBXReference *)reference
{
	_productRef = reference;
}

- (NSMutableDictionary *)settings
{
	return (_settings);
}

- (void)setSettings:(NSDictionary *)settings
{
	_settings = (settings != nil) ? [settings mutableCopy] : nil;
}

- (NSArray *)assetTags
{
	return (_assetTags);
}

- (void)setAssetTags:(NSArray *)tags
{
	_assetTags = (tags != nil) ? [tags mutableCopy] : nil;
}

- (NSSet *)attributes
{
	id raw = [_settings objectForKey:@"ATTRIBUTES"];

	if (raw == nil)
		return ([NSSet set]);
	if ([raw isKindOfClass:[NSArray class]])
		return ([NSSet setWithArray:raw]);
	if ([raw isKindOfClass:[NSSet class]])
		return (raw);
	if ([raw isKindOfClass:[NSString class]]) {
		NSMutableSet *set = [NSMutableSet set];
		NSArray *parts = [raw componentsSeparatedByString:@","];
		NSString *part;

		for (part in parts) {
			NSString *trimmed = [part
			    stringByTrimmingCharactersInSet:
			    [NSCharacterSet whitespaceCharacterSet]];
			if ([trimmed length] > 0)
				[set addObject:trimmed];
		}
		return (set);
	}
	return ([NSSet set]);
}

- (void)setAttributes:(NSSet *)attributes
{
	if (_settings == nil)
		_settings = [[NSMutableDictionary alloc] init];
	if ([attributes count] == 0) {
		[_settings removeObjectForKey:@"ATTRIBUTES"];
	} else {
		[_settings setObject:[[attributes allObjects]
		    sortedArrayUsingSelector:@selector(compare:)]
		    forKey:@"ATTRIBUTES"];
	}
}

- (BOOL)boolValueOfAttributeNamed:(NSString *)name
{
	return ([[self attributes] containsObject:name]);
}

- (void)setBoolValue:(BOOL)value ofAttributeNamed:(NSString *)name
{
	NSMutableSet *set = [[self attributes] mutableCopy];

	if (value)
		[set addObject:name];
	else
		[set removeObject:name];
	[self setAttributes:set];
}

static NSArray *SplitCompilerFlags(NSString *string)
{
	NSMutableArray *result = [NSMutableArray array];
	NSMutableString *current = [NSMutableString string];
	NSUInteger length = [string length];
	BOOL inQuotes = NO;
	NSUInteger i;

	for (i = 0; i < length; i++) {
		unichar c = [string characterAtIndex:i];

		if (c == '"') {
			inQuotes = !inQuotes;
		} else if (!inQuotes &&
		    [[NSCharacterSet whitespaceCharacterSet]
		    characterIsMember:c]) {
			if ([current length] > 0) {
				[result addObject:[current copy]];
				current = [NSMutableString string];
			}
		} else {
			[current appendFormat:@"%C", c];
		}
	}
	if ([current length] > 0)
		[result addObject:[current copy]];
	return (result);
}

- (NSArray *)additionalCompilerArguments
{
	id raw = [_settings objectForKey:@"COMPILER_FLAGS"];

	if (raw == nil)
		return (nil);
	if ([raw isKindOfClass:[NSArray class]])
		return (raw);
	if ([raw isKindOfClass:[NSString class]])
		return (SplitCompilerFlags(raw));
	return (nil);
}

- (void)setAdditionalCompilerArguments:(NSArray *)arguments
{
	if (_settings == nil)
		_settings = [[NSMutableDictionary alloc] init];
	if ([arguments count] == 0)
		[_settings removeObjectForKey:@"COMPILER_FLAGS"];
	else
		[_settings setObject:[arguments componentsJoinedByString:@" "]
		    forKey:@"COMPILER_FLAGS"];
}

- (NSString *)additionalCompilerArgumentsAsString
{
	id raw = [_settings objectForKey:@"COMPILER_FLAGS"];

	if ([raw isKindOfClass:[NSString class]])
		return (raw);
	if ([raw isKindOfClass:[NSArray class]])
		return ([raw componentsJoinedByString:@" "]);
	return (nil);
}

- (void)setAdditionalCompilerArgumentsAsString:(NSString *)string
{
	if (_settings == nil)
		_settings = [[NSMutableDictionary alloc] init];
	if ([string length] == 0)
		[_settings removeObjectForKey:@"COMPILER_FLAGS"];
	else
		[_settings setObject:[string copy] forKey:@"COMPILER_FLAGS"];
}

- (NSString *)primaryAttribute
{
	NSSet *attributes = [self attributes];
	NSArray *priority = @[@"Public", @"Private", @"Project", @"Weak"];
	NSString *candidate;

	for (candidate in priority) {
		if ([attributes containsObject:candidate])
			return (candidate);
	}
	return ([[[attributes allObjects]
	    sortedArrayUsingSelector:@selector(compare:)] firstObject]);
}

- (NSString *)stringValueForPrimaryAttribute
{
	return ([self primaryAttribute]);
}

+ (instancetype)buildFileWithReference:(PBXFileReference *)reference
{
	return ([[self alloc] initWithReference:reference]);
}

- (instancetype)initWithReference:(PBXFileReference *)reference
{
	self = [self init];
	if (self != nil)
		_fileRef = reference;
	return (self);
}

- (instancetype)initWithProductReference:(PBXReference *)reference
{
	self = [self init];
	if (self != nil)
		_productRef = reference;
	return (self);
}

- (PBXFileReference *)fileReference
{
	return (_fileRef);
}

- (PBXReference *)reference
{
	return (_fileRef);
}

- (PBXReference *)productReference
{
	return (_productRef);
}

- (BOOL)shouldArchiveSettings
{
	return (_settings != nil && [_settings count] > 0);
}

- (PBXBuildPhase *)buildPhase
{
	return (_buildPhase);
}

- (void)setBuildPhase:(PBXBuildPhase *)phase
{
	_buildPhase = phase;
}

- (PBXTarget *)target
{
	return ([_buildPhase target]);
}

- (NSString *)displayName
{
	PBXReference *ref = _fileRef ?: _productRef;
	NSString *fileName = [ref displayName] ?: [self objectID];
	NSString *phaseName = ([_buildPhase name] != nil) ? [_buildPhase name] :
	    [[_buildPhase class] defaultName];

	if (phaseName == nil)
		phaseName = @"";
	return ([NSString stringWithFormat:@"%@ in %@", fileName, phaseName]);
}

- (NSString *)name
{
	return ([self displayName]);
}

- (NSComparisonResult)compareName:(NSString *)name
{
	return ([[self displayName] compare:name]);
}

- (NSComparisonResult)compareFullPath:(NSString *)path
{
	NSString *full = [_fileRef path] ?: [_productRef path];

	if (full == nil)
		return (NSOrderedSame);
	return ([full compare:path]);
}

- (NSString *)archiveComment
{
	return (nil);
}

@end

@implementation PBXBuildPhase

+ (NSString *)identifier
{
	return (@"com.apple.buildphase.generic");
}

+ (NSString *)defaultName
{
	return (@"");
}

+ (instancetype)buildPhase
{
	return ([[self alloc] init]);
}

+ (instancetype)buildPhaseFromTemplateDictionary:(NSDictionary *)dictionary
{
	NSString *className;
	Class phaseClass;
	Class baseClass = [PBXBuildPhase class];

	if (![dictionary isKindOfClass:[NSDictionary class]])
		[NSException raise:NSInvalidArgumentException format:
		    @"%@ should be an instance inheriting from %@, but it is %@",
		    dictionary, [NSDictionary class], [dictionary class]];

	className = [dictionary objectForKey:@"Class"];
	if (className == nil || [className isEqualToString:@""]) {
		NSLog(@"ERROR: malformed buildphase dictionary -- required "
		    "key '%@' is missing or empty", @"Class");
		return (nil);
	}
	phaseClass = NSClassFromString(className);
	if (phaseClass == Nil) {
		phaseClass = NSClassFromString(
		    [NSString stringWithFormat:@"PBX%@BuildPhase", className]);
	}
	if (phaseClass == Nil) {
		NSLog(@"ERROR: malformed buildphase dictionary -- unknown "
		    "buildphase class '%@'", className);
		return (nil);
	}
	if (![phaseClass isSubclassOfClass:baseClass]) {
		NSLog(@"ERROR: malformed buildphase dictionary -- buildphase "
		    "class '%@' doesn't inherit from PBXBuildPhase", className);
		return (nil);
	}
	return ([[phaseClass alloc] initFromTemplateDictionary:dictionary]);
}

+ (id)fileTypeForCheckingAcceptanceOfReference:(PBXReference *)reference
{
	NSString *identifier;

	if ([reference isVariant])
		identifier = [[[[reference children] firstObject] fileType] copy];
	else
		identifier = [reference fileType];
	return ((identifier != nil) ?
	    [PBXFileType specificationForIdentifier:identifier] : nil);
}

+ (BOOL)allowedFileTypes:(XCSpecificationFilter *)filter
    acceptReference:(PBXReference *)reference
{
	return ([filter includesSpecification:
	    [self fileTypeForCheckingAcceptanceOfReference:reference]]);
}

+ (XCSpecificationFilter *)allowedFileTypes
{
	static XCSpecificationFilter *allowedFileTypes = nil;

	if (allowedFileTypes == nil) {
		allowedFileTypes = [[XCSpecificationFilter alloc]
		    initWithSpecificationClass:[PBXFileType class]
		    includeAllByDefault:YES];
	}
	return (allowedFileTypes);
}

+ (NSArray *)archivableAttributes
{
	static NSArray *archivableAttributes = nil;

	if (archivableAttributes == nil) {
		archivableAttributes = @[@"name", @"buildActionMask",
		    @"runOnlyForDeploymentPostprocessing"];
	}
	return (archivableAttributes);
}

+ (NSArray *)archivableRelationships
{
	static NSArray *archivableRelationships = nil;

	if (archivableRelationships == nil)
		archivableRelationships = @[@"archivedBuildFiles"];
	return (archivableRelationships);
}

+ (NSString *)archiveNameForKey:(NSString *)key
{
	if ([key isEqualToString:@"archivedBuildFiles"])
		return (@"files");
	return ([super archiveNameForKey:key]);
}

- (id)initFromTemplateDictionary:(NSDictionary *)dictionary
{
	NSString *key;

	if ((self = [self init]) == nil)
		return (nil);
	if ([dictionary isKindOfClass:[NSDictionary class]]) {
		for (key in [[self class] archivableKeys]) {
			id value = [dictionary objectForKey:key];

			if (value != nil)
				[self setArchiveValue:value forKey:key];
		}
	}
	return (self);
}

- (NSString *)name
{
	return (_name);
}

- (void)setName:(NSString *)name
{
	_name = [name copy];
}

- (NSNumber *)buildActionMask
{
	return (_buildActionMask);
}

- (void)setBuildActionMask:(NSNumber *)mask
{
	_buildActionMask = mask;
}

- (NSNumber *)runOnlyForDeploymentPostprocessing
{
	return (_runOnlyForDeploymentPostprocessing);
}

- (void)setRunOnlyForDeploymentPostprocessing:(NSNumber *)flag
{
	_runOnlyForDeploymentPostprocessing = flag;
}

- (NSArray *)files
{
	return (_files);
}

- (void)setFiles:(NSArray *)files
{
	PBXBuildFile *file;

	_files = (files != nil) ? [files mutableCopy] : nil;
	for (file in _files) {
		if ([file isKindOfClass:[PBXBuildFile class]])
			[file setBuildPhase:self];
	}
}

- (void)addFile:(PBXBuildFile *)file
{
	[self addBuildFile:file];
}

- (NSArray *)buildFiles
{
	return (_files);
}

- (NSArray *)archivedBuildFiles
{
	return (_files);
}

- (void)setArchivedBuildFiles:(NSArray *)files
{
	[self setFiles:files];
}

- (void)insertBuildFiles:(NSArray *)files atIndex:(NSUInteger)index
{
	PBXBuildFile *file;

	if (_files == nil)
		_files = [[NSMutableArray alloc] init];
	if (index > [_files count])
		index = [_files count];
	for (file in files) {
		if (![file isKindOfClass:[PBXBuildFile class]])
			continue;
		[_files insertObject:file atIndex:index++];
		[file setBuildPhase:self];
	}
}

- (void)insertBuildFile:(PBXBuildFile *)file atIndex:(NSUInteger)index
{
	if (file != nil)
		[self insertBuildFiles:@[ file ] atIndex:index];
}

- (void)addBuildFile:(PBXBuildFile *)file
{
	if (file == nil)
		return;
	if (_files == nil)
		_files = [[NSMutableArray alloc] init];
	[_files addObject:file];
	[file setBuildPhase:self];
}

- (void)addBuildFiles:(NSArray *)files
{
	PBXBuildFile *file;

	for (file in files)
		[self addBuildFile:file];
}

- (void)removeBuildFile:(PBXBuildFile *)file
{
	if (file == nil || _files == nil)
		return;
	if ([file buildPhase] == self)
		[file setBuildPhase:nil];
	[_files removeObject:file];
}

- (void)removeBuildFiles:(NSArray *)files
{
	PBXBuildFile *file;

	for (file in files)
		[self removeBuildFile:file];
}

- (PBXBuildFile *)buildFileForReference:(PBXReference *)reference
{
	PBXBuildFile *file;

	if (reference == nil)
		return (nil);
	for (file in _files) {
		if (![file isKindOfClass:[PBXBuildFile class]])
			continue;
		if ([file fileRef] == reference || [file productRef] == reference)
			return (file);
	}
	return (nil);
}

- (PBXBuildFile *)buildFileForProductReference:(PBXReference *)reference
{
	PBXBuildFile *file;

	if (reference == nil)
		return (nil);
	for (file in _files) {
		if (![file isKindOfClass:[PBXBuildFile class]])
			continue;
		if ([file productRef] == reference)
			return (file);
	}
	return (nil);
}

- (BOOL)containsFileReferenceIdenticalTo:(PBXReference *)reference
{
	return ([self buildFileForReference:reference] != nil);
}

- (PBXTarget *)target
{
	return (_target);
}

- (void)setTarget:(PBXTarget *)target
{
	_target = target;
}

- (BOOL)canRename
{
	return (NO);
}

- (BOOL)isDeletable
{
	return (YES);
}

/* Apple answers with an XCPropertyDefinition built from an inline property
 * list.  We do not model the property-definition subsystem yet, so the base
 * implementation (which also returns nil) is used for every phase. */
- (id)primaryAttributeForBuildFile:(PBXBuildFile *)file
{
	if (![file isKindOfClass:[PBXBuildFile class]])
		[NSException raise:NSInvalidArgumentException format:
		    @"%@ should be an instance inheriting from %@, but it is %@",
		    file, [PBXBuildFile class], [file class]];
	if ([file buildPhase] != self)
		[NSException raise:NSInvalidArgumentException format:
		    @"%@ should be the build phase of %@", self, file];
	return (nil);
}

- (BOOL)_isReferenceReallyInProject:(PBXReference *)reference
{
	PBXProjectModel *referenceProject = [reference projectModel];

	if (referenceProject == nil)
		return (NO);
	if (referenceProject != [self projectModel])
		return (NO);
	return ([reference group] != nil);
}

- (BOOL)acceptsReference:(PBXReference *)reference
    checkFileType:(BOOL)checkFileType
{
	PBXFileType *fileType;

	if (![self _isReferenceReallyInProject:reference])
		return (NO);
	if ([reference isMemberOfClass:[PBXGroup class]])
		return (NO);
	if ([reference isKindOfClass:
	    [PBXFileSystemSynchronizedAbstractGroup class]])
		return (NO);
	if ([reference isVariant])
		return (NO);
	fileType = [PBXFileType specificationForIdentifier:[reference fileType]];
	if ([fileType isProjectWrapper])
		return (NO);
	if ([reference isVariantGroup]) {
		if (!checkFileType)
			return (NO);
		if (![self acceptsVariantGroups])
			return (NO);
	} else if (!checkFileType) {
		return (YES);
	}
	return ([[self class] allowedFileTypes:[[self class] allowedFileTypes]
	    acceptReference:reference]);
}

- (BOOL)acceptsReference:(PBXReference *)reference
{
	return ([self acceptsReference:reference checkFileType:YES]);
}

- (BOOL)allowsFileType:(PBXFileType *)fileType
{
	XCSpecificationFilter *filter = [[self class] allowedFileTypes];

	if (fileType != nil &&
	    fileType != [PBXFileType specificationForIdentifier:@"file"])
		return ([filter includesSpecification:fileType]);
	return ([filter includesAllSpecifications]);
}

- (BOOL)acceptsVariantGroups
{
	return (NO);
}

- (BOOL)phaseContainsJavaFiles
{
	PBXBuildFile *file;

	for (file in _files) {
		NSString *path = [[file fileRef] path];

		if ([[path pathExtension] isEqualToString:@"java"])
			return (YES);
	}
	return (NO);
}

- (BOOL)phaseContainsNonJavaFiles
{
	PBXBuildFile *file;

	for (file in _files) {
		NSString *path = [[file fileRef] path];

		if (![[path pathExtension] isEqualToString:@"java"])
			return (YES);
	}
	return (NO);
}

- (NSArray *)customBuildRules
{
	return (_customBuildRules);
}

- (void)setCustomBuildRules:(NSArray *)rules
{
	_customBuildRules = (rules != nil) ? [rules mutableCopy] : nil;
}

- (NSString *)archiveComment
{
	return ((_name != nil) ? _name : [[self class] defaultName]);
}

@end

@implementation PBXCopyFilesBuildPhase

+ (NSString *)identifier
{
	return (@"com.apple.buildphase.copy-files");
}

+ (NSString *)defaultName
{
	return (@"Copy Files");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"dstPath", @"dstSubfolderSpec", @"dstSubfolderSpecName"]);
}

- (NSString *)dstPath
{
	return (_dstPath);
}

- (void)setDstPath:(NSString *)path
{
	_dstPath = [path copy];
}

- (NSNumber *)dstSubfolderSpec
{
	return (_dstSubfolderSpec);
}

- (void)setDstSubfolderSpec:(NSNumber *)spec
{
	_dstSubfolderSpec = spec;
}

- (NSString *)dstSubfolderSpecName
{
	return (_dstSubfolderSpecName);
}

- (void)setDstSubfolderSpecName:(NSString *)name
{
	_dstSubfolderSpecName = [name copy];
}

@end

@implementation PBXShellScriptBuildPhase

+ (NSString *)identifier
{
	return (@"com.apple.buildphase.shell-script");
}

+ (NSString *)defaultName
{
	return (@"Run Script");
}

+ (NSArray *)archivableAttributes
{
	return (@[@"alwaysOutOfDate", @"archivedShellScript", @"dependencyFile",
	    @"inputFileListPaths", @"inputPaths", @"outputFileListPaths",
	    @"outputPaths", @"shellPath", @"showEnvVarsInLog"]);
}

+ (NSString *)archiveNameForKey:(NSString *)key
{
	if ([key isEqualToString:@"archivedShellScript"])
		return (@"shellScript");
	return ([super archiveNameForKey:key]);
}

+ (XCSpecificationFilter *)allowedFileTypes
{
	static XCSpecificationFilter *allowedFileTypes = nil;

	if (allowedFileTypes == nil) {
		allowedFileTypes = [[XCSpecificationFilter alloc]
		    initWithSpecificationClass:[PBXFileType class]
		    includeAllByDefault:NO];
	}
	return (allowedFileTypes);
}

- (NSString *)shellPath
{
	return (_shellPath);
}

- (void)setShellPath:(NSString *)path
{
	_shellPath = [path copy];
}

- (NSString *)shellScript
{
	return (_shellScript);
}

- (void)setShellScript:(NSString *)script
{
	_shellScript = [script copy];
}

- (id<NSCopying>)archivedShellScript
{
	return (_shellScript);
}

- (void)setArchivedShellScript:(id<NSCopying>)script
{
	_shellScript = [(id)script copy];
}

- (NSString *)dependencyFile
{
	return (_dependencyFile);
}

- (void)setDependencyFile:(NSString *)path
{
	_dependencyFile = [path copy];
}

- (NSArray *)inputPaths
{
	return (_inputPaths);
}

- (void)setInputPaths:(NSArray *)paths
{
	_inputPaths = (paths != nil) ? [paths mutableCopy] : nil;
}

- (NSArray *)outputPaths
{
	return (_outputPaths);
}

- (void)setOutputPaths:(NSArray *)paths
{
	_outputPaths = (paths != nil) ? [paths mutableCopy] : nil;
}

- (NSArray *)inputFileListPaths
{
	return (_inputFileListPaths);
}

- (void)setInputFileListPaths:(NSArray *)paths
{
	_inputFileListPaths = (paths != nil) ? [paths mutableCopy] : nil;
}

- (NSArray *)outputFileListPaths
{
	return (_outputFileListPaths);
}

- (void)setOutputFileListPaths:(NSArray *)paths
{
	_outputFileListPaths = (paths != nil) ? [paths mutableCopy] : nil;
}

- (NSNumber *)alwaysOutOfDate
{
	return (_alwaysOutOfDate);
}

- (void)setAlwaysOutOfDate:(NSNumber *)flag
{
	_alwaysOutOfDate = flag;
}

- (NSNumber *)showEnvVarsInLog
{
	return (_showEnvVarsInLog);
}

- (void)setShowEnvVarsInLog:(NSNumber *)flag
{
	_showEnvVarsInLog = flag;
}

@end

@implementation PBXHeadersBuildPhase

+ (NSString *)identifier
{
	return (@"com.apple.buildphase.headers");
}

+ (NSString *)defaultName
{
	return (@"Headers");
}

+ (XCSpecificationFilter *)allowedFileTypes
{
	return ([PBXProject headerFileTypes]);
}

@end

@implementation PBXSourcesBuildPhase

+ (NSString *)identifier
{
	return (@"com.apple.buildphase.sources");
}

+ (NSString *)defaultName
{
	return (@"Compile Sources");
}

+ (XCSpecificationFilter *)allowedFileTypes
{
	return ([PBXProject sourceFileTypes]);
}

@end

@implementation PBXFrameworksBuildPhase

+ (NSString *)identifier
{
	return (@"com.apple.buildphase.frameworks");
}

+ (NSString *)defaultName
{
	return (@"Link Binary With Libraries");
}

+ (XCSpecificationFilter *)allowedFileTypes
{
	return ([PBXProject linkableFileTypes]);
}

@end

/* Deviation: see PBXProject.m; nil lookups are skipped. */
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

@implementation PBXResourcesBuildPhase

+ (NSString *)identifier
{
	return (@"com.apple.buildphase.resources");
}

+ (NSString *)defaultName
{
	return (@"Copy Bundle Resources");
}

+ (XCSpecificationFilter *)allowedFileTypes
{
	static XCSpecificationFilter *allowedFileTypes = nil;

	if (allowedFileTypes == nil) {
		allowedFileTypes = [[XCSpecificationFilter alloc]
		    initWithSpecificationClass:[PBXFileType class]
		    includeAllByDefault:YES];
		[allowedFileTypes addExcludedSpecifications:
		    [[PBXSourcesBuildPhase allowedFileTypes]
		    includedSpecifications]];
		[allowedFileTypes addExcludedSpecifications:
		    [[PBXAppleScriptBuildPhase allowedFileTypes]
		    includedSpecifications]];
		[allowedFileTypes addExcludedSpecifications:
		    [[PBXHeadersBuildPhase allowedFileTypes]
		    includedSpecifications]];
		[allowedFileTypes addExcludedSpecifications:
		    [[PBXFrameworksBuildPhase allowedFileTypes]
		    includedSpecifications]];
		[allowedFileTypes addExcludedSpecifications:
		    [[PBXRezBuildPhase allowedFileTypes]
		    includedSpecifications]];
		AddExcluded(allowedFileTypes, @"file.playground");
		AddExcluded(allowedFileTypes, @"text.apinotes");
		AddIncluded(allowedFileTypes, @"sourcecode.glsl");
		AddIncluded(allowedFileTypes, @"sourcecode.javascript");
		AddIncluded(allowedFileTypes, @"net.daringfireball.markdown");
		AddExcluded(allowedFileTypes, @"sourcecode.module-map");
		AddExcluded(allowedFileTypes, @"sourcecode.text-based-dylib-definition");
		AddExcluded(allowedFileTypes, @"text.plist.entitlements");
	}
	return (allowedFileTypes);
}

@end

@implementation PBXRezBuildPhase

+ (NSString *)identifier
{
	return (@"com.apple.buildphase.rez");
}

+ (NSString *)defaultName
{
	return (@"Build Carbon Resources");
}

+ (XCSpecificationFilter *)allowedFileTypes
{
	return ([PBXProject rezzableFileTypes]);
}

@end

@implementation PBXAppleScriptBuildPhase

+ (NSString *)identifier
{
	return (@"com.apple.buildphase.applescript");
}

+ (NSString *)defaultName
{
	return (@"Compile AppleScript Files");
}

+ (XCSpecificationFilter *)allowedFileTypes
{
	return ([PBXProject appleScriptFileTypes]);
}

- (NSString *)contextName
{
	return (_contextName);
}

- (void)setContextName:(NSString *)name
{
	_contextName = [name copy];
}

- (NSNumber *)isSharedContext
{
	return (_isSharedContext);
}

- (void)setIsSharedContext:(NSNumber *)flag
{
	_isSharedContext = flag;
}

@end

@implementation PBXJavaArchiveBuildPhase

+ (NSString *)identifier
{
	return (@"com.apple.buildphase.java-archive");
}

+ (NSString *)defaultName
{
	return (@"Build Java Resources");
}

@end

@implementation PBXBuildRule

+ (NSArray *)archivableAttributes
{
	return (@[@"compilerSpec", @"filePatterns", @"fileType", @"inputFiles",
	    @"isEditable", @"outputFiles", @"outputFilesCompilerFlags",
	    @"runOncePerArchitecture", @"script", @"name"]);
}

- (NSString *)compilerSpec
{
	return (_compilerSpec);
}

- (void)setCompilerSpec:(NSString *)spec
{
	_compilerSpec = [spec copy];
}

- (NSString *)filePatterns
{
	return (_filePatterns);
}

- (void)setFilePatterns:(NSString *)patterns
{
	_filePatterns = [patterns copy];
}

- (NSString *)fileType
{
	return (_fileType);
}

- (void)setFileType:(NSString *)type
{
	_fileType = [type copy];
}

- (NSArray *)inputFiles
{
	return (_inputFiles);
}

- (void)setInputFiles:(NSArray *)files
{
	_inputFiles = (files != nil) ? [files mutableCopy] : nil;
}

- (NSArray *)outputFiles
{
	return (_outputFiles);
}

- (void)setOutputFiles:(NSArray *)files
{
	_outputFiles = (files != nil) ? [files mutableCopy] : nil;
}

- (NSArray *)outputFilesCompilerFlags
{
	return (_outputFilesCompilerFlags);
}

- (void)setOutputFilesCompilerFlags:(NSArray *)flags
{
	_outputFilesCompilerFlags = (flags != nil) ? [flags mutableCopy] : nil;
}

- (NSNumber *)runOncePerArchitecture
{
	return (_runOncePerArchitecture);
}

- (void)setRunOncePerArchitecture:(NSNumber *)flag
{
	_runOncePerArchitecture = flag;
}

- (NSString *)script
{
	return (_script);
}

- (void)setScript:(NSString *)script
{
	_script = [script copy];
}

- (NSNumber *)isEditable
{
	return (_isEditable);
}

- (void)setIsEditable:(NSNumber *)flag
{
	_isEditable = flag;
}

- (NSString *)name
{
	return (_name);
}

- (void)setName:(NSString *)name
{
	_name = [name copy];
}

@end

@implementation PBXBuildStyle

+ (NSArray *)archivableAttributes
{
	return (@[@"name", @"buildSettings"]);
}

+ (NSArray *)archivableRelationships
{
	return (@[@"buildRules"]);
}

- (NSString *)name
{
	return (_name);
}

- (void)setName:(NSString *)name
{
	_name = [name copy];
}

- (NSMutableDictionary *)buildSettings
{
	return (_buildSettings);
}

- (void)setBuildSettings:(NSDictionary *)settings
{
	_buildSettings = (settings != nil) ? [settings mutableCopy] : nil;
}

- (NSString *)archiveComment
{
	return (_name);
}

@end
