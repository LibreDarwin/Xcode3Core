/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * OpenStep property list parser and Xcode-compatible project.pbxproj writer. */

#include "pbxproj.h"

#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------ */
/* dynamic byte string                                                 */
/* ------------------------------------------------------------------ */

typedef struct {
	char *p;
	size_t len;
	size_t cap;
} SB;

static void *
xmalloc(size_t n)
{
	void *p = malloc(n);
	if (p == NULL)
		abort();
	return (p);
}

static void *
xrealloc(void *p, size_t n)
{
	void *q = realloc(p, n);
	if (q == NULL)
		abort();
	return (q);
}

static char *
xstrndup(const char *s, size_t n)
{
	char *p = xmalloc(n + 1);
	memcpy(p, s, n);
	p[n] = '\0';
	return (p);
}

static char *
xstrdup(const char *s)
{
	return (xstrndup(s, strlen(s)));
}

static void
sb_init(SB *sb)
{
	sb->cap = 4096;
	sb->len = 0;
	sb->p = xmalloc(sb->cap);
	sb->p[0] = '\0';
}

static void
sb_reserve(SB *sb, size_t extra)
{
	if (sb->len + extra + 1 > sb->cap) {
		while (sb->len + extra + 1 > sb->cap)
			sb->cap *= 2;
		sb->p = xrealloc(sb->p, sb->cap);
	}
}

static void
sb_putn(SB *sb, const char *s, size_t n)
{
	sb_reserve(sb, n);
	memcpy(sb->p + sb->len, s, n);
	sb->len += n;
	sb->p[sb->len] = '\0';
}

static void
sb_puts(SB *sb, const char *s)
{
	sb_putn(sb, s, strlen(s));
}

static void
sb_putc(SB *sb, char c)
{
	sb_putn(sb, &c, 1);
}

static void
sb_indent(SB *sb, int depth)
{
	int i;
	for (i = 0; i < depth; i++)
		sb_putc(sb, '\t');
}

/* ------------------------------------------------------------------ */
/* model                                                               */
/* ------------------------------------------------------------------ */

OPPValue *
opp_new(OPPKind kind)
{
	OPPValue *v = xmalloc(sizeof (*v));
	memset(v, 0, sizeof (*v));
	v->kind = kind;
	return (v);
}

void
opp_free(OPPValue *v)
{
	size_t i;

	if (v == NULL)
		return;
	switch (v->kind) {
	case OPP_STRING:
		free(v->str);
		free(v->raw);
		break;
	case OPP_ARRAY:
		for (i = 0; i < v->nelem; i++) {
			opp_free(v->elems[i].value);
			free(v->elems[i].comment);
		}
		free(v->elems);
		break;
	case OPP_DICT:
		for (i = 0; i < v->nentry; i++) {
			free(v->entries[i].key);
			free(v->entries[i].key_raw);
			free(v->entries[i].key_comment);
			opp_free(v->entries[i].value);
			free(v->entries[i].value_comment);
		}
		free(v->entries);
		for (i = 0; i < v->nlayout; i++)
			free(v->layout[i].text);
		free(v->layout);
		break;
	}
	free(v);
}

OPPValue *
opp_dict_get(const OPPValue *dict, const char *key)
{
	size_t i;

	if (dict == NULL || dict->kind != OPP_DICT)
		return (NULL);
	for (i = 0; i < dict->nentry; i++)
		if (strcmp(dict->entries[i].key, key) == 0)
			return (dict->entries[i].value);
	return (NULL);
}

const char *
opp_scalar_get(const OPPValue *dict, const char *key)
{
	OPPValue *v = opp_dict_get(dict, key);
	if (v == NULL || v->kind != OPP_STRING)
		return (NULL);
	return (v->str);
}

static void
opp_dict_add_raw(OPPValue *d, char *key, OPPValue *v)
{
	d->entries = xrealloc(d->entries,
	    (d->nentry + 1) * sizeof (OPPDictEntry));
	memset(&d->entries[d->nentry], 0, sizeof (OPPDictEntry));
	d->entries[d->nentry].key = key;
	d->entries[d->nentry].value = v;
	d->nentry++;
}

