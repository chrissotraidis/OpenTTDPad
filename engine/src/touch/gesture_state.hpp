/*
 * This file is part of OpenTTDPad and OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License version 2.
 */

/** @file gesture_state.hpp Platform-neutral direct-touch gesture recognizer. */

#ifndef OPENTTDPAD_GESTURE_STATE_HPP
#define OPENTTDPAD_GESTURE_STATE_HPP

#include "touch_settings.hpp"

#include <array>
#include <cstdint>
#include <vector>

namespace OpenTTDPad::Touch {

struct TouchPoint {
	double x = 0;
	double y = 0;
};

enum class State : uint8_t {
	Idle,
	Pending,
	OneFingerSuppressed,
	TwoFingerPending,
	Panning,
	DirectDragging,
	Pinching,
	Precision,
};

enum class ActionType : uint8_t {
	Tap,
	DoubleTap,
	SecondaryClick,
	PanBegin,
	PanMove,
	PanEnd,
	DirectDragBegin,
	DirectDragMove,
	DirectDragEnd,
	DirectDragCancel,
	ZoomIn,
	ZoomOut,
	PrecisionBegin,
	PrecisionMove,
	PrecisionCommit,
	Cancel,
};

struct Action {
	ActionType type;
	TouchPoint position;
	TouchPoint delta{};
};

/**
 * Recognizes touch intent without depending on SDL or OpenTTD globals.
 * The caller decides at first-finger-down whether a drag at that position
 * should go to a desktop UI/construction tool. Bare one-finger map movement
 * is suppressed; map panning begins only after a second finger lands.
 */
class GestureState {
public:
	explicit GestureState(Settings settings = {});

	std::vector<Action> FingerDown(int64_t id, TouchPoint position, uint32_t timestamp_ms, bool direct_drag,
		bool precision_allowed = true);
	std::vector<Action> FingerMove(int64_t id, TouchPoint position, uint32_t timestamp_ms);
	std::vector<Action> FingerUp(int64_t id, TouchPoint position, uint32_t timestamp_ms);
	std::vector<Action> Update(uint32_t timestamp_ms);
	std::vector<Action> Cancel();

	State GetState() const { return this->state; }
	const Settings &GetSettings() const { return this->settings; }
	bool SetSettings(Settings settings);
	size_t FingerCount() const;

private:
	struct Finger {
		bool active = false;
		int64_t id = 0;
		TouchPoint start{};
		TouchPoint current{};
		uint32_t down_ms = 0;
	};

	Settings settings;
	State state = State::Idle;
	std::array<Finger, 2> fingers{};
	bool direct_drag = false;
	bool precision_allowed = true;
	double initial_pinch_distance = 0;
	double pinch_reference_distance = 0;
	TouchPoint initial_centroid{};
	TouchPoint last_centroid{};
	TouchPoint pan_velocity{};
	uint32_t last_pan_move_ms = 0;
	bool two_finger_tap_possible = false;
	uint32_t two_finger_start_ms = 0;
	uint32_t two_finger_contact_ms = 0;
	bool has_last_tap = false;
	TouchPoint last_tap_position{};
	uint32_t last_tap_ms = 0;

	Finger *FindFinger(int64_t id);
	const Finger *FindFinger(int64_t id) const;
	Finger *AllocateFinger(int64_t id);
	TouchPoint Centroid() const;
	double FingerDistance() const;
	double MaxMovement() const;
	TouchPoint EndPan(uint32_t timestamp_ms);
	TouchPoint UpdatePanVelocity(TouchPoint position, uint32_t timestamp_ms);
	void ResetActiveGesture();
	std::vector<Action> EmitTap(TouchPoint position, uint32_t timestamp_ms);
};

} // namespace OpenTTDPad::Touch

#endif /* OPENTTDPAD_GESTURE_STATE_HPP */
