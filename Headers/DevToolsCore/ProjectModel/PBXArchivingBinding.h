/* Copyright (C) 2026, LibreDarwin
 * SPDX-License-Identifier: BSD-3-Clause
 * Archiving half of the PBXArchiveBinding family. */

#ifndef DEVTOOLSCORE_PBXARCHIVINGBINDING_H
#define DEVTOOLSCORE_PBXARCHIVINGBINDING_H

#import "DevToolsCore/ProjectModel/PBXArchiveBinding.h"

@interface PBXArchivingBinding : PBXArchiveBinding
{
	SEL _archiveSelector;
	IMP _archiveMethod;
	void *_getValueMethod;
}

- (void)writeValueForObject:(id)object toPListArchiver:(id)archiver;

@end

#endif /* DEVTOOLSCORE_PBXARCHIVINGBINDING_H */