static void
opp_array_add_raw(OPPValue *a, OPPValue *v)
{
	a->elems = xrealloc(a->elems, (a->nelem + 1) * sizeof (OPPArrayElem));
	memset(&a->elems[a->nelem], 0, sizeof (OPPArrayElem));
	a->elems[a->nelem].value = v;
	a->nelem++;
}

static void
opp_layout_add(OPPValue *d, OPPLayoutKind kind, size_t index, char *text)
{
	d->layout = xrealloc(d->layout,
	    (d->nlayout + 1) * sizeof (OPPLayoutItem));
	d->layout[d->nlayout].kind = kind;
	d->layout[d->nlayout].index = index;
	d->layout[d->nlayout].text = text;
	d->nlayout++;
	if (kind == OPP_LAYOUT_SECTION_BEGIN)
		d->has_sections = 1;
}

/* ------------------------------------------------------------------ */
/* parser                                                              */
/* ------------------------------------------------------------------ */

typedef struct {
	const char *p;
	const char *end;
	char *err;
} Cursor;

static void
fail(Cursor *c, const char *msg)
{
	if (c->err == NULL)
		c->err = xstrdup(msg);
}

static int
at_end(const Cursor *c)
{
	return (c->p >= c->end);
}

/*
 * Skip whitespace and comments.  A block comment that starts on the same
 * line as whatever preceded it is treated as an annotation for that token
 * and returned in *cap; comments on their own line (such as the
 * "Begin ... section" markers) are discarded.
 */
static void
skip_ws(Cursor *c, char **cap)
{
	int saw_newline = 0;

	if (cap != NULL)
		*cap = NULL;
	for (;;) {
		if (at_end(c))
			return;
		if (*c->p == '\n') {
			saw_newline = 1;
			c->p++;
			continue;
		}
		if (*c->p == ' ' || *c->p == '\t' || *c->p == '\r') {
			c->p++;
			continue;
		}
		if (*c->p == '/' && c->p + 1 < c->end && c->p[1] == '*') {
			const char *start = c->p + 2;
			const char *q = start;

			while (q + 1 < c->end && !(q[0] == '*' && q[1] == '/'))
				q++;
			if (q + 1 >= c->end) {
				fail(c, "unterminated comment");
				return;
			}
			if (cap != NULL && !saw_newline &&
			    (*cap == NULL)) {
				const char *cs = start, *ce = q;

				/* Xcode pads comments with one space on
				 * each side; drop exactly that padding. */
				if (cs < ce && *cs == ' ')
					cs++;
				if (ce > cs && ce[-1] == ' ')
					ce--;
				*cap = xstrndup(cs, (size_t)(ce - cs));
			}
			c->p = q + 2;
			saw_newline = 1;
			continue;
		}
		if (*c->p == '/' && c->p + 1 < c->end && c->p[1] == '/') {
			while (c->p < c->end && *c->p != '\n')
				c->p++;
			saw_newline = 1;
			continue;
		}
		return;
	}
}

/* Skip whitespace/comments without capturing. */
static void
skip_ws_nc(Cursor *c)
{
	skip_ws(c, NULL);
}

/*
 * Recognise a "Begin NAME section" / "End NAME section" comment body.
 * Returns 1 for a begin marker, -1 for an end marker, 0 otherwise, and
 * stores the section name (caller frees) in *namep.
 */
static int
parse_section_marker(const char *s, const char *e, char **namep)
{
	size_t len;

	while (s < e && (*s == ' ' || *s == '\t'))
		s++;
	while (e > s && (e[-1] == ' ' || e[-1] == '\t'))
		e--;
	len = (size_t)(e - s);
	if (len > 8 && memcmp(s, "Begin ", 6) == 0 &&
	    memcmp(e - 8, " section", 8) == 0) {
		*namep = xstrndup(s + 6, len - 14);
		return (1);
	}
	if (len > 6 && memcmp(s, "End ", 4) == 0 &&
	    memcmp(e - 8, " section", 8) == 0) {
		*namep = xstrndup(s + 4, len - 12);
		return (-1);
	}
	return (0);
}

