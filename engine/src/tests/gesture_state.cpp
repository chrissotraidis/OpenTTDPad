/*
 * This file is part of OpenTTDPad and OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License version 2.
 */

/** @file gesture_state.cpp Tests for the platform-neutral touch recognizer. */

#include "../stdafx.h"
#include "../3rdparty/catch2/catch.hpp"
#include "../touch/gesture_state.hpp"
#include "../touch/hit_test.hpp"

#include "../safeguards.h"

using namespace OpenTTDPad::Touch;

static bool HasAction(const std::vector<Action> &actions, ActionType type)
{
	return std::ranges::any_of(actions, [type](const Action &action) { return action.type == type; });
}

TEST_CASE("OpenTTDPad touch tap and double tap")
{
	GestureState state;
	CHECK(state.FingerDown(1, {100, 100}, 0, false).empty());
	CHECK(HasAction(state.FingerUp(1, {104, 103}, 100), ActionType::Tap));
	CHECK(state.FingerDown(2, {105, 102}, 200, false).empty());
	CHECK(HasAction(state.FingerUp(2, {105, 102}, 250), ActionType::DoubleTap));
}

TEST_CASE("OpenTTDPad double tap respects time and distance windows")
{
	GestureState time;
	time.FingerDown(1, {100, 100}, 0, false);
	time.FingerUp(1, {100, 100}, 50);
	time.FingerDown(2, {100, 100}, 301, false);
	auto late = time.FingerUp(2, {100, 100}, 302);
	CHECK(HasAction(late, ActionType::Tap));
	CHECK_FALSE(HasAction(late, ActionType::DoubleTap));

	GestureState distance;
	distance.FingerDown(1, {100, 100}, 0, false);
	distance.FingerUp(1, {100, 100}, 50);
	distance.FingerDown(2, {125, 100}, 100, false);
	auto far = distance.FingerUp(2, {125, 100}, 120);
	CHECK(HasAction(far, ActionType::Tap));
	CHECK_FALSE(HasAction(far, ActionType::DoubleTap));
}

TEST_CASE("OpenTTDPad one-finger map movement is suppressed")
{
	GestureState state;
	state.FingerDown(1, {50, 50}, 0, false);
	CHECK(state.FingerMove(1, {60, 50}, 20).empty());
	CHECK(state.FingerMove(1, {61, 50}, 30).empty());
	CHECK(state.GetState() == State::OneFingerSuppressed);
	CHECK(state.FingerUp(1, {70, 50}, 60).empty());
	CHECK(state.GetState() == State::Idle);
}

TEST_CASE("OpenTTDPad two-finger map pan reports release velocity but construction never does")
{
	GestureState pan;
	pan.FingerDown(1, {50, 50}, 1, false);
	pan.FingerDown(2, {90, 50}, 5, false);
	pan.FingerMove(1, {65, 50}, 20);
	pan.FingerMove(2, {105, 50}, 30);
	pan.FingerMove(1, {75, 50}, 40);
	auto end = pan.FingerUp(2, {105, 50}, 45);
	REQUIRE(end.size() == 1);
	CHECK(end.front().type == ActionType::PanEnd);
	CHECK(end.front().delta.x > 0);
	CHECK(pan.FingerUp(1, {75, 50}, 50).empty());

	GestureState held;
	held.FingerDown(1, {50, 50}, 1, false);
	held.FingerDown(2, {90, 50}, 5, false);
	held.FingerMove(1, {65, 50}, 20);
	held.FingerMove(2, {105, 50}, 30);
	held.FingerMove(1, {75, 50}, 40);
	auto stopped = held.FingerUp(2, {105, 50}, 121);
	REQUIRE(stopped.size() == 1);
	CHECK(stopped.front().delta.x == 0);

	GestureState construction;
	construction.FingerDown(1, {50, 50}, 1, true);
	construction.FingerMove(1, {100, 50}, 40);
	auto commit = construction.FingerUp(1, {110, 50}, 45);
	REQUIRE(commit.size() == 1);
	CHECK(commit.front().type == ActionType::DirectDragEnd);
	CHECK(commit.front().delta.x == 0);
}

TEST_CASE("OpenTTDPad UI or construction drag retains primary-button semantics")
{
	GestureState state;
	state.FingerDown(1, {50, 50}, 0, true);
	auto actions = state.FingerMove(1, {70, 50}, 30);
	CHECK(HasAction(actions, ActionType::DirectDragBegin));
	CHECK(HasAction(actions, ActionType::DirectDragMove));
	CHECK(HasAction(state.FingerUp(1, {70, 50}, 50), ActionType::DirectDragEnd));
}

TEST_CASE("OpenTTDPad two-finger tap emits one secondary click")
{
	GestureState state;
	state.FingerDown(1, {100, 100}, 0, false);
	state.FingerDown(2, {140, 100}, 50, false);
	CHECK(state.FingerUp(1, {100, 100}, 120).empty());
	CHECK(HasAction(state.FingerUp(2, {140, 100}, 140), ActionType::SecondaryClick));
}

