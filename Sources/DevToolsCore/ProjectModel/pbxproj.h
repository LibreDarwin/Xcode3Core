/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * OpenStep ("old-style") property list model used for .xcodeproj/project.pbxproj. */

#ifndef PBXPROJ_H
#define PBXPROJ_H

#include <stddef.h>

typedef enum {
	OPP_STRING = 1,
	OPP_ARRAY = 2,
	OPP_DICT = 3
} OPPKind;

typedef struct OPPValue OPPValue;

typedef struct {
	char *key;
	char *key_raw;			/* source token, incl. quotes if quoted */
	char *key_comment;
	OPPValue *value;
	char *value_comment;
} OPPDictEntry;

typedef struct {
	OPPValue *value;
	char *comment;
} OPPArrayElem;

/*
 * Layout of the "objects" dictionary, preserving the exact source
 * arrangement of section markers and line comments between entries.
 */
typedef enum {
	OPP_LAYOUT_ENTRY = 1,
	OPP_LAYOUT_SECTION_BEGIN = 2,
	OPP_LAYOUT_SECTION_END = 3,
	OPP_LAYOUT_LINE_COMMENT = 4,
	OPP_LAYOUT_BLANK = 5
} OPPLayoutKind;

typedef struct {
	OPPLayoutKind kind;
	size_t index;			/* OPP_LAYOUT_ENTRY: entry index */
	char *text;			/* SECTION: name; LINE_COMMENT: "//...";
				   BLANK: leading whitespace of the blank line */
} OPPLayoutItem;

struct OPPValue {
	OPPKind kind;
	/* OPP_STRING */
	char *str;			/* unescaped value */
	char *raw;			/* source token, incl. quotes/escapes */
	int quoted;
	/* OPP_ARRAY */
	OPPArrayElem *elems;
	size_t nelem;
	/* OPP_DICT */
	OPPDictEntry *entries;
	size_t nentry;
	int inline_form;		/* written without newlines in source */
	int inline_join;		/* array: join form "(a, b)" vs trailing "(a, b, )" */
	int inline_lead_space;		/* dict: "{ k = v; }" vs "{k = v; }" */
	/* OPP_DICT: "objects" layout, when present */
	OPPLayoutItem *layout;
	size_t nlayout;
	int has_sections;
};

typedef struct {
	char *header;			/* "// !$*UTF8*$!" or NULL */
	OPPValue *root;			/* OPP_DICT */
	int no_trailing_newline;	/* input ended without '\n' */
} OPPDocument;

OPPValue *opp_new(OPPKind kind);
OPPValue *opp_dict_get(const OPPValue *dict, const char *key);
const char *opp_scalar_get(const OPPValue *dict, const char *key);
void opp_free(OPPValue *v);

OPPDocument *opp_parse_buffer(const char *buf, size_t len, char **errp);
OPPDocument *opp_parse_file(const char *path, char **errp);
char *opp_write_document(const OPPDocument *doc, size_t *lenp, char **errp);

#endif	/* PBXPROJ_H */