/*
 * Objects-specific whitespace skipper: behaves like skip_ws but also
 * reports section markers and "//" line comments so the exact layout can
 * be preserved.  When a marker/comment is found, *kind is non-zero and
 * *text (caller frees) holds its payload; the cursor is left just past it.
 */
static void
skip_ws_obj(Cursor *c, char **cap, int *kind, char **text)
{
	int saw_newline = 0;

	if (cap != NULL)
		*cap = NULL;
	if (kind != NULL)
		*kind = 0;
	if (text != NULL)
		*text = NULL;
	for (;;) {
		if (at_end(c))
			return;
		if (*c->p == '\n') {
			const char *q = c->p + 1;

			while (q < c->end && (*q == ' ' || *q == '\t' ||
			    *q == '\r'))
				q++;
			if (q < c->end && *q == '\n') {
				*kind = OPP_LAYOUT_BLANK;
				*text = xstrndup(c->p + 1,
				    (size_t)(q - (c->p + 1)));
				c->p = q;
				return;
			}
			saw_newline = 1;
			c->p++;
			continue;
		}
		if (*c->p == ' ' || *c->p == '\t' || *c->p == '\r') {
			c->p++;
			continue;
		}
		if (*c->p == '/' && c->p + 1 < c->end && c->p[1] == '*') {
			const char *start = c->p + 2;
			const char *q = start;
			char *name = NULL;
			int m;

			while (q + 1 < c->end && !(q[0] == '*' && q[1] == '/'))
				q++;
			if (q + 1 >= c->end) {
				fail(c, "unterminated comment");
				return;
			}
			m = parse_section_marker(start, q, &name);
			if (m != 0) {
				*kind = (m > 0) ? OPP_LAYOUT_SECTION_BEGIN :
				    OPP_LAYOUT_SECTION_END;
				*text = name;
				c->p = q + 2;
				return;
			}
			if (cap != NULL && !saw_newline && *cap == NULL) {
				const char *cs = start, *ce = q;

				if (cs < ce && *cs == ' ')
					cs++;
				if (ce > cs && ce[-1] == ' ')
					ce--;
				*cap = xstrndup(cs, (size_t)(ce - cs));
			}
			c->p = q + 2;
			saw_newline = 1;
			continue;
		}
		if (*c->p == '/' && c->p + 1 < c->end && c->p[1] == '/') {
			const char *ls = c->p;
			const char *le = c->p;

			while (le < c->end && *le != '\n')
				le++;
			*kind = OPP_LAYOUT_LINE_COMMENT;
			*text = xstrndup(ls, (size_t)(le - ls));
			c->p = le;
			return;
		}
		return;
	}
}

static int is_bare_delim(char ch)
{
	return (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' ||
	    ch == '{' || ch == '}' || ch == '(' || ch == ')' ||
	    ch == ',' || ch == ';' || ch == '=' || ch == '"');
}