TEST_CASE("OpenTTDPad two-finger tap rejects movement and slow staggering")
{
	GestureState moved;
	moved.FingerDown(1, {100, 100}, 0, false);
	moved.FingerDown(2, {180, 100}, 40, false);
	moved.FingerMove(1, {109, 100}, 80);
	moved.FingerUp(1, {109, 100}, 120);
	CHECK_FALSE(HasAction(moved.FingerUp(2, {180, 100}, 140), ActionType::SecondaryClick));

	GestureState staggered;
	staggered.FingerDown(1, {100, 100}, 0, false);
	staggered.FingerDown(2, {180, 100}, 101, false);
	staggered.FingerUp(1, {100, 100}, 130);
	CHECK_FALSE(HasAction(staggered.FingerUp(2, {180, 100}, 140), ActionType::SecondaryClick));
}

TEST_CASE("OpenTTDPad two-finger pan and pinch intent stay separate")
{
	GestureState pinch;
	pinch.FingerDown(1, {100, 100}, 0, false);
	pinch.FingerDown(2, {140, 100}, 10, false);
	CHECK(pinch.FingerMove(1, {80, 100}, 30).empty());
	CHECK(HasAction(pinch.FingerMove(2, {160, 100}, 40), ActionType::ZoomIn));
	CHECK(pinch.GetState() == State::Pinching);
	CHECK_FALSE(HasAction(pinch.FingerMove(1, {90, 110}, 50), ActionType::PanMove));

	GestureState pan;
	pan.FingerDown(1, {100, 100}, 0, false);
	pan.FingerDown(2, {140, 100}, 10, false);
	CHECK(pan.FingerMove(1, {125, 100}, 30).empty());
	auto actions = pan.FingerMove(2, {165, 100}, 40);
	CHECK(HasAction(actions, ActionType::PanBegin));
	CHECK(pan.GetState() == State::Panning);
	CHECK_FALSE(HasAction(pan.FingerMove(2, {200, 100}, 50), ActionType::ZoomIn));
	CHECK(pan.GetState() == State::Panning);
}

TEST_CASE("OpenTTDPad anchored pinch resolves after the intent window")
{
	GestureState state;
	state.FingerDown(1, {100, 100}, 0, false);
	state.FingerDown(2, {140, 100}, 10, false);
	CHECK(state.FingerMove(2, {180, 100}, 50).empty());
	CHECK(HasAction(state.FingerMove(2, {180, 100}, 101), ActionType::ZoomIn));
	CHECK(state.GetState() == State::Pinching);
}

TEST_CASE("OpenTTDPad two-finger pan stops when one finger lifts")
{
	GestureState state;
	state.FingerDown(1, {100, 100}, 0, false);
	state.FingerDown(2, {140, 100}, 10, false);
	state.FingerMove(1, {120, 120}, 30);
	state.FingerMove(2, {160, 120}, 40);

	auto stopped = state.FingerUp(2, {160, 120}, 50);
	REQUIRE(stopped.size() == 1);
	CHECK(stopped.front().type == ActionType::PanEnd);
	CHECK(state.GetState() == State::OneFingerSuppressed);
	CHECK(state.FingerMove(1, {125, 120}, 60).empty());
	CHECK(state.FingerUp(1, {125, 120}, 70).empty());
	CHECK(state.GetState() == State::Idle);
}

TEST_CASE("OpenTTDPad long press enters precision and commits on lift")
{
	GestureState state;
	state.FingerDown(1, {80, 90}, 0, false);
	CHECK(HasAction(state.Update(500), ActionType::PrecisionBegin));
	CHECK(HasAction(state.FingerMove(1, {82, 91}, 520), ActionType::PrecisionMove));
	CHECK(HasAction(state.FingerUp(1, {82, 91}, 550), ActionType::PrecisionCommit));
}

TEST_CASE("OpenTTDPad precision uses an offset crosshair and UI holds stay inert")
{
	GestureState map;
	map.FingerDown(1, {80, 90}, 0, false);
	auto begin = map.Update(500);
	REQUIRE(begin.size() == 1);
	CHECK(begin.front().position.x == 80);
	CHECK(begin.front().position.y == 30);

	GestureState ui;
	ui.FingerDown(1, {80, 90}, 0, true, false);
	CHECK(ui.Update(500).empty());
}

TEST_CASE("OpenTTDPad deliberate presses tap where the finger landed")
{
	/* A 400 ms press on a window button used to fall between the 300 ms tap
	 * limit and the 500 ms long press and did nothing. */
	GestureState slow;
	slow.FingerDown(1, {20, 40}, 0, true, false);
	slow.Update(400);
	auto slow_up = slow.FingerUp(1, {20, 40}, 400);
	REQUIRE(slow_up.size() == 1);
	CHECK(slow_up.front().type == ActionType::Tap);

	GestureState held;
	held.FingerDown(1, {20, 40}, 0, true, false);
	CHECK(held.Update(1500).empty());
	CHECK(HasAction(held.FingerUp(1, {20, 40}, 1500), ActionType::Tap));

	/* Lifting rolls the contact a few points; the click stays on the target. */
	GestureState rolled;
	rolled.FingerDown(1, {20, 40}, 0, true, false);
	rolled.FingerMove(1, {26, 45}, 80);
	auto rolled_up = rolled.FingerUp(1, {26, 45}, 120);
	REQUIRE(rolled_up.size() == 1);
	CHECK(rolled_up.front().type == ActionType::Tap);
	CHECK(rolled_up.front().position.x == 20);
	CHECK(rolled_up.front().position.y == 40);
}

