/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * agvtool: Apple-generic versioning for Xcode projects.
 *
 * Clean-room reimplementation of Apple's agvtool (a /bin/sh script shipped
 * at Xcode.app/Contents/Developer/usr/bin/agvtool).  The build number lives
 * in project.pbxproj as CURRENT_PROJECT_VERSION / DYLIB_CURRENT_VERSION /
 * MODULE_VERSION, and -- with -all -- as CFBundleVersion in each target's
 * Info.plist; the marketing version lives in the Info.plists as
 * CFBundleShortVersionString.
 *
 * The reference is a shell script, so there is no binary to be byte-for-byte
 * identical to; the contract reproduced here is the script's observable
 * behaviour: stdout, exit status, and the in-place edits it makes.
 *
 * Both files are edited textually, a value at a time, rather than parsed and
 * rewritten: a project file carries comments, ordering and an Xcode layout
 * that nothing here has any business reformatting, and the same goes for a
 * hand-edited Info.plist.
 */

#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fnmatch.h>
#include <pwd.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* Apple's exit statuses, which callers around this tool test. */
#define EX_NOOP		1	/* no operation given */
#define EX_BADOP	2	/* bad or missing operation argument */
#define EX_NOPROJ	3	/* no project in this directory */
#define EX_NOSCM	4	/* tag with neither CVS nor SVN enabled */
#define EX_UNCOMMITTED	5	/* tag update check found local changes */
#define EX_NOVERSION	6	/* no CURRENT_PROJECT_VERSION / marketing ver */
#define EX_NONEWVERSION	7	/* no new version number supplied */
#define EX_NORCNAME	8	/* cannot derive an RC submission name */

static const char *g_argv0;

static char *g_project;		/* e.g. "MyApp.xcodeproj/project.pbxproj" */
static char *g_projbase;	/* e.g. "MyApp" */
static char *g_rc_project_name;	/* RC_PROJECT_NAME, or the project basename */

/*
 * USE_CVS / USE_SVN are unset (NULL) until the global flags or the user
 * defaults decide them; the reference distinguishes "unset" from "NO".
 */
static char *g_cvs, *g_svn;
static char *g_cvs_tool, *g_svn_tool, *g_svn_base_tag_url;
static char *g_submit_cvs_tag, *g_submit_svn_tag;

static const char *g_version_num;	/* sanitised CURRENT_PROJECT_VERSION */

/* ------------------------------------------------------------------ */
/* small helpers                                                       */
/* ------------------------------------------------------------------ */

static void
die(const char *msg)
{
	fprintf(stderr, "agvtool: %s\n", msg);
	exit(1);
}

static void *
xmalloc(size_t n)
{
	void *p = malloc(n ? n : 1);

	if (p == NULL)
		die("out of memory");
	return (p);
}

static char *
xstrdup(const char *s)
{
	char *p = xmalloc(strlen(s) + 1);

	strcpy(p, s);
	return (p);
}

static char *
xstrndup(const char *s, size_t n)
{
	char *p = xmalloc(n + 1);

	memcpy(p, s, n);
	p[n] = '\0';
	return (p);
}

/* printf, but always with a trailing newline, matching echo. */
static void
pr_line(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vprintf(fmt, ap);
	va_end(ap);
	putchar('\n');
}

static void
pr_blank(void)
{
	putchar('\n');
}

/* ------------------------------------------------------------------ */
/* growable string buffer                                              */
/* ------------------------------------------------------------------ */

struct sb {
	char	*p;
	size_t	len, cap;
};

static void
sb_init(struct sb *b)
{
	b->p = NULL;
	b->len = b->cap = 0;
}

static void
sb_grow(struct sb *b, size_t want)
{
	if (b->len + want + 1 <= b->cap)
		return;
	b->cap = b->cap ? b->cap : 64;
	while (b->len + want + 1 > b->cap)
		b->cap *= 2;
	b->p = realloc(b->p, b->cap);
	if (b->p == NULL)
		die("out of memory");
}

static void
sb_putn(struct sb *b, const char *s, size_t n)
{
	sb_grow(b, n);
	memcpy(b->p + b->len, s, n);
	b->len += n;
	b->p[b->len] = '\0';
}

static void
sb_puts(struct sb *b, const char *s)
{
	sb_putn(b, s, strlen(s));
}

static void
sb_putc(struct sb *b, char c)
{
	sb_putn(b, &c, 1);
}

/* ------------------------------------------------------------------ */
/* a vector of strings                                                 */
/* ------------------------------------------------------------------ */

struct strv {
	char	**v;
	size_t	  n, cap;
};

static void
strv_push(struct strv *s, char *item)
{
	if (s->n == s->cap) {
		s->cap = s->cap ? s->cap * 2 : 8;
		s->v = realloc(s->v, s->cap * sizeof(*s->v));
		if (s->v == NULL)
			die("out of memory");
	}
	s->v[s->n++] = item;
}

static int
cmp_str(const void *a, const void *b)
{
	return (strcmp(*(char *const *)a, *(char *const *)b));
}

/*
 * sort -u: sort the items bytewise and drop duplicates, joining the result
 * with newlines.
 */
static char *
strv_dedup_join(struct strv *s)
{
	struct sb b;
	size_t i;

	sb_init(&b);
	if (s->n == 0)
		return (b.p = xstrdup(""), b.p);
	qsort(s->v, s->n, sizeof(*s->v), cmp_str);
	for (i = 0; i < s->n; i++) {
		if (i > 0 && strcmp(s->v[i], s->v[i - 1]) == 0)
			continue;
		if (b.len > 0)
			sb_putc(&b, '\n');
		sb_puts(&b, s->v[i]);
	}
	return (b.p);
}

/* ------------------------------------------------------------------ */
/* path helpers                                                        */
/* ------------------------------------------------------------------ */

static char *
path_basename(const char *path, const char *suffix)
{
	size_t n = strlen(path), i, bl, sl;
	char *b;

	while (n > 1 && path[n - 1] == '/')
		n--;
	i = n;
	while (i > 0 && path[i - 1] != '/')
		i--;
	b = xstrndup(path + i, n - i);
	if (suffix != NULL && suffix[0] != '\0') {
		bl = strlen(b);
		sl = strlen(suffix);
		if (bl > sl && memcmp(b + bl - sl, suffix, sl) == 0)
			b[bl - sl] = '\0';
	}
	return (b);
}

static char *
path_dirname(const char *path)
{
	size_t n = strlen(path), i, j;

	while (n > 1 && path[n - 1] == '/')
		n--;
	i = n;
	while (i > 0 && path[i - 1] != '/')
		i--;
	if (i == 0)
		return (xstrdup("."));
	j = i;
	while (j > 1 && path[j - 1] == '/')
		j--;
	return (xstrndup(path, j));
}

static bool
file_is_reg(const char *path)
{
	struct stat st;

	return (stat(path, &st) == 0 && S_ISREG(st.st_mode));
}

static char *
read_file(const char *path, size_t *lenp)
{
	FILE *f = fopen(path, "rb");
	struct sb b;
	char buf[8192];
	size_t n;

	sb_init(&b);
	if (f == NULL)
		return (NULL);
	while ((n = fread(buf, 1, sizeof(buf), f)) > 0)
		sb_putn(&b, buf, n);
	fclose(f);
	if (b.p == NULL)
		b.p = xstrdup("");
	if (lenp != NULL)
		*lenp = b.len;
	return (b.p);
}