/* Parse a string token (quoted or bare). */
static OPPValue *
parse_string(Cursor *c)
{
	OPPValue *v;
	const char *start;
	SB sb;

	skip_ws_nc(c);
	if (at_end(c)) {
		fail(c, "unexpected end of file");
		return (NULL);
	}
	start = c->p;
	if (*c->p == '"') {
		sb_init(&sb);
		c->p++;			/* opening quote */
		for (;;) {
			if (at_end(c)) {
				fail(c, "unterminated string");
				free(sb.p);
				return (NULL);
			}
			if (*c->p == '"') {
				c->p++;
				break;
			}
			if (*c->p == '\\') {
				c->p++;
				if (at_end(c)) {
					fail(c, "unterminated escape");
					free(sb.p);
					return (NULL);
				}
				switch (*c->p) {
				case 'n': sb_putc(&sb, '\n'); c->p++; break;
				case 't': sb_putc(&sb, '\t'); c->p++; break;
				case 'r': sb_putc(&sb, '\r'); c->p++; break;
				case '"': sb_putc(&sb, '"'); c->p++; break;
				case '\\': sb_putc(&sb, '\\'); c->p++; break;
				default:
					/* keep unknown escapes verbatim */
					sb_putc(&sb, '\\');
					sb_putc(&sb, *c->p);
					c->p++;
					break;
				}
				continue;
			}
			sb_putc(&sb, *c->p);
			c->p++;
		}
		v = opp_new(OPP_STRING);
		v->quoted = 1;
		v->str = sb.p;
		v->raw = xstrndup(start, (size_t)(c->p - start));
		return (v);
	}
	/* bare token */
	while (!at_end(c)) {
		if (is_bare_delim(*c->p))
			break;
		if (*c->p == '/' && c->p + 1 < c->end &&
		    (c->p[1] == '*' || c->p[1] == '/'))
			break;
		c->p++;
	}
	if (c->p == start) {
		fail(c, "expected a value");
		return (NULL);
	}
	v = opp_new(OPP_STRING);
	v->quoted = 0;
	v->str = xstrndup(start, (size_t)(c->p - start));
	v->raw = xstrdup(v->str);
	return (v);
}

static OPPValue *parse_value(Cursor *c);
static OPPValue *parse_objects(Cursor *c);

static OPPValue *
parse_array(Cursor *c)
{
	OPPValue *a = opp_new(OPP_ARRAY);
	const char *open = c->p;

	c->p++;				/* '(' */
	for (;;) {
		char *cap = NULL;
		OPPValue *v;

		skip_ws(c, &cap);
		if (at_end(c)) {
			fail(c, "unterminated array");
			free(cap);
			opp_free(a);
			return (NULL);
		}
		if (*c->p == ')') {
			c->p++;
			free(cap);
			break;
		}
		v = parse_value(c);
		if (v == NULL) {
			free(cap);
			opp_free(a);
			return (NULL);
		}
		opp_array_add_raw(a, v);
		if (cap != NULL) {
			a->elems[a->nelem - 1].comment = cap;
			cap = NULL;
		}
		skip_ws(c, &cap);
		if (cap != NULL && a->elems[a->nelem - 1].comment == NULL) {
			a->elems[a->nelem - 1].comment = cap;
			cap = NULL;
		}
		free(cap);
		if (at_end(c)) {
			fail(c, "unterminated array");
			opp_free(a);
			return (NULL);
		}
		if (*c->p == ',') {
			c->p++;
			continue;
		}
		if (*c->p == ')') {
			c->p++;
			break;
		}
		fail(c, "expected ',' or ')' in array");
		opp_free(a);
		return (NULL);
	}
	/* inline form: no newline between '(' and ')' */
	if (memchr(open, '\n', (size_t)(c->p - open)) == NULL) {
		a->inline_form = 1;
		if (a->nelem > 0) {
			const char *r = c->p - 1;	/* the ')' */

			while (r > open && (r[-1] == ' ' || r[-1] == '\t'))
				r--;
			a->inline_join = (r[-1] != ',');
		}
	}
	return (a);
}

