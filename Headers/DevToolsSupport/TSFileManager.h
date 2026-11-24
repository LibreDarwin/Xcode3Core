/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef DEVTOOLSSUPPORT_TSFILEMANAGER_H
#define DEVTOOLSSUPPORT_TSFILEMANAGER_H

#import <Foundation/Foundation.h>

@interface TSFileManager : NSObject

+ (id)defaultManager;

- (BOOL)setAttributes:(NSDictionary *)attributes
         ofItemAtPath:(NSString *)path
                error:(NSError **)error;
- (BOOL)changeFileAttributes:(NSDictionary *)attributes atPath:(NSString *)path;
- (BOOL)linkItemAtPath:(NSString *)source
                toPath:(NSString *)dest
                 error:(NSError **)error;
- (BOOL)copyItemAtPath:(NSString *)source
                toPath:(NSString *)dest
                 error:(NSError **)error;
- (BOOL)copyPath:(NSString *)source toPath:(NSString *)dest handler:(id)handler;
- (BOOL)moveItemAtPath:(NSString *)source
                toPath:(NSString *)dest
                 error:(NSError **)error;
- (BOOL)movePath:(NSString *)source toPath:(NSString *)dest handler:(id)handler;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)removeFileAtPath:(NSString *)path handler:(id)handler;
- (BOOL)createDirectoryAtPath:(NSString *)path
    withIntermediateDirectories:(BOOL)intermediate
                     attributes:(NSDictionary *)attributes
                          error:(NSError **)error;
- (BOOL)createDirectoryAtPath:(NSString *)path
                   attributes:(NSDictionary *)attributes;
- (BOOL)createFileAtPath:(NSString *)path
                contents:(NSData *)contents
              attributes:(NSDictionary *)attributes;
- (BOOL)createSymbolicLinkAtPath:(NSString *)path
             withDestinationPath:(NSString *)dest
                           error:(NSError **)error;
- (BOOL)createDirectoryAtPath:(NSString *)path
                   attributes:(NSDictionary *)attributes
                      recurse:(BOOL)recurse;
- (BOOL)isDirectoryAtPath:(NSString *)path traverseLink:(BOOL)traverseLink;
- (NSUInteger)posixPermissionsByApplyingChmodString:(NSString *)string
                                                 to:(NSUInteger)mode;
- (BOOL)copyOwnerGroupAndPermissionsFromPath:(NSString *)source
                                     toPath:(NSString *)dest;
- (BOOL)copyPermissionsFromPath:(NSString *)source toPath:(NSString *)dest;
- (BOOL)copyFinderInfoFromPath:(NSString *)source toPath:(NSString *)dest;
- (BOOL)copyResourceForkFromPath:(NSString *)source toPath:(NSString *)dest;
- (BOOL)_copyPath:(NSString *)source
          toPath:(NSString *)dest
        delegate:(id)delegate
       ownerName:(id)ownerName
       groupName:(id)groupName
     chmodString:(id)chmodString
preserveFinderInfo:(BOOL)preserveFinderInfo
preserveResourceForks:(BOOL)preserveResourceForks;
- (BOOL)copyPath:(NSString *)source
          toPath:(NSString *)dest
        delegate:(id)delegate
       ownerName:(id)ownerName
       groupName:(id)groupName
     chmodString:(id)chmodString
preserveFinderInfo:(BOOL)preserveFinderInfo
preserveResourceForks:(BOOL)preserveResourceForks;
- (BOOL)copyPath:(NSString *)source
          toPath:(NSString *)dest
        delegate:(id)delegate
       ownerName:(id)ownerName
       groupName:(id)groupName
     chmodString:(id)chmodString;
- (BOOL)copyPath:(NSString *)source toPath:(NSString *)dest delegate:(id)delegate;
- (BOOL)movePath:(NSString *)source
          toPath:(NSString *)dest
        delegate:(id)delegate
       ownerName:(id)ownerName
       groupName:(id)groupName
     chmodString:(id)chmodString
preserveFinderInfo:(BOOL)preserveFinderInfo
preserveResourceForks:(BOOL)preserveResourceForks;
- (BOOL)movePath:(NSString *)source
          toPath:(NSString *)dest
        delegate:(id)delegate
       ownerName:(id)ownerName
       groupName:(id)groupName
     chmodString:(id)chmodString;
- (BOOL)movePath:(NSString *)source toPath:(NSString *)dest delegate:(id)delegate;

@end

#endif	/* DEVTOOLSSUPPORT_TSFILEMANAGER_H */
