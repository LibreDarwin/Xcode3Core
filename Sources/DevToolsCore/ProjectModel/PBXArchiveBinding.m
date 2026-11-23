/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Archive binding implementations for the project-model object graph. */

#import "DevToolsCore/ProjectModel/PBXArchiveBinding.h"
#import "DevToolsCore/ProjectModel/PBXArchivingBinding.h"
#import "DevToolsCore/ProjectModel/PBXUnarchivingBinding.h"
#import "DevToolsCore/PBXObject.h"
#import <objc/runtime.h>

@protocol LBSArchiveBindingClassQueries
+ (NSString *)archiveNameForKey:(NSString *)key;
+ (BOOL)canArchiveAnyClassForKey:(NSString *)key;
@end

@interface NSKeyBinding : NSObject
- (NSString *)key;
- (Class)targetClass;
- (void)setKey:(NSString *)key;
@end

@interface NSKeyGetBinding : NSKeyBinding
- (id)getValueFromObject:(id)object;
@end

@interface NSKeySetBinding : NSKeyBinding
- (BOOL)isScalarProperty;
- (void)setValue:(id)value inObject:(id)object;
@end

@interface PBXArchivingBinding (LBSPrivate)
- (void)lbs_setArchiveKey:(NSString *)archiveKey
    allowsAnyClass:(BOOL)flag;
@end

@interface PBXUnarchivingBinding (LBSPrivate)
- (void)lbs_setArchiveKey:(NSString *)archiveKey
    allowsAnyClass:(BOOL)flag
    scalar:(BOOL)scalar;
@end

@interface NSKeyGetBinding (LBSFoundation)
- (instancetype)initWithFunc:(void *)function
    forImp:(IMP)implementation
    selector:(SEL)selector;
- (instancetype)initWithFunc:(void *)function ivarOffset:(long)offset;
@end

@interface NSKeySetBinding (LBSFoundation)
- (instancetype)initWithSetFunc:(void *)function
    forImp:(IMP)implementation
    selector:(SEL)selector;
- (instancetype)initWithSetFunc:(void *)function ivarOffset:(long)offset;
@end

static Ivar
LBSIvarAtOffset(id object, void *slot)
{
	Class cls;
	uintptr_t address;
	uintptr_t target;

	if (object == nil || slot == NULL)
		return (NULL);
	address = (uintptr_t)(__bridge void *)object;
	target = (uintptr_t)slot;
	if (target < address)
		return (NULL);
	target -= address;
	for (cls = [object class]; cls != Nil; cls = class_getSuperclass(cls)) {
		Ivar *ivars;
		unsigned int count;
		unsigned int i;

		ivars = class_copyIvarList(cls, &count);
		for (i = 0; i < count; i++) {
			if ((uintptr_t)ivar_getOffset(ivars[i]) == target) {
				Ivar found = ivars[i];

				free(ivars);
				return (found);
			}
		}
		free(ivars);
	}
	return (NULL);
}

static void
LBSSetKeyBindingClass(id keyBinding, Class targetClass)
{
	Ivar ivar = class_getInstanceVariable([NSKeyBinding class], "_class");

	if (ivar != NULL)
		object_setIvar(keyBinding, ivar, targetClass);
}

static NSInvocation *
LBSInvocationForSelector(id target, SEL selector)
{
	NSMethodSignature *signature;
	NSInvocation *invocation;

	if (target == nil || selector == NULL ||
	    ![target respondsToSelector:selector])
		return (nil);
	signature = [target methodSignatureForSelector:selector];
	if (signature == nil)
		return (nil);
	invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:selector];
	return (invocation);
}

static id
LBSGetArchiveValue(id object, SEL selector, IMP implementation)
{
	NSInvocation *invocation;
	__unsafe_unretained id value = nil;

	(void)implementation;
	invocation = LBSInvocationForSelector(object, selector);
	if (invocation == nil)
		return (nil);
	[invocation invokeWithTarget:object];
	[invocation getReturnValue:&value];
	return (value);
}

