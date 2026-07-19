/*
 * This file is part of OpenTTDPad and OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License version 2.
 */

/** @file hit_test.cpp Platform-neutral expanded touch-target resolution. */

#include "../stdafx.h"
#include "hit_test.hpp"

#include <limits>

#include "../safeguards.h"

namespace OpenTTDPad::Touch {

int ResolveExpandedHitTarget(TouchPoint point, const std::vector<HitTarget> &targets, double min_target_size)
{
	int best_id = -1;
	double best_distance = std::numeric_limits<double>::max();

	for (const HitTarget &target : targets) {
		const double centre_x = (target.left + target.right) / 2.0;
		const double centre_y = (target.top + target.bottom) / 2.0;
		const double half_width = std::max((target.right - target.left) / 2.0, min_target_size / 2.0);
		const double half_height = std::max((target.bottom - target.top) / 2.0, min_target_size / 2.0);
		if (point.x < centre_x - half_width || point.x > centre_x + half_width ||
				point.y < centre_y - half_height || point.y > centre_y + half_height) {
			continue;
		}

		const double dx = point.x - centre_x;
		const double dy = point.y - centre_y;
		const double distance = dx * dx + dy * dy;
		if (distance < best_distance) {
			best_id = target.id;
			best_distance = distance;
		}
	}
	return best_id;
}

TouchPoint ClampToHitTarget(TouchPoint point, const HitTarget &target)
{
	return {
		std::clamp(point.x, target.left, target.right),
		std::clamp(point.y, target.top, target.bottom),
	};
}

} // namespace OpenTTDPad::Touch