static void
write_file(const char *path, const char *buf, size_t len)
{
	FILE *f = fopen(path, "wb");

	if (f == NULL) {
		fprintf(stderr, "%s: %s\n", path, strerror(errno));
		return;
	}
	if (fwrite(buf, 1, len, f) != len) {
		fclose(f);
		return;
	}
	fclose(f);
}

/*
 * Read a user default the way the reference does: `defaults read agvtool
 * <key>`, with the empty string standing for "not set".
 */
static char *
defaults_read(const char *key)
{
	char cmd[256], buf[1024];
	FILE *f;
	size_t len;

	snprintf(cmd, sizeof(cmd), "/usr/bin/defaults read agvtool %s 2>/dev/null",
	    key);
	f = popen(cmd, "r");
	if (f == NULL)
		return (xstrdup(""));
	len = fread(buf, 1, sizeof(buf) - 1, f);
	fclose(f);
	buf[len] = '\0';
	if (len > 0 && buf[len - 1] == '\n')
		buf[len - 1] = '\0';
	return (xstrdup(buf));
}

/* ------------------------------------------------------------------ */
/* line splitting                                                      */
/* ------------------------------------------------------------------ */

struct lspan {
	size_t	off, len;
};

/*
 * Split a buffer into lines on '\n'.  *trailing_nl records whether the
 * original ended with a newline, so a line-preserving rewrite reproduces
 * the file exactly.
 */
static struct lspan *
split_lines(const char *buf, size_t len, size_t *nlinesp, int *trailing_nl)
{
	struct lspan *ls = NULL;
	size_t n = 0, cap = 0, pos = 0;

	*trailing_nl = (len > 0 && buf[len - 1] == '\n');
	while (pos < len) {
		size_t e = pos;

		while (e < len && buf[e] != '\n')
			e++;
		if (n == cap) {
			cap = cap ? cap * 2 : 16;
			ls = realloc(ls, cap * sizeof(*ls));
			if (ls == NULL)
				die("out of memory");
		}
		ls[n].off = pos;
		ls[n].len = e - pos;
		n++;
		pos = e + 1;
	}
	*nlinesp = n;
	return (ls);
}

/* ------------------------------------------------------------------ */
/* sed emulation                                                       */
/* ------------------------------------------------------------------ */

/*
 * sed "s/\(^[ \t]*KEY =[ \t]*\)\(.*\)\(;.*$\)/\1VAL\3/"
 * Rewrites a setting on one line, returning a fresh string, or NULL if the
 * line does not match.  The value runs up to the last ';' on the line.
 */
static char *
subst_setting(const char *line, size_t len, const char *key, const char *val)
{
	size_t i = 0, kl = strlen(key), j;
	long k;
	struct sb b;

	while (i < len && (line[i] == ' ' || line[i] == '\t'))
		i++;
	if (i + kl + 2 > len)
		return (NULL);
	if (memcmp(line + i, key, kl) != 0)
		return (NULL);
	if (line[i + kl] != ' ' || line[i + kl + 1] != '=')
		return (NULL);
	j = i + kl + 2;
	while (j < len && (line[j] == ' ' || line[j] == '\t'))
		j++;
	for (k = (long)len - 1; k >= (long)j; k--)
		if (line[k] == ';')
			break;
	if (k < (long)j)
		return (NULL);
	sb_init(&b);
	sb_putn(&b, line, j);
	sb_puts(&b, val);
	sb_putn(&b, line + k, len - (size_t)k);
	return (b.p);
}

/*
 * sed "s/\(^[ \t]*<string>\)\(.*\)\(<\/string>.*$\)/\1VAL\3/"
 * Replaces the text between <string> and the last </string> on a line.
 */
static char *
subst_string_value(const char *line, size_t len, const char *val)
{
	static const char open[] = "<string>", close[] = "</string>";
	size_t i = 0, j, close_at = 0;
	bool found = false;
	struct sb b;

	while (i < len && (line[i] == ' ' || line[i] == '\t'))
		i++;
	if (i + sizeof(open) - 1 > len ||
	    memcmp(line + i, open, sizeof(open) - 1) != 0)
		return (NULL);
	j = i + sizeof(open) - 1;
	for (size_t k = j; k + sizeof(close) - 1 <= len; k++) {
		if (memcmp(line + k, close, sizeof(close) - 1) == 0) {
			close_at = k;
			found = true;
		}
	}
	if (!found)
		return (NULL);
	sb_init(&b);
	sb_putn(&b, line, j);
	sb_puts(&b, val);
	sb_putn(&b, line + close_at, len - close_at);
	return (b.p);
}

/* Does this line begin (after indentation) with the given literal? */
static bool
line_begins_with(const char *line, size_t len, const char *lit)
{
	size_t i = 0, ll = strlen(lit);

	while (i < len && (line[i] == ' ' || line[i] == '\t'))
		i++;
	return (i + ll <= len && memcmp(line + i, lit, ll) == 0);
}

/*
 * Apply subst_setting to every line, returning a fresh buffer.  Line count
 * and trailing-newline state are preserved.
 */
static char *
transform_setting(const char *buf, size_t len, const char *key, const char *val)
{
	size_t n, i;
	int trail;
	struct lspan *ls = split_lines(buf, len, &n, &trail);
	struct sb b;

	sb_init(&b);
	for (i = 0; i < n; i++) {
		const char *line = buf + ls[i].off;
		char *nv = subst_setting(line, ls[i].len, key, val);

		if (nv != NULL) {
			sb_puts(&b, nv);
			free(nv);
		} else {
			sb_putn(&b, line, ls[i].len);
		}
		if (i + 1 < n || trail)
			sb_putc(&b, '\n');
	}
	free(ls);
	if (b.p == NULL)
		b.p = xstrdup("");
	return (b.p);
}

/*
 * sed "/^[ \t]*<key>KEY.*$/,/.*$/s/<string>...<\/string>/.../"
 * The end address matches any line, so the edit covers the key line and the
 * line that follows it.
 */
static char *
transform_range_string(const char *buf, size_t len, const char *key,
    const char *val)
{
	size_t n, i;
	int trail;
	struct lspan *ls = split_lines(buf, len, &n, &trail);
	struct sb b;
	char *needle;

	if (asprintf(&needle, "<key>%s", key) < 0)
		die("out of memory");
	sb_init(&b);
	i = 0;
	while (i < n) {
		const char *line = buf + ls[i].off;
		bool in_range = false;

		if (line_begins_with(line, ls[i].len, needle))
			in_range = true;
		if (in_range && i + 1 < n) {
			const char *l2 = buf + ls[i + 1].off;
			char *nv = subst_string_value(l2, ls[i + 1].len, val);

			sb_putn(&b, line, ls[i].len);
			sb_putc(&b, '\n');
			if (nv != NULL) {
				sb_puts(&b, nv);
				free(nv);
			} else {
				sb_putn(&b, l2, ls[i + 1].len);
			}
			if (i + 2 < n || trail)
				sb_putc(&b, '\n');
			i += 2;
			continue;
		}
		sb_putn(&b, line, ls[i].len);
		if (i + 1 < n || trail)
			sb_putc(&b, '\n');
		i++;
	}
	free(needle);
	free(ls);
	if (b.p == NULL)
		b.p = xstrdup("");
	return (b.p);
}