static OPPValue *
parse_dict(Cursor *c)
{
	OPPValue *d = opp_new(OPP_DICT);
	const char *open = c->p;

	c->p++;				/* '{' */
	if (c->p < c->end && *c->p == ' ')
		d->inline_lead_space = 1;
	for (;;) {
		char *kcap = NULL;
		char *vcap = NULL;
		OPPValue *k, *v;

		skip_ws(c, &kcap);
		if (at_end(c)) {
			fail(c, "unterminated dictionary");
			free(kcap);
			opp_free(d);
			return (NULL);
		}
		if (*c->p == '}') {
			c->p++;
			free(kcap);
			break;
		}
		k = parse_string(c);
		if (k == NULL) {
			free(kcap);
			opp_free(d);
			return (NULL);
		}
		skip_ws(c, &vcap);
		if (vcap != NULL && kcap == NULL) {
			kcap = vcap;
			vcap = NULL;
		}
		free(vcap);
		if (at_end(c) || *c->p != '=') {
			fail(c, "expected '=' in dictionary");
			opp_free(k);
			free(kcap);
			opp_free(d);
			return (NULL);
		}
		c->p++;			/* '=' */
		skip_ws_nc(c);
		if (strcmp(k->str, "objects") == 0 &&
		    !at_end(c) && *c->p == '{')
			v = parse_objects(c);
		else
			v = parse_value(c);
		if (v == NULL) {
			opp_free(k);
			free(kcap);
			opp_free(d);
			return (NULL);
		}
		/* comment after the value, before the ';' */
		skip_ws(c, &vcap);
		if (at_end(c) || *c->p != ';') {
			fail(c, "expected ';' after dictionary entry");
			opp_free(k);
			opp_free(v);
			free(kcap);
			free(vcap);
			opp_free(d);
			return (NULL);
		}
		c->p++;			/* ';' */
		opp_dict_add_raw(d, k->str, v);
		d->entries[d->nentry - 1].key_raw = k->raw;
		free(k);		/* k->str, k->raw now owned by the entry */
		d->entries[d->nentry - 1].key_comment = kcap;
		d->entries[d->nentry - 1].value_comment = vcap;
	}
	/* inline form: no newline between '{' and '}' */
	if (memchr(open, '\n', (size_t)(c->p - open)) == NULL)
		d->inline_form = 1;
	return (d);
}

/*
 * Parse the "objects" dictionary, recording the exact sequence of
 * section markers and line comments so the layout can be reproduced.
 */
static OPPValue *
parse_objects(Cursor *c)
{
	OPPValue *d = opp_new(OPP_DICT);
	const char *open = c->p;

	c->p++;				/* '{' */
	if (c->p < c->end && *c->p == ' ')
		d->inline_lead_space = 1;
	for (;;) {
		char *kcap = NULL;
		char *vcap = NULL;
		char *otext = NULL;
		int okind = 0;
		OPPValue *k, *v;

		skip_ws_obj(c, &kcap, &okind, &otext);
		if (okind != 0) {
			opp_layout_add(d, (OPPLayoutKind)okind, 0, otext);
			free(kcap);
			continue;
		}
		if (at_end(c)) {
			fail(c, "unterminated dictionary");
			free(kcap);
			opp_free(d);
			return (NULL);
		}
		if (*c->p == '}') {
			c->p++;
			free(kcap);
			break;
		}
		k = parse_string(c);
		if (k == NULL) {
			free(kcap);
			opp_free(d);
			return (NULL);
		}
		skip_ws(c, &vcap);
		if (vcap != NULL && kcap == NULL) {
			kcap = vcap;
			vcap = NULL;
		}
		free(vcap);
		if (at_end(c) || *c->p != '=') {
			fail(c, "expected '=' in dictionary");
			opp_free(k);
			free(kcap);
			opp_free(d);
			return (NULL);
		}
		c->p++;			/* '=' */
		skip_ws_nc(c);
		v = parse_value(c);
		if (v == NULL) {
			opp_free(k);
			free(kcap);
			opp_free(d);
			return (NULL);
		}
		skip_ws(c, &vcap);
		if (at_end(c) || *c->p != ';') {
			fail(c, "expected ';' after dictionary entry");
			opp_free(k);
			opp_free(v);
			free(kcap);
			free(vcap);
			opp_free(d);
			return (NULL);
		}
		c->p++;			/* ';' */
		opp_dict_add_raw(d, k->str, v);
		d->entries[d->nentry - 1].key_raw = k->raw;
		free(k);
		d->entries[d->nentry - 1].key_comment = kcap;
		d->entries[d->nentry - 1].value_comment = vcap;
		opp_layout_add(d, OPP_LAYOUT_ENTRY, d->nentry - 1, NULL);
	}
	if (memchr(open, '\n', (size_t)(c->p - open)) == NULL)
		d->inline_form = 1;
	return (d);
}

