/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Private Foundation <-> OPP value conversion (DevToolsCore). */

#import "PBXPListCoding.h"

id
PBXObjectFromOPPValue(const OPPValue *value)
{
	switch (opp_kind(value)) {
	case OPP_STRING:
		return ([NSString stringWithUTF8String:
		    opp_string_value(value) ?: ""]);
	case OPP_ARRAY: {
		NSUInteger i, n = opp_array_count(value);
		NSMutableArray *a = [NSMutableArray arrayWithCapacity:n];

		for (i = 0; i < n; i++) {
			id o = PBXObjectFromOPPValue(opp_array_get(value, i));
			[a addObject:(o != nil) ? o : [NSNull null]];
		}
		return (a);
	}
	case OPP_DICT: {
		NSMutableDictionary *d = [NSMutableDictionary dictionary];
		OPPValue *dict = (OPPValue *)value;
		NSUInteger i;

		for (i = 0; i < dict->nentry; i++) {
			NSString *key = [NSString stringWithUTF8String:
			    dict->entries[i].key];
			id o = PBXObjectFromOPPValue(dict->entries[i].value);
			if (key != nil)
				d[key] = (o != nil) ? o : [NSNull null];
		}
		return (d);
	}
	default:
		return (nil);
	}
}

OPPValue *
PBXOPPValueFromObject(id object)
{
	if (object == nil || object == [NSNull null])
		return (opp_string_new(""));
	if ([object isKindOfClass:[NSString class]])
		return (opp_string_new([object UTF8String]));
	if ([object isKindOfClass:[NSNumber class]])
		return (opp_string_new([[object stringValue] UTF8String]));
	if ([object isKindOfClass:[NSArray class]]) {
		OPPValue *a = opp_array_new();
		id element;

		for (element in (NSArray *)object)
			opp_array_append(a, PBXOPPValueFromObject(element));
		return (a);
	}
	if ([object isKindOfClass:[NSDictionary class]]) {
		OPPValue *d = opp_dict_new();
		NSString *key;

		for (key in [(NSDictionary *)object allKeys]) {
			NSString *k = [key isKindOfClass:[NSString class]] ?
			    key : [key description];
			opp_dict_set(d, [k UTF8String],
			    PBXOPPValueFromObject([(NSDictionary *)object objectForKey:key]));
		}
		return (d);
	}
	/* Fallback: describe anything else as a string. */
	return (opp_string_new([[object description] UTF8String]));
}
