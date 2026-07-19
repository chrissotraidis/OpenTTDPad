/*
 * This file is part of OpenTTDPad and OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License version 2.
 */

/** @file hit_test.hpp Platform-neutral expanded touch-target resolution. */

#ifndef OPENTTDPAD_TOUCH_HIT_TEST_HPP
#define OPENTTDPAD_TOUCH_HIT_TEST_HPP

#include "gesture_state.hpp"

#include <vector>

namespace OpenTTDPad::Touch {

struct HitTarget {
	int id;
	double left;
	double top;
	double right;
	double bottom;
};

/**
 * Find the closest target centre whose effective square contains a touch.
 * Visual bounds are never changed; min_target_size only expands hit regions.
 */
int ResolveExpandedHitTarget(TouchPoint point, const std::vector<HitTarget> &targets, double min_target_size);

/** Move a touch just inside the visual bounds of a resolved target. */
TouchPoint ClampToHitTarget(TouchPoint point, const HitTarget &target);

} // namespace OpenTTDPad::Touch

#endif /* OPENTTDPAD_TOUCH_HIT_TEST_HPP */
