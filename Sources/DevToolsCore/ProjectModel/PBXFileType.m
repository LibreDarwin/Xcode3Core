/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's PBXFileType.
 *
 * See Headers/DevToolsCore/PBXFileType.h for the list of deliberate
 * deviations from Apple's implementation. */

#import "DevToolsCore/PBXFileType.h"

#import "DevToolsCore/BuildSystem/XCSpecificationProxy.h"
#import "DevToolsCore/PBXFileTypePart.h"
#import "DevToolsSupport/NSString+TSStringAdditions.h"
#import "DevToolsSupport/TSPropertyListDictionary.h"

#include <fnmatch.h>
#include <string.h>

/* Set to NO whenever a not-yet-loaded proxy is registered; the first path
 * based lookup then asks every registered specification to load itself. */
static BOOL XCAllFileTypesHaveBeenLoaded = NO;

/* Memoizes +fileTypeForFilePath: results, keyed by path.  Apple gets the same
 * effect from DVTFilePath's cached-info derivation functions. */
static NSMutableDictionary *sFileTypeForFilePathCache = nil;

/* Apple reads the first bytes of a file with
 * +[NSData(DVTFoundationClassAdditions) dvt_dataWithFirstBytes:ofFile:error:].
 * DVTFoundation is out of scope for this tree, so the read is done locally. */
static NSData *PBXDataWithFirstBytesOfFile(NSString *path, NSUInteger maxLength)
{
	NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
	NSData *data = nil;

	if (handle == nil)
		return (nil);

	@try {
		data = [handle readDataOfLength:maxLength];
	} @catch (NSException *exception) {
		data = nil;
	}
	[handle closeFile];

	return (data);
}

@interface PBXFileType ()
- (void)_checkCompletedInitialization;
@end

@implementation PBXFileType

/* Class methods */

+ (Class)specificationTypeBaseClass
{
	return ([self class]);
}

+ (NSString *)specificationType
{
	return (@"FileType");
}

+ (NSString *)localizedSpecificationTypeName
{
	NSBundle *bundle = [NSBundle bundleWithIdentifier:@"com.apple.Xcode.DevToolsCore"];
	NSString *localizedName = [bundle localizedStringForKey:@"file type" value:nil table:@"PBXCore"];

	return ((localizedName != nil) ? localizedName : @"file type");
}

+ (NSSet *)specificationTypePathExtensions
{
	return ([NSSet setWithObject:@"pbfilespec"]);
}

+ (NSString *)specificationRegistryName
{
	return ([self specificationType]);
}

+ (void)registerSpecificationOrProxy:(id)proxy
{
	[super registerSpecificationOrProxy:proxy];

	if ([proxy isNotYetLoadedSpecificationProxy]) {
		@synchronized ([PBXFileType class]) {
			XCAllFileTypesHaveBeenLoaded = NO;
		}
	}
}

+ (NSMutableDictionary *)_extensionToFileTypeDictionary
{
	static NSMutableDictionary *dictionary = nil;

	@synchronized ([PBXFileType class]) {
		if (dictionary == nil)
			dictionary = [[NSMutableDictionary alloc] initWithCapacity:128];
	}
	return (dictionary);
}

+ (NSMutableDictionary *)_lowercasedExtensionToFileTypeDictionary
{
	static NSMutableDictionary *dictionary = nil;

	@synchronized ([PBXFileType class]) {
		if (dictionary == nil)
			dictionary = [[NSMutableDictionary alloc] initWithCapacity:128];
	}
	return (dictionary);
}

+ (NSMutableDictionary *)_magicWordToFileTypeDictionary
{
	static NSMutableDictionary *dictionary = nil;

	@synchronized ([PBXFileType class]) {
		if (dictionary == nil)
			dictionary = [[NSMutableDictionary alloc] initWithCapacity:32];
	}
	return (dictionary);
}

+ (NSMutableDictionary *)_fileNamePatternToFileTypeDictionary
{
	static NSMutableDictionary *dictionary = nil;

	@synchronized ([PBXFileType class]) {
		if (dictionary == nil)
			dictionary = [[NSMutableDictionary alloc] initWithCapacity:16];
	}
	return (dictionary);
}

