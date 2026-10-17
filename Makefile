# Copyright (C) 2026, LibreDarwin
# SPDX-License-Identifier: BSD-3-Clause
# Open source reimplementation of Apple's Xcode3Core.
#
# This Makefile builds the tools that live under Sources/DevToolsCore
# (agvtool, pbxtool and pbxmodel); the framework targets are added as their
# sources are reconstructed.
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

PROJECTMODEL := Sources/DevToolsCore/ProjectModel

CFLAGS   := $(OPT) -std=c11 -D_DARWIN_C_SOURCE -isysroot "$(SDK)" -ISources -Wall -Wextra
OBJCFLAGS := $(OPT) -fobjc-arc -D_DARWIN_C_SOURCE -isysroot "$(SDK)" \
	-IHeaders -ISources -I$(PROJECTMODEL) -Wall -Wextra

AGVTOOL      := $(BUILD_DIR)/agvtool
AGVTOOL_OBJS := $(OBJDIR)/agvtool.o

PBXTOOL      := $(BUILD_DIR)/pbxtool
PBXTOOL_OBJS := $(OBJDIR)/pbxproj.o $(OBJDIR)/pbxtool.o

PBXMODEL      := $(BUILD_DIR)/pbxmodel
PBXMODEL_OBJS := $(OBJDIR)/pbxmodel.o $(OBJDIR)/pbxproj.o \
	$(OBJDIR)/PBXBuild.o $(OBJDIR)/PBXObject.o $(OBJDIR)/PBXPListCoding.o \
	$(OBJDIR)/PBXProject.o $(OBJDIR)/PBXProjectModel.o $(OBJDIR)/PBXReference.o \
	$(OBJDIR)/PBXTarget.o $(OBJDIR)/XCBuildConfiguration.o

PREFIX  ?= /usr/local
DESTDIR ?=

all: $(AGVTOOL) $(PBXTOOL) $(PBXMODEL)

$(AGVTOOL): $(AGVTOOL_OBJS)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $(AGVTOOL_OBJS) -lm

$(OBJDIR)/agvtool.o: Sources/DevToolsCore/agvtool/agvtool.c
	@mkdir -p $(OBJDIR)
	$(CC) $(CFLAGS) -c -o $@ Sources/DevToolsCore/agvtool/agvtool.c

$(PBXTOOL): $(PBXTOOL_OBJS)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -o $@ $(PBXTOOL_OBJS)

$(OBJDIR)/pbxproj.o: $(PROJECTMODEL)/pbxproj.c
	@mkdir -p $(OBJDIR)
	$(CC) $(CFLAGS) -c -o $@ $(PROJECTMODEL)/pbxproj.c

$(OBJDIR)/pbxtool.o: Sources/DevToolsCore/pbxtool/pbxtool.c
	@mkdir -p $(OBJDIR)
	$(CC) $(CFLAGS) -c -o $@ Sources/DevToolsCore/pbxtool/pbxtool.c

$(PBXMODEL): $(PBXMODEL_OBJS)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(OBJCFLAGS) -o $@ $(PBXMODEL_OBJS) -framework Foundation

$(OBJDIR)/pbxmodel.o: Sources/DevToolsCore/pbxmodel/pbxmodel.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/pbxmodel/pbxmodel.m

$(OBJDIR)/PBXBuild.o: $(PROJECTMODEL)/PBXBuild.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXBuild.m

$(OBJDIR)/PBXObject.o: $(PROJECTMODEL)/PBXObject.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXObject.m

$(OBJDIR)/PBXPListCoding.o: $(PROJECTMODEL)/PBXPListCoding.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXPListCoding.m

$(OBJDIR)/PBXProject.o: $(PROJECTMODEL)/PBXProject.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXProject.m

$(OBJDIR)/PBXProjectModel.o: $(PROJECTMODEL)/PBXProjectModel.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXProjectModel.m

$(OBJDIR)/PBXReference.o: $(PROJECTMODEL)/PBXReference.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXReference.m

$(OBJDIR)/PBXTarget.o: $(PROJECTMODEL)/PBXTarget.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXTarget.m

$(OBJDIR)/XCBuildConfiguration.o: $(PROJECTMODEL)/XCBuildConfiguration.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/XCBuildConfiguration.m

test: all
	bash tools/difftest.sh $(AGVTOOL)

install: all
	install -d $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(PREFIX)/share/man/man1
	install -m 0755 $(AGVTOOL) $(DESTDIR)$(PREFIX)/bin/agvtool
	install -m 0755 $(PBXTOOL) $(DESTDIR)$(PREFIX)/bin/pbxtool
	install -m 0755 $(PBXMODEL) $(DESTDIR)$(PREFIX)/bin/pbxmodel
	install -m 0444 man/agvtool.1 $(DESTDIR)$(PREFIX)/share/man/man1/agvtool.1

clean:
	rm -rf build

.PHONY: all test install clean
