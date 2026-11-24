/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#ifndef DEVTOOLSSUPPORT_TSTIMEDTRACE_H
#define DEVTOOLSSUPPORT_TSTIMEDTRACE_H

#import <Foundation/Foundation.h>

@interface TSTimedTraceSubtrace : NSObject {
	NSString *_userDescription;
	double _startTime;
	double _lastMarkTime;
	unsigned long long _markCount;
	double _averageTimeBetweenMarks;
}

- (id)initWithStartTime:(double)startTime
  userDescription:(NSString *)userDescription;
- (double)startTime;
- (void)setStartTime:(double)startTime;
- (NSString *)userDescription;
- (double)lastMarkTime;
- (void)setLastMarkTime:(double)lastMarkTime;
- (double)averageTimeBetweenMarks;

@end

@interface TSTimedTrace : NSObject {
	NSString *_name;
	int _outputFileDesc;
	BOOL _closeOutputFileDescWhenDone;
	NSMutableArray *_activeSubtraces;
}

- (id)initWithName:(NSString *)name;
- (void)setOutputFileDescriptor:(int)descriptor
                  closeWhenDone:(BOOL)closeWhenDone;
- (int)outputFileDescriptor;
- (NSUInteger)currentSubtraceLevel;
- (id)toplevelSubtrace;
- (id)currentSubtrace;
- (void)_emitString:(NSString *)string;
- (void)_emitLineWithCurrentTime:(double)currentTime
           timeIntoTrace:(double)timeIntoTrace
        timeIntoSubtrace:(double)timeIntoSubtrace
       timeSinceLastMark:(double)timeSinceLastMark
 averageTimeBetweenMarks:(double)averageTimeBetweenMarks
         typeTokenString:(NSString *)typeTokenString
         userDescription:(NSString *)userDescription;
- (void)beginSubtraceWithDescription:(NSString *)description;
- (void)markWithDescription:(NSString *)description;
- (void)endSubtraceWithDescription:(NSString *)description;

+ (NSSet *)_enabledTraceNames;
+ (NSDictionary *)_namesToTraceObjectsDictionary;
+ (BOOL)shouldCreateTimedTraceWithName:(NSString *)name;
+ (id)timedTraceWithName:(NSString *)name;

@end

#endif	/* DEVTOOLSSUPPORT_TSTIMEDTRACE_H */
