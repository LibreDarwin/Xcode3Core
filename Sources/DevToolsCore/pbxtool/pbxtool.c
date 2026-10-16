/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Command-line driver for the ProjectModel OpenStep project reader/writer. */

#include "DevToolsCore/ProjectModel/pbxproj.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void
usage(void)
{
	fprintf(stderr,
	    "usage: pbxtool roundtrip <project.pbxproj>\n"
	    "       pbxtool cat <project.pbxproj>\n"
	    "       pbxtool dump <project.pbxproj>\n");
	exit(2);
}

static char *
slurp(const char *path, size_t *lenp)
{
	FILE *f;
	char *buf;
	size_t cap = 0, len = 0, n;
	char tmp[65536];

	f = fopen(path, "rb");
	if (f == NULL)
		return (NULL);
	buf = NULL;
	while ((n = fread(tmp, 1, sizeof (tmp), f)) > 0) {
		if (len + n + 1 > cap) {
			cap = (cap == 0) ? 65536 : cap;
			while (len + n + 1 > cap)
				cap *= 2;
			buf = realloc(buf, cap);
			if (buf == NULL)
				abort();
		}
		memcpy(buf + len, tmp, n);
		len += n;
	}
	if (ferror(f)) {
		fclose(f);
		free(buf);
		return (NULL);
	}
	fclose(f);
	if (buf == NULL) {
		buf = malloc(1);
		if (buf == NULL)
			abort();
	}
	buf[len] = '\0';
	*lenp = len;
	return (buf);
}

static void
dump_value(const OPPValue *v, int depth)
{
	size_t i;

	for (i = 0; i < (size_t)depth; i++)
		fputc('\t', stdout);
	if (v == NULL) {
		printf("<null>\n");
		return;
	}
	switch (v->kind) {
	case OPP_STRING:
		printf("string \"%s\"\n", v->str);
		break;
	case OPP_ARRAY:
		printf("array[%zu]\n", v->nelem);
		for (i = 0; i < v->nelem; i++) {
			dump_value(v->elems[i].value, depth + 1);
			if (v->elems[i].comment != NULL) {
				size_t j;
				for (j = 0; j < (size_t)(depth + 1); j++)
					fputc('\t', stdout);
				printf("  /* %s */\n", v->elems[i].comment);
			}
		}
		break;
	case OPP_DICT:
		printf("dict[%zu]%s\n", v->nentry,
		    v->inline_form ? " (inline)" : "");
		for (i = 0; i < v->nentry; i++) {
			size_t j;
			for (j = 0; j < (size_t)(depth + 1); j++)
				fputc('\t', stdout);
			printf("%s:\n", v->entries[i].key);
			dump_value(v->entries[i].value, depth + 2);
		}
		break;
	}
}

int
main(int argc, char **argv)
{
	OPPDocument *doc;
	char *err = NULL;
	char *out;
	size_t outlen = 0;
	const char *cmd;

	if (argc < 3)
		usage();
	cmd = argv[1];

	doc = opp_parse_file(argv[2], &err);
	if (doc == NULL) {
		fprintf(stderr, "pbxtool: %s: %s\n", argv[2],
		    (err != NULL) ? err : "parse error");
		free(err);
		return (1);
	}

	if (strcmp(cmd, "dump") == 0) {
		if (doc->header != NULL)
			printf("header: %s\n", doc->header);
		dump_value(doc->root, 0);
		opp_free(doc->root);
		free(doc->header);
		free(doc);
		return (0);
	}

	out = opp_write_document(doc, &outlen, &err);
	if (out == NULL) {
		fprintf(stderr, "pbxtool: %s: %s\n", argv[2],
		    (err != NULL) ? err : "write error");
		free(err);
		opp_free(doc->root);
		free(doc->header);
		free(doc);
		return (1);
	}

	if (strcmp(cmd, "cat") == 0) {
		fwrite(out, 1, outlen, stdout);
		free(out);
		opp_free(doc->root);
		free(doc->header);
		free(doc);
		return (0);
	}

	if (strcmp(cmd, "roundtrip") == 0) {
		size_t inlen = 0;
		char *in = slurp(argv[2], &inlen);

		if (in == NULL) {
			fprintf(stderr, "pbxtool: %s: %s\n", argv[2],
			    strerror(errno));
			free(out);
			opp_free(doc->root);
			free(doc->header);
			free(doc);
			return (1);
		}
		if (inlen == outlen && memcmp(in, out, inlen) == 0) {
			printf("OK %s\n", argv[2]);
			free(in);
			free(out);
			opp_free(doc->root);
			free(doc->header);
			free(doc);
			return (0);
		}
		fprintf(stderr, "pbxtool: MISMATCH %s (%zu -> %zu bytes)\n",
		    argv[2], inlen, outlen);
		free(in);
		free(out);
		opp_free(doc->root);
		free(doc->header);
		free(doc);
		return (1);
	}

	usage();
	return (2);
}