+ (NSMutableDictionary *)_UTIToFileTypeDictionary
{
	static NSMutableDictionary *dictionary = nil;

	@synchronized ([PBXFileType class]) {
		if (dictionary == nil) {
			dictionary = [[NSMutableDictionary alloc] init];

			for (XCSpecification *specification in [PBXFileType registeredSpecifications]) {
				PBXFileType *fileType = (PBXFileType *)specification;

				if ([specification isKindOfClass:[XCSpecificationProxy class]])
					fileType = (PBXFileType *)[specification loadedSpecification];
				if ([fileType UTI] != nil)
					[dictionary setObject:fileType forKey:[fileType UTI]];
			}
		}
	}
	return (dictionary);
}

+ (NSMutableArray *)_fileTypeDetectorArray
{
	static NSMutableArray *array = nil;

	@synchronized ([PBXFileType class]) {
		if (array == nil)
			array = [[NSMutableArray alloc] initWithCapacity:16];
	}
	return (array);
}

+ (PBXFileType *)genericFileType
{
	return ([self specificationForIdentifier:@"file"]);
}

+ (PBXFileType *)textFileType
{
	return ([self specificationForIdentifier:@"text"]);
}

+ (PBXFileType *)genericFolderType
{
	return ([self specificationForIdentifier:@"folder"]);
}

+ (PBXFileType *)wrapperFolderType
{
	return ([self specificationForIdentifier:@"wrapper"]);
}

+ (PBXFileType *)bestFileTypeForRepresentingFileAtPath:(NSString *)path
				    withFileAttributes:(NSDictionary *)attributes
			       withLessSpecificFileType:(PBXFileType *)type
{
	if (path == nil) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is nil",
				   @"path", NSStringFromClass([NSString class])];
	}
	if (![path isKindOfClass:[NSString class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"path", NSStringFromClass([NSString class]), path];
	}
	if ([path isEqualToString:@""]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be a non-empty string, but it's an empty string",
				   @"path"];
	}

	(void)attributes;
	(void)type;

	return (nil);
}

+ (PBXFileType *)fileTypeForFileName:(NSString *)name
		     posixPermissions:(unsigned long long)permissions
			 hfsTypeCode:(unsigned int)hfsTypeCode
			  hfsCreatorCode:(unsigned int)hfsCreatorCode
{
	if (name == nil) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is nil",
				   @"filename", NSStringFromClass([NSString class])];
	}
	if (![name isKindOfClass:[NSString class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"filename", NSStringFromClass([NSString class]), name];
	}
	if ([name isEqualToString:@""]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be a non-empty string, but it's an empty string",
				   @"filename"];
	}

	NSString *extension = [name pathExtension];
	PBXFileType *bestFileType = [[self _extensionToFileTypeDictionary] objectForKey:extension];

	if (bestFileType == nil) {
		bestFileType = [[self _lowercasedExtensionToFileTypeDictionary]
		    objectForKey:[extension lowercaseString]];
	}
	if (bestFileType == nil)
		bestFileType = [self genericFileType];

	if (bestFileType != nil && ![bestFileType isKindOfClass:[PBXFileType class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"bestFileType", NSStringFromClass([PBXFileType class]), bestFileType];
	}

	(void)permissions;
	(void)hfsTypeCode;
	(void)hfsCreatorCode;

	return (bestFileType);
}

+ (PBXFileType *)fileTypeForFileName:(NSString *)name
{
	return ([self fileTypeForFileName:name
			  posixPermissions:0x7fffffffULL
			      hfsTypeCode:0x3f3f3f3fU
			   hfsCreatorCode:0x3f3f3f3fU]);
}

+ (PBXFileType *)fileTypeMatchingPatternsForFileName:(NSString *)name
{
	const char *fileNameCString = [[name lastPathComponent] UTF8String];
	NSDictionary *fileNamePatternToFileTypeDictionary = [self _fileNamePatternToFileTypeDictionary];

	for (NSString *filenamePattern in fileNamePatternToFileTypeDictionary) {
		if (![filenamePattern isKindOfClass:[NSString class]]) {
			[NSException raise:NSInvalidArgumentException
				    format:@"%@ should be an instance inheriting from %@, but it is %@",
					   @"filenamePattern", NSStringFromClass([NSString class]),
					   filenamePattern];
		}
		if (fnmatch([filenamePattern UTF8String], fileNameCString, 0) == 0) {
			return ([fileNamePatternToFileTypeDictionary objectForKey:filenamePattern]);
		}
	}

	return ([self fileTypeForFileName:name]);
}