static void
LBSSetArchiveValue(id object, SEL selector, id value, IMP implementation)
{
	NSInvocation *invocation;

	(void)implementation;
	invocation = LBSInvocationForSelector(object, selector);
	if (invocation == nil)
		return;
	[invocation setArgument:&value atIndex:2];
	[invocation invokeWithTarget:object];
}

static id
LBSGetArchiveValueAtOffset(void *slot, void *function, id object)
{
	Ivar ivar;

	(void)function;
	ivar = LBSIvarAtOffset(object, slot);
	if (ivar != NULL)
		return (object_getIvar(object, ivar));
	if (slot == NULL)
		return (nil);
	return ((__bridge id)(*(void **)slot));
}

static void
LBSSetArchiveValueAtOffset(id value, void *slot, id valueAgain, id object)
{
	Ivar ivar;

	(void)valueAgain;
	ivar = LBSIvarAtOffset(object, slot);
	if (ivar != NULL)
		object_setIvar(object, ivar, value);
	else if (slot != NULL)
		*(void **)slot = (__bridge void *)value;
}

@implementation PBXArchiveBinding

+ (instancetype)bindingWithClass:(Class)targetClass
    key:(NSString *)key
    archiveMask:(NSInteger)mask
{
	NSString *archiveKey = key;
	BOOL allowsAny = NO;

	if ([targetClass respondsToSelector:@selector(archiveNameForKey:)]) {
		NSString *mapped = [(id<LBSArchiveBindingClassQueries>)targetClass
		    archiveNameForKey:key];

		if (mapped != nil)
			archiveKey = mapped;
	}
	if ([targetClass respondsToSelector:@selector(canArchiveAnyClassForKey:)])
		allowsAny = [(id<LBSArchiveBindingClassQueries>)targetClass
		    canArchiveAnyClassForKey:key];
	SEL accessor = NSSelectorFromString(key);
	IMP implementation = class_getMethodImplementation(targetClass, accessor);
	Ivar archiveIvar = NULL;
	if (key != nil) {
		NSString *ivarName = [key hasPrefix:@"_"] ? key :
		    [@"_" stringByAppendingString:key];

		archiveIvar = class_getInstanceVariable(targetClass,
		    [ivarName UTF8String]);
		if (archiveIvar == NULL)
			archiveIvar = class_getInstanceVariable(targetClass,
			    [key UTF8String]);
	}
	if ((mask & 4) != 0) {
		NSKeySetBinding *keyBinding;
		PBXUnarchivingBinding *binding;

		if (archiveIvar != NULL) {
			keyBinding = [[objc_getClass("_NSKVCPIvarSetBinding")
			    alloc] initWithSetFunc:(void *)LBSSetArchiveValueAtOffset
			    ivarOffset:ivar_getOffset(archiveIvar)];
		} else {
			keyBinding = [[objc_getClass("_NSSelectorSetBinding")
			    alloc] initWithSetFunc:(void *)LBSSetArchiveValue
			    forImp:implementation selector:accessor];
		}
		[keyBinding setKey:key];
		LBSSetKeyBindingClass(keyBinding, targetClass);
		binding = [[PBXUnarchivingBinding alloc]
		    initWithKeyBinding:keyBinding archiveMask:mask
		    clss:targetClass key:key];
		[binding lbs_setArchiveKey:archiveKey allowsAnyClass:allowsAny
		    scalar:[keyBinding isScalarProperty]];
		return (binding);
	}
	NSKeyGetBinding *keyBinding;
	PBXArchivingBinding *binding;

	if (archiveIvar != NULL) {
		keyBinding = [[objc_getClass("_NSKVCPIvarGetBinding") alloc]
		    initWithFunc:(void *)LBSGetArchiveValueAtOffset
		    ivarOffset:ivar_getOffset(archiveIvar)];
	} else {
		keyBinding = [[objc_getClass("_NSSelectorGetBinding") alloc]
		    initWithFunc:(void *)LBSGetArchiveValue forImp:implementation
		    selector:accessor];
	}
	[keyBinding setKey:key];
	LBSSetKeyBindingClass(keyBinding, targetClass);
	binding = [[PBXArchivingBinding alloc]
	    initWithKeyBinding:keyBinding archiveMask:mask];

	[binding lbs_setArchiveKey:archiveKey allowsAnyClass:allowsAny];
	return (binding);
}

