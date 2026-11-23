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

# The DVT* frameworks live in the sibling DVTFrameworks repository and are
# built there first ("make -C $(DVTFRAMEWORKS)").  The path is relative to
# this repository root and is baked into the binary's run path.
DVTFRAMEWORKS       ?= ../DVTFrameworks
DVTFRAMEWORKS_BUILD := $(DVTFRAMEWORKS)/build
APPKIT              ?= ../../../Library/Staging/AppKit
APPKIT_BUILD        := $(APPKIT)/build/release

CFLAGS   := $(OPT) -std=c11 -D_DARWIN_C_SOURCE -isysroot "$(SDK)" -ISources -Wall -Wextra
OBJCFLAGS := $(OPT) -fobjc-arc -D_DARWIN_C_SOURCE -isysroot "$(SDK)" \
	-IHeaders -ISources -I$(PROJECTMODEL) -F$(DVTFRAMEWORKS_BUILD) \
	-F$(APPKIT_BUILD) -Wall -Wextra

AGVTOOL      := $(BUILD_DIR)/agvtool
AGVTOOL_OBJS := $(OBJDIR)/agvtool.o

PBXTOOL      := $(BUILD_DIR)/pbxtool
PBXTOOL_OBJS := $(OBJDIR)/pbxproj.o $(OBJDIR)/pbxtool.o

PBXMODEL      := $(BUILD_DIR)/pbxmodel
PBXMODEL_OBJS := $(OBJDIR)/pbxmodel.o $(OBJDIR)/pbxproj.o \
	$(OBJDIR)/PBXBuild.o $(OBJDIR)/PBXObject.o \
	$(OBJDIR)/PBXArchiveBinding.o $(OBJDIR)/PBXPListArchiver.o \
	$(OBJDIR)/PBXPListCoding.o \
	$(OBJDIR)/PBXProject.o $(OBJDIR)/PBXProjectModel.o $(OBJDIR)/PBXReference.o \
	$(OBJDIR)/PBXTarget.o $(OBJDIR)/XCBuildConfiguration.o \
	$(OBJDIR)/PBXSupport.o $(OBJDIR)/PBXNamePath.o \
	$(OBJDIR)/PBXPlatformFilterableItem.o $(OBJDIR)/PBXFolder.o \
	$(OBJDIR)/PBXFramework.o $(OBJDIR)/PBXFileTypePart.o \
	$(OBJDIR)/PBXFileType.o \
	$(OBJDIR)/TSPropertyListDictionary.o \
	$(OBJDIR)/NSString+TSStringAdditions.o \
	$(OBJDIR)/XCSpecification.o $(OBJDIR)/XCSpecificationProxy.o \
	$(OBJDIR)/XCSpecificationRegistry.o $(OBJDIR)/XCSpecificationFilter.o \
	$(OBJDIR)/XCPropertyDefinition.o $(OBJDIR)/XCPropertyTypes.o \
	$(OBJDIR)/XCPropertyCategory.o $(OBJDIR)/XCPropertyDomainSpecification.o \
	$(OBJDIR)/DVTMacroDefinitionTable+XCMacroExpansionExtensions.o \
	$(OBJDIR)/XCMacroExpansionScope.o $(OBJDIR)/XCObjectGraphPath.o \
	$(OBJDIR)/XCStringList.o \
	$(OBJDIR)/XCPropertyDefinition_SupportedVersionRange.o \
	$(OBJDIR)/XCCompatibilityFeature.o \
	$(OBJDIR)/PBXPlistArchiverAdditions.o \
	$(OBJDIR)/PBXPackageTypeSpecification.o \
	$(OBJDIR)/XCProductTypeSpecification.o \
	$(OBJDIR)/PBXRuntimeValues.o

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
	$(CC) $(OBJCFLAGS) -o $@ $(PBXMODEL_OBJS) -framework Foundation \
		-F$(DVTFRAMEWORKS_BUILD) -framework DVTMacroFoundation \
		-framework DVTFoundation -framework AppKit \
		-Wl,-rpath,@loader_path/../../$(DVTFRAMEWORKS)/build \
		-Wl,-rpath,@loader_path/../../$(APPKIT)/build/release

$(OBJDIR)/pbxmodel.o: Sources/DevToolsCore/pbxmodel/pbxmodel.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/pbxmodel/pbxmodel.m

$(OBJDIR)/PBXBuild.o: $(PROJECTMODEL)/PBXBuild.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXBuild.m

$(OBJDIR)/PBXObject.o: $(PROJECTMODEL)/PBXObject.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXObject.m

$(OBJDIR)/PBXArchiveBinding.o: $(PROJECTMODEL)/PBXArchiveBinding.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXArchiveBinding.m

$(OBJDIR)/PBXPListArchiver.o: $(PROJECTMODEL)/PBXPListArchiver.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXPListArchiver.m

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

$(OBJDIR)/PBXSupport.o: $(PROJECTMODEL)/PBXSupport.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXSupport.m

$(OBJDIR)/PBXNamePath.o: $(PROJECTMODEL)/PBXNamePath.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXNamePath.m

$(OBJDIR)/PBXPlatformFilterableItem.o: $(PROJECTMODEL)/PBXPlatformFilterableItem.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXPlatformFilterableItem.m

$(OBJDIR)/PBXFolder.o: $(PROJECTMODEL)/PBXFolder.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXFolder.m

$(OBJDIR)/PBXFramework.o: $(PROJECTMODEL)/PBXFramework.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXFramework.m