+ (PBXFileType *)fileTypeForFilenamePattern:(NSString *)pattern isFolder:(BOOL)isFolder
{
	const char *patternCString = [pattern UTF8String];
	NSDictionary *fileNamePatternToFileTypeDictionary = [self _fileNamePatternToFileTypeDictionary];

	for (NSString *filenamePattern in fileNamePatternToFileTypeDictionary) {
		if (![filenamePattern isKindOfClass:[NSString class]]) {
			[NSException raise:NSInvalidArgumentException
				    format:@"%@ should be an instance inheriting from %@, but it is %@",
					   @"filenamePattern", NSStringFromClass([NSString class]),
					   filenamePattern];
		}
		if (fnmatch([filenamePattern UTF8String], patternCString, 0) == 0) {
			PBXFileType *fileType = [fileNamePatternToFileTypeDictionary
			    objectForKey:filenamePattern];

			if ([fileType isFolder] == isFolder)
				return (fileType);
		}
	}

	return (nil);
}

+ (PBXFileType *)fileTypeForUTI:(NSString *)uti
{
	return ([[self _UTIToFileTypeDictionary] objectForKey:uti]);
}

+ (PBXFileType *)guessFileTypeForGenericFileAtPath:(NSString *)path
{
	NSData *data = PBXDataWithFirstBytesOfFile(path, 1024);
	const void *bytes = [data bytes];
	NSUInteger length = [data length];

	if (length == 0) {
		/* Apple logs "Guessed unknown file '%@' as TEXT because it is
		 * zero-length." at the verbose document-file-type level. */
		return ([self textFileType]);
	}
	if (data == nil || bytes == NULL)
		return ([self textFileType]);

	NSDictionary *magicWordToFileTypeDictionary = [[self _magicWordToFileTypeDictionary] copy];

	for (NSData *magicWord in magicWordToFileTypeDictionary) {
		if (![magicWord isKindOfClass:[NSData class]]) {
			[NSException raise:NSInvalidArgumentException
				    format:@"%@ should be an instance inheriting from %@, but it is %@",
					   @"magic", NSStringFromClass([NSData class]), magicWord];
		}
		if ([magicWord length] > length)
			continue;
		if (memcmp(bytes, [magicWord bytes], [magicWord length]) == 0) {
			return ([magicWordToFileTypeDictionary objectForKey:magicWord]);
		}
	}

	if ([NSString isFileUnicode:path fileData:data])
		return ([self textFileType]);
	if ([NSString isFileUTF8WithBOM:path fileData:data])
		return ([self textFileType]);

	NSUInteger controlCharacterCount = 0;

	for (NSUInteger i = 0; i < length; i++) {
		unsigned char character = ((const unsigned char *)bytes)[i];

		if (character == 0)
			return ([self genericFileType]);
		if (character < 32)
			controlCharacterCount++;
	}

	if (((double)controlCharacterCount / (double)length) > 0.1)
		return ([self genericFileType]);

	return ([self textFileType]);
}