- (instancetype)initWithKeyBinding:(NSKeyBinding *)binding
    archiveMask:(NSInteger)mask
{
	if ((self = [super init]) != nil) {
		_keyBindingInternal = binding;
		_key = [[binding key] copy];
		_archiveKey = [_key copy];
		_archiveMask = mask;
		_allowsAnyClass = NO;
	}
	return (self);
}

- (NSInteger)archiveMask
{
	return (_archiveMask);
}

- (NSString *)key
{
	return (_key);
}

- (Class)targetClass
{
	return ([_keyBindingInternal targetClass]);
}

- (BOOL)allowsAnyClass
{
	return (_allowsAnyClass);
}

- (void)setAllowsAnyClass:(BOOL)flag
{
	_allowsAnyClass = flag;
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@: %p; key = '%@'>",
	    NSStringFromClass([self class]), self, _key]);
}

@end

@implementation PBXArchivingBinding

- (void)lbs_setArchiveKey:(NSString *)archiveKey allowsAnyClass:(BOOL)flag
{
	_archiveKey = [archiveKey copy];
	_allowsAnyClass = flag;
}

- (void)writeValueForObject:(id)object toPListArchiver:(id)archiver
{
	id value = [(NSKeyGetBinding *)_keyBindingInternal
	    getValueFromObject:object];
	SEL selector = NULL;
	NSInvocation *invocation;

	if (value == nil)
		return;
	if ([value respondsToSelector:@selector(selectorForArchiveMask:)])
		selector = [(PBXObject *)value selectorForArchiveMask:_archiveMask];
	if (selector == NULL)
		selector = @selector(encodeObject:forKey:);
	invocation = LBSInvocationForSelector(archiver, selector);
	if (invocation == nil)
		return;
	[invocation setArgument:&value atIndex:2];
	[invocation setArgument:&_archiveKey atIndex:3];
	[invocation invokeWithTarget:archiver];
	_archiveSelector = selector;
	_archiveMethod = class_getMethodImplementation([archiver class], selector);
	_getValueMethod = (void *)LBSGetArchiveValue;
}

@end

@implementation PBXUnarchivingBinding

- (instancetype)initWithKeyBinding:(NSKeyBinding *)binding
    archiveMask:(NSInteger)mask
    clss:(Class)targetClass
    key:(NSString *)key
{
	if ((self = [super initWithKeyBinding:binding archiveMask:mask]) != nil) {
		if (key != nil)
			_key = [key copy];
		_archiveKey = [_key copy];
		(void)targetClass;
	}
	return (self);
}

- (void)lbs_setArchiveKey:(NSString *)archiveKey
    allowsAnyClass:(BOOL)flag
    scalar:(BOOL)scalar
{
	_archiveKey = [archiveKey copy];
	_allowsAnyClass = flag;
	_isScalar = scalar;
}

- (void)readValueForObject:(id)object
    fromPListUnarchiver:(id)unarchiver
{
	id archived = [unarchiver valueForKey:_archiveKey];
	SEL selector = NULL;
	NSInvocation *invocation;
	__unsafe_unretained id decoded = nil;
	id value;

	if (archived == nil)
		return;
	if ([archived respondsToSelector:@selector(selectorForArchiveMask:)])
		selector = [(PBXObject *)archived
		    selectorForArchiveMask:_archiveMask];
	if (selector == NULL || ![unarchiver respondsToSelector:selector])
		selector = @selector(decodeObjectForKey:);
	invocation = LBSInvocationForSelector(unarchiver, selector);
	if (invocation == nil)
		return;
	[invocation setArgument:&_archiveKey atIndex:2];
	[invocation invokeWithTarget:unarchiver];
	[invocation getReturnValue:&decoded];
	value = decoded;
	_unarchiveSelector = selector;
	_unarchiveMethod = class_getMethodImplementation([unarchiver class],
	    selector);
	_isScalar = [(NSKeySetBinding *)_keyBindingInternal isScalarProperty];
	[(NSKeySetBinding *)_keyBindingInternal setValue:value inObject:object];
}

@end