static OPPValue *
parse_value(Cursor *c)
{
	skip_ws_nc(c);
	if (at_end(c)) {
		fail(c, "unexpected end of file");
		return (NULL);
	}
	switch (*c->p) {
	case '{':
		return (parse_dict(c));
	case '(':
		return (parse_array(c));
	case '"':
	default:
		return (parse_string(c));
	}
}

OPPDocument *
opp_parse_buffer(const char *buf, size_t len, char **errp)
{
	Cursor c;
	OPPDocument *doc;
	OPPValue *root;

	c.p = buf;
	c.end = buf + len;
	c.err = NULL;

	/* UTF-8 BOM */
	if (len >= 3 && (unsigned char)buf[0] == 0xef &&
	    (unsigned char)buf[1] == 0xbb && (unsigned char)buf[2] == 0xbf)
		c.p += 3;

	doc = xmalloc(sizeof (*doc));
	memset(doc, 0, sizeof (*doc));

	/* optional "// !$*UTF8*$!" header line */
	if ((size_t)(c.end - c.p) >= 2 && c.p[0] == '/' && c.p[1] == '/') {
		const char *nl = memchr(c.p, '\n', (size_t)(c.end - c.p));
		const char *e = (nl != NULL) ? nl : c.end;

		while (e > c.p && (e[-1] == '\r'))
			e--;
		doc->header = xstrndup(c.p, (size_t)(e - c.p));
		c.p = (nl != NULL) ? nl + 1 : c.end;
	}

	root = parse_value(&c);
	if (root == NULL) {
		if (errp != NULL)
			*errp = (c.err != NULL) ? c.err :
			    xstrdup("parse error");
		else
			free(c.err);
		free(doc->header);
		free(doc);
		return (NULL);
	}
	skip_ws_nc(&c);
	if (!at_end(&c)) {
		if (c.err == NULL)
			c.err = xstrdup("trailing data after root value");
		if (errp != NULL)
			*errp = c.err;
		else
			free(c.err);
		opp_free(root);
		free(doc->header);
		free(doc);
		return (NULL);
	}
	doc->root = root;
	doc->no_trailing_newline = (len == 0 || buf[len - 1] != '\n');
	if (errp != NULL)
		*errp = NULL;
	return (doc);
}

OPPDocument *
opp_parse_file(const char *path, char **errp)
{
	FILE *f;
	char *buf;
	size_t cap = 0, len = 0;
	char tmp[65536];
	size_t n;
	OPPDocument *doc;

	f = fopen(path, "rb");
	if (f == NULL) {
		if (errp != NULL)
			*errp = xstrdup(strerror(errno));
		return (NULL);
	}
	while ((n = fread(tmp, 1, sizeof (tmp), f)) > 0) {
		if (len + n + 1 > cap) {
			cap = (cap == 0) ? 65536 : cap;
			while (len + n + 1 > cap)
				cap *= 2;
			buf = xrealloc((len == 0) ? NULL : buf, cap);
		} else if (len == 0) {
			buf = xmalloc(cap);
		}
		memcpy(buf + len, tmp, n);
		len += n;
	}
	if (ferror(f)) {
		fclose(f);
		if (errp != NULL)
			*errp = xstrdup("read error");
		return (NULL);
	}
	fclose(f);
	if (len == 0)
		buf = xmalloc(1);
	buf[len] = '\0';
	doc = opp_parse_buffer(buf, len, errp);
	free(buf);
	return (doc);
}

/* ------------------------------------------------------------------ */
/* writer                                                              */
/* ------------------------------------------------------------------ */

static void emit_value(SB *sb, const OPPValue *v, int depth, int compact);