+ (PBXFileType *)fileTypeForFilePath:(NSString *)path
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	PBXFileType *bestFileType = nil;
	BOOL isFolder = NO;
	BOOL isRegular = NO;
	BOOL cacheResult = NO;
	NSDictionary *attributes = nil;

	if (path == nil)
		return (nil);

	@synchronized ([PBXFileType class]) {
		if (sFileTypeForFilePathCache == nil)
			sFileTypeForFilePathCache = [[NSMutableDictionary alloc] init];

		id cachedValue = [sFileTypeForFilePathCache objectForKey:path];

		if (cachedValue != nil)
			return ((cachedValue == [NSNull null]) ? nil : cachedValue);
	}

	if (![fileManager fileExistsAtPath:path])
		return (nil);

	cacheResult = YES;
	attributes = [fileManager attributesOfItemAtPath:path error:NULL];

	NSString *fileTypeAttribute = [attributes fileType];

	isFolder = [fileTypeAttribute isEqualToString:NSFileTypeDirectory];
	isRegular = [fileTypeAttribute isEqualToString:NSFileTypeRegular];

	@synchronized ([PBXFileType class]) {
		if (!XCAllFileTypesHaveBeenLoaded) {
			XCAllFileTypesHaveBeenLoaded = YES;
			[[PBXFileType registeredSpecifications]
			    makeObjectsPerformSelector:@selector(loadedSpecification)];
		}
	}

	NSString *extension = [path pathExtension];

	if (extension != nil && ![extension isEqualToString:@""]) {
		bestFileType = [[self _extensionToFileTypeDictionary] objectForKey:extension];
		if (bestFileType == nil) {
			bestFileType = [[self _lowercasedExtensionToFileTypeDictionary]
			    objectForKey:[extension lowercaseString]];
		}
		if ([bestFileType isTextFile] && isFolder)
			bestFileType = nil;
		if (!isFolder && [bestFileType isFolder])
			bestFileType = nil;
	}

	if (bestFileType != nil) {
		Class fileTypeClass = [bestFileType class];

		if (fileTypeClass != [PBXFileType class] && isRegular && attributes != nil &&
		    [fileTypeClass respondsToSelector:@selector(bestFileTypeForRepresentingFileAtPath:withFileAttributes:withLessSpecificFileType:)]) {
			PBXFileType *refinedFileType = [fileTypeClass
			    bestFileTypeForRepresentingFileAtPath:path
					  withFileAttributes:attributes
				     withLessSpecificFileType:bestFileType];

			if (refinedFileType != nil)
				bestFileType = refinedFileType;
		}
	} else {
		bestFileType = [self fileTypeForFilenamePattern:[path lastPathComponent] isFolder:isFolder];

		if (bestFileType == nil && isRegular) {
			if (attributes == nil)
				attributes = [fileManager attributesOfItemAtPath:path error:NULL];
			if (attributes == nil)
				goto done;

			bestFileType = [self _fileTypeUsingFileAttributesAtPath:path
								 withAttributes:attributes];
			if (bestFileType == nil) {
				if ([path rangeOfString:@"/usr/include/gcc"].location != NSNotFound ||
				    [path rangeOfString:@"/usr/include/c++"].location != NSNotFound) {
					bestFileType = [self specificationForIdentifier:@"sourcecode.cpp.h"];
				}
				if (bestFileType == nil)
					bestFileType = [self guessFileTypeForGenericFileAtPath:path];
				if (bestFileType == nil)
					bestFileType = [self genericFileType];
			}
		} else if (isFolder) {
			/* Apple asks the DVTFilePath for its presumed data type and
			 * tests it against com.apple.package; NSURLIsPackageKey is
			 * the Foundation equivalent. */
			NSNumber *isPackageValue = nil;

			[[NSURL fileURLWithPath:path] getResourceValue:&isPackageValue
							      forKey:NSURLIsPackageKey
							       error:NULL];

			bestFileType = [isPackageValue boolValue]
			    ? [self wrapperFolderType]
			    : [self genericFolderType];
		}
	}

done:
	if (cacheResult) {
		@synchronized ([PBXFileType class]) {
			[sFileTypeForFilePathCache setObject:(bestFileType != nil
			    ? (id)bestFileType
			    : (id)[NSNull null])
						      forKey:path];
		}
	}

	return (bestFileType);
}

+ (PBXFileType *)fileTypeForPath:(NSString *)path
{
	NSString *absolutePath;

	if (path == nil)
		return (nil);

	absolutePath = [path isAbsolutePath]
	    ? path
	    : [[[NSFileManager defaultManager] currentDirectoryPath]
		stringByAppendingPathComponent:path];

	return ([self fileTypeForFilePath:absolutePath]);
}

