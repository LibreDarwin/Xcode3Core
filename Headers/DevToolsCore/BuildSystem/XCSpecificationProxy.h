/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Clean-room reimplementation of DevToolsCore's XCSpecificationProxy.
 *
 * A proxy stands in for a specification whose property list has not been
 * turned into a real object yet.  It answers the identifier/name/description
 * queries from the property list and lazily instantiates the real
 * specification the first time another message is sent to it.
 *
 * XCSpecificationCache backed proxies (the cache:byteRange: initialiser) are
 * accepted but cannot be loaded because this tree does not implement
 * XCSpecificationCache.
 */

#ifndef DEVTOOLSCORE_BUILDSYSTEM_XCSPECIFICATIONPROXY_H
#define DEVTOOLSCORE_BUILDSYSTEM_XCSPECIFICATIONPROXY_H

#import <Foundation/Foundation.h>

@class NSError, NSString, TSPropertyListDictionary, XCSpecification, XCSpecificationCache;

@interface XCSpecificationProxy : NSObject {
    Class _specTypeBaseClass;
    TSPropertyListDictionary *_propertyList;
    XCSpecification *_loadedSpecification;
    NSError *_loadError;
    XCSpecificationCache *_cache;
    NSRange _cacheByteRange;
    NSString *_identifier;
    NSString *_proxyDomain;
}

+ (NSString *)localizedSpecificationTypeName;

- (id)initWithSpecificationTypeBaseClass:(Class)specTypeBaseClass
			    propertyList:(TSPropertyListDictionary *)propertyList
				inDomain:(NSString *)domain;
- (id)initWithSpecificationTypeBaseClass:(Class)specTypeBaseClass
			      identifier:(NSString *)identifier
				   cache:(XCSpecificationCache *)cache
			       byteRange:(NSRange)byteRange
				inDomain:(NSString *)domain;

- (NSString *)identifier;
- (NSDictionary *)properties;
- (TSPropertyListDictionary *)tsProperties;
- (NSString *)name;
- (NSString *)localizedDescription;
- (NSString *)specificationType;
- (Class)specificationTypeBaseClass;
- (BOOL)isNotYetLoadedSpecificationProxy;
- (XCSpecification *)loadedSpecification;
- (BOOL)isMissingSpecificationProxy;
- (NSComparisonResult)identifierCompare:(id)other;
- (NSComparisonResult)nameCompare:(id)other;
- (void)doesNotRecognizeSelector:(SEL)selector;
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector;
- (void)forwardInvocation:(NSInvocation *)invocation;
- (NSString *)description;
- (id)objectOrNilForKey:(NSString *)key;
- (NSString *)domain;

@end

#endif	/* DEVTOOLSCORE_BUILDSYSTEM_XCSPECIFICATIONPROXY_H */
