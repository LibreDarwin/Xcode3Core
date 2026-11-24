/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsSupport/TSFileManager.h"

#import <errno.h>
#import <stdlib.h>
#import <sys/stat.h>
#import <sys/xattr.h>
#import <unistd.h>

static NSFileManager *
TSFM(void)
{
	return ([NSFileManager defaultManager]);
}

static NSUInteger
TSFMClassMode(NSUInteger cls)
{
	if (cls == 1)
		return (0700);
	if (cls == 2)
		return (0070);
	if (cls == 4)
		return (0007);
	return (0);
}

static NSUInteger
TSFMPermissionBits(NSUInteger permissions, NSUInteger cls)
{
	NSUInteger shift = (cls == 1) ? 6 : ((cls == 2) ? 3 : 0);
	NSUInteger bits = 0;

	if ((permissions & 1) != 0)
		bits |= (4 << shift);
	if ((permissions & 2) != 0)
		bits |= (2 << shift);
	if ((permissions & 4) != 0)
		bits |= (1 << shift);
	return (bits);
}

static BOOL
TSFMOctalString(NSString *string)
{
	const char *characters;
	size_t index;

	if ([string length] == 0)
		return (NO);
	characters = [string UTF8String];
	for (index = 0; characters[index] != '\0'; index++) {
		if (characters[index] < '0' || characters[index] > '7')
			return (NO);
	}
	return (YES);
}

static NSUInteger
TSFMApplyClause(NSUInteger mode, NSString *clause)
{
	const char *cursor;
	NSUInteger classes = 0;
	NSUInteger permissions = 0;
	NSUInteger classMode = 0;
	NSUInteger selectedBits = 0;
	NSUInteger conditionalBits = 0;
	mode_t mask;
	BOOL applyUmask;
	BOOL conditionalExecute;
	char operation;
	NSUInteger cls;

	cursor = [clause UTF8String];
	while (*cursor == 'u' || *cursor == 'g' || *cursor == 'o' ||
	    *cursor == 'a') {
		if (*cursor == 'a')
			classes = 7;
		else if (*cursor == 'u')
			classes |= 1;
		else if (*cursor == 'g')
			classes |= 2;
		else
			classes |= 4;
		cursor++;
	}
	if (*cursor != '+' && *cursor != '-' && *cursor != '=')
		return (mode);
	operation = *cursor++;
	conditionalExecute = NO;
	while (*cursor == 'r' || *cursor == 'w' || *cursor == 'x' ||
	    *cursor == 'X') {
		if (*cursor == 'r')
			permissions |= 1;
		else if (*cursor == 'w')
			permissions |= 2;
		else if (*cursor == 'x')
			permissions |= 4;
		else
			conditionalExecute = YES;
		cursor++;
	}
	if (*cursor != '\0' || (permissions == 0 && !conditionalExecute))
		return (mode);
	applyUmask = (classes == 0);
	if (applyUmask)
		classes = 7;
	for (cls = 1; cls <= 4; cls <<= 1) {
		if ((classes & cls) == 0)
			continue;
		classMode |= TSFMClassMode(cls);
		selectedBits |= TSFMPermissionBits(permissions, cls);
		if (conditionalExecute && (mode & 0111) != 0)
			conditionalBits |= TSFMPermissionBits(4, cls);
	}
	if (applyUmask) {
		mask = umask(0);
		umask(mask);
		selectedBits &= ~((NSUInteger)mask);
		conditionalBits &= ~((NSUInteger)mask);
	}
	if (operation == '+')
		return (mode | selectedBits | conditionalBits);
	if (operation == '-')
		return ((mode & ~selectedBits) | conditionalBits);
	return ((mode & ~classMode) | selectedBits | conditionalBits);
}