+ (PBXFileType *)_fileTypeUsingFileAttributesAtPath:(NSString *)path
				     withAttributes:(NSDictionary *)attributes
{
	PBXFileType *bestFileType = nil;

	if (attributes == nil)
		return (nil);

	NSArray *fileTypeDetectorArray = [self _fileTypeDetectorArray];
	NSUInteger count = [fileTypeDetectorArray count];

	for (NSUInteger i = 0; i < count; i++) {
		Class fileTypeDetector = [fileTypeDetectorArray objectAtIndex:i];

		if (fileTypeDetector == nil) {
			[NSException raise:NSInvalidArgumentException
				    format:@"%@ should respond to '%@', but it is nil",
					   @"fileTypeDetector",
					   NSStringFromSelector(@selector(bestFileTypeForRepresentingFileAtPath:withFileAttributes:withLessSpecificFileType:))];
		}
		if (![fileTypeDetector respondsToSelector:@selector(bestFileTypeForRepresentingFileAtPath:withFileAttributes:withLessSpecificFileType:)]) {
			[NSException raise:NSInvalidArgumentException
				    format:@"%@ should respond to '%@', but %@ doesn't",
					   @"fileTypeDetector",
					   NSStringFromSelector(@selector(bestFileTypeForRepresentingFileAtPath:withFileAttributes:withLessSpecificFileType:)),
					   NSStringFromClass(fileTypeDetector)];
		}

		bestFileType = [fileTypeDetector
		    bestFileTypeForRepresentingFileAtPath:path
					withFileAttributes:attributes
				   withLessSpecificFileType:nil];
		if (bestFileType != nil)
			break;
	}

	return (bestFileType);
}

/* Instance methods */

- (id)initWithPropertyListDictionary:(TSPropertyListDictionary *)propertyList
			    inDomain:(NSString *)domain
{
	self = [super initWithPropertyListDictionary:propertyList inDomain:domain];
	if (self == nil)
		return (nil);

	if (propertyList == nil) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is nil",
				   @"propertyList", NSStringFromClass([TSPropertyListDictionary class])];
	}
	if (![propertyList isKindOfClass:[TSPropertyListDictionary class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"propertyList", NSStringFromClass([TSPropertyListDictionary class]),
				   propertyList];
	}

	Class fileTypeClass = [self class];

	_extensions = [propertyList arrayOrNilForKey:@"Extensions"];
	for (NSUInteger i = 0; i < [_extensions count]; i++) {
		NSString *extension = [_extensions objectAtIndex:i];

		[[fileTypeClass _extensionToFileTypeDictionary] setObject:self forKey:extension];
		[[fileTypeClass _lowercasedExtensionToFileTypeDictionary] setObject:self
									    forKey:[extension lowercaseString]];
	}

	NSArray *magicWords = [propertyList arrayOrNilForKey:@"MagicWord"];

	for (NSUInteger i = 0; i < [magicWords count]; i++) {
		id magicWord = [magicWords objectAtIndex:i];
		NSData *magic = magicWord;

		if ([magicWord isKindOfClass:[NSString class]]) {
			magic = [magicWord dataUsingEncoding:NSUTF8StringEncoding
					     allowLossyConversion:YES];
		}
		if (magic == nil) {
			[NSException raise:NSInvalidArgumentException
				    format:@"%@ should be an instance inheriting from %@, but it is nil",
					   @"magic", NSStringFromClass([NSData class])];
		}
		if (![magic isKindOfClass:[NSData class]]) {
			[NSException raise:NSInvalidArgumentException
				    format:@"%@ should be an instance inheriting from %@, but it is %@",
					   @"magic", NSStringFromClass([NSData class]), magic];
		}
		[[fileTypeClass _magicWordToFileTypeDictionary] setObject:self forKey:magic];
	}

	NSArray *filenamePatterns = [propertyList arrayOrNilForKey:@"FilenamePatterns"];

	for (NSUInteger i = 0; i < [filenamePatterns count]; i++) {
		id filenamePattern = [filenamePatterns objectAtIndex:i];

		if (filenamePattern == nil) {
			[NSException raise:NSInvalidArgumentException
				    format:@"%@ should be an instance inheriting from %@, but it is nil",
					   @"filenamePattern", NSStringFromClass([NSString class])];
		}
		if (![filenamePattern isKindOfClass:[NSString class]]) {
			[NSException raise:NSInvalidArgumentException
				    format:@"%@ should be an instance inheriting from %@, but it is %@",
					   @"filenamePattern", NSStringFromClass([NSString class]),
					   filenamePattern];
		}
		[[fileTypeClass _fileNamePatternToFileTypeDictionary] setObject:self
								       forKey:filenamePattern];
	}

	if (fileTypeClass != [PBXFileType class]) {
		NSMutableArray *fileTypeDetectorArray = [fileTypeClass _fileTypeDetectorArray];

		if (![fileTypeDetectorArray containsObject:fileTypeClass])
			[fileTypeDetectorArray addObject:fileTypeClass];
	}

	_hfsTypeCodes = [self arrayForKey:@"HFSTypes"];
	_UTI = [self stringForKey:@"UTI"];

	_isBundle = [self boolForKey:@"IsBundle"];
	_isLibrary = [self boolForKey:@"IsLibrary"];
	_isDynamicLibrary = [self boolForKey:@"IsDynamicLibrary"];
	_isStaticLibrary = [self boolForKey:@"IsStaticLibrary"];
	_isFramework = [self boolForKey:@"IsFrameworkWrapper"];
	_isStaticFramework = [self boolForKey:@"IsStaticFrameworkWrapper"];
	_isProjectWrapper = [self boolForKey:@"IsProjectWrapper"];
	_isTargetWrapper = [self boolForKey:@"IsTargetWrapper"];
	_isExecutable = [self boolForKey:@"IsExecutable"];
	_isExecutableWithGUI = [self boolForKey:@"IsExecutableWithGUI"];
	_isTextFile = [self boolForKey:@"IsTextFile"];
	_isPreprocessed = [self boolForKey:@"IsPreprocessed"];
	_isSourceCode = [self boolForKey:@"IsSourceCode"];
	_isSwiftSourceCode = [self boolForKey:@"IsSwiftSourceCode"];
	_isDocumentation = [self boolForKey:@"IsDocumentation"];
	_isFolder = [self boolForKey:@"IsFolder"];
	_isWrapperFolder = [self boolForKey:@"IsWrapperFolder"];
	_includeInIndex = [self boolForKey:@"IncludeInIndex"];
	_isTransparent = [self boolForKey:@"IsTransparent"];
	_canSetIncludeInIndex = [self boolForKey:@"CanSetIncludeInIndex"];

	_languageSpecificationIdentifier = [self stringForKey:@"ComputerLanguage"];
	_xcLanguageSpecificationIdentifier = [self stringForKey:@"Language"];
	_plistStructureDefinitionIdentifier = [self stringForKey:@"PlistStructureDefinition"];

	_isScannedForIncludes = [self boolForKey:@"IsScannedForIncludes"];
	_requiresHardTabs = [self boolForKey:@"RequiresHardTabs"];
	_codeSignOnCopy = [self boolForKey:@"CodeSignOnCopy"];
	_removeHeadersOnCopy = [self boolForKey:@"RemoveHeadersOnCopy"];
	_validateOnCopy = [self boolForKey:@"ValidateOnCopy"];

	_extraPropertyNames = [self arrayForKey:@"ExtraPropertyNames"];

	_isEmbeddable = [self boolForKey:@"IsEmbeddable"];

	_buildPhaseInjectionsWhenEmbedding = [self arrayForKey:@"BuildPhaseInjectionsWhenEmbedding"];

	_completedInitialization = YES;

	return (self);
}

