/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * PList archiver support for DevToolsCore. */

#import "DevToolsCore/ProjectModel/PBXPListArchiver.h"
#import "DevToolsCore/PBXObjectID.h"

static NSMutableDictionary *PBXPListClassSubstitutions;

static NSString *
PBXPListArchiveClassName(id object)
{
	if ([object respondsToSelector:@selector(classNameForPListArchive)]) {
		NSString *name = [object performSelector:@selector(classNameForPListArchive)];

		if (name != nil)
			return (name);
	}
	return (NSStringFromClass([object class]));
}

static NSString *
PBXPListArchiveFallbackClassName(id object)
{
	if (![object respondsToSelector:@selector(fallbackClassNameForPListArchive)])
		return (nil);
	return ([object performSelector:@selector(fallbackClassNameForPListArchive)]);
}

static BOOL
PBXPListObjectHasUserKeys(id object)
{
	Class cls = [object class];

	if ([cls respondsToSelector:@selector(hasUserKeys)])
		return ([cls performSelector:@selector(hasUserKeys)]);
	return (NO);
}

static NSString *
PBXPListObjectIDString(id object)
{
	id objectID;

	if (object == nil || ![object respondsToSelector:@selector(objectID)])
		return (nil);
	objectID = [object performSelector:@selector(objectID)];
	if (objectID == nil)
		return (nil);
	return ([objectID description]);
}

static id
PBXPListRootObjectID(id object)
{
	NSString *string = PBXPListObjectIDString(object);
	id objectID;

	if (string == nil)
		return (@"nil");
	if ([object respondsToSelector:@selector(objectID)]) {
		objectID = [object performSelector:@selector(objectID)];
		if (objectID != nil)
			return (objectID);
	}
	objectID = [[PBXObjectID alloc] initFromStringRepresentation:string];
	return (objectID ?: string);
}

static NSRange
PBXPListRangeFromString(id value)
{
	NSArray *parts;
	NSUInteger location = 0;
	NSUInteger length = 0;

	if (![value isKindOfClass:[NSString class]])
		return (NSMakeRange(0, 0));
	parts = [value componentsSeparatedByCharactersInSet:
	    [NSCharacterSet whitespaceCharacterSet]];
	if ([parts count] > 0)
		location = (NSUInteger)[[parts objectAtIndex:0] integerValue];
	if ([parts count] > 1)
		length = (NSUInteger)[[parts objectAtIndex:1] integerValue];
	return (NSMakeRange(location, length));
}

@interface PBXPListArchiver ()
- (void)archiveObject:(id)object intoDictionary:(NSMutableDictionary *)values;
- (void)archiveUserObject:(id)object globalID:(NSString *)globalID weakly:(BOOL)weakly;
- (NSString *)archiveObjectReference:(id)object weakly:(BOOL)weakly;
@end

@implementation PBXPListArchiver

+ (NSDictionary *)plistArchiveWithRootObject:(id)root
    delegate:(id)delegate
    role:(NSUInteger)role
{
	PBXPListArchiver *archiver = [[self alloc] initWithRootObject:root
	    delegate:delegate role:role];

	return ([archiver plistArchive]);
}

+ (id)currentArchiveFormat
{
	return (nil);
}

- (instancetype)init
{
	return ([self initWithRootObject:nil delegate:nil role:0]);
}