$(OBJDIR)/TSPropertyListDictionary.o: Sources/DevToolsSupport/TSPropertyListDictionary.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsSupport/TSPropertyListDictionary.m

$(OBJDIR)/PBXFileTypePart.o: $(PROJECTMODEL)/PBXFileTypePart.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXFileTypePart.m

$(OBJDIR)/PBXFileType.o: $(PROJECTMODEL)/PBXFileType.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXFileType.m

$(OBJDIR)/NSString+TSStringAdditions.o: Sources/DevToolsSupport/NSString+TSStringAdditions.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsSupport/NSString+TSStringAdditions.m

$(OBJDIR)/XCSpecification.o: Sources/DevToolsCore/BuildSystem/XCSpecification.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/BuildSystem/XCSpecification.m

$(OBJDIR)/XCSpecificationProxy.o: Sources/DevToolsCore/BuildSystem/XCSpecificationProxy.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/BuildSystem/XCSpecificationProxy.m

$(OBJDIR)/XCSpecificationFilter.o: Sources/DevToolsCore/BuildSystem/XCSpecificationFilter.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/BuildSystem/XCSpecificationFilter.m

$(OBJDIR)/XCSpecificationRegistry.o: Sources/DevToolsCore/BuildSystem/XCSpecificationRegistry.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/BuildSystem/XCSpecificationRegistry.m

$(OBJDIR)/XCPropertyDefinition.o: Sources/DevToolsCore/BuildSystem/XCPropertyDefinition.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/BuildSystem/XCPropertyDefinition.m

$(OBJDIR)/XCPropertyTypes.o: Sources/DevToolsCore/BuildSystem/XCPropertyTypes.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/BuildSystem/XCPropertyTypes.m

$(OBJDIR)/XCPropertyCategory.o: Sources/DevToolsCore/BuildSystem/XCPropertyCategory.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/BuildSystem/XCPropertyCategory.m

$(OBJDIR)/XCPropertyDomainSpecification.o: Sources/DevToolsCore/BuildSystem/XCPropertyDomainSpecification.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/BuildSystem/XCPropertyDomainSpecification.m

$(OBJDIR)/DVTMacroDefinitionTable+XCMacroExpansionExtensions.o: Sources/DevToolsCore/BuildSystem/DVTMacroDefinitionTable+XCMacroExpansionExtensions.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/BuildSystem/DVTMacroDefinitionTable+XCMacroExpansionExtensions.m

$(OBJDIR)/XCMacroExpansionScope.o: Sources/DevToolsCore/XCMacroExpansionScope.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/XCMacroExpansionScope.m

$(OBJDIR)/XCObjectGraphPath.o: Sources/DevToolsCore/XCObjectGraphPath.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/XCObjectGraphPath.m

$(OBJDIR)/XCStringList.o: Sources/DevToolsCore/XCStringList.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/XCStringList.m

$(OBJDIR)/XCPropertyDefinition_SupportedVersionRange.o: Sources/DevToolsCore/BuildSystem/XCPropertyDefinition_SupportedVersionRange.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/BuildSystem/XCPropertyDefinition_SupportedVersionRange.m

$(OBJDIR)/XCCompatibilityFeature.o: Sources/DevToolsCore/XCCompatibilityFeature.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/XCCompatibilityFeature.m

$(OBJDIR)/PBXPlistArchiverAdditions.o: Sources/DevToolsCore/ProjectModel/PBXPlistArchiverAdditions.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/ProjectModel/PBXPlistArchiverAdditions.m

$(OBJDIR)/PBXPackageTypeSpecification.o: Sources/DevToolsCore/BuildSystem/PBXPackageTypeSpecification.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/BuildSystem/PBXPackageTypeSpecification.m

$(OBJDIR)/XCProductTypeSpecification.o: Sources/DevToolsCore/BuildSystem/XCProductTypeSpecification.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ Sources/DevToolsCore/BuildSystem/XCProductTypeSpecification.m

$(OBJDIR)/PBXRuntimeValues.o: $(PROJECTMODEL)/PBXRuntimeValues.m
	@mkdir -p $(OBJDIR)
	$(CC) $(OBJCFLAGS) -c -o $@ $(PROJECTMODEL)/PBXRuntimeValues.m

test: all
	@ok=0; \
	bash tools/difftest.sh $(AGVTOOL) || ok=1; \
	PBXMODEL=$(PBXMODEL) PBXTOOL=$(PBXTOOL) bash tools/pbxroundtrip.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/propertydefs.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/propertydomains.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/xcmacroexpansion.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/macroevaluation.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/objectgraphpath.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/compatfeatures.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/supportedversionranges.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/propertyvalues.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/propertyconditions.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/propertysupported.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/plistwrappers.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/stringlist.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/tsstringbom.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/xcproducttypes.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/runtimevalues.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/buildconfigurations.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/targetdependencies.sh || ok=1; \
	PBXMODEL=$(PBXMODEL) bash tools/archivebindings.sh || ok=1; \
	exit $$ok

install: all
	install -d $(DESTDIR)$(PREFIX)/bin $(DESTDIR)$(PREFIX)/share/man/man1
	install -m 0755 $(AGVTOOL) $(DESTDIR)$(PREFIX)/bin/agvtool
	install -m 0755 $(PBXTOOL) $(DESTDIR)$(PREFIX)/bin/pbxtool
	install -m 0755 $(PBXMODEL) $(DESTDIR)$(PREFIX)/bin/pbxmodel
	install -m 0444 man/agvtool.1 $(DESTDIR)$(PREFIX)/share/man/man1/agvtool.1

clean:
	rm -rf build

.PHONY: all test install clean