- (NSArray *)extensions
{
	return (_extensions);
}

- (NSArray *)hfsTypeCodes
{
	[self _checkCompletedInitialization];
	return (_hfsTypeCodes);
}

- (NSString *)UTI
{
	[self _checkCompletedInitialization];
	return (_UTI);
}

- (BOOL)isBundle
{
	[self _checkCompletedInitialization];
	return (_isBundle);
}

- (BOOL)isLibrary
{
	[self _checkCompletedInitialization];
	return (_isLibrary);
}

- (BOOL)isDynamicLibrary
{
	[self _checkCompletedInitialization];
	return (_isDynamicLibrary);
}

- (BOOL)isStaticLibrary
{
	[self _checkCompletedInitialization];
	return (_isStaticLibrary);
}

- (BOOL)isFramework
{
	[self _checkCompletedInitialization];
	return (_isFramework);
}

- (BOOL)isStaticFramework
{
	[self _checkCompletedInitialization];
	return (_isStaticFramework);
}

- (BOOL)isProjectWrapper
{
	[self _checkCompletedInitialization];
	return (_isProjectWrapper);
}

- (BOOL)isTargetWrapper
{
	[self _checkCompletedInitialization];
	return (_isTargetWrapper);
}

- (BOOL)isExecutable
{
	[self _checkCompletedInitialization];
	return (_isExecutable);
}

- (BOOL)isExecutableWithGUI
{
	[self _checkCompletedInitialization];
	return (_isExecutableWithGUI);
}

- (BOOL)isTextFile
{
	[self _checkCompletedInitialization];
	return (_isTextFile);
}

