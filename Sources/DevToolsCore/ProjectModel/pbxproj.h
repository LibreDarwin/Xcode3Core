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
	char *indent;			/* source leading whitespace, or NULL */
	char *lead;			/* blank line(s) (ws + '\n') before, or NULL */
	OPPValue *value;
	char *value_comment;
} OPPDictEntry;

typedef struct {
	OPPValue *value;
	char *comment;
	char *indent;			/* source leading whitespace, or NULL */
	char *lead;			/* blank line(s) (ws + '\n') before, or NULL */
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
	char *indent;			/* source leading whitespace, or NULL */
	int glued;			/* marker began on the previous line */
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
	int no_trailing_comma;		/* multi-line array: last element has no ',' */
	int inline_lead_space;		/* dict: "{ k = v; }" vs "{k = v; }" */
	/* OPP_DICT / OPP_ARRAY: source leading whitespace of the close token */
	char *close_indent;
	char *close_lead;		/* blank line(s) (ws + '\n') before close */
	int inline_tight;		/* dict: "{a = b;}" (no space before '}') */
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

/* Construction / mutation (used by the object model). New values are
 * heap-owned; opp_dict_set/opp_array_append take ownership of their value. */
OPPValue *opp_string_new(const char *utf8);	/* computes quoting + raw token */
OPPValue *opp_dict_new(void);
OPPValue *opp_array_new(void);
void opp_dict_set(OPPValue *dict, const char *key, OPPValue *value);
void opp_dict_append(OPPValue *dict, const char *key, OPPValue *value);
void opp_dict_set_comment(OPPValue *dict, const char *key,
    const char *key_comment, const char *value_comment);
void opp_dict_remove(OPPValue *dict, const char *key);
size_t opp_array_count(const OPPValue *arr);
OPPValue *opp_array_get(const OPPValue *arr, size_t idx);
void opp_array_append(OPPValue *arr, OPPValue *value);
void opp_string_set(OPPValue *str, const char *utf8);
const char *opp_string_value(const OPPValue *str);
int opp_kind(const OPPValue *v);

OPPDocument *opp_parse_buffer(const char *buf, size_t len, char **errp);
OPPDocument *opp_parse_file(const char *path, char **errp);
OPPDocument *opp_document_new(OPPValue *root);
void opp_document_free(OPPDocument *doc);
char *opp_write_document(const OPPDocument *doc, size_t *lenp, char **errp);

#endif	/* PBXPROJ_H */