- (instancetype)initWithRootObject:(id)root
    delegate:(id)delegate
    role:(NSUInteger)role
{
	if ((self = [super init]) != nil) {
		_role = role;
		_delegate = delegate;
		_classTable = [[NSMutableDictionary alloc] init];
		_objectTable = [[NSMutableDictionary alloc] init];
		_userObjects = [[NSMutableArray alloc] init];
		_currentArchiveDict = [[NSMutableDictionary alloc] init];
		_archiveDictionary = [[NSMutableDictionary alloc]
		    initWithObjectsAndKeys:@"1", @"archiveVersion",
		    _classTable, @"classes", _objectTable, @"objects",
		    PBXPListRootObjectID(root), @"rootObject", nil];

		if (root != nil) {
			NSString *globalID = PBXPListObjectIDString(root);

			if (globalID != nil)
				[self archiveObject:root intoDictionary:
				    [NSMutableDictionary dictionary]];
			if (PBXPListObjectHasUserKeys(root) && globalID != nil) {
				NSMutableDictionary *saved = _currentArchiveDict;
				NSMutableDictionary *settings =
				    [NSMutableDictionary dictionary];

				if (_userSettingsTable == nil)
					_userSettingsTable =
					    [[NSMutableDictionary alloc] init];

				_currentArchiveDict = settings;
				if ([root respondsToSelector:
				    @selector(writeUserSettingsToPListArchiver:)])
					[root performSelector:
					    @selector(writeUserSettingsToPListArchiver:)
					    withObject:self];
				_currentArchiveDict = saved;
				[_userSettingsTable setObject:settings forKey:globalID];
			}
		}
	}
	return (self);
}

- (void)archiveObject:(id)object intoDictionary:(NSMutableDictionary *)values
{
	NSString *globalID = PBXPListObjectIDString(object);
	NSString *fallback;

	if (globalID == nil || [_objectTable objectForKey:globalID] != nil)
		return;
	[values setObject:PBXPListArchiveClassName(object) forKey:@"isa"];
	fallback = PBXPListArchiveFallbackClassName(object);
	if (fallback != nil)
		[values setObject:fallback forKey:@"fallbackIsa"];
	if ([object respondsToSelector:@selector(writeToPListArchiver:)]) {
		NSMutableDictionary *saved = _currentArchiveDict;

		_currentArchiveDict = values;
		[object performSelector:@selector(writeToPListArchiver:)
		    withObject:self];
		_currentArchiveDict = saved;
	}
	[_objectTable setObject:values forKey:globalID];
}

- (void)archiveUserObject:(id)object
    globalID:(NSString *)globalID
    weakly:(BOOL)weakly
{
	NSMutableDictionary *values;
	NSString *fallback;

	if (weakly || globalID == nil || _userSettingsTable == nil)
		return;
	if ([_userSettingsTable objectForKey:globalID] != nil)
		return;
	values = [NSMutableDictionary dictionary];
	[values setObject:PBXPListArchiveClassName(object) forKey:@"isa"];
	fallback = PBXPListArchiveFallbackClassName(object);
	if (fallback != nil)
		[values setObject:fallback forKey:@"fallbackIsa"];
	if ([object respondsToSelector:@selector(writeToPListArchiver:)]) {
		NSMutableDictionary *saved = _currentArchiveDict;

		_currentArchiveDict = values;
		[object performSelector:@selector(writeToPListArchiver:)
		    withObject:self];
		_currentArchiveDict = saved;
	}
	[_userSettingsTable setObject:values forKey:globalID];
	[_userObjects addObject:object];
}

- (NSString *)archiveObjectReference:(id)object weakly:(BOOL)weakly
{
	NSString *globalID = PBXPListObjectIDString(object);

	if (globalID == nil)
		[NSException raise:NSInvalidArgumentException
		    format:@"objectID should be an instance inheriting from PBXObjectID"];
	[self archiveUserObject:object globalID:globalID weakly:weakly];
	return (globalID);
}

- (NSDictionary *)plistArchive
{
	return (_archiveDictionary);
}

- (NSDictionary *)userSettings
{
	return (_userSettingsTable);
}

- (NSUInteger)role
{
	return (_role);
}

- (id)delegate
{
	return (_delegate);
}

- (void)setDelegate:(id)delegate
{
	_delegate = delegate;
}

- (id)archiveFormat
{
	return (_archiveFormat);
}

- (BOOL)shouldUseJuly2024Formatting
{
	return (NO);
}