/*
 * sed "/<key>CFBundleShortVersionString<\/key>/ { N ; s/.../.../ ; }"
 * Used to edit the marketing version inside a project file: on a line that
 * mentions the key, the following line is pulled in and the <string> value
 * replaced.  Lines that do not mention the key pass through untouched.
 */
static char *
transform_bsvs(const char *buf, size_t len, const char *val)
{
	static const char key[] = "<key>CFBundleShortVersionString</key>";
	static const char skey[] = "<key>CFBundleShortVersionString</key>";
	static const char open[] = "<string>";
	size_t n, i;
	int trail;
	struct lspan *ls = split_lines(buf, len, &n, &trail);
	struct sb b;

	sb_init(&b);
	i = 0;
	while (i < n) {
		const char *line = buf + ls[i].off;
		bool mentions = false;

		for (size_t k = 0; k + sizeof(key) - 1 <= ls[i].len; k++)
			if (memcmp(line + k, key, sizeof(key) - 1) == 0)
				mentions = true;
		if (mentions && i + 1 < n) {
			const char *l2 = buf + ls[i + 1].off;
			size_t ii = 0;
			char *nv = NULL;

			/*
			 * The substitution only fires when the key line is
			 * exactly the key (plus indent) and the next line
			 * opens with <string>.
			 */
			while (ii < ls[i].len && (line[ii] == ' ' ||
			    line[ii] == '\t'))
				ii++;
			if (ii + sizeof(skey) - 1 == ls[i].len &&
			    memcmp(line + ii, skey, sizeof(skey) - 1) == 0 &&
			    line_begins_with(l2, ls[i + 1].len, open))
				nv = subst_string_value(l2, ls[i + 1].len, val);
			sb_putn(&b, line, ls[i].len);
			sb_putc(&b, '\n');
			if (nv != NULL) {
				sb_puts(&b, nv);
				free(nv);
			} else {
				sb_putn(&b, l2, ls[i + 1].len);
			}
			if (i + 2 < n || trail)
				sb_putc(&b, '\n');
			i += 2;
			continue;
		}
		sb_putn(&b, line, ls[i].len);
		if (i + 1 < n || trail)
			sb_putc(&b, '\n');
		i++;
	}
	free(ls);
	if (b.p == NULL)
		b.p = xstrdup("");
	return (b.p);
}

/*
 * The reference's marketing-version extractor, run over a project file or a
 * plist, yielding one line per extracted value.
 */
static void
bsvs_lines(const char *buf, size_t len, struct strv *out)
{
	static const char key[] = "<key>CFBundleShortVersionString</key>";
	static const char open[] = "<string>";
	static const char close[] = "</string>";
	size_t n, i;
	int trail;
	struct lspan *ls = split_lines(buf, len, &n, &trail);

	i = 0;
	while (i < n) {
		const char *line = buf + ls[i].off;
		bool mentions = false;

		for (size_t k = 0; k + sizeof(key) - 1 <= ls[i].len; k++)
			if (memcmp(line + k, key, sizeof(key) - 1) == 0)
				mentions = true;
		if (mentions) {
			bool anchored = false;
			char *grp = NULL;

			if (i + 1 < n) {
				const char *l2 = buf + ls[i + 1].off;
				size_t ii = 0, j, c = 0;
				bool hasclose = false;

				while (ii < ls[i].len && (line[ii] == ' ' ||
				    line[ii] == '\t'))
					ii++;
				if (ii + sizeof(key) - 1 == ls[i].len &&
				    memcmp(line + ii, key, sizeof(key) - 1) == 0)
					anchored = true;
				j = 0;
				while (j < ls[i + 1].len && (l2[j] == ' ' ||
				    l2[j] == '\t'))
					j++;
				if (j + sizeof(open) - 1 <= ls[i + 1].len &&
				    memcmp(l2 + j, open, sizeof(open) - 1) == 0) {
					for (size_t k = j; k + sizeof(close) - 1
					    <= ls[i + 1].len; k++)
						if (memcmp(l2 + k, close,
						    sizeof(close) - 1) == 0) {
							c = k;
							hasclose = true;
						}
				}
				if (anchored && hasclose) {
					grp = xstrndup(l2 + j + sizeof(open) - 1,
					    c - (j + sizeof(open) - 1));
					strv_push(out, grp);
					i += 2;
					continue;
				}
				/*
				 * No substitution: p prints the pair, then
				 * because the pattern space still holds the
				 * key, rule 2's !{D} is skipped and sed
				 * auto-prints it again.
				 */
				strv_push(out, xstrndup(line, ls[i].len));
				strv_push(out, xstrndup(l2, ls[i + 1].len));
				strv_push(out, xstrndup(line, ls[i].len));
				strv_push(out, xstrndup(l2, ls[i + 1].len));
				i += 2;
				continue;
			}
			strv_push(out, xstrndup(line, ls[i].len));
			i++;
			continue;
		}
		i++;	/* discarded by the D in rule 2 */
	}
}

/*
 * grep INFOPLIST_FILE | sed ... | sort -u: the info-plist paths a project
 * references, stripped of the surrounding syntax and sorted.
 */
static char *
infoplist_paths(const char *buf, size_t len)
{
	struct strv v = { 0 };
	size_t n, i;
	int trail;
	struct lspan *ls = split_lines(buf, len, &n, &trail);
	char *joined;

	for (i = 0; i < n; i++) {
		const char *line = buf + ls[i].off;
		const char *last = NULL, *p;
		size_t end;

		for (size_t k = 0; k < ls[i].len; k++)
			if (k + 15 <= ls[i].len &&
			    memcmp(line + k, "INFOPLIST_FILE", 14) == 0)
				last = line + k;
		if (last == NULL)
			continue;
		p = last + 14;
		while (p < line + ls[i].len && *p != '=')
			p++;
		if (p < line + ls[i].len && *p == '=')
			p++;
		while (p < line + ls[i].len && (*p == ' ' || *p == '\t'))
			p++;
		end = ls[i].len - (size_t)(p - line);
		while (end > 0 && (p[end - 1] == ' ' || p[end - 1] == '\t'))
			end--;
		if (end > 0 && p[end - 1] == ';')
			end--;
		if (end > 0 && *p == '"') {
			p++;
			end--;
		}
		if (end > 0 && p[end - 1] == '"')
			end--;
		strv_push(&v, xstrndup(p, end));
	}
	joined = strv_dedup_join(&v);
	return (joined);
}

/* ------------------------------------------------------------------ */
/* project discovery                                                   */
/* ------------------------------------------------------------------ */

static void usage(void);

static void
multiple_projects(void)
{
	pr_line("There are multiple projects in this directory.  agvtool does not "
	    "work with multiple projects in the same directory.");
	usage();
	exit(EX_NOPROJ);
}

static void
find_project(void)
{
	struct strv v = { 0 };
	struct dirent *e;
	DIR *d = opendir(".");

	while (d != NULL && (e = readdir(d)) != NULL) {
		if (e->d_name[0] == '.')
			continue;
		if (fnmatch("*.xcodeproj", e->d_name, FNM_PERIOD) == 0)
			strv_push(&v, xstrdup(e->d_name));
	}
	if (d != NULL)
		closedir(d);
	if (v.n == 0)
		return;
	if (v.n > 1)
		multiple_projects();
	g_project = xstrdup(v.v[0]);
	g_projbase = path_basename(v.v[0], ".xcodeproj");
	{
		struct sb b;

		sb_init(&b);
		sb_puts(&b, v.v[0]);
		sb_puts(&b, "/project.pbxproj");
		g_project = b.p;
	}
}