static BOOL
TSFMCopyExtendedAttribute(NSString *name, NSString *source, NSString *dest)
{
	const char *attributeName;
	const char *sourcePath;
	const char *destPath;
	void *buffer;
	ssize_t size;
	NSData *value;
	int result;

	if (source == nil || dest == nil)
		return (NO);
	attributeName = [name UTF8String];
	sourcePath = [source fileSystemRepresentation];
	destPath = [dest fileSystemRepresentation];
	size = getxattr(sourcePath, attributeName, NULL, 0, 0, 0);
	if (size < 0) {
		if (errno == ENOATTR)
			return (YES);
		return (NO);
	}
	if (size == 0)
		return (YES);
	buffer = malloc((size_t)size);
	if (buffer == NULL)
		return (NO);
	size = getxattr(sourcePath, attributeName, buffer, (size_t)size, 0, 0);
	if (size < 0) {
		free(buffer);
		return (NO);
	}
	value = [NSData dataWithBytes:buffer length:(NSUInteger)size];
	free(buffer);
	result = setxattr(destPath, attributeName, [value bytes], [value length],
	    0, 0);
	return (result == 0);
}

@implementation TSFileManager

+ (id)defaultManager
{
	static TSFileManager *manager;

	@synchronized (self) {
		if (manager == nil)
			manager = [[self alloc] init];
	}
	return (manager);
}

- (BOOL)setAttributes:(NSDictionary *)attributes
         ofItemAtPath:(NSString *)path
                error:(NSError **)error
{
	if (path == nil)
		return (YES);
	return ([TSFM() setAttributes:attributes ofItemAtPath:path error:error]);
}

- (BOOL)changeFileAttributes:(NSDictionary *)attributes atPath:(NSString *)path
{
	return ([self setAttributes:attributes ofItemAtPath:path error:NULL]);
}

- (BOOL)linkItemAtPath:(NSString *)source
                toPath:(NSString *)dest
                 error:(NSError **)error
{
	if (source == nil || dest == nil)
		return (NO);
	return ([TSFM() linkItemAtPath:source toPath:dest error:error]);
}

- (BOOL)copyItemAtPath:(NSString *)source
                toPath:(NSString *)dest
                 error:(NSError **)error
{
	if (source == nil || dest == nil)
		return (NO);
	return ([TSFM() copyItemAtPath:source toPath:dest error:error]);
}

- (BOOL)copyPath:(NSString *)source toPath:(NSString *)dest handler:(id)handler
{
	(void)handler;
	return ([self copyItemAtPath:source toPath:dest error:NULL]);
}

- (BOOL)moveItemAtPath:(NSString *)source
                toPath:(NSString *)dest
                 error:(NSError **)error
{
	if (source == nil || dest == nil)
		return (NO);
	return ([TSFM() moveItemAtPath:source toPath:dest error:error]);
}

- (BOOL)movePath:(NSString *)source toPath:(NSString *)dest handler:(id)handler
{
	(void)handler;
	return ([self moveItemAtPath:source toPath:dest error:NULL]);
}

- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error
{
	if (path == nil)
		return (YES);
	return ([TSFM() removeItemAtPath:path error:error]);
}

- (BOOL)removeFileAtPath:(NSString *)path handler:(id)handler
{
	(void)handler;
	return ([self removeItemAtPath:path error:NULL]);
}

- (BOOL)createDirectoryAtPath:(NSString *)path
    withIntermediateDirectories:(BOOL)intermediate
                     attributes:(NSDictionary *)attributes
                          error:(NSError **)error
{
	if (path == nil)
		return (NO);
	return ([TSFM() createDirectoryAtPath:path
	    withIntermediateDirectories:intermediate attributes:attributes
	    error:error]);
}

- (BOOL)createDirectoryAtPath:(NSString *)path
                   attributes:(NSDictionary *)attributes
{
	return ([self createDirectoryAtPath:path
	    withIntermediateDirectories:NO attributes:attributes error:NULL]);
}

- (BOOL)createFileAtPath:(NSString *)path
                contents:(NSData *)contents
              attributes:(NSDictionary *)attributes
{
	if (path == nil)
		return (NO);
	return ([TSFM() createFileAtPath:path contents:contents attributes:attributes]);
}

- (BOOL)createSymbolicLinkAtPath:(NSString *)path
             withDestinationPath:(NSString *)dest
                           error:(NSError **)error
{
	if (path == nil || dest == nil)
		return (NO);
	return ([TSFM() createSymbolicLinkAtPath:path withDestinationPath:dest
	    error:error]);
}