- (id)keptProxyItems
{
	return (nil);
}

- (void)setKeptProxyItems:(id)items
{
	(void)items;
}

- (BOOL)shouldArchiveReferenceProxy:(id)proxy
{
	(void)proxy;
	return (NO);
}

- (void)encodeBoolean:(BOOL)value forKey:(NSString *)key
{
	if (key == nil)
		return;
	[_currentArchiveDict setObject:(value ? @"YES" : @"NO") forKey:key];
}

- (void)encodeCharacter:(unichar)value forKey:(NSString *)key
{
	if (key == nil)
		return;
	[_currentArchiveDict setObject:[NSString stringWithFormat:@"%u",
	    (unsigned int)value] forKey:key];
}

- (void)encodeInteger:(NSInteger)value forKey:(NSString *)key
{
	if (key == nil)
		return;
	[_currentArchiveDict setObject:[NSString stringWithFormat:@"%ld",
	    (long)value] forKey:key];
}

- (void)encodeFloat:(float)value forKey:(NSString *)key
{
	if (key == nil)
		return;
	[_currentArchiveDict setObject:[NSString stringWithFormat:@"%f", value]
	    forKey:key];
}

- (void)encodeDouble:(double)value forKey:(NSString *)key
{
	if (key == nil)
		return;
	[_currentArchiveDict setObject:[NSString stringWithFormat:@"%f", value]
	    forKey:key];
}

- (void)encodeRange:(NSRange)value forKey:(NSString *)key
{
	if (key == nil)
		return;
	[_currentArchiveDict setObject:[NSString stringWithFormat:@"%lu %lu",
	    (unsigned long)value.location, (unsigned long)value.length]
	    forKey:key];
}

- (void)encodeValue:(id)value forKey:(NSString *)key
{
	if (key == nil)
		return;
	[_currentArchiveDict setObject:value forKey:key];
}

- (void)encodeObject:(id)value forKey:(NSString *)key
{
	if (key == nil)
		return;
	[_currentArchiveDict setObject:[self archiveObjectReference:value weakly:NO]
	    forKey:key];
}

- (void)encodeObjectWeakly:(id)value forKey:(NSString *)key
{
	if (key == nil)
		return;
	[_currentArchiveDict setObject:[self archiveObjectReference:value weakly:YES]
	    forKey:key];
}

- (void)encodeObjectArray:(NSArray *)value forKey:(NSString *)key
{
	[self encodeObjectArray:value forKey:key weakly:NO];
}

- (void)encodeObjectArrayWeakly:(NSArray *)value forKey:(NSString *)key
{
	[self encodeObjectArray:value forKey:key weakly:YES];
}

- (void)encodeObjectArray:(NSArray *)value
    forKey:(NSString *)key
    weakly:(BOOL)weakly
{
	NSMutableArray *archived;

	if (key == nil)
		return;
	archived = [NSMutableArray arrayWithCapacity:[value count]];
	for (id object in value)
		[archived addObject:[self archiveObjectReference:object weakly:weakly]];
	[_currentArchiveDict setObject:archived forKey:key];
}

- (void)encodeObjectDictionary:(NSDictionary *)value forKey:(NSString *)key
{
	[self encodeObjectDictionary:value forKey:key weakly:NO];
}

- (void)encodeObjectDictionaryWeakly:(NSDictionary *)value forKey:(NSString *)key
{
	[self encodeObjectDictionary:value forKey:key weakly:YES];
}

- (void)encodeObjectDictionary:(NSDictionary *)value
    forKey:(NSString *)key
    weakly:(BOOL)weakly
{
	NSMutableDictionary *archived;

	if (key == nil)
		return;
	archived = [NSMutableDictionary dictionaryWithCapacity:[value count]];
	for (id objectKey in value) {
		id archivedObject = [self archiveObjectReference:
		    [value objectForKey:objectKey] weakly:weakly];

		[archived setObject:archivedObject forKey:objectKey];
	}
	[_currentArchiveDict setObject:archived forKey:key];
}

