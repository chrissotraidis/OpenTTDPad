/*
 * This file is part of OpenTTDPad and OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License version 2.
 */

/** @file gesture_state.cpp Direct-touch gesture recognizer implementation. */

#include "../stdafx.h"
#include "gesture_state.hpp"

#include <cmath>

#include "../safeguards.h"

namespace OpenTTDPad::Touch {

static double Distance(TouchPoint a, TouchPoint b)
{
	return std::hypot(a.x - b.x, a.y - b.y);
}

GestureState::GestureState(Settings settings) : settings(settings)
{
}

bool GestureState::SetSettings(Settings settings)
{
	if (this->state != State::Idle) return false;
	this->settings = settings;
	return true;
}

size_t GestureState::FingerCount() const
{
	return std::count_if(this->fingers.begin(), this->fingers.end(), [](const Finger &finger) { return finger.active; });
}

GestureState::Finger *GestureState::FindFinger(int64_t id)
{
	for (Finger &finger : this->fingers) if (finger.active && finger.id == id) return &finger;
	return nullptr;
}

const GestureState::Finger *GestureState::FindFinger(int64_t id) const
{
	for (const Finger &finger : this->fingers) if (finger.active && finger.id == id) return &finger;
	return nullptr;
}

GestureState::Finger *GestureState::AllocateFinger(int64_t id)
{
	for (Finger &finger : this->fingers) {
		if (!finger.active) {
			finger = {};
			finger.active = true;
			finger.id = id;
			return &finger;
		}
	}
	return nullptr;
}

TouchPoint GestureState::Centroid() const
{
	TouchPoint result{};
	double count = 0;
	for (const Finger &finger : this->fingers) {
		if (!finger.active) continue;
		result.x += finger.current.x;
		result.y += finger.current.y;
		count++;
	}
	if (count != 0) {
		result.x /= count;
		result.y /= count;
	}
	return result;
}

double GestureState::FingerDistance() const
{
	const Finger *first = nullptr;
	const Finger *second = nullptr;
	for (const Finger &finger : this->fingers) {
		if (!finger.active) continue;
		if (first == nullptr) first = &finger; else second = &finger;
	}
	return first != nullptr && second != nullptr ? Distance(first->current, second->current) : 0;
}

double GestureState::MaxMovement() const
{
	double movement = 0;
	for (const Finger &finger : this->fingers) {
		if (finger.active) movement = std::max(movement, Distance(finger.start, finger.current));
	}
	return movement;
}

TouchPoint GestureState::UpdatePanVelocity(TouchPoint position, uint32_t timestamp_ms)
{
	TouchPoint delta{position.x - this->last_centroid.x, position.y - this->last_centroid.y};
	if (this->last_pan_move_ms != 0 && timestamp_ms > this->last_pan_move_ms) {
		const double elapsed = timestamp_ms - this->last_pan_move_ms;
		TouchPoint instantaneous{delta.x / elapsed, delta.y / elapsed};
		constexpr double new_sample_weight = 0.65;
		this->pan_velocity.x = this->pan_velocity.x * (1.0 - new_sample_weight) + instantaneous.x * new_sample_weight;
		this->pan_velocity.y = this->pan_velocity.y * (1.0 - new_sample_weight) + instantaneous.y * new_sample_weight;
	}
	this->last_centroid = position;
	this->last_pan_move_ms = timestamp_ms;
	return delta;
}

TouchPoint GestureState::EndPan(uint32_t timestamp_ms)
{
	if (this->last_pan_move_ms == 0 || timestamp_ms - this->last_pan_move_ms > this->settings.momentum_max_release_delay_ms) {
		return {};
	}
	return this->pan_velocity;
}

void GestureState::ResetActiveGesture()
{
	for (Finger &finger : this->fingers) finger = {};
	this->state = State::Idle;
	this->direct_drag = false;
	this->precision_allowed = true;
	this->two_finger_tap_possible = false;
	this->initial_pinch_distance = 0;
	this->pinch_reference_distance = 0;
	this->pan_velocity = {};
	this->last_pan_move_ms = 0;
}

std::vector<Action> GestureState::EmitTap(TouchPoint position, uint32_t timestamp_ms)
{
	if (this->has_last_tap && timestamp_ms - this->last_tap_ms <= this->settings.double_tap_ms &&
			Distance(position, this->last_tap_position) <= this->settings.double_tap_slop) {
		this->has_last_tap = false;
		return {{ActionType::DoubleTap, position}};
	}
	this->has_last_tap = true;
	this->last_tap_position = position;
	this->last_tap_ms = timestamp_ms;
	return {{ActionType::Tap, position}};
}

std::vector<Action> GestureState::FingerDown(int64_t id, TouchPoint position, uint32_t timestamp_ms, bool direct_drag,
		bool precision_allowed)
{
	if (this->FindFinger(id) != nullptr || this->FingerCount() == this->fingers.size()) return {};
	Finger *finger = this->AllocateFinger(id);
	finger->start = finger->current = position;
	finger->down_ms = timestamp_ms;

	if (this->FingerCount() == 1) {
		this->state = State::Pending;
		this->direct_drag = direct_drag;
		this->precision_allowed = precision_allowed;
		return {};
	}

	if (this->state == State::Precision) {
		this->state = State::TwoFingerPending;
		this->two_finger_tap_possible = false;
		this->two_finger_start_ms = timestamp_ms;
		this->initial_pinch_distance = this->pinch_reference_distance = this->FingerDistance();
		this->initial_centroid = this->last_centroid = this->Centroid();
		return {{ActionType::Cancel, position}};
	}

	if (this->state == State::DirectDragging) {
		auto result = std::vector<Action>{{ActionType::DirectDragCancel, position}, {ActionType::Cancel, position}};
		this->state = State::TwoFingerPending;
		this->two_finger_tap_possible = false;
		this->two_finger_start_ms = timestamp_ms;
		this->initial_pinch_distance = this->pinch_reference_distance = this->FingerDistance();
		this->initial_centroid = this->last_centroid = this->Centroid();
		return result;
	}

	const uint32_t first_down_ms = std::min(this->fingers[0].down_ms, this->fingers[1].down_ms);
	this->state = State::TwoFingerPending;
	this->two_finger_tap_possible = timestamp_ms - first_down_ms <= this->settings.two_tap_stagger_ms;
	this->two_finger_start_ms = first_down_ms;
	this->initial_pinch_distance = this->pinch_reference_distance = this->FingerDistance();
	this->initial_centroid = this->last_centroid = this->Centroid();
	return {};
}

std::vector<Action> GestureState::FingerMove(int64_t id, TouchPoint position, uint32_t timestamp_ms)
{
	Finger *finger = this->FindFinger(id);
	if (finger == nullptr) return {};
	finger->current = position;
	(void)timestamp_ms;

	if (this->state == State::Pending) {
		if (Distance(finger->start, finger->current) <= this->settings.drag_activate) return {};
		if (this->direct_drag) {
			this->state = State::DirectDragging;
			return {{ActionType::DirectDragBegin, finger->start}, {ActionType::DirectDragMove, finger->current,
				{finger->current.x - finger->start.x, finger->current.y - finger->start.y}}};
		}
		this->state = State::Panning;
		this->last_centroid = finger->current;
		this->last_pan_move_ms = timestamp_ms;
		return {{ActionType::PanBegin, finger->start}, {ActionType::PanMove, finger->current,
			{finger->current.x - finger->start.x, finger->current.y - finger->start.y}}};
	}

	if (this->state == State::TwoFingerPending) {
		const double distance = this->FingerDistance();
		const TouchPoint centroid = this->Centroid();
		if (std::abs(distance - this->initial_pinch_distance) > this->settings.pinch_activate) {
			this->state = State::Pinching;
			this->pinch_reference_distance = distance;
			this->two_finger_tap_possible = false;
			return {};
		}
		if (Distance(centroid, this->initial_centroid) > this->settings.drag_activate) {
			this->state = State::Panning;
			this->two_finger_tap_possible = false;
			TouchPoint delta{centroid.x - this->initial_centroid.x, centroid.y - this->initial_centroid.y};
			this->last_centroid = centroid;
			this->last_pan_move_ms = timestamp_ms;
			return {{ActionType::PanBegin, this->initial_centroid}, {ActionType::PanMove, centroid, delta}};
		}
		return {};
	}

	if (this->state == State::Panning) {
		const TouchPoint centroid = this->Centroid();
		TouchPoint delta = this->UpdatePanVelocity(centroid, timestamp_ms);
		return {{ActionType::PanMove, centroid, delta}};
	}

	if (this->state == State::DirectDragging) {
		return {{ActionType::DirectDragMove, position}};
	}

	if (this->state == State::Pinching) {
		const double distance = this->FingerDistance();
		const TouchPoint centroid = this->Centroid();
		if (distance >= this->pinch_reference_distance * this->settings.pinch_step_factor) {
			this->pinch_reference_distance = distance;
			return {{ActionType::ZoomIn, centroid}};
		}
		if (distance <= this->pinch_reference_distance / this->settings.pinch_step_factor) {
			this->pinch_reference_distance = distance;
			return {{ActionType::ZoomOut, centroid}};
		}
		return {};
	}

	if (this->state == State::Precision) {
		return {{ActionType::PrecisionMove, {position.x, position.y - this->settings.precision_offset}}};
	}
	return {};
}

std::vector<Action> GestureState::FingerUp(int64_t id, TouchPoint position, uint32_t timestamp_ms)
{
	Finger *finger = this->FindFinger(id);
	if (finger == nullptr) return {};
	finger->current = position;
	const TouchPoint start = finger->start;
	const uint32_t down_ms = finger->down_ms;
	const State ending_state = this->state;
	const double max_movement = this->MaxMovement();
	if (ending_state == State::TwoFingerPending && max_movement > this->settings.tap_slop) {
		this->two_finger_tap_possible = false;
	}
	finger->active = false;

	if (ending_state == State::Pending) {
		this->state = State::Idle;
		if (timestamp_ms - down_ms <= this->settings.tap_max_ms && Distance(start, position) <= this->settings.tap_slop) {
			return this->EmitTap(position, timestamp_ms);
		}
		return {};
	}

	if (ending_state == State::DirectDragging) {
		this->ResetActiveGesture();
		return {{ActionType::DirectDragEnd, position}};
	}

	if (ending_state == State::Precision) {
		this->ResetActiveGesture();
		return {{ActionType::PrecisionCommit, {position.x, position.y - this->settings.precision_offset}}};
	}

	if (ending_state == State::TwoFingerPending) {
		if (this->FingerCount() != 0) return {};
		const bool is_tap = this->two_finger_tap_possible &&
			timestamp_ms - this->two_finger_start_ms <= this->settings.two_tap_max_ms &&
			max_movement <= this->settings.tap_slop;
		const TouchPoint centroid = this->initial_centroid;
		this->ResetActiveGesture();
		return is_tap ? std::vector<Action>{{ActionType::SecondaryClick, centroid}} : std::vector<Action>{};
	}

	if (ending_state == State::Pinching && this->FingerCount() == 1) {
		this->state = State::Panning;
		this->last_centroid = this->Centroid();
		this->pan_velocity = {};
		this->last_pan_move_ms = timestamp_ms;
		return {{ActionType::PanBegin, this->last_centroid}};
	}

	if ((ending_state == State::Panning || ending_state == State::Pinching) && this->FingerCount() == 0) {
		TouchPoint velocity = ending_state == State::Panning ? this->EndPan(timestamp_ms) : TouchPoint{};
		this->ResetActiveGesture();
		return {{ActionType::PanEnd, position, velocity}};
	}
	return {};
}

std::vector<Action> GestureState::Update(uint32_t timestamp_ms)
{
	if (this->state != State::Pending || this->FingerCount() != 1 || !this->precision_allowed) return {};
	Finger &finger = *std::find_if(this->fingers.begin(), this->fingers.end(), [](const Finger &candidate) { return candidate.active; });
	if (timestamp_ms - finger.down_ms < this->settings.long_press_ms || Distance(finger.start, finger.current) > this->settings.tap_slop) return {};
	this->state = State::Precision;
	return {{ActionType::PrecisionBegin, {finger.current.x, finger.current.y - this->settings.precision_offset}}};
}

std::vector<Action> GestureState::Cancel()
{
	std::vector<Action> result;
	if (this->state == State::Panning || this->state == State::Pinching) result.push_back({ActionType::PanEnd, this->Centroid()});
	if (this->state == State::DirectDragging) result.push_back({ActionType::DirectDragCancel, this->Centroid()});
	if (this->state != State::Idle) result.push_back({ActionType::Cancel, this->Centroid()});
	this->ResetActiveGesture();
	return result;
}

} // namespace OpenTTDPad::Touch
