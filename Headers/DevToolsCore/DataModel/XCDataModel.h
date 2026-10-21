/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * DataModel base classes (DevToolsCore). */

#ifndef DEVTOOLSCORE_DATAMODEL_XCDATAMODEL_H
#define DEVTOOLSCORE_DATAMODEL_XCDATAMODEL_H

#import <Foundation/Foundation.h>

@interface XCDataModel : NSObject
{
	NSString *_name;
	NSString *_path;
	NSMutableArray *_entities;
	NSMutableArray *_configurations;
}

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, readonly) NSArray *entities;
@property (nonatomic, readonly) NSArray *configurations;

- (BOOL)loadFromContentsOfFile:(NSString *)path error:(NSError **)error;
- (BOOL)writeToFile:(NSString *)path error:(NSError **)error;

@end

#endif	/* DEVTOOLSCORE_DATAMODEL_XCDATAMODEL_H */