- (BOOL)createDirectoryAtPath:(NSString *)path
                   attributes:(NSDictionary *)attributes
                      recurse:(BOOL)recurse
{
	return ([self createDirectoryAtPath:path
	    withIntermediateDirectories:recurse attributes:attributes error:NULL]);
}

- (BOOL)isDirectoryAtPath:(NSString *)path traverseLink:(BOOL)traverseLink
{
	BOOL isDirectory = NO;
	struct stat information;

	if (path == nil)
		return (NO);
	if (!traverseLink) {
		if (lstat([path fileSystemRepresentation], &information) != 0)
			return (NO);
		return (S_ISDIR(information.st_mode));
	}
	return ([TSFM() fileExistsAtPath:path isDirectory:&isDirectory] &&
	    isDirectory);
}

- (NSUInteger)posixPermissionsByApplyingChmodString:(NSString *)string
                                                 to:(NSUInteger)mode
{
	const char *characters;
	NSUInteger value = 0;
	size_t index;

	if (string == nil)
		return (mode);
	if (TSFMOctalString(string)) {
		characters = [string UTF8String];
		for (index = 0; characters[index] != '\0'; index++)
			value = (value * 8) + (NSUInteger)(characters[index] - '0');
		return (value);
	}
	for (NSString *clause in [string componentsSeparatedByString:@","])
		mode = TSFMApplyClause(mode, clause);
	return (mode);
}

- (BOOL)copyPermissionsFromPath:(NSString *)source toPath:(NSString *)dest
{
	NSDictionary *attributes;
	NSNumber *permissions;

	if (source == nil || dest == nil)
		return (NO);
	attributes = [TSFM() attributesOfItemAtPath:source error:NULL];
	permissions = [attributes objectForKey:NSFilePosixPermissions];
	if (permissions == nil)
		return (NO);
	return ([self setAttributes:
	    [NSDictionary dictionaryWithObject:permissions
	        forKey:NSFilePosixPermissions] ofItemAtPath:dest error:NULL]);
}

- (BOOL)copyOwnerGroupAndPermissionsFromPath:(NSString *)source
                                     toPath:(NSString *)dest
{
	NSDictionary *attributes;
	NSNumber *owner;
	NSNumber *group;
	BOOL result;

	if (source == nil || dest == nil)
		return (NO);
	attributes = [TSFM() attributesOfItemAtPath:source error:NULL];
	owner = [attributes objectForKey:NSFileOwnerAccountID];
	group = [attributes objectForKey:NSFileGroupOwnerAccountID];
	result = [self copyPermissionsFromPath:source toPath:dest];
	if (owner == nil || group == nil)
		return (result);
	if (chown([dest fileSystemRepresentation], [owner unsignedIntValue],
	    [group unsignedIntValue]) != 0)
		return (NO);
	return (result);
}

- (BOOL)copyFinderInfoFromPath:(NSString *)source toPath:(NSString *)dest
{
	return (TSFMCopyExtendedAttribute(@"com.apple.FinderInfo", source, dest));
}

- (BOOL)copyResourceForkFromPath:(NSString *)source toPath:(NSString *)dest
{
	return (TSFMCopyExtendedAttribute(@"com.apple.ResourceFork", source, dest));
}

- (BOOL)_copyPath:(NSString *)source
          toPath:(NSString *)dest
        delegate:(id)delegate
       ownerName:(id)ownerName
       groupName:(id)groupName
     chmodString:(id)chmodString
preserveFinderInfo:(BOOL)preserveFinderInfo
preserveResourceForks:(BOOL)preserveResourceForks
{
	NSUInteger permissions;
	BOOL result;
	NSDictionary *attributes;

	(void)delegate;
	result = [self copyItemAtPath:source toPath:dest error:NULL];
	if (!result)
		return (NO);
	if (preserveFinderInfo)
		result = [self copyFinderInfoFromPath:source toPath:dest];
	if (!result)
		return (NO);
	if (preserveResourceForks)
		result = [self copyResourceForkFromPath:source toPath:dest];
	if (!result)
		return (NO);
	if ([chmodString isKindOfClass:[NSString class]]) {
		attributes = [TSFM() attributesOfItemAtPath:dest error:NULL];
		permissions = [[attributes objectForKey:NSFilePosixPermissions]
		    unsignedIntegerValue];
		permissions = [self posixPermissionsByApplyingChmodString:chmodString
		    to:permissions];
		result = [self setAttributes:
		    [NSDictionary dictionaryWithObject:
		        [NSNumber numberWithUnsignedInteger:permissions]
		        forKey:NSFilePosixPermissions] ofItemAtPath:dest
		    error:NULL];
		if (!result)
			return (NO);
	}
	if ([ownerName isKindOfClass:[NSString class]] ||
	    [groupName isKindOfClass:[NSString class]])
		result = [self copyOwnerGroupAndPermissionsFromPath:source toPath:dest];
	return (result);
}

