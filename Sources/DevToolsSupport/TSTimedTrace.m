/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsSupport/TSTimedTrace.h"

#import <math.h>
#import <objc/runtime.h>
#import <unistd.h>

static NSMutableSet *TSTraceEnabledNames = nil;
static NSMutableDictionary *TSTraceObjects = nil;

static NSString *
TSTimedTraceIndentationString(NSUInteger level)
{
	NSMutableString *result = [NSMutableString string];

	for (NSUInteger index = 0; index < level; index++)
		[result appendString:@"   "];
	return (result);
}

@implementation TSTimedTraceSubtrace

- (id)initWithStartTime:(double)startTime
        userDescription:(NSString *)userDescription
{
	self = [super init];
	if (self == nil)
		return (nil);
	_startTime = startTime;
	_lastMarkTime = startTime;
	_userDescription = [userDescription copy];
	_markCount = 0;
	_averageTimeBetweenMarks = 0.0;
	return (self);
}

- (double)startTime
{
	return (_startTime);
}

- (void)setStartTime:(double)startTime
{
	_startTime = startTime;
}

- (NSString *)userDescription
{
	return (_userDescription);
}

- (double)lastMarkTime
{
	return (_lastMarkTime);
}

- (void)setLastMarkTime:(double)lastMarkTime
{
	double delta = lastMarkTime - _lastMarkTime;

	_lastMarkTime = lastMarkTime;
	_averageTimeBetweenMarks =
	    (_averageTimeBetweenMarks * (double)_markCount + delta) /
	    (double)(_markCount + 1);
	_markCount++;
}

- (double)averageTimeBetweenMarks
{
	return (_averageTimeBetweenMarks);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%s:%p:%@>",
	    class_getName([self class]), self, _userDescription]);
}

@end

@implementation TSTimedTrace

+ (void)initialize
{
	if (self == [TSTimedTrace class]) {
		TSTraceObjects = [[NSMutableDictionary alloc] init];
	}
}

+ (NSSet *)_enabledTraceNames
{
	if (TSTraceEnabledNames == nil) {
		NSArray *names = [[NSUserDefaults standardUserDefaults]
		    stringArrayForKey:@"TSEnabledTimedTraces"];

		if (names == nil)
			TSTraceEnabledNames = [[NSMutableSet alloc] init];
		else
			TSTraceEnabledNames = [[NSMutableSet alloc]
			    initWithArray:names];
	}
	return (TSTraceEnabledNames);
}

+ (NSDictionary *)_namesToTraceObjectsDictionary
{
	if (TSTraceObjects == nil)
		TSTraceObjects = [[NSMutableDictionary alloc] init];
	return (TSTraceObjects);
}

+ (BOOL)shouldCreateTimedTraceWithName:(NSString *)name
{
	if (name == nil || [name length] == 0)
		return (NO);
	return ([[self _enabledTraceNames] containsObject:name]);
}

+ (id)timedTraceWithName:(NSString *)name
{
	TSTimedTrace *trace;

	if (name == nil || [name length] == 0)
		return (nil);
	trace = [[self _namesToTraceObjectsDictionary] objectForKey:name];
	if (trace != nil) {
		if ([trace isKindOfClass:[TSTimedTrace class]])
			return (trace);
		return (nil);
	}
	if (![self shouldCreateTimedTraceWithName:name])
		return (nil);
	trace = [[TSTimedTrace alloc] initWithName:name];
	if (trace != nil)
		[(NSMutableDictionary *)[self _namesToTraceObjectsDictionary]
		    setObject:trace forKey:name];
	return (trace);
}

- (id)init
{
	return (nil);
}

- (id)initWithName:(NSString *)name
{
	self = [super init];
	if (self == nil)
		return (nil);
	if (name == nil || [name length] == 0)
		return (nil);
	_name = [name copy];
	_outputFileDesc = STDOUT_FILENO;
	_closeOutputFileDescWhenDone = NO;
	_activeSubtraces = [[NSMutableArray alloc] init];
	NSString *description = [NSString stringWithFormat:
	    @"Start of trace '%@'", _name];
	TSTimedTraceSubtrace *subtrace = [[TSTimedTraceSubtrace alloc]
	    initWithStartTime:[NSDate timeIntervalSinceReferenceDate]
	    userDescription:description];
	[_activeSubtraces addObject:subtrace];
	return (self);
}

- (void)dealloc
{
	if (_outputFileDesc >= 3 && _closeOutputFileDescWhenDone)
		close(_outputFileDesc);
}

- (void)setOutputFileDescriptor:(int)descriptor
                  closeWhenDone:(BOOL)closeWhenDone
{
	if (_outputFileDesc >= 3 && _closeOutputFileDescWhenDone)
		close(_outputFileDesc);
	_outputFileDesc = descriptor;
	_closeOutputFileDescWhenDone = closeWhenDone;
}

- (int)outputFileDescriptor
{
	return (_outputFileDesc);
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%s:%p:%@>",
	    class_getName([self class]), self, _name]);
}

- (NSUInteger)currentSubtraceLevel
{
	if ([_activeSubtraces count] == 0)
		return (0);
	return ([_activeSubtraces count] - 1);
}

