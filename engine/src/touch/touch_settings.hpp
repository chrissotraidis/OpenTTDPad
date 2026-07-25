/*
 * This file is part of OpenTTDPad and OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License version 2.
 */

/** @file touch_settings.hpp Single source of truth for touch gesture thresholds. */

#ifndef OPENTTDPAD_TOUCH_SETTINGS_HPP
#define OPENTTDPAD_TOUCH_SETTINGS_HPP

#include <cstdint>

namespace OpenTTDPad::Touch {

struct Settings {
	double tap_slop = 8.0;
	uint32_t tap_max_ms = 300;
	uint32_t double_tap_ms = 250;
	double double_tap_slop = 24.0;
	uint32_t long_press_ms = 500;
	double drag_activate = 10.0;
	uint32_t two_tap_max_ms = 250;
	uint32_t two_tap_stagger_ms = 100;
	double pinch_activate = 24.0;
	double pinch_step_factor = 1.25;
	double precision_magnification = 2.0;
	double precision_offset = 60.0;
	double edge_reject = 8.0;
	double minimum_target = 44.0;
	double momentum_decay_per_frame = 0.92;
	double momentum_min_velocity = 0.02;
	uint32_t momentum_max_release_delay_ms = 80;
};

} // namespace OpenTTDPad::Touch

#endif /* OPENTTDPAD_TOUCH_SETTINGS_HPP */
