/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsCore/DataModel/XCDataModel.h"

@implementation XCDataModel

- (instancetype)init
{
	if ((self = [super init]) != nil) {
		_entities = [[NSMutableArray alloc] init];
		_configurations = [[NSMutableArray alloc] init];
	}
	return (self);
}

- (NSArray *)entities
{
	return ([_entities copy]);
}

- (NSArray *)configurations
{
	return ([_configurations copy]);
}

- (BOOL)loadFromContentsOfFile:(NSString *)path error:(NSError **)error
{
	(void)path;
	(void)error;
	return (NO);
}

- (BOOL)writeToFile:(NSString *)path error:(NSError **)error
{
	(void)path;
	(void)error;
	return (NO);
}

@end