- (TSTimedTraceSubtrace *)toplevelSubtrace
{
	if ([_activeSubtraces count] == 0)
		return (nil);
	return ([_activeSubtraces objectAtIndex:0]);
}

- (TSTimedTraceSubtrace *)currentSubtrace
{
	return ([_activeSubtraces lastObject]);
}

- (void)_emitString:(NSString *)string
{
	const char *bytes = [string UTF8String];

	if (bytes != NULL)
		write(_outputFileDesc, bytes, strlen(bytes));
}

- (void)_emitLineWithCurrentTime:(double)currentTime
           timeIntoTrace:(double)timeIntoTrace
        timeIntoSubtrace:(double)timeIntoSubtrace
       timeSinceLastMark:(double)timeSinceLastMark
 averageTimeBetweenMarks:(double)averageTimeBetweenMarks
         typeTokenString:(NSString *)typeTokenString
         userDescription:(NSString *)userDescription
{
	NSString *indentation = TSTimedTraceIndentationString(
	    [self currentSubtraceLevel]);
	double currentMilliseconds =
	    (currentTime - trunc(currentTime)) * 1000.0;
	NSString *line;

	if (timeSinceLastMark < 0.0) {
		line = [NSString stringWithFormat:
		    @"TRACE: %@%@  %@   %7.2fms %7.2fms %7.2fms                      %@\n",
		    _name, indentation, typeTokenString, currentMilliseconds,
		    timeIntoTrace * 1000.0, timeIntoSubtrace * 1000.0,
		    userDescription];
	} else if (averageTimeBetweenMarks < 0.0) {
		line = [NSString stringWithFormat:
		    @"TRACE: %@%@  %@   %7.2fms %7.2fms %7.2fms %7.2fms            %@\n",
		    _name, indentation, typeTokenString, currentMilliseconds,
		    timeIntoTrace * 1000.0, timeIntoSubtrace * 1000.0,
		    timeSinceLastMark * 1000.0, userDescription];
	} else {
		line = [NSString stringWithFormat:
		    @"TRACE: %@%@  %@   %7.2fms %7.2fms %7.2fms %7.2fms %7.2fms  %@\n",
		    _name, indentation, typeTokenString, currentMilliseconds,
		    timeIntoTrace * 1000.0, timeIntoSubtrace * 1000.0,
		    timeSinceLastMark * 1000.0,
		    averageTimeBetweenMarks * 1000.0, userDescription];
	}
	[self _emitString:line];
}

- (void)beginSubtraceWithDescription:(NSString *)description
{
	double now = [NSDate timeIntervalSinceReferenceDate];
	NSUInteger level = [self currentSubtraceLevel];
	NSString *formatted = [NSString stringWithFormat:@"       %@\n",
	    description];
	TSTimedTraceSubtrace *top;
	TSTimedTraceSubtrace *subtrace;

	if (level == 0)
		[[self toplevelSubtrace] setStartTime:now];
	subtrace = [[TSTimedTraceSubtrace alloc] initWithStartTime:now
	    userDescription:formatted];
	[_activeSubtraces addObject:subtrace];
	top = [self toplevelSubtrace];
	subtrace = [self currentSubtrace];
	[self _emitLineWithCurrentTime:now
	    timeIntoTrace:now - [top startTime]
	    timeIntoSubtrace:now - [subtrace startTime]
	    timeSinceLastMark:-1.0
	    averageTimeBetweenMarks:-1.0
	    typeTokenString:@"<< "
	    userDescription:formatted];
}

- (void)markWithDescription:(NSString *)description
{
	double now = [NSDate timeIntervalSinceReferenceDate];
	TSTimedTraceSubtrace *top = [self toplevelSubtrace];
	TSTimedTraceSubtrace *subtrace = [self currentSubtrace];

	[self _emitLineWithCurrentTime:now
	    timeIntoTrace:now - [top startTime]
	    timeIntoSubtrace:now - [subtrace startTime]
	    timeSinceLastMark:now - [subtrace lastMarkTime]
	    averageTimeBetweenMarks:-1.0
	    typeTokenString:@" | "
	    userDescription:description];
	[subtrace setLastMarkTime:now];
}

- (void)endSubtraceWithDescription:(NSString *)description
{
	double now;
	TSTimedTraceSubtrace *top;
	TSTimedTraceSubtrace *subtrace;
	double previousLastMarkTime;

	if ([_activeSubtraces count] <= 1) {
		[self _emitString:
		    @"TRACE: -endSubtraceWithDescription: stack underflow\n"];
		return;
	}
	now = [NSDate timeIntervalSinceReferenceDate];
	subtrace = [self currentSubtrace];
	previousLastMarkTime = [subtrace lastMarkTime];
	[subtrace setLastMarkTime:now];
	top = [self toplevelSubtrace];
	[self _emitLineWithCurrentTime:now
	    timeIntoTrace:now - [top startTime]
	    timeIntoSubtrace:now - [subtrace startTime]
	    timeSinceLastMark:now - previousLastMarkTime
	    averageTimeBetweenMarks:[subtrace averageTimeBetweenMarks]
	    typeTokenString:@">> "
	    userDescription:description];
	[_activeSubtraces removeLastObject];
}

@end
