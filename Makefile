# Copyright (C) 2026, LibreDarwin
# SPDX-License-Identifier: BSD-3-Clause
# Open source reimplementation of Apple's Xcode3Core.
#
# This Makefile currently builds the tools that live under Sources/DevToolsCore
# (agvtool and pbxtool); the framework targets are added as their sources are
# reconstructed.
#
# Portable to both GNU make and BSD make (bmake): no pattern rules, no
# ifeq/ifdef/.if conditionals and no $(if)/$(shell) functions.  Per-config
# flags come from make/<CONFIG>.mk so both make variants behave identically.

CONFIG ?= release
SDK    ?= /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
CC     := /Users/sunneva/xnuports-root/devel/xcode-tools/build/release/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang

-include make/$(CONFIG).mk

BUILD_DIR := build/$(CONFIG)
OBJDIR    := $(BUILD_DIR)/obj

CFLAGS := $(OPT) -std=c11 -D_DARWIN_C_SOURCE -isysroot "$(SDK)" -ISources -Wall -Wextra

AGVTOOL      := $(BUILD_DIR)/agvtool
AGVTOOL_OBJS := $(OBJDIR)/agvtool.o

PBXTOOL      := $(BUILD_DIR)/pbxtool
PBXTOOL_OBJS := $(OBJDIR)/pbxproj.o $(OBJDIR)/pbxtool.o

PREFIX  ?= /usr/local
DESTDIR ?=

all: $(AGVTOOL) $(PBXTOOL)

$(AGVTOOL): $(AGVTOOL_OBJS)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $(AGVTOOL_OBJS) -lm

$(OBJDIR)/agvtool.o: Sources/DevToolsCore/agvtool/agvtool.c
	@mkdir -p $(OBJDIR)
	$(CC) $(CFLAGS) -c -o $@ Sources/DevToolsCore/agvtool/agvtool.c

$(PBXTOOL): $(PBXTOOL_OBJS)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $(PBXTOOL_OBJS)

$(OBJDIR)/pbxproj.o: Sources/DevToolsCore/ProjectModel/pbxproj.c
	@mkdir -p $(OBJDIR)
	$(CC) $(CFLAGS) -c -o $@ Sources/DevToolsCore/ProjectModel/pbxproj.c

$(OBJDIR)/pbxtool.o: Sources/DevToolsCore/pbxtool/pbxtool.c
	@mkdir -p $(OBJDIR)
	$(CC) $(CFLAGS) -c -o $@ Sources/DevToolsCore/pbxtool/pbxtool.c

test: all
	bash tools/difftest.sh $(AGVTOOL)

install: all
	install -d $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(PREFIX)/share/man/man1
	install -m 0755 $(AGVTOOL) $(DESTDIR)$(PREFIX)/bin/agvtool
	install -m 0755 $(PBXTOOL) $(DESTDIR)$(PREFIX)/bin/pbxtool
	install -m 0444 man/agvtool.1 $(DESTDIR)$(PREFIX)/share/man/man1/agvtool.1

clean:
	rm -rf build

.PHONY: all test install clean