static void
emit_string_token(SB *sb, const OPPValue *v)
{
	const char *s;

	if (v->raw != NULL) {
		sb_puts(sb, v->raw);
		return;
	}
	s = (v->str != NULL) ? v->str : "";
	if (v->quoted) {
		sb_putc(sb, '"');
		while (*s != '\0') {
			switch (*s) {
			case '"': sb_puts(sb, "\\\""); break;
			case '\\': sb_puts(sb, "\\\\"); break;
			case '\n': sb_puts(sb, "\\n"); break;
			case '\t': sb_puts(sb, "\\t"); break;
			case '\r': sb_puts(sb, "\\r"); break;
			default: sb_putc(sb, *s); break;
			}
			s++;
		}
		sb_putc(sb, '"');
		return;
	}
	sb_puts(sb, s);
}

static void
emit_comment(SB *sb, const char *comment)
{
	if (comment == NULL)
		return;
	sb_puts(sb, " /* ");
	sb_puts(sb, comment);
	sb_puts(sb, " */");
}

static void
emit_inline_array(SB *sb, const OPPValue *a)
{
	size_t i;

	sb_putc(sb, '(');
	for (i = 0; i < a->nelem; i++) {
		emit_value(sb, a->elems[i].value, 0, 1);
		emit_comment(sb, a->elems[i].comment);
		if (!a->inline_join || i + 1 < a->nelem)
			sb_puts(sb, ", ");
	}
	sb_putc(sb, ')');
}

static void
emit_inline_dict(SB *sb, const OPPValue *d)
{
	size_t i;

	if (d->nentry == 0) {
		sb_puts(sb, "{}");
		return;
	}
	sb_putc(sb, '{');
	if (d->inline_lead_space)
		sb_putc(sb, ' ');
	for (i = 0; i < d->nentry; i++) {
		if (i != 0)
			sb_putc(sb, ' ');
		sb_puts(sb, (d->entries[i].key_raw != NULL) ?
		    d->entries[i].key_raw : d->entries[i].key);
		emit_comment(sb, d->entries[i].key_comment);
		sb_puts(sb, " = ");
		emit_value(sb, d->entries[i].value, 0, 1);
		emit_comment(sb, d->entries[i].value_comment);
		sb_puts(sb, ";");
	}
	sb_puts(sb, " }");
}

static void emit_dict(SB *sb, const OPPValue *d, int depth);

static void
emit_array(SB *sb, const OPPValue *a, int depth)
{
	size_t i;

	sb_puts(sb, "(\n");
	for (i = 0; i < a->nelem; i++) {
		sb_indent(sb, depth + 1);
		emit_value(sb, a->elems[i].value, depth + 1, 0);
		emit_comment(sb, a->elems[i].comment);
		sb_puts(sb, ",\n");
	}
	sb_indent(sb, depth);
	sb_putc(sb, ')');
}

static void
emit_value(SB *sb, const OPPValue *v, int depth, int compact)
{
	if (v == NULL) {
		sb_puts(sb, "\"\"");
		return;
	}
	switch (v->kind) {
	case OPP_STRING:
		emit_string_token(sb, v);
		break;
	case OPP_ARRAY:
		if (compact || v->inline_form)
			emit_inline_array(sb, v);
		else
			emit_array(sb, v, depth);
		break;
	case OPP_DICT:
		if (compact || v->inline_form)
			emit_inline_dict(sb, v);
		else
			emit_dict(sb, v, depth);
		break;
	}
}

/* ---- objects: section markers, source order preserved ---- */

static void
emit_object_entry(SB *sb, const OPPValue *d, size_t idx, int depth)
{
	const OPPDictEntry *e = &d->entries[idx];
	OPPValue *val = e->value;

	sb_indent(sb, depth + 1);
	sb_puts(sb, (e->key_raw != NULL) ? e->key_raw : e->key);
	emit_comment(sb, e->key_comment);
	sb_puts(sb, " = ");
	emit_value(sb, val, depth + 1, val != NULL && val->inline_form);
	emit_comment(sb, e->value_comment);
	sb_puts(sb, ";\n");
}