static void
find_oldproject(void)
{
	struct strv v = { 0 };
	struct dirent *e;
	DIR *d = opendir(".");

	while (d != NULL && (e = readdir(d)) != NULL) {
		if (e->d_name[0] == '.')
			continue;
		if (fnmatch("*.pb*proj", e->d_name, FNM_PERIOD) == 0 ||
		    fnmatch("*.xcode", e->d_name, FNM_PERIOD) == 0)
			strv_push(&v, xstrdup(e->d_name));
	}
	if (d != NULL)
		closedir(d);
	if (v.n == 0)
		return;
	if (v.n > 1)
		multiple_projects();
	g_projbase = path_basename(v.v[0], ".xcode");
	{
		char *t = path_basename(g_projbase, ".pbproj");

		free(g_projbase);
		g_projbase = path_basename(t, ".pbxproj");
		free(t);
	}
	{
		struct sb b;

		sb_init(&b);
		sb_puts(&b, v.v[0]);
		sb_puts(&b, "/project.pbxproj");
		g_project = b.p;
	}
}

/* ------------------------------------------------------------------ */
/* version reading                                                     */
/* ------------------------------------------------------------------ */

/*
 * sed -n 's/^[ \t]*KEY =[ \t]*\(.*\);.*$/\1/p' <file> | sort -u
 */
static char *
setting_values(const char *buf, size_t len, const char *key)
{
	struct strv v = { 0 };
	size_t n, i;
	int trail;
	struct lspan *ls;

	if (buf == NULL)
		return (xstrdup(""));
	ls = split_lines(buf, len, &n, &trail);
	for (i = 0; i < n; i++) {
		const char *line = buf + ls[i].off;
		size_t l = ls[i].len, ii = 0, kl = strlen(key), j;
		long k;

		while (ii < l && (line[ii] == ' ' || line[ii] == '\t'))
			ii++;
		if (ii + kl + 2 > l || memcmp(line + ii, key, kl) != 0)
			continue;
		if (line[ii + kl] != ' ' || line[ii + kl + 1] != '=')
			continue;
		j = ii + kl + 2;
		while (j < l && (line[j] == ' ' || line[j] == '\t'))
			j++;
		for (k = (long)l - 1; k >= (long)j; k--)
			if (line[k] == ';')
				break;
		if (k < (long)j)
			continue;
		strv_push(&v, xstrndup(line + j, (size_t)k - j));
	}
	free(ls);
	return (strv_dedup_join(&v));
}

/*
 * get_version: populate g_version_num, or diagnose and exit.  The reference
 * then checks for more than one value with `echo ${VERSION_NUM} | wc -l`,
 * but echo rejoins the newline-separated values with spaces, so that test
 * can never see more than one line and is reproduced here by doing nothing.
 */
static void
get_version(bool terse)
{
	size_t len = 0;
	char *text = read_file(g_project, &len);

	g_version_num = setting_values(text, len, "CURRENT_PROJECT_VERSION");
	free(text);
	if (g_version_num[0] == '\0') {
		if (!terse) {
			pr_line("There does not seem to be a CURRENT_PROJECT_VERSION "
			    "key set for this project.  Add this key to your "
			    "target's expert build settings.");
			pr_blank();
		}
		exit(EX_NOVERSION);
	}
}

static void
get_rc_project_name(void)
{
	size_t len = 0;
	char *text = read_file(g_project, &len);

	(void)text;
	(void)len;
	{
		char *v = setting_values(text, len, "RC_PROJECT_NAME");

		free(text);
		if (v[0] == '\0') {
			free(v);
			v = xstrdup(g_projbase);
		}
		if (v[0] == '\0') {
			pr_line("Cannot figure out a project name for RC submission.");
			exit(EX_NORCNAME);
		}
		g_rc_project_name = v;
	}
}

/* ------------------------------------------------------------------ */
/* usage                                                               */
/* ------------------------------------------------------------------ */

static void
usage(void)
{
	char *b = path_basename(g_argv0, NULL);

	pr_blank();
	pr_line("%s - Apple-generic versioning tool for Xcode projects", b);
	pr_line("  usage:");
	pr_line("    %s help", b);
	pr_line("    %s what-version | vers [-terse]", b);
	pr_line("    %s [-noscm | -usecvs | -usesvn] next-version | bump [-all]", b);
	pr_line("    %s [-noscm | -usecvs | -usesvn] new-version [-all] <versNum>", b);
	pr_line("    %s [-noscm | -usecvs | -usesvn] tag [-force | -F] "
	    "[-noupdatecheck | -Q] [-baseurlfortag]", b);
	pr_line("    %s what-marketing-version | mvers [-terse | -terse1]", b);
	pr_line("    %s [-noscm | -usecvs | -usesvn] new-marketing-version "
	    "<versString>", b);
	pr_blank();
	free(b);
}

static void
print_help(void)
{
	usage();
	pr_blank();
	pr_line("For more information type \"man agvtool\".");
}

/* ------------------------------------------------------------------ */
/* operations                                                          */
/* ------------------------------------------------------------------ */

static void
what_version(bool terse)
{
	get_version(terse);
	if (terse)
		pr_line("%s", g_version_num);
	else {
		pr_line("Current version of project %s is: ", g_projbase);
		pr_line("    %s", g_version_num);
		pr_blank();
	}
}

/* Run a helper, letting it own the terminal; returns its exit status. */
static int
run_argv(char *const av[])
{
	pid_t p;
	int st;

	fflush(stdout);
	fflush(stderr);
	p = fork();
	if (p < 0) {
		fprintf(stderr, "%s: %s\n", av[0], strerror(errno));
		return (126);
	}
	if (p == 0) {
		execvp(av[0], av);
		fprintf(stderr, "%s: %s\n", av[0], strerror(errno));
		_exit(errno == ENOENT ? 127 : 126);
	}
	if (waitpid(p, &st, 0) < 0)
		return (1);
	if (WIFEXITED(st))
		return (WEXITSTATUS(st));
	return (126);
}

/* Expand a leading "~user" the way /bin/sh would. */
static char *
expand_tilde(const char *s)
{
	const char *slash;
	char user[64];
	struct passwd *pw;
	size_t n;
	struct sb b;

	if (s[0] != '~')
		return (xstrdup(s));
	slash = strchr(s, '/');
	n = slash ? (size_t)(slash - s - 1) : strlen(s) - 1;
	if (n >= sizeof(user))
		return (xstrdup(s));
	memcpy(user, s + 1, n);
	user[n] = '\0';
	pw = getpwnam(user);
	if (pw == NULL)
		return (xstrdup(s));
	sb_init(&b);
	sb_puts(&b, pw->pw_dir);
	sb_puts(&b, slash ? slash : "");
	return (b.p);
}

/* The version with dots turned into tildes, as the reference's sed does. */
static char *
version_tilde(void)
{
	char *v = xstrdup(g_version_num);

	for (char *p = v; *p; p++)
		if (*p == '.')
			*p = '~';
	return (v);
}

