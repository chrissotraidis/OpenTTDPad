/*
 * This file is part of OpenTTDPad and OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License version 2.
 */

#ifndef OPENTTDPAD_DOCUMENT_MANAGER_H
#define OPENTTDPAD_DOCUMENT_MANAGER_H

#include <cstdint>

#ifdef __OBJC__
@class NSArray;
@class NSURL;
#endif

extern "C" void OpenTTDPadEnsureOptionsButton();
extern "C" void OpenTTDPadSetConstructionPalette(int transport_type);
extern "C" uint64_t OpenTTDPadTouchSettingsGeneration();
extern "C" void OpenTTDPadLoadTouchSettings(double *threshold_scale, uint32_t *long_press_ms,
	bool *expanded_targets, bool *momentum);

#ifdef __OBJC__
extern "C" void OpenTTDPadHandleOpenURLs(NSArray *urls);
#endif

#endif /* OPENTTDPAD_DOCUMENT_MANAGER_H */
