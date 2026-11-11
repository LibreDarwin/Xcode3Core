/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsSupport's TSPropertyListDictionary.
 *
 * The class is an immutable NSDictionary facade over a plain dictionary that
 * adds localized type-checked accessors.  A missing required key, or a value
 * of the wrong class, raises TSPropertyListDictionaryInconsistencyException
 * with the same messages Apple uses.  Argument validation in Apple's build is
 * expressed with DVTAssert(); we raise NSInvalidArgumentException with the
 * same text instead of depending on DVTFoundation.
 */

#import "DevToolsSupport/TSPropertyListDictionary.h"

#import <objc/runtime.h>

static NSString *const TSPropertyListDictionaryException = @"TSPropertyListDictionaryInconsistencyException";

static NSString *
TSLocalizedString(NSString *key, NSString *fallback)
{
    static NSBundle *bundle = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bundle = [NSBundle bundleForClass:NSClassFromString(@"TSPropertyListDictionary")];
    });
    if (bundle != nil) {
        NSString *value = [bundle localizedStringForKey:key value:nil table:@"DevToolsSupport"];
        if (value != nil && ![value isEqualToString:key]) {
            return value;
        }
    }
    return fallback;
}

static void
TSRequireKindOfClass(id object, Class expectedClass)
{
    if (object != nil && ![object isKindOfClass:expectedClass]) {
        [NSException raise:NSInvalidArgumentException
                    format:TSLocalizedString(@"%@ should be an instance inheriting from %@, but it is %@",
                                             @"%@ should be an instance inheriting from %@, but it is %@"),
                           object,
                           NSStringFromClass(expectedClass),
                           NSStringFromClass(object_getClass(object))];
    }
}

@implementation TSPropertyListDictionary

+ (id)propertyListDictionaryWithDictionary:(id)dictionary
{
    return [[self alloc] initWithDictionary:dictionary];
}

+ (id)propertyListDictionaryWithContentsOfString:(id)string
{
    return [[self alloc] initWithContentsOfString:string];
}

- (id)init
{
    return [self initWithDictionary:nil];
}

- (id)initWithDictionary:(id)dictionary
{
    self = [super init];
    if (self != nil) {
        TSRequireKindOfClass(dictionary, [NSDictionary class]);
        _dict = [dictionary copy];
        if (_dict == nil) {
            _dict = [[NSDictionary alloc] init];
        }
        _localizedDesc = [TSLocalizedString(@"property list dictionary",
                                            @"property list dictionary") copy];
        _bundle = nil;
        _localizationDict = nil;
    }
    return self;
}

- (id)initWithContentsOfString:(id)string
{
    TSRequireKindOfClass(string, [NSString class]);

    id propertyList = [string propertyList];
    if (propertyList != nil && ![propertyList isKindOfClass:[NSDictionary class]]) {
        [NSException raise:TSPropertyListDictionaryException
                    format:TSLocalizedString(@"Top level container should be an NSDictionary but is an %@",
                                             @"Top level container should be an NSDictionary but is an %@"),
                           [self _localizedTypeNameForClass:object_getClass(propertyList)]];
    }
    return [self initWithDictionary:propertyList];
}

- (id)initWithContentsOfFile:(id)file encoding:(unsigned long long)encoding
{
    NSString *contents = [NSString stringWithContentsOfFile:file
                                                   encoding:(NSStringEncoding)encoding
                                                      error:NULL];
    return [self initWithContentsOfString:contents];
}

- (void)dealloc
{
}

- (id)_localizedTypeNameForClass:(Class)aClass
{
    if (aClass != Nil) {
        if ([aClass isSubclassOfClass:[NSString class]]) {
            return TSLocalizedString(@"a string", @"a string");
        }
        if ([aClass isSubclassOfClass:[NSData class]]) {
            return TSLocalizedString(@"a data block", @"a data block");
        }
        if ([aClass isSubclassOfClass:[NSDictionary class]]) {
            return TSLocalizedString(@"a dictionary", @"a dictionary");
        }
        if ([aClass isSubclassOfClass:[NSArray class]]) {
            return TSLocalizedString(@"an array", @"an array");
        }
        return [NSString stringWithFormat:TSLocalizedString(@"an %@", @"an %@"),
                                          NSStringFromClass(aClass)];
    }
    return TSLocalizedString(@"an %@", @"an %@");
}