static void
emit_objects(SB *sb, const OPPValue *d, int depth)
{
	const char *cur = NULL;
	size_t i;

	sb_puts(sb, "{\n");
	if (d->nlayout != 0) {
		for (i = 0; i < d->nlayout; i++) {
			const OPPLayoutItem *it = &d->layout[i];

			switch (it->kind) {
			case OPP_LAYOUT_SECTION_BEGIN:
				sb_puts(sb, "/* Begin ");
				sb_puts(sb, it->text);
				sb_puts(sb, " section */\n");
				break;
			case OPP_LAYOUT_SECTION_END:
				sb_puts(sb, "/* End ");
				sb_puts(sb, it->text);
				sb_puts(sb, " section */\n");
				break;
			case OPP_LAYOUT_LINE_COMMENT:
				sb_puts(sb, it->text);
				sb_putc(sb, '\n');
				break;
			case OPP_LAYOUT_BLANK:
				if (it->text != NULL)
					sb_puts(sb, it->text);
				sb_putc(sb, '\n');
				break;
			case OPP_LAYOUT_ENTRY:
				emit_object_entry(sb, d, it->index, depth);
				break;
			}
		}
		sb_indent(sb, depth);
		sb_puts(sb, "}");
		return;
	}
	/* No recorded layout (programmatically built): group by isa. */
	if (d->nentry != 0)
		sb_putc(sb, '\n');
	for (i = 0; i < d->nentry; i++) {
		const char *isa = opp_scalar_get(d->entries[i].value, "isa");

		if (isa == NULL)
			isa = "";
		if (cur == NULL || strcmp(cur, isa) != 0) {
			if (cur != NULL) {
				sb_puts(sb, "/* End ");
				sb_puts(sb, cur);
				sb_puts(sb, " section */\n\n");
			}
			sb_puts(sb, "/* Begin ");
			sb_puts(sb, isa);
			sb_puts(sb, " section */\n");
			cur = isa;
		}
		emit_object_entry(sb, d, i, depth);
	}
	if (cur != NULL) {
		sb_puts(sb, "/* End ");
		sb_puts(sb, cur);
		sb_puts(sb, " section */\n");
	}
	sb_indent(sb, depth);
	sb_puts(sb, "}");
}

static void
emit_dict(SB *sb, const OPPValue *d, int depth)
{
	size_t i;

	sb_puts(sb, "{\n");
	for (i = 0; i < d->nentry; i++) {
		OPPDictEntry *e = &d->entries[i];

		sb_indent(sb, depth + 1);
		sb_puts(sb, (e->key_raw != NULL) ? e->key_raw : e->key);
		emit_comment(sb, e->key_comment);
		sb_puts(sb, " = ");
		if (strcmp(e->key, "objects") == 0 &&
		    e->value != NULL && e->value->kind == OPP_DICT)
			emit_objects(sb, e->value, depth + 1);
		else
			emit_value(sb, e->value, depth + 1, 0);
		emit_comment(sb, e->value_comment);
		sb_puts(sb, ";\n");
	}
	sb_indent(sb, depth);
	sb_puts(sb, "}");
}

char *
opp_write_document(const OPPDocument *doc, size_t *lenp, char **errp)
{
	SB sb;

	if (doc == NULL || doc->root == NULL || doc->root->kind != OPP_DICT) {
		if (errp != NULL)
			*errp = xstrdup("document root is not a dictionary");
		return (NULL);
	}
	sb_init(&sb);
	if (doc->header != NULL) {
		sb_puts(&sb, doc->header);
		sb_putc(&sb, '\n');
	}
	emit_dict(&sb, doc->root, 0);
	if (!doc->no_trailing_newline)
		sb_putc(&sb, '\n');
	if (lenp != NULL)
		*lenp = sb.len;
	if (errp != NULL)
		*errp = NULL;
	return (sb.p);
}