static void
new_version(const char *newver, bool all)
{
	struct sb b;
	char *text, *out;
	size_t len = 0;
	char *plists;

	if (newver[0] == '\0') {
		pr_line("No new version number specified.");
		exit(EX_NONEWVERSION);
	}
	pr_line("Setting version of project %s to: ", g_projbase);
	pr_line("    %s.", newver);
	pr_blank();

	text = read_file(g_project, &len);
	if (text == NULL) {
		text = xstrdup("");
		len = 0;
	}
	out = transform_setting(text, len, "CURRENT_PROJECT_VERSION", newver);
	free(text);
	text = transform_setting(out, strlen(out), "DYLIB_CURRENT_VERSION",
	    newver);
	free(out);
	out = transform_setting(text, strlen(text), "MODULE_VERSION", newver);
	free(text);
	if (all) {
		pr_line("Also setting CFBundleVersion key (assuming it exists)");
		pr_blank();
		text = transform_range_string(out, strlen(out),
		    "CFBundleVersion", newver);
		free(out);
		out = text;
	}
	write_file(g_project, out, strlen(out));
	free(out);

	if (all) {
		char *ptext = read_file(g_project, &len);

		plists = infoplist_paths(ptext ? ptext : "", ptext ? len : 0);
		free(ptext);
		if (plists[0] != '\0') {
			pr_line("Updating CFBundleVersion in Info.plist(s)...");
			pr_blank();
			{
				char *save = NULL, *line;

				for (line = strtok_r(plists, "\n", &save);
				    line != NULL;
				    line = strtok_r(NULL, "\n", &save)) {
					char *canon, *dir;

					if (line[0] == '\0')
						continue;
					dir = path_dirname(g_project);
					if (dir[0] == '\0') {
						free(dir);
						dir = xstrdup(".");
					}
					if (line[0] == '/' || line[0] == '~' ||
					    line[0] == '$') {
						canon = xstrdup(line);
					} else {
						sb_init(&b);
						sb_puts(&b, dir);
						sb_puts(&b, "/../");
						sb_puts(&b, line);
						canon = b.p;
					}
					free(dir);
					if (canon[0] == '\0' ||
					    !file_is_reg(canon)) {
						pr_line("Cannot find \"%s\"",
						    canon);
						free(canon);
						continue;
					}
					{
						size_t clen = 0;
						char *cb = read_file(canon, &clen);
						char *nb;

						if (cb == NULL)
							cb = xstrdup("");
						nb = transform_range_string(cb,
						    clen, "CFBundleVersion",
						    newver);
						if (nb[0] != '\0')
							write_file(canon, nb,
							    strlen(nb));
						free(nb);
						free(cb);
					}
					pr_line("Updated CFBundleVersion in \"%s\" "
					    "to %s", canon, newver);
					free(canon);
				}
			}
		}
		free(plists);
		pr_blank();
	}
	pr_blank();
	if (g_cvs != NULL && strcmp(g_cvs, "YES") == 0) {
		pr_line("%s commit -m \"Change version to %s\"", g_cvs_tool,
		    newver);
		{
			char *av[] = { g_cvs_tool, "commit", "-m", NULL, NULL };
			char *msg;

			if (asprintf(&msg, "Change version to %s", newver) < 0)
				die("out of memory");
			av[3] = msg;
			run_argv(av);
			free(msg);
		}
	} else if (g_svn != NULL && strcmp(g_svn, "YES") == 0) {
		pr_line("%s commit -m \"Change version to %s\"", g_svn_tool,
		    newver);
	}
}

static void
next_version(bool all, bool incr_minor)
{
	const char *v;
	char *joined, *result;
	struct sb b;

	get_version(false);
	/* echo ${VERSION_NUM} rejoins newline-separated values with spaces. */
	joined = xstrdup(g_version_num);
	for (char *p = joined; *p; p++)
		if (*p == '\n')
			*p = ' ';
	v = joined;
	if (incr_minor) {
		/* awk -F . '{$NF = $NF + 1; OFS="."; print $0}' */
		char *copy = xstrdup(v), *save = NULL, *tok;
		struct strv f = { 0 };
		char *last;
		double dval;
		char num[64];

		for (tok = strtok_r(copy, ".", &save); tok != NULL;
		    tok = strtok_r(NULL, ".", &save))
			strv_push(&f, xstrdup(tok));
		if (f.n == 0)
			strv_push(&f, xstrdup(""));
		last = f.v[f.n - 1];
		dval = strtod(last, NULL) + 1;
		snprintf(num, sizeof(num), "%.6g", dval);
		free(f.v[f.n - 1]);
		f.v[f.n - 1] = xstrdup(num);
		sb_init(&b);
		for (size_t i = 0; i < f.n; i++) {
			if (i > 0)
				sb_putc(&b, '.');
			sb_puts(&b, f.v[i]);
		}
		result = b.p;
		free(copy);
	} else {
		/* sed 's%\..*$%%' | awk '{print $1 + 1}' */
		char *dot = strchr(v, '.');
		char *prefix = dot ? xstrndup(v, (size_t)(dot - v)) : xstrdup(v);
		char *save = NULL, *first = strtok_r(prefix, " \t", &save);
		double dval = (first ? strtod(first, NULL) : 0) + 1;
		char num[64];

		snprintf(num, sizeof(num), "%.6g", dval);
		result = xstrdup(num);
		free(prefix);
	}
	free(joined);
	new_version(result, all);
	free(result);
}

static void
new_marketing_version(const char *newver)
{
	char *text, *out;
	size_t len = 0;
	char *plists;

	if (newver[0] == '\0') {
		pr_line("No new marketing version number specified.");
		exit(EX_NONEWVERSION);
	}
	pr_line("Setting CFBundleShortVersionString of project %s to: ",
	    g_projbase);
	pr_line("    %s.", newver);
	pr_blank();
	text = read_file(g_project, &len);
	if (text == NULL) {
		text = xstrdup("");
		len = 0;
	}
	out = transform_bsvs(text, len, newver);
	free(text);
	write_file(g_project, out, strlen(out));
	free(out);

	text = read_file(g_project, &len);
	plists = infoplist_paths(text ? text : "", text ? len : 0);
	free(text);
	if (plists[0] != '\0') {
		pr_line("Updating CFBundleShortVersionString in Info.plist(s)...");
		pr_blank();
		{
			char *save = NULL, *line;

			for (line = strtok_r(plists, "\n", &save); line != NULL;
			    line = strtok_r(NULL, "\n", &save)) {
				char *canon, *dir, *nb, *cb;
				size_t clen = 0;

				if (line[0] == '\0')
					continue;
				dir = path_dirname(g_project);
				if (line[0] == '/' || line[0] == '~' ||
				    line[0] == '$')
					canon = xstrdup(line);
				else {
					struct sb bb;

					sb_init(&bb);
					sb_puts(&bb, dir);
					sb_puts(&bb, "/../");
					sb_puts(&bb, line);
					canon = bb.p;
				}
				free(dir);
				if (canon[0] == '\0' || !file_is_reg(canon)) {
					pr_line("Cannot find \"%s\"", canon);
					free(canon);
					continue;
				}
				cb = read_file(canon, &clen);
				if (cb == NULL) {
					pr_line("Cannot find \"%s\"", canon);
					free(canon);
					continue;
				}
				nb = transform_range_string(cb, clen,
				    "CFBundleShortVersionString", newver);
				if (nb[0] != '\0')
					write_file(canon, nb, strlen(nb));
				free(nb);
				free(cb);
				pr_line("Updated CFBundleShortVersionString in "
				    "\"%s\" to %s", canon, newver);
				free(canon);
			}
		}
	}
	free(plists);
	if (g_cvs != NULL && strcmp(g_cvs, "YES") == 0) {
		pr_line("%s commit -m \"Change marketing version to %s\"",
		    g_cvs_tool, newver);
	} else if (g_svn != NULL && strcmp(g_svn, "YES") == 0) {
		pr_line("%s commit -m \"Change marketing version to %s\"",
		    g_svn_tool, newver);
	}
}