- (void)encodeString:(id)value forKey:(NSString *)key
{
	[self encodeValue:value forKey:key];
}

- (void)encodePListArray:(id)value forKey:(NSString *)key
{
	[self encodeValue:value forKey:key];
}

- (void)encodePListDictionary:(id)value forKey:(NSString *)key
{
	[self encodeValue:value forKey:key];
}

- (void)encodeBool:(BOOL)value forKey:(NSString *)key
{
	[self encodeBoolean:value forKey:key];
}

- (NSDictionary *)archive
{
	return ([self plistArchive]);
}

@end

@implementation PBXPListUnarchiver

+ (void)initialize
{
	if (self == [PBXPListUnarchiver class] && PBXPListClassSubstitutions == nil)
		PBXPListClassSubstitutions = [[NSMutableDictionary alloc] init];
}

+ (id)unarchivedRootObjectFromPListArchive:(NSDictionary *)archive
{
	PBXPListUnarchiver *unarchiver = [[self alloc] initWithPListArchive:archive];

	return ([unarchiver decodeRootObject]);
}

+ (void)setClassName:(NSString *)className
    decodedForArchiveClassName:(NSString *)archiveClassName
{
	if (className == nil || archiveClassName == nil)
		return;
	[PBXPListClassSubstitutions setObject:className forKey:archiveClassName];
}

+ (NSString *)classNameDecodedForArchiveClassName:(NSString *)archiveClassName
{
	if (archiveClassName == nil)
		return (nil);
	return ([PBXPListClassSubstitutions objectForKey:archiveClassName]
	    ?: archiveClassName);
}

+ (id)currentArchiveFormat
{
	return (nil);
}

- (instancetype)initWithPListArchive:(NSDictionary *)archive
{
	if ((self = [super init]) != nil) {
		NSDictionary *contents = (archive ?: [NSDictionary dictionary]);

		_archiveDictionary = [contents copy];
		_classTable = [[contents objectForKey:@"classes"] copy] ?:
		    [[NSDictionary alloc] init];
		_objectTable = [[contents objectForKey:@"objects"] copy] ?:
		    [[NSDictionary alloc] init];
		_userSettingsTable = [[contents objectForKey:@"userSettings"] copy] ?:
		    [[NSDictionary alloc] init];
		_contextInfo = [[contents objectForKey:@"contextInfo"] copy] ?:
		    [[NSDictionary alloc] init];
		_archivedObjectVersion = (NSUInteger)[[contents
		    objectForKey:@"archiveVersion"] integerValue];
		_translatedGlobalIDs = [[NSMutableDictionary alloc] init];
		_substituteClassNames = [[NSMutableDictionary alloc] init];
		_unarchivedObjects = [[NSMutableArray alloc] init];
		_unarchivedObjectsByGID = [[NSMutableDictionary alloc] init];
	}
	return (self);
}

- (id)rootObject
{
	return (_rootObject);
}

- (id)decodeRootObject
{
	id rootID = [_archiveDictionary objectForKey:@"rootObject"];
	id object = [self decodeObjectForKey:[rootID description]];

	_rootObject = object;
	return (object);
}

- (id)valueForKey:(NSString *)key
{
	NSAssert([_currentArchiveDict isKindOfClass:[NSDictionary class]],
	    @"_currentArchiveDict should be an instance inheriting from NSDictionary");
	if (key == nil)
		return (nil);
	return ([_currentArchiveDict objectForKey:key]);
}

- (BOOL)hasValueForKey:(NSString *)key
{
	return ([self valueForKey:key] != nil);
}

- (BOOL)decodeBooleanForKey:(NSString *)key
{
	id value = [self valueForKey:key];

	return ([value isKindOfClass:[NSString class]] &&
	    [value isEqualToString:@"YES"]);
}

