/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Private Foundation <-> OPP value conversion (DevToolsCore). */

#ifndef DEVTOOLSCORE_PBXPLISTCODING_H
#define DEVTOOLSCORE_PBXPLISTCODING_H

#import <Foundation/Foundation.h>

#include "pbxproj.h"

/* Convert an OPP value tree into immutable Foundation containers
 * (NSString / NSArray / NSDictionary).  Returns nil for a NULL input. */
id PBXObjectFromOPPValue(const OPPValue *value);

/* Convert a Foundation value into a freshly-owned OPP value tree.
 * Supports NSString, NSNumber, NSArray and NSDictionary. */
OPPValue *PBXOPPValueFromObject(id object);

#endif	/* DEVTOOLSCORE_PBXPLISTCODING_H */
