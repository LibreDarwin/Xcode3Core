/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Command-line driver for the ProjectModel object graph (DevToolsCore). */

#import <Foundation/Foundation.h>

#include <string.h>

#import "DevToolsCore/PBXProjectModel.h"
#import "DevToolsCore/PBXObject.h"
#import "DevToolsCore/ProjectModel/pbxproj.h"
#import "PBXPListCoding.h"

static void
usage(void)
{
	fprintf(stderr,
	    "usage: pbxmodel roundtrip <project.pbxproj>\n"
	    "       pbxmodel cat <project.pbxproj>\n"
	    "       pbxmodel dump <project.pbxproj>\n");
	exit(2);
}

/* Parse a project.pbxproj into the plain OPP value tree. */
static id
loadOPP(const char *path)
{
	char *err = NULL;
	OPPDocument *d = opp_parse_file(path, &err);
	id v;

	if (d == NULL) {
		fprintf(stderr, "pbxmodel: %s: %s\n", path,
		    (err != NULL) ? err : "parse error");
		free(err);
		return (nil);
	}
	v = PBXObjectFromOPPValue(d->root);
	opp_document_free(d);
	return (v);
}

/* Parse an in-memory archive string into the plain OPP value tree. */
static id
loadOPPString(NSString *s)
{
	char *err = NULL;
	const char *utf8 = [s UTF8String];
	OPPDocument *d = opp_parse_buffer(utf8, (utf8 != NULL) ? strlen(utf8) : 0,
	    &err);
	id v;

	if (d == NULL) {
		fprintf(stderr, "pbxmodel: %s\n", (err != NULL) ? err : "?");
		free(err);
		return (nil);
	}
	v = PBXObjectFromOPPValue(d->root);
	opp_document_free(d);
	return (v);
}

/*
 * roundtrip: load the object graph, re-archive it, and verify that the
 * result still describes the same project:
 *   - semantic  : re-parsing our output yields an equal value tree;
 *   - stability : archiving the same model twice gives identical bytes;
 *   - idempotence: archive(load(archive)) == archive (semantically).
 */
static int
cmdRoundtrip(NSString *path)
{
	NSError *error = nil;
	PBXProjectModel *model;
	NSString *s1, *s2;
	id v0, v1, v2;
	int status = 0;

	v0 = loadOPP([path UTF8String]);
	if (v0 == nil)
		return (1);

	model = [PBXProjectModel modelWithContentsOfFile:path error:&error];
	if (model == nil) {
		fprintf(stderr, "pbxmodel: %s: %s\n", [path UTF8String],
		    [[error description] UTF8String]);
		return (1);
	}

	s1 = [model archiveString];
	v1 = loadOPPString(s1);
	if (v1 == nil)
		return (1);
	if (![v0 isEqual:v1]) {
		fprintf(stderr, "pbxmodel: SEMANTIC MISMATCH %s\n",
		    [path UTF8String]);
		status = 1;
	}
	if (![s1 isEqualToString:[model archiveString]]) {
		fprintf(stderr, "pbxmodel: UNSTABLE ARCHIVE %s\n",
		    [path UTF8String]);
		status = 1;
	}

	{
		PBXProjectModel *m2 = [PBXProjectModel modelWithArchiveString:s1
		    error:&error];

		if (m2 == nil) {
			fprintf(stderr, "pbxmodel: %s: %s\n", [path UTF8String],
			    [[error description] UTF8String]);
			return (1);
		}
		s2 = [m2 archiveString];
		v2 = loadOPPString(s2);
		if (v2 == nil || ![v1 isEqual:v2]) {
			fprintf(stderr, "pbxmodel: NOT IDEMPOTENT %s\n",
			    [path UTF8String]);
			status = 1;
		}
	}

	if (status == 0)
		printf("OK %s\n", [path UTF8String]);
	return (status);
}

/* cat: load the object graph and print its canonical archive. */
static int
cmdCat(NSString *path)
{
	NSError *error = nil;
	PBXProjectModel *model;

	model = [PBXProjectModel modelWithContentsOfFile:path error:&error];
	if (model == nil) {
		fprintf(stderr, "pbxmodel: %s: %s\n", [path UTF8String],
		    [[error description] UTF8String]);
		return (1);
	}
	fputs([[model archiveString] UTF8String], stdout);
	return (0);
}

/* dump: summarize the materialized object graph. */
static int
cmdDump(NSString *path)
{
	NSError *error = nil;
	PBXProjectModel *model;
	NSDictionary *objects;
	NSMutableDictionary *counts;
	NSArray *isas;
	NSString *isa;

	model = [PBXProjectModel modelWithContentsOfFile:path error:&error];
	if (model == nil) {
		fprintf(stderr, "pbxmodel: %s: %s\n", [path UTF8String],
		    [[error description] UTF8String]);
		return (1);
	}
	objects = [model objects];
	counts = [NSMutableDictionary dictionary];
	for (id key in objects) {
		PBXObject *object = [objects objectForKey:key];
		NSString *name = [object classNameForPListArchive];
		NSNumber *n = [counts objectForKey:name];

		[counts setObject:@([n unsignedIntegerValue] + 1)
		    forKey:name];
	}
	printf("archiveVersion = %s\n",
	    [[model archiveVersion] UTF8String]);
	printf("objectVersion = %s\n",
	    [[model objectVersion] UTF8String]);
	printf("objects = %lu\n", (unsigned long)[objects count]);
	isas = [[counts allKeys] sortedArrayUsingSelector:@selector(compare:)];
	for (isa in isas)
		printf("  %-36s %lu\n", [isa UTF8String],
		    (unsigned long)[[counts objectForKey:isa] unsignedIntegerValue]);
	return (0);
}

int
main(int argc, char **argv)
{
	@autoreleasepool {
		const char *cmd;

		if (argc < 3)
			usage();
		cmd = argv[1];

		if (strcmp(cmd, "roundtrip") == 0)
			return (cmdRoundtrip([NSString stringWithUTF8String:
			    argv[2]]));
		if (strcmp(cmd, "cat") == 0)
			return (cmdCat([NSString stringWithUTF8String:
			    argv[2]]));
		if (strcmp(cmd, "dump") == 0)
			return (cmdDump([NSString stringWithUTF8String:
			    argv[2]]));

		usage();
		return (2);
	}
}
