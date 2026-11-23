/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Unarchiving half of the PBXArchiveBinding family. */

#ifndef DEVTOOLSCORE_PBXUNARCHIVINGBINDING_H
#define DEVTOOLSCORE_PBXUNARCHIVINGBINDING_H

#import "DevToolsCore/ProjectModel/PBXArchiveBinding.h"

@interface PBXUnarchivingBinding : PBXArchiveBinding
{
	SEL _unarchiveSelector;
	IMP _unarchiveMethod;
	SEL _validateValueSelector;
	void *_validateValueFunction;
	BOOL _isScalar;
}

- (instancetype)initWithKeyBinding:(NSKeyBinding *)binding
    archiveMask:(NSInteger)mask
    clss:(Class)targetClass
    key:(NSString *)key;

- (void)readValueForObject:(id)object
    fromPListUnarchiver:(id)unarchiver;

@end

#endif /* DEVTOOLSCORE_PBXUNARCHIVINGBINDING_H */