- (unichar)decodeCharacterForKey:(NSString *)key
{
	id value = [self valueForKey:key];

	if (![value isKindOfClass:[NSString class]])
		return (0);
	return ((unichar)[value integerValue]);
}

- (NSInteger)decodeIntegerForKey:(NSString *)key
{
	id value = [self valueForKey:key];

	if (![value isKindOfClass:[NSString class]])
		return (0);
	return ([value integerValue]);
}

- (float)decodeFloatForKey:(NSString *)key
{
	id value = [self valueForKey:key];

	if (![value isKindOfClass:[NSString class]])
		return (0.0f);
	return ([value floatValue]);
}

- (double)decodeDoubleForKey:(NSString *)key
{
	id value = [self valueForKey:key];

	if (![value isKindOfClass:[NSString class]])
		return (0.0);
	return ([value doubleValue]);
}

- (NSRange)decodeRangeForKey:(NSString *)key
{
	return (PBXPListRangeFromString([self valueForKey:key]));
}

- (id)decodeObjectForKey:(NSString *)key
{
	NSString *globalID = [self valueForKey:key];
	NSDictionary *values;
	Class cls;
	id object;

	if (![globalID isKindOfClass:[NSString class]])
		return (nil);
	object = [_unarchivedObjectsByGID objectForKey:globalID];
	if (object != nil)
		return (object);
	values = [_objectTable objectForKey:globalID];
	if (values == nil)
		return (nil);
	cls = NSClassFromString([[self class]
	    classNameDecodedForArchiveClassName:[values objectForKey:@"isa"]]);
	if (cls == Nil)
		cls = [NSObject class];
	object = [[cls alloc] init];
	[_unarchivedObjectsByGID setObject:object forKey:globalID];
	[_unarchivedObjects addObject:object];
	return (object);
}

- (id)decodeMutableObjectArrayForKey:(NSString *)key
{
	NSArray *values = [self valueForKey:key];
	NSMutableArray *decoded;

	if (![values isKindOfClass:[NSArray class]])
		return (nil);
	decoded = [NSMutableArray arrayWithCapacity:[values count]];
	for (id globalID in values) {
		id object = [self decodeObjectForKey:globalID];

		[decoded addObject:(object ?: [NSNull null])];
	}
	return (decoded);
}

- (id)decodeMutableObjectDictionaryForKey:(NSString *)key
{
	NSDictionary *values = [self valueForKey:key];
	NSMutableDictionary *decoded;

	if (![values isKindOfClass:[NSDictionary class]])
		return (nil);
	decoded = [NSMutableDictionary dictionaryWithCapacity:[values count]];
	for (id objectKey in values) {
		id object = [self decodeObjectForKey:[values objectForKey:objectKey]];

		[decoded setObject:(object ?: [NSNull null]) forKey:objectKey];
	}
	return (decoded);
}

- (id)decodeStringForKey:(NSString *)key
{
	id value = [self valueForKey:key];

	if (![value isKindOfClass:[NSString class]])
		return (nil);
	return (value);
}

- (id)decodeNumberForKey:(NSString *)key
{
	id value = [self valueForKey:key];

	if (value == nil)
		return (nil);
	return ([NSDecimalNumber decimalNumberWithString:[value description]]);
}

- (id)decodeMutablePListArrayForKey:(NSString *)key
{
	id value = [self valueForKey:key];

	if (![value isKindOfClass:[NSArray class]])
		return (nil);
	return ([value mutableCopy]);
}

- (id)decodeMutablePListDictionaryForKey:(NSString *)key
{
	id value = [self valueForKey:key];

	if (![value isKindOfClass:[NSDictionary class]])
		return (nil);
	return ([value mutableCopy]);
}

- (BOOL)decodeBoolForKey:(NSString *)key
{
	return ([self decodeBooleanForKey:key]);
}

@end