- (BOOL)isPreprocessed
{
	[self _checkCompletedInitialization];
	return (_isPreprocessed);
}

- (BOOL)isSourceCode
{
	[self _checkCompletedInitialization];
	return (_isSourceCode);
}

- (BOOL)isSwiftSourceCode
{
	[self _checkCompletedInitialization];
	return (_isSwiftSourceCode);
}

- (BOOL)isDocumentation
{
	[self _checkCompletedInitialization];
	return (_isDocumentation);
}

- (BOOL)isFolder
{
	[self _checkCompletedInitialization];
	return (_isFolder);
}

- (BOOL)isWrapperFolder
{
	[self _checkCompletedInitialization];
	return (_isWrapperFolder);
}

- (BOOL)includeInIndex
{
	[self _checkCompletedInitialization];
	return (_includeInIndex);
}

- (BOOL)isTransparent
{
	[self _checkCompletedInitialization];
	return (_isTransparent);
}

- (BOOL)canSetIncludeInIndex
{
	[self _checkCompletedInitialization];
	return (_canSetIncludeInIndex);
}

- (NSString *)languageSpecificationIdentifier
{
	[self _checkCompletedInitialization];
	return (_languageSpecificationIdentifier);
}

- (NSString *)xcLanguageSpecificationIdentifier
{
	[self _checkCompletedInitialization];
	return (_xcLanguageSpecificationIdentifier);
}

- (NSString *)plistStructureDefinitionIdentifier
{
	[self _checkCompletedInitialization];
	return (_plistStructureDefinitionIdentifier);
}

- (BOOL)isScannedForIncludes
{
	[self _checkCompletedInitialization];
	return (_isScannedForIncludes);
}

- (BOOL)requiresHardTabs
{
	[self _checkCompletedInitialization];
	return (_requiresHardTabs);
}

- (BOOL)codeSignOnCopy
{
	[self _checkCompletedInitialization];
	return (_codeSignOnCopy);
}

- (BOOL)removeHeadersOnCopy
{
	[self _checkCompletedInitialization];
	return (_removeHeadersOnCopy);
}

- (BOOL)validateOnCopy
{
	[self _checkCompletedInitialization];
	return (_validateOnCopy);
}

- (NSArray *)extraPropertyNames
{
	[self _checkCompletedInitialization];
	return (_extraPropertyNames);
}

- (BOOL)isEmbeddable
{
	[self _checkCompletedInitialization];
	return (_isEmbeddable);
}

- (NSArray *)buildPhaseInjectionsWhenEmbedding
{
	[self _checkCompletedInitialization];
	return (_buildPhaseInjectionsWhenEmbedding);
}

- (BOOL)isPlainFile
{
	return (![self isFolder]);
}

- (BOOL)isApplication
{
	if (![self isBundle])
		return (NO);
	return ([self isExecutable]);
}

- (BOOL)isNonWrapperFolder
{
	if (![self isFolder])
		return (NO);
	return (![self isWrapperFolder]);
}

- (PBXFileTypePart *)fileTypePartForIdentifier:(NSString *)partIdentifier
{
	if (partIdentifier == nil) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is nil",
				   @"partIdentifier", NSStringFromClass([NSString class])];
	}
	if (![partIdentifier isKindOfClass:[NSString class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"partIdentifier", NSStringFromClass([NSString class]), partIdentifier];
	}
	if ([partIdentifier isEqualToString:@""]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be a non-empty string, but it's an empty string",
				   @"partIdentifier"];
	}

	/* The base class has no file type parts of its own. */
	return (nil);
}

- (id)_objectForKeyIgnoringInheritance:(NSString *)key
{
	if ([key isEqualToString:@"Extensions"] && _extensions != nil)
		return (_extensions);
	return ([super _objectForKeyIgnoringInheritance:key]);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@:%p:'%@':%c%c%c>",
		    NSStringFromClass([self class]), self, [self identifier],
		    [self isTextFile] ? 'T' : 't',
		    [self isFolder] ? 'F' : 'f',
		    [self isWrapperFolder] ? 'W' : 'w']);
}

- (void)_checkCompletedInitialization
{
	if (!_completedInitialization) {
		[NSException raise:NSInternalInconsistencyException
			    format:@"%@ was messaged before its initialization completed",
				   NSStringFromClass([self class])];
	}
}

@end