static void
what_marketing_version(const char *arg)
{
	bool terse = (strcmp(arg, "TERSE") == 0 ||
	    strcmp(arg, "TERSE_ONE") == 0);
	bool one_only = (strcmp(arg, "TERSE_ONE") == 0);
	size_t len = 0;
	char *text, *mvers, *plists;

	text = read_file(g_project, &len);
	if (text != NULL) {
		struct strv v = { 0 };

		bsvs_lines(text, len, &v);
		mvers = strv_dedup_join(&v);
		free(text);
	} else {
		mvers = xstrdup("");
	}
	if (mvers[0] == '\0') {
		if (!terse) {
			pr_line("No marketing version number "
			    "(CFBundleShortVersionString) found for Jambase "
			    "targets.");
			pr_blank();
		}
	} else if (!terse) {
		pr_line("Current marketing version (CFBundleShortVersionString) "
		    "for Jambase targets: ");
		pr_line("    %s", mvers);
		pr_blank();
	} else {
		pr_line("%s", mvers);
	}
	free(mvers);

	if (!terse)
		pr_line("Looking for marketing version in native targets...");

	text = read_file(g_project, &len);
	plists = infoplist_paths(text ? text : "", text ? len : 0);
	free(text);
	if (plists[0] == '\0') {
		if (!terse) {
			pr_line("No native targets with Info.plist files found.");
			pr_blank();
		}
		free(plists);
		exit(EX_NOVERSION);
	}
	if (!terse) {
		pr_line("Looking for marketing version "
		    "(CFBundleShortVersionString) in native targets...");
		pr_blank();
	}
	{
		char *save = NULL, *line;

		for (line = strtok_r(plists, "\n", &save); line != NULL;
		    line = strtok_r(NULL, "\n", &save)) {
			char *canon, *dir, *cb, *mv;
			size_t clen = 0;
			struct strv v = { 0 };

			if (line[0] == '\0')
				continue;
			dir = path_dirname(g_project);
			if (line[0] == '/' || line[0] == '~' || line[0] == '$')
				canon = xstrdup(line);
			else {
				struct sb bb;

				sb_init(&bb);
				sb_puts(&bb, dir);
				sb_puts(&bb, "/../");
				sb_puts(&bb, line);
				canon = bb.p;
			}
			free(dir);
			if (canon[0] == '\0' || !file_is_reg(canon)) {
				if (!terse)
					pr_line("Cannot find \"%s\"", canon);
				free(canon);
				continue;
			}
			cb = read_file(canon, &clen);
			if (cb == NULL) {
				if (!terse)
					pr_line("Cannot find \"%s\"", canon);
				free(canon);
				continue;
			}
			bsvs_lines(cb, clen, &v);
			mv = strv_dedup_join(&v);
			free(cb);
			if (!terse) {
				pr_line("Found CFBundleShortVersionString of "
				    "\"%s\" in \"%s\" ", mv, canon);
			} else if (one_only) {
				pr_line("%s", mv);
				free(mv);
				free(canon);
				free(plists);
				exit(0);
			} else {
				pr_line("\"%s\"=%s", canon, mv);
			}
			free(mv);
			free(canon);
		}
	}
	free(plists);
}

static void
tag(const char *force, const char *updcheck, const char *baseurl)
{
	(void)baseurl;
	if (g_cvs != NULL && strcmp(g_cvs, "YES") == 0) {
		char *tname;
		char *expanded;

		get_version(false);
		if (strcmp(updcheck, "UPDATECHECK") == 0) {
			pr_line("Checking for uncommitted changes...");
			/* "$CVS" -nq update -d -P | awk '$1=="C"||$1=="M"{exit 1}' */
			{
				char cmd[512];
				FILE *f;
				char line[1024];
				int dirty = 0;

				snprintf(cmd, sizeof(cmd), "%s -nq update -d -P "
				    "2>/dev/null", g_cvs_tool);
				f = popen(cmd, "r");
				if (f != NULL) {
					while (fgets(line, sizeof(line), f)) {
						char *t = strtok(line, " \t\n");

						if (t != NULL && (strcmp(t, "C") ==
						    0 || strcmp(t, "M") == 0)) {
							dirty = 1;
							break;
						}
					}
					fclose(f);
				}
				if (dirty) {
					pr_line("*** Uncommitted files found "
					    "during update check.");
					pr_line("*** Commit all files or update by "
					    "hand and try again.");
					exit(EX_UNCOMMITTED);
				}
			}
		}
		tname = version_tilde();
		expanded = NULL;
		if (asprintf(&expanded, "%s-%s", g_projbase, tname) < 0)
			die("out of memory");
		if (strcmp(force, "FORCE") == 0) {
			pr_line("%s tag -F \"%s\"", g_cvs_tool, expanded);
			{
				char *av[] = { g_cvs_tool, "tag", "-F", expanded,
				    NULL };

				run_argv(av);
			}
			pr_blank();
			pr_line("Tagged %s-%s with force option.", g_projbase,
			    g_version_num);
		} else {
			pr_line("%s tag \"%s\"", g_cvs_tool, expanded);
			{
				char *av[] = { g_cvs_tool, "tag", expanded, NULL };

				run_argv(av);
			}
			pr_blank();
			pr_line("Tagged %s-%s.", g_projbase, g_version_num);
		}
		free(expanded);
		free(tname);
	} else if (g_svn != NULL && strcmp(g_svn, "YES") == 0) {
		char *tname, *svnurl, *tagurl, *copyurl, *tmp;

		get_version(false);
		if (strcmp(updcheck, "UPDATECHECK") == 0) {
			pr_line("Checking for uncommitted changes...");
			pr_line("\"%s\" status | awk '$1 == \"C\" || $1 == \"M\" "
			    "{exit 1}'", g_svn_tool);
			{
				char cmd[512];
				FILE *f;
				char line[1024];
				int dirty = 0;

				snprintf(cmd, sizeof(cmd), "%s status 2>/dev/null",
				    g_svn_tool);
				f = popen(cmd, "r");
				if (f != NULL) {
					while (fgets(line, sizeof(line), f)) {
						char *t = strtok(line, " \t\n");

						if (t != NULL && (strcmp(t, "C") ==
						    0 || strcmp(t, "M") == 0)) {
							dirty = 1;
							break;
						}
					}
					fclose(f);
				}
				if (dirty) {
					pr_line("*** Uncommitted files found "
					    "during update check.");
					pr_line("*** Commit all files or update by "
					    "hand and try again.");
					exit(EX_UNCOMMITTED);
				}
			}
		}
		tname = version_tilde();
		if (asprintf(&tagurl, "%s-", g_projbase) < 0)
			die("out of memory");
		tmp = tagurl;
		if (asprintf(&tagurl, "%s%s", tmp, tname) < 0)
			die("out of memory");
		free(tmp);
		svnurl = NULL;
		{
			char cmd[512];
			FILE *f;
			char line[1024];

			snprintf(cmd, sizeof(cmd), "%s info 2>/dev/null",
			    g_svn_tool);
			f = popen(cmd, "r");
			if (f != NULL) {
				while (fgets(line, sizeof(line), f)) {
					if (strncmp(line, "URL:", 4) == 0) {
						char *s = line + 4, *e;

						while (*s == ' ' || *s == '\t')
							s++;
						e = s + strlen(s);
						while (e > s &&
						    (e[-1] == '\n' ||
						    e[-1] == '\r'))
							*--e = '\0';
						free(svnurl);
						svnurl = xstrdup(s);
					}
				}
				fclose(f);
			}
		}
		if (svnurl == NULL)
			svnurl = xstrdup("");
		pr_line("Original URL is %s", svnurl);
		if (asprintf(&copyurl, "%s/%s",
		    (baseurl && baseurl[0]) ? baseurl : g_svn_base_tag_url,
		    tagurl) < 0)
			die("out of memory");
		pr_line("%s copy %s %s -m \"Creating copy for %s\"",
		    g_svn_tool, svnurl, copyurl, tagurl);
		pr_blank();
		pr_line("Created copy for %s-%s at %s.", g_projbase,
		    g_version_num, copyurl);
		free(copyurl);
		free(svnurl);
		free(tagurl);
		free(tname);
	} else {
		pr_line("The tag operation is supported only if CVS or SVN "
		    "support is enabled.");
		usage();
		exit(EX_NOSCM);
	}
}