- (id)bundle
{
    return _bundle;
}

- (void)setBundle:(id)bundle
{
    TSRequireKindOfClass(bundle, [NSBundle class]);
    if (_bundle != bundle) {
        _bundle = bundle;
    }
}

- (id)localizationDictionary
{
    return _localizationDict;
}

- (void)setLocalizationDictionary:(id)dictionary
{
    TSRequireKindOfClass(dictionary, [NSDictionary class]);
    if (_localizationDict != dictionary) {
        _localizationDict = dictionary;
    }
}

- (unsigned long long)count
{
    return [_dict count];
}

- (id)keyEnumerator
{
    return [_dict keyEnumerator];
}

- (id)objectForKey:(id)key
{
    id object;
    if ([key isKindOfClass:[NSString class]] && [(NSString *)key isEqualToString:@""]) {
        return self;
    }
    object = [_dict objectForKey:key];
    if (object == nil) {
        [NSException raise:TSPropertyListDictionaryException
                    format:TSLocalizedString(@"malformed %@ (required key '%@' not present)",
                                             @"malformed %@ (required key '%@' not present)"),
                           _localizedDesc, key];
    }
    return object;
}

- (id)objectOrNilForKey:(id)key
{
    if ([key isKindOfClass:[NSString class]] && [(NSString *)key isEqualToString:@""]) {
        return self;
    }
    return [_dict objectForKey:key];
}

- (id)_typedObjectForKey:(id)key
                  class:(Class)expectedClass
               optional:(BOOL)optional
{
    id object;
    if ([key isKindOfClass:[NSString class]] && [(NSString *)key isEqualToString:@""]) {
        object = self;
    } else {
        object = [_dict objectForKey:key];
    }
    if (object == nil) {
        if (!optional) {
            [NSException raise:TSPropertyListDictionaryException
                        format:TSLocalizedString(@"malformed %@ (required key '%@' not present)",
                                                 @"malformed %@ (required key '%@' not present)"),
                               _localizedDesc, key];
        }
        return nil;
    }
    if (![object isKindOfClass:expectedClass]) {
        NSString *format = optional
            ? TSLocalizedString(@"malformed %@ (optional key '%@' should be %@, but is %@)",
                                @"malformed %@ (optional key '%@' should be %@, but is %@)")
            : TSLocalizedString(@"malformed %@ (required key '%@' should be %@, but is %@)",
                                @"malformed %@ (required key '%@' should be %@, but is %@)");
        [NSException raise:TSPropertyListDictionaryException
                    format:format,
                           _localizedDesc, key,
                           [self _localizedTypeNameForClass:expectedClass],
                           [self _localizedTypeNameForClass:object_getClass(object)]];
    }
    return object;
}

- (id)stringForKey:(id)key
{
    return [self _typedObjectForKey:key class:[NSString class] optional:NO];
}

- (id)stringOrNilForKey:(id)key
{
    return [self _typedObjectForKey:key class:[NSString class] optional:YES];
}

- (id)dataForKey:(id)key
{
    return [self _typedObjectForKey:key class:[NSData class] optional:NO];
}

- (id)dictionaryForKey:(id)key
{
    return [self _typedObjectForKey:key class:[NSDictionary class] optional:NO];
}

- (id)dictionaryOrNilForKey:(id)key
{
    return [self _typedObjectForKey:key class:[NSDictionary class] optional:YES];
}

- (id)arrayForKey:(id)key
{
    return [self _typedObjectForKey:key class:[NSArray class] optional:NO];
}

- (id)arrayOrNilForKey:(id)key
{
    return [self _typedObjectForKey:key class:[NSArray class] optional:YES];
}

- (id)arrayOrObjectOrNilForKey:(id)key
{
    id object = [self objectOrNilForKey:key];
    if (object == nil || [object isKindOfClass:[NSArray class]]) {
        return object;
    }
    return [NSArray arrayWithObject:object];
}

@end
