/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's PBXFileType.
 *
 * A PBXFileType is the XCSpecification subclass that describes one kind of
 * file ("sourcecode.c.objc", "wrapper.application", ...).  Instances are
 * created from .pbfilespec property lists and are looked up by file name,
 * extension, magic word, filename pattern or UTI.
 *
 * Apple looks up the file type for a path through DVTFilePath's cached-info
 * derivation machinery.  This tree has no DVTFilePath, so
 * +fileTypeForFilePath: performs the same derivation directly (see the
 * implementation for the exact rules) and memoizes its results.
 *
 * Other deviations from Apple's implementation, all invisible to the archive
 * pipeline:
 *
 *   - the "isFileUnicode:fileData:" / "isFileUTF8WithBOM:fileData:" helpers
 *     live in DevToolsSupport (as in Apple's DevToolsSupport framework) and
 *     are reconstructed there,
 *   - the first-1024-bytes read that Apple gets from
 *     +[NSData dvt_dataWithFirstBytes:ofFile:error:] is implemented locally,
 *   - Apple's diagnostic logging (the verbose document-file-type log aspect)
 *     is omitted, and
 *   - argument validation raises NSInvalidArgumentException instead of
 *     calling __DVTAssertionFailureHandler(). */

#ifndef DEVTOOLSCORE_PBXFILETYPE_H
#define DEVTOOLSCORE_PBXFILETYPE_H

#import <Foundation/Foundation.h>

#import "DevToolsCore/BuildSystem/XCSpecification.h"

@class PBXFileTypePart, TSPropertyListDictionary;

@interface PBXFileType : XCSpecification
{
	NSArray *_extensions;
	BOOL _completedInitialization;
	NSArray *_hfsTypeCodes;
	NSString *_UTI;
	BOOL _isBundle;
	BOOL _isLibrary;
	BOOL _isDynamicLibrary;
	BOOL _isStaticLibrary;
	BOOL _isFramework;
	BOOL _isStaticFramework;
	BOOL _isProjectWrapper;
	BOOL _isTargetWrapper;
	BOOL _isExecutable;
	BOOL _isExecutableWithGUI;
	BOOL _isTextFile;
	BOOL _isPreprocessed;
	BOOL _isSourceCode;
	BOOL _isSwiftSourceCode;
	BOOL _isDocumentation;
	BOOL _isFolder;
	BOOL _isWrapperFolder;
	BOOL _includeInIndex;
	BOOL _isTransparent;
	BOOL _canSetIncludeInIndex;
	NSString *_languageSpecificationIdentifier;
	NSString *_xcLanguageSpecificationIdentifier;
	NSString *_plistStructureDefinitionIdentifier;
	BOOL _isScannedForIncludes;
	BOOL _requiresHardTabs;
	BOOL _codeSignOnCopy;
	BOOL _removeHeadersOnCopy;
	BOOL _validateOnCopy;
	NSArray *_extraPropertyNames;
	BOOL _isEmbeddable;
	NSArray *_buildPhaseInjectionsWhenEmbedding;
}

/* Class methods */
+ (Class)specificationTypeBaseClass;
+ (NSString *)specificationType;
+ (NSString *)localizedSpecificationTypeName;
+ (NSSet *)specificationTypePathExtensions;
+ (NSString *)specificationRegistryName;
+ (void)registerSpecificationOrProxy:(id)proxy;

+ (NSMutableDictionary *)_extensionToFileTypeDictionary;
+ (NSMutableDictionary *)_lowercasedExtensionToFileTypeDictionary;
+ (NSMutableDictionary *)_magicWordToFileTypeDictionary;
+ (NSMutableDictionary *)_fileNamePatternToFileTypeDictionary;
+ (NSMutableDictionary *)_UTIToFileTypeDictionary;
+ (NSMutableArray *)_fileTypeDetectorArray;

+ (PBXFileType *)genericFileType;
+ (PBXFileType *)textFileType;
+ (PBXFileType *)genericFolderType;
+ (PBXFileType *)wrapperFolderType;

+ (PBXFileType *)bestFileTypeForRepresentingFileAtPath:(NSString *)path
				    withFileAttributes:(NSDictionary *)attributes
			       withLessSpecificFileType:(PBXFileType *)type;
+ (PBXFileType *)fileTypeForFileName:(NSString *)name
		     posixPermissions:(unsigned long long)permissions
			 hfsTypeCode:(unsigned int)hfsTypeCode
			  hfsCreatorCode:(unsigned int)hfsCreatorCode;
+ (PBXFileType *)fileTypeForFileName:(NSString *)name;
+ (PBXFileType *)fileTypeMatchingPatternsForFileName:(NSString *)name;
+ (PBXFileType *)fileTypeForFilenamePattern:(NSString *)pattern isFolder:(BOOL)isFolder;
+ (PBXFileType *)fileTypeForUTI:(NSString *)uti;
+ (PBXFileType *)guessFileTypeForGenericFileAtPath:(NSString *)path;
+ (PBXFileType *)fileTypeForFilePath:(NSString *)path;
+ (PBXFileType *)fileTypeForPath:(NSString *)path;
+ (PBXFileType *)_fileTypeUsingFileAttributesAtPath:(NSString *)path
				     withAttributes:(NSDictionary *)attributes;

/* Instance methods */
- (id)initWithPropertyListDictionary:(TSPropertyListDictionary *)propertyList
			    inDomain:(NSString *)domain;

- (NSArray *)extensions;
- (NSArray *)hfsTypeCodes;
- (NSString *)UTI;

- (BOOL)isBundle;
- (BOOL)isLibrary;
- (BOOL)isDynamicLibrary;
- (BOOL)isStaticLibrary;
- (BOOL)isFramework;
- (BOOL)isStaticFramework;
- (BOOL)isProjectWrapper;
- (BOOL)isTargetWrapper;
- (BOOL)isExecutable;
- (BOOL)isExecutableWithGUI;
- (BOOL)isTextFile;
- (BOOL)isPreprocessed;
- (BOOL)isSourceCode;
- (BOOL)isSwiftSourceCode;
- (BOOL)isDocumentation;
- (BOOL)isFolder;
- (BOOL)isWrapperFolder;
- (BOOL)includeInIndex;
- (BOOL)isTransparent;
- (BOOL)canSetIncludeInIndex;
- (NSString *)languageSpecificationIdentifier;
- (NSString *)xcLanguageSpecificationIdentifier;
- (NSString *)plistStructureDefinitionIdentifier;
- (BOOL)isScannedForIncludes;
- (BOOL)requiresHardTabs;
- (BOOL)codeSignOnCopy;
- (BOOL)removeHeadersOnCopy;
- (BOOL)validateOnCopy;
- (NSArray *)extraPropertyNames;
- (BOOL)isEmbeddable;
- (NSArray *)buildPhaseInjectionsWhenEmbedding;

- (BOOL)isPlainFile;
- (BOOL)isApplication;
- (BOOL)isNonWrapperFolder;
- (PBXFileTypePart *)fileTypePartForIdentifier:(NSString *)partIdentifier;
- (id)_objectForKeyIgnoringInheritance:(NSString *)key;
- (NSString *)description;

@end

#endif	/* DEVTOOLSCORE_PBXFILETYPE_H */