static int
submit(const char *arg1, const char *arg2, const char *arg3)
{
	char *starp = NULL, *rcv = NULL;
	const char *star;
	int rc = 0;

	get_version(false);
	get_rc_project_name();

	if (asprintf(&rcv, "%s-%s", g_rc_project_name, g_version_num) < 0)
		die("out of memory");
	/* $* joins the remaining positional parameters with IFS (newline). */
	if (arg2[0] != '\0') {
		if (asprintf(&starp, "%s\n%s", arg2, arg3) < 0)
			die("out of memory");
	} else {
		starp = xstrdup(arg3);
	}
	star = starp;

	if (strcmp(arg1, "BYTAG") == 0) {
		if (g_cvs != NULL && strcmp(g_cvs, "YES") == 0) {
			char *av[10];
			int n = 0;
			char *save = NULL, *t;

			pr_line("~rc/bin/submitproject -version \"%s\" -tag "
			    "\"%s\" \"%s\" %s", rcv, rcv, g_rc_project_name,
			    star);
			av[n++] = expand_tilde("~rc/bin/submitproject");
			av[n++] = "-version";
			av[n++] = rcv;
			av[n++] = "-tag";
			av[n++] = rcv;
			av[n++] = g_rc_project_name;
			for (t = strtok_r(starp, "\n", &save); t != NULL;
			    t = strtok_r(NULL, "\n", &save))
				av[n++] = t;
			av[n] = NULL;
			rc = run_argv(av);
			free(av[0]);
		} else if (g_svn != NULL && strcmp(g_svn, "YES") == 0) {
			const char *base = (arg2[0]) ? arg2 : g_svn_base_tag_url;
			char *url, *av[10];
			int n = 0;
			char *save = NULL, *t;

			if (asprintf(&url, "%s/%s-", base, g_rc_project_name) < 0)
				die("out of memory");
			{
				char *wt = version_tilde(), *u2;

				if (asprintf(&u2, "%s%s", url, wt) < 0)
					die("out of memory");
				free(url);
				free(wt);
				url = u2;
			}
			pr_line("~rc/bin/submitproject -url \"%s\" -version "
			    "\"%s\" %s", url, rcv, star);
			av[n++] = expand_tilde("~rc/bin/submitproject");
			av[n++] = "-url";
			av[n++] = url;
			av[n++] = "-version";
			av[n++] = rcv;
			for (t = strtok_r(starp, "\n", &save); t != NULL;
			    t = strtok_r(NULL, "\n", &save))
				av[n++] = t;
			av[n] = NULL;
			rc = run_argv(av);
			free(av[0]);
			free(url);
		}
	} else {
		char *exe = expand_tilde("~rc/bin/submitproject");

		pr_line("~rc/bin/submitproject -version \"%s\" . %s", rcv, star);
		{
			char *av[8];
			int n = 0;
			char *save = NULL, *t;

			av[n++] = exe;
			av[n++] = "-version";
			av[n++] = rcv;
			av[n++] = ".";
			for (t = strtok_r(starp, "\n", &save); t != NULL;
			    t = strtok_r(NULL, "\n", &save))
				av[n++] = t;
			av[n] = NULL;
			rc = run_argv(av);
		}
		free(exe);
	}
	free(starp);
	free(rcv);
	return (rc);
}

/* ------------------------------------------------------------------ */
/* main                                                                */
/* ------------------------------------------------------------------ */