- (BOOL)copyPath:(NSString *)source
          toPath:(NSString *)dest
        delegate:(id)delegate
       ownerName:(id)ownerName
       groupName:(id)groupName
     chmodString:(id)chmodString
preserveFinderInfo:(BOOL)preserveFinderInfo
preserveResourceForks:(BOOL)preserveResourceForks
{
	return ([self _copyPath:source toPath:dest delegate:delegate
	    ownerName:ownerName groupName:groupName chmodString:chmodString
	    preserveFinderInfo:preserveFinderInfo
	    preserveResourceForks:preserveResourceForks]);
}

- (BOOL)copyPath:(NSString *)source
          toPath:(NSString *)dest
        delegate:(id)delegate
       ownerName:(id)ownerName
       groupName:(id)groupName
     chmodString:(id)chmodString
{
	return ([self _copyPath:source toPath:dest delegate:delegate
	    ownerName:ownerName groupName:groupName chmodString:chmodString
	    preserveFinderInfo:NO preserveResourceForks:NO]);
}

- (BOOL)copyPath:(NSString *)source toPath:(NSString *)dest delegate:(id)delegate
{
	return ([self _copyPath:source toPath:dest delegate:delegate
	    ownerName:nil groupName:nil chmodString:nil
	    preserveFinderInfo:NO preserveResourceForks:NO]);
}

- (BOOL)movePath:(NSString *)source
          toPath:(NSString *)dest
        delegate:(id)delegate
       ownerName:(id)ownerName
       groupName:(id)groupName
     chmodString:(id)chmodString
preserveFinderInfo:(BOOL)preserveFinderInfo
preserveResourceForks:(BOOL)preserveResourceForks
{
	if (![self moveItemAtPath:source toPath:dest error:NULL])
		return (NO);
	if ([chmodString isKindOfClass:[NSString class]]) {
		NSUInteger permissions;
		NSDictionary *attributes = [TSFM()
		    attributesOfItemAtPath:dest error:NULL];

		permissions = [[attributes objectForKey:NSFilePosixPermissions]
		    unsignedIntegerValue];
		permissions = [self posixPermissionsByApplyingChmodString:chmodString
		    to:permissions];
		if (![self setAttributes:
		    [NSDictionary dictionaryWithObject:
		        [NSNumber numberWithUnsignedInteger:permissions]
		        forKey:NSFilePosixPermissions] ofItemAtPath:dest
		    error:NULL])
			return (NO);
	}
	if (preserveFinderInfo &&
	    ![self copyFinderInfoFromPath:dest toPath:dest])
		return (NO);
	if (preserveResourceForks &&
	    ![self copyResourceForkFromPath:dest toPath:dest])
		return (NO);
	(void)delegate;
	(void)ownerName;
	(void)groupName;
	return (YES);
}

- (BOOL)movePath:(NSString *)source
          toPath:(NSString *)dest
        delegate:(id)delegate
       ownerName:(id)ownerName
       groupName:(id)groupName
     chmodString:(id)chmodString
{
	return ([self movePath:source toPath:dest delegate:delegate
	    ownerName:ownerName groupName:groupName chmodString:chmodString
	    preserveFinderInfo:NO preserveResourceForks:NO]);
}

- (BOOL)movePath:(NSString *)source toPath:(NSString *)dest delegate:(id)delegate
{
	return ([self movePath:source toPath:dest delegate:delegate
	    ownerName:nil groupName:nil chmodString:nil
	    preserveFinderInfo:NO preserveResourceForks:NO]);
}

@end