TEST_CASE("OpenTTDPad two-finger contact cancels precision without committing")
{
	GestureState state;
	state.FingerDown(1, {80, 90}, 0, false);
	state.Update(500);
	auto actions = state.FingerDown(2, {120, 90}, 520, false);
	CHECK(HasAction(actions, ActionType::Cancel));
	CHECK_FALSE(HasAction(actions, ActionType::PrecisionCommit));
}

TEST_CASE("OpenTTDPad long press rejects excess movement")
{
	GestureState state;
	state.FingerDown(1, {80, 90}, 0, false);
	state.FingerMove(1, {88, 90}, 100);
	CHECK(HasAction(state.Update(500), ActionType::PrecisionBegin));

	GestureState moved;
	moved.FingerDown(1, {80, 90}, 0, false);
	moved.FingerMove(1, {89, 90}, 100);
	CHECK(moved.Update(500).empty());
}

TEST_CASE("OpenTTDPad second finger aborts a direct construction drag")
{
	GestureState state;
	state.FingerDown(1, {50, 50}, 0, true);
	state.FingerMove(1, {70, 50}, 20);
	auto actions = state.FingerDown(2, {100, 100}, 30, false);
	CHECK(HasAction(actions, ActionType::DirectDragCancel));
	CHECK_FALSE(HasAction(actions, ActionType::DirectDragEnd));
	CHECK(HasAction(actions, ActionType::Cancel));
}

TEST_CASE("OpenTTDPad cancellation releases any active gesture")
{
	GestureState pan;
	pan.FingerDown(1, {50, 50}, 0, false);
	pan.FingerDown(2, {90, 50}, 5, false);
	pan.FingerMove(1, {80, 50}, 20);
	pan.FingerMove(2, {120, 50}, 30);
	auto actions = pan.Cancel();
	CHECK(HasAction(actions, ActionType::PanEnd));
	CHECK(HasAction(actions, ActionType::Cancel));
	CHECK(pan.GetState() == State::Idle);
	CHECK(pan.FingerCount() == 0);

	GestureState idle;
	CHECK(idle.Cancel().empty());
}

TEST_CASE("OpenTTDPad touch settings only change between gestures")
{
	GestureState gestures;
	Settings responsive;
	responsive.drag_activate = 6.0;
	CHECK(gestures.SetSettings(responsive));
	CHECK(gestures.GetSettings().drag_activate == 6.0);

	gestures.FingerDown(1, {100, 100}, 0, false);
	Settings relaxed;
	relaxed.drag_activate = 14.0;
	CHECK_FALSE(gestures.SetSettings(relaxed));
	CHECK(gestures.GetSettings().drag_activate == 6.0);
	gestures.Cancel();
	CHECK(gestures.SetSettings(relaxed));
	CHECK(gestures.GetSettings().drag_activate == 14.0);
}

TEST_CASE("OpenTTDPad expands small touch targets and preserves visual bounds")
{
	const std::vector<HitTarget> targets = {
		{1, 10, 10, 29, 29},
		{2, 31, 10, 50, 29},
	};

	CHECK(ResolveExpandedHitTarget({30, 20}, targets, 44) == 1);
	CHECK(ResolveExpandedHitTarget({34, 20}, targets, 44) == 2);
	CHECK(ResolveExpandedHitTarget({200, 200}, targets, 44) == -1);

	const TouchPoint clamped = ClampToHitTarget({4, 20}, targets.front());
	CHECK(clamped.x == 10);
	CHECK(clamped.y == 20);
}

TEST_CASE("OpenTTDPad pinch from coincident contacts stays bounded")
{
	/* A second contact at exactly the first one's point (a stale touch and a
	 * new tap on the same spot) made the pinch reference zero, and the zoom
	 * loop never ended until memory ran out. */
	GestureState state;
	state.FingerDown(1, {100, 100}, 0, false);
	state.FingerDown(2, {100, 100}, 10, false);
	auto actions = state.FingerMove(2, {160, 100}, 120);
	CHECK(state.GetState() == State::Pinching);
	CHECK(actions.size() <= 4);
	actions = state.FingerMove(2, {400, 100}, 140);
	CHECK(actions.size() <= 4);
	actions = state.FingerMove(2, {100, 100}, 160);
	CHECK(actions.size() <= 4);
	state.FingerUp(2, {100, 100}, 180);
	state.FingerUp(1, {100, 100}, 190);
	CHECK(state.GetState() == State::Idle);
}