int
main(int argc, char **argv)
{
	int i, restn;
	const char *op;
	char **rest;

	g_argv0 = argv[0];
	if (argc == 1) {
		pr_line("Operation specifier required.");
		usage();
		return (EX_NOOP);
	}
	i = 1;
	if (strcmp(argv[i], "-noscm") == 0) {
		g_cvs = "NO";
		g_svn = "NO";
		i++;
	} else if (strcmp(argv[i], "-usecvs") == 0) {
		g_cvs = "YES";
		g_svn = "NO";
		i++;
	} else if (strcmp(argv[i], "-usesvn") == 0) {
		g_cvs = "NO";
		g_svn = "YES";
		i++;
	}
	op = (i < argc) ? argv[i] : "";
	i++;
	rest = argv + i;
	restn = argc - i;

	if (strcmp(op, "help") == 0) {
		print_help();
		return (0);
	}

	find_project();
	if (g_project == NULL)
		find_oldproject();
	if (g_project == NULL) {
		pr_line("There are no Xcode project files in this directory.  "
		    "agvtool needs a project to operate.");
		return (EX_NOPROJ);
	}

	g_cvs_tool = defaults_read("CVSToolPath");
	if (g_cvs_tool[0] == '\0') {
		if (file_is_reg("/usr/local/bin/ocvs"))
			g_cvs_tool = "/usr/local/bin/ocvs";
		else if (file_is_reg("/usr/bin/ocvs"))
			g_cvs_tool = "/usr/bin/ocvs";
		else
			g_cvs_tool = "/usr/bin/cvs";
	}
	g_svn_tool = defaults_read("SVNToolPath");
	if (g_svn_tool[0] == '\0') {
		if (file_is_reg("/usr/bin/svn"))
			g_svn_tool = "/usr/bin/svn";
		else
			g_svn_tool = "/usr/local/bin/svn";
	}
	g_svn_base_tag_url = defaults_read("SVNBaseTagURL");
	if (g_cvs == NULL) {
		char *d = defaults_read("CVSEnabled");

		if (strcmp(d, "YES") == 0 || strcmp(d, "1") == 0) {
			g_cvs = "YES";
			g_svn = "NO";
		} else
			g_cvs = "NO";
		free(d);
	}
	if (g_svn == NULL) {
		char *d = defaults_read("SVNEnabled");

		if (strcmp(d, "YES") == 0 || strcmp(d, "1") == 0) {
			g_cvs = "NO";
			g_svn = "YES";
		} else
			g_svn = "NO";
		free(d);
	}
	{
		char *d = defaults_read("CVSSubmitByTag");

		if (strcmp(d, "YES") == 0 || strcmp(d, "1") == 0)
			g_submit_cvs_tag = g_cvs;
		else
			g_submit_cvs_tag = "NO";
		free(d);
	}
	{
		char *d = defaults_read("SVNSubmitByTag");

		if (strcmp(d, "YES") == 0 || strcmp(d, "1") == 0)
			g_submit_svn_tag = g_svn;
		else
			g_submit_svn_tag = "NO";
		free(d);
	}

	if (strcmp(op, "what-version") == 0 || strcmp(op, "vers") == 0) {
		bool terse = false;

		if (restn == 1) {
			if (strcmp(rest[0], "-terse") == 0) {
				terse = true;
				rest++;
				restn--;
			} else {
				pr_line("The what-version operation supports only "
				    "the optional -terse argument.");
				usage();
				return (EX_BADOP);
			}
		}
		if (restn != 0) {
			pr_line("The what-version operation supports only the "
			    "optional -terse argument.");
			usage();
			return (EX_BADOP);
		}
		what_version(terse);
	} else if (strcmp(op, "new-version") == 0) {
		bool all = false;

		if (restn >= 1 && strcmp(rest[0], "-all") == 0) {
			all = true;
			rest++;
			restn--;
		}
		if (restn != 1) {
			pr_line("The new-version operation takes optional -all "
			    "argument followed by a version number (required).");
			usage();
			return (EX_BADOP);
		}
		{
			const char *nv = rest[0];
			bool eff_all = all;

			/*
			 * The reference calls `new_version $1 $UPDATEALL`
			 * unquoted.  With IFS=newline an empty version number
			 * disappears, so UPDATEALL ("YES"/"NO") becomes the
			 * version and -all is lost.
			 */
			if (nv[0] == '\0') {
				nv = all ? "YES" : "NO";
				eff_all = false;
			}
			new_version(nv, eff_all);
		}
	} else if (strcmp(op, "apple-built") == 0) {
		bool all = false;

		while (restn > 0) {
			if (strcmp(rest[0], "-all") == 0)
				all = true;
			else {
				pr_line("The apple-built operation only accepts "
				    "-all as an optional argument. No other "
				    "arguments are supported.");
				usage();
				return (EX_BADOP);
			}
			rest++;
			restn--;
		}
		new_version("\"$(RC_ProjectSourceVersion)\"", all);
	} else if (strcmp(op, "next-version") == 0 ||
	    strcmp(op, "bump") == 0) {
		bool all = false, incr = false;

		while (restn > 0) {
			if (strcmp(rest[0], "-all") == 0)
				all = true;
			else if (strcmp(rest[0], "-increment-minor-version") == 0)
				incr = true;
			else {
				pr_line("The next-version operation only accepts "
				    "-all and -increment-minor-version as "
				    "optional arguments. No other arguments are "
				    "supported.");
				usage();
				return (EX_BADOP);
			}
			rest++;
			restn--;
		}
		next_version(all, incr);
	} else if (strcmp(op, "tag") == 0) {
		const char *force = "NOFORCE", *upd = "UPDATECHECK", *base = "";

		while (restn > 0) {
			if (strcmp(rest[0], "-force") == 0 ||
			    strcmp(rest[0], "-F") == 0) {
				force = "FORCE";
			} else if (strcmp(rest[0], "-noupdatecheck") == 0 ||
			    strcmp(rest[0], "-Q") == 0) {
				upd = "NOUPDATECHECK";
			} else if (strcmp(rest[0], "-baseurlfortag") == 0) {
				rest++;
				restn--;
				if (restn > 0) {
					if (g_svn != NULL &&
					    strcmp(g_svn, "YES") == 0)
						base = rest[0];
					else
						pr_line("The -baseurlfortag "
						    "optional argument is not valid "
						    "when using CVS. Ignoring "
						    "option.");
				}
			} else {
				pr_line("The tag operation takes accepts "
				    "-force|-F and -noupdatecheck|-Q as optional "
				    "arguments.  -baseurlfortag is also accepted "
				    "when using SVN. No other arguments are "
				    "supported.");
				usage();
				return (EX_BADOP);
			}
			rest++;
			restn--;
		}
		tag(force, upd, base);
	} else if (strcmp(op, "submit") == 0) {
		const char *arg1 = "NOTBYTAG", *arg2 = "", *arg3 = "";

		if (restn == 0) {
			pr_line("At least one release name argument is required "
			    "for the submit operation.");
			usage();
			return (EX_BADOP);
		}
		{
			struct sb names;

			sb_init(&names);
			while (restn > 0) {
				if (strcmp(rest[0], "-bytag") == 0) {
					arg1 = "BYTAG";
				} else if (strcmp(rest[0], "-notbytag") == 0) {
					arg1 = "NOTBYTAG";
				} else if (strcmp(rest[0], "-baseurlfortag")
				    == 0) {
					rest++;
					restn--;
					if (restn > 0) {
						if (g_svn != NULL &&
						    strcmp(g_svn, "YES") == 0)
							arg2 = rest[0];
						else
							pr_line("The "
							    "-baseurlfortag "
							    "optional argument is "
							    "not valid when using "
							    "CVS. Ignoring "
							    "option.");
					}
				} else {
					if (names.len > 0)
						sb_putc(&names, ' ');
					sb_puts(&names, rest[0]);
				}
				rest++;
				restn--;
			}
			arg3 = names.p ? names.p : "";
		}
		if (arg3[0] == '\0') {
			pr_line("At least one release name argument is required "
			    "for the submit operation.");
			usage();
			return (EX_BADOP);
		}
		if (g_submit_cvs_tag != NULL &&
		    strcmp(g_submit_cvs_tag, "YES") == 0)
			arg1 = "BYTAG";
		else if (g_submit_svn_tag != NULL &&
		    strcmp(g_submit_svn_tag, "YES") == 0)
			arg1 = "BYTAG";
		return (submit(arg1, arg2, arg3));
	} else if (strcmp(op, "new-marketing-version") == 0) {
		if (restn != 1) {
			pr_line("The new-marketing-version command requires a "
			    "single argument to specify the new version.");
			usage();
			return (EX_BADOP);
		}
		new_marketing_version(rest[0]);
	} else if (strcmp(op, "what-marketing-version") == 0 ||
	    strcmp(op, "mvers") == 0) {
		const char *arg = "NORMAL";

		if (restn == 1) {
			if (strcmp(rest[0], "-terse") == 0) {
				arg = "TERSE";
				rest++;
				restn--;
			} else if (strcmp(rest[0], "-terse1") == 0) {
				arg = "TERSE_ONE";
				rest++;
				restn--;
			} else {
				pr_line("The what-marketing-version operation "
				    "supports only the optional -terse or -terse1 "
				    "argument.");
				usage();
				return (EX_BADOP);
			}
		}
		if (restn != 0) {
			pr_line("The what-marketing-version operation supports "
			    "only the optional -terse or -terse1 argument.");
			usage();
			return (EX_BADOP);
		}
		what_marketing_version(arg);
	} else {
		pr_line("Unrecognized operation specifier \"%s\".", op);
		usage();
		return (EX_BADOP);
	}
	return (0);
}
