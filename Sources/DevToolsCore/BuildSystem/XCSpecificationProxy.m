/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 */

#import "DevToolsCore/BuildSystem/XCSpecificationProxy.h"

#import "DevToolsCore/BuildSystem/XCSpecification.h"
#import "DevToolsSupport/TSPropertyListDictionary.h"

@implementation XCSpecificationProxy

+ (NSString *)localizedSpecificationTypeName
{
	return (@"proxy");
}

- (id)initWithSpecificationTypeBaseClass:(Class)specTypeBaseClass
			    propertyList:(TSPropertyListDictionary *)propertyList
				inDomain:(NSString *)domain
{
	if (specTypeBaseClass == nil || ![specTypeBaseClass isSubclassOfClass:[XCSpecification class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be a subclass of %@, but it is %@",
				   @"specTypeBaseClass", NSStringFromClass([XCSpecification class]), NSStringFromClass(specTypeBaseClass)];
	}
	if (propertyList == nil || ![propertyList isKindOfClass:[TSPropertyListDictionary class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"propertyList", NSStringFromClass([TSPropertyListDictionary class]), propertyList];
	}

	self = [super init];
	if (self != nil) {
		_specTypeBaseClass = specTypeBaseClass;
		_propertyList = propertyList;
		_proxyDomain = [domain copy];
	}
	return (self);
}

- (id)initWithSpecificationTypeBaseClass:(Class)specTypeBaseClass
			      identifier:(NSString *)identifier
				   cache:(XCSpecificationCache *)cache
			       byteRange:(NSRange)byteRange
				inDomain:(NSString *)domain
{
	if (specTypeBaseClass == nil || ![specTypeBaseClass isSubclassOfClass:[XCSpecification class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be a subclass of %@, but it is %@",
				   @"specTypeBaseClass", NSStringFromClass([XCSpecification class]), NSStringFromClass(specTypeBaseClass)];
	}
	if (identifier == nil || ![identifier isKindOfClass:[NSString class]] || [identifier length] == 0) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be a non-empty string, but it is %@", @"identifier", identifier];
	}

	self = [super init];
	if (self != nil) {
		_specTypeBaseClass = specTypeBaseClass;
		_identifier = [identifier copy];
		_cache = cache;
		_cacheByteRange = byteRange;
		_proxyDomain = [domain copy];
	}
	return (self);
}

- (void)dealloc
{
#if !__has_feature(objc_arc)
	[_propertyList release];
	[_loadedSpecification release];
	[_loadError release];
	[_cache release];
	[_identifier release];
	[_proxyDomain release];
	[super dealloc];
#endif
}

- (NSString *)identifier
{
	if (_propertyList != nil) {
		NSString *identifier = [_propertyList stringOrNilForKey:@"Identifier"];

		if (identifier != nil) {
			return (identifier);
		}
	}
	return (_identifier);
}

- (NSDictionary *)properties
{
	if (_propertyList != nil) {
		return (_propertyList);
	}
	if (_cache != nil) {
		/* XCSpecificationCache is not implemented in this tree. */
		return (nil);
	}
	return (nil);
}

- (TSPropertyListDictionary *)tsProperties
{
	return (_propertyList);
}

- (NSString *)name
{
	NSString *name = [_propertyList stringOrNilForKey:@"Name"];

	if (name != nil) {
		return (name);
	}
	return ([self identifier]);
}

- (NSString *)localizedDescription
{
	NSString *description = [_propertyList stringOrNilForKey:@"Description"];

	if (description != nil) {
		return (description);
	}
	return ([self identifier]);
}

- (NSString *)specificationType
{
	return ([_specTypeBaseClass specificationType]);
}

- (Class)specificationTypeBaseClass
{
	return (_specTypeBaseClass);
}

- (BOOL)isNotYetLoadedSpecificationProxy
{
	BOOL result;

	@synchronized (self) {
		result = (_loadedSpecification != nil) ? [_loadedSpecification isNotYetLoadedSpecificationProxy] : YES;
	}
	return (result);
}

- (XCSpecification *)loadedSpecification
{
	@synchronized (self) {
		if (_loadedSpecification == nil && _propertyList != nil) {
			_loadedSpecification = [[_specTypeBaseClass alloc] initWithPropertyListDictionary:_propertyList inDomain:_proxyDomain];
			[_loadedSpecification awakeAfterInitialization];
		}
	}
	return (_loadedSpecification);
}

- (BOOL)isMissingSpecificationProxy
{
	BOOL result;

	@synchronized (self) {
		result = (_loadedSpecification != nil) ? [_loadedSpecification isMissingSpecificationProxy] : NO;
	}
	return (result);
}

- (NSComparisonResult)identifierCompare:(id)other
{
	if (![other isKindOfClass:[XCSpecification class]] && ![other isKindOfClass:[XCSpecificationProxy class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"other", NSStringFromClass([XCSpecification class]), other];
	}
	return ([[self identifier] compare:[other identifier]]);
}

- (NSComparisonResult)nameCompare:(id)other
{
	if (![other isKindOfClass:[XCSpecification class]] && ![other isKindOfClass:[XCSpecificationProxy class]]) {
		[NSException raise:NSInvalidArgumentException
			    format:@"%@ should be an instance inheriting from %@, but it is %@",
				   @"other", NSStringFromClass([XCSpecification class]), other];
	}
	return ([[self name] compare:[other name]]);
}

- (void)doesNotRecognizeSelector:(SEL)selector
{
	[[self loadedSpecification] doesNotRecognizeSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
	NSMethodSignature *signature = [XCSpecification instanceMethodSignatureForSelector:selector];

	if (signature != nil) {
		return (signature);
	}
	return ([[self loadedSpecification] methodSignatureForSelector:selector]);
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
	[invocation invokeWithTarget:[self loadedSpecification]];
}

- (NSString *)description
{
	return ([NSString stringWithFormat:@"<%@:%p:'%@':%@:spec=%@:err=%@>",
		   NSStringFromClass([self class]),
		   self,
		   [self identifier],
		   ([_proxyDomain isEqualToString:@""] ? @"Default" : _proxyDomain),
		   _loadedSpecification,
		   _loadError]);
}

- (id)objectOrNilForKey:(NSString *)key
{
	return ([_propertyList objectOrNilForKey:key]);
}

- (NSString *)domain
{
	return (_proxyDomain);
}

@end
