/*
 * This file is part of OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 2.
 * OpenTTD is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with OpenTTD. If not, see <https://www.gnu.org/licenses/old-licenses/gpl-2.0>.
 */

/** @file sdl2_v.cpp Implementation of the SDL2 video driver. */

#include "../stdafx.h"
#include "../openttd.h"
#include "../gfx_func.h"
#include "../blitter/factory.hpp"
#include "../thread.h"
#include "../progress.h"
#include "../core/math_func.hpp"
#include "../core/geometry_func.hpp"
#include "../core/utf8.hpp"
#include "../fileio_func.h"
#include "../framerate_type.h"
#include "../network/network.h"
#include "../saveload/saveload.h"
#include "../settings_func.h"
#include "../tilehighlight_func.h"
#include "../touch/gesture_state.hpp"
#include "../touch/hit_test.hpp"
#include "../viewport_func.h"
#include "../window_func.h"
#include "../window_gui.h"
#include "sdl2_v.h"
#include <SDL.h>
#ifdef OPENTTDPAD_IOS
extern "C" void OpenTTDPadAttachSDLWindowToScene(SDL_Window *window);
extern "C" void OpenTTDPadHaptic(int kind);
extern "C" void OpenTTDPadPrecisionLoupe(bool visible, double x, double y, double magnification);
extern "C" void OpenTTDPadMaybeShowTouchHint();
extern "C" void OpenTTDPadSetToolOverlay(bool active);

static OpenTTDPad::Touch::GestureState _openttdpad_gestures;
static bool _openttdpad_added_background_pause = false;
static bool _openttdpad_is_background = false;
static bool _openttdpad_momentum_active = false;
static OpenTTDPad::Touch::TouchPoint _openttdpad_momentum_velocity{};
static uint32_t _openttdpad_momentum_last_tick = 0;

static void OpenTTDPadInputProbe(const char *kind, int64_t source, double x, double y)
{
	fmt::print(stderr, "OpenTTDPad input: {} source={} x={:.3f} y={:.3f}\n", kind, source, x, y);
	fflush(stderr);
}

static Point OpenTTDPadTouchPoint(const SDL_TouchFingerEvent &event)
{
	return {
		static_cast<int>(std::clamp(event.x, 0.0f, 1.0f) * (_screen.width - 1)),
		static_cast<int>(std::clamp(event.y, 0.0f, 1.0f) * (_screen.height - 1)),
	};
}

static bool OpenTTDPadTouchIsInRejectedEdge(Point point)
{
	const double edge = _openttdpad_gestures.GetSettings().edge_reject;
	return point.x < edge || point.y < edge || point.x >= _screen.width - edge || point.y >= _screen.height - edge;
}

static bool OpenTTDPadTouchUsesDirectDrag(Point point)
{
	Window *window = FindWindowFromPt(point.x, point.y);
	if (window == nullptr) return true;
	const bool over_map = IsPtInWindowViewport(window, point.x, point.y) != nullptr;
	const bool tool_active = _thd.place_mode != HT_NONE;
	return !over_map || tool_active;
}

static bool OpenTTDPadTouchIsOverMap(Point point)
{
	Window *window = FindWindowFromPt(point.x, point.y);
	return window != nullptr && IsPtInWindowViewport(window, point.x, point.y) != nullptr;
}

static void OpenTTDPadMoveCursor(Point point)
{
	_cursor.UpdateCursorPosition(point.x, point.y);
	HandleMouseEvents();
}

static bool OpenTTDPadIsExpandableWidget(const NWidgetBase *widget)
{
	if (widget == nullptr || widget->GetIndex() < 0) return false;
	switch (widget->type & WWT_MASK) {
		case WWT_IMGBTN:
		case WWT_IMGBTN_2:
		case WWT_ARROWBTN:
		case WWT_TEXTBTN:
		case WWT_TEXTBTN_2:
		case WWT_BOOLBTN:
		case WWT_IMGTEXTBTN:
		case WWT_DEBUGBOX:
		case WWT_SHADEBOX:
		case WWT_DEFSIZEBOX:
		case WWT_STICKYBOX:
		case WWT_RESIZEBOX:
		case WWT_CLOSEBOX:
		case WWT_DROPDOWN:
		case WWT_EDITBOX:
			return true;
		default:
			return false;
	}
}

static Point OpenTTDPadExpandedTouchPoint(Point point)
{
	Window *window = FindWindowFromPt(point.x, point.y);
	if (window == nullptr || IsPtInWindowViewport(window, point.x, point.y) != nullptr) return point;

	std::vector<OpenTTDPad::Touch::HitTarget> targets;
	targets.reserve(window->widget_lookup.size());
	for (const auto &[id, widget] : window->widget_lookup) {
		if (!OpenTTDPadIsExpandableWidget(widget) || window->IsWidgetDisabled(id)) continue;
		const Rect rect = widget->GetCurrentRect();
		targets.push_back({id,
			static_cast<double>(window->left + rect.left), static_cast<double>(window->top + rect.top),
			static_cast<double>(window->left + rect.right), static_cast<double>(window->top + rect.bottom)});
	}

	const int target_id = OpenTTDPad::Touch::ResolveExpandedHitTarget(
		{static_cast<double>(point.x), static_cast<double>(point.y)}, targets,
		_openttdpad_gestures.GetSettings().minimum_target);
	if (target_id < 0) return point;

	const auto target = std::ranges::find_if(targets,
		[target_id](const auto &candidate) { return candidate.id == target_id; });
	if (target == std::end(targets)) return point;
	const auto resolved = OpenTTDPad::Touch::ClampToHitTarget(
		{static_cast<double>(point.x), static_cast<double>(point.y)}, *target);
	return {static_cast<int>(std::round(resolved.x)), static_cast<int>(std::round(resolved.y))};
}

static void OpenTTDPadPrimaryClick(Point point)
{
	point = OpenTTDPadExpandedTouchPoint(point);
	OpenTTDPadMoveCursor(point);
	_left_button_down = true;
	HandleMouseEvents();
	_left_button_down = false;
	_left_button_clicked = false;
	HandleMouseEvents();
}

static void OpenTTDPadShowPrecisionLoupe(OpenTTDPad::Touch::TouchPoint crosshair)
{
	OpenTTDPadPrecisionLoupe(true,
		std::clamp(crosshair.x / std::max(1, _screen.width), 0.0, 1.0),
		std::clamp((crosshair.y + _openttdpad_gestures.GetSettings().precision_offset) /
			std::max(1, _screen.height), 0.0, 1.0),
		_openttdpad_gestures.GetSettings().precision_magnification);
}

static void OpenTTDPadStopMomentum()
{
	_openttdpad_momentum_active = false;
	_openttdpad_momentum_velocity = {};
	_openttdpad_momentum_last_tick = 0;
}

static bool OpenTTDPadAdvanceMomentum(uint32_t timestamp_ms)
{
	if (!_openttdpad_momentum_active || _openttdpad_momentum_last_tick == 0) return false;
	const uint32_t elapsed_ms = std::min<uint32_t>(timestamp_ms - _openttdpad_momentum_last_tick, 50);
	_openttdpad_momentum_last_tick = timestamp_ms;
	if (elapsed_ms == 0) return false;

	Point delta{
		static_cast<int>(std::round(-_openttdpad_momentum_velocity.x * elapsed_ms)),
		static_cast<int>(std::round(-_openttdpad_momentum_velocity.y * elapsed_ms)),
	};
	Window *window = GetMainWindow();
	if (window == nullptr || window->viewport == nullptr) {
		OpenTTDPadStopMomentum();
		return false;
	}
	if (delta.x != 0 || delta.y != 0) window->OnScroll(delta);

	const double frame_count = elapsed_ms / 16.6667;
	const double decay = std::pow(_openttdpad_gestures.GetSettings().momentum_decay_per_frame, frame_count);
	_openttdpad_momentum_velocity.x *= decay;
	_openttdpad_momentum_velocity.y *= decay;
	if (std::hypot(_openttdpad_momentum_velocity.x, _openttdpad_momentum_velocity.y) <
			_openttdpad_gestures.GetSettings().momentum_min_velocity) {
		OpenTTDPadStopMomentum();
	}
	return delta.x != 0 || delta.y != 0;
}

static void OpenTTDPadApplyTouchActions(const std::vector<OpenTTDPad::Touch::Action> &actions)
{
	using OpenTTDPad::Touch::ActionType;
	for (const auto &action : actions) {
		Point point{static_cast<int>(std::round(action.position.x)), static_cast<int>(std::round(action.position.y))};
		switch (action.type) {
			case ActionType::Tap:
				OpenTTDPadPrimaryClick(point);
				break;
			case ActionType::DoubleTap:
				/* The first tap is delivered immediately. The recognizer emits
				 * DoubleTap for the second one, so one additional click lets
				 * OpenTTD's native click timing produce MC_DOUBLE_LEFT. */
				OpenTTDPadPrimaryClick(point);
				break;
			case ActionType::SecondaryClick:
				OpenTTDPadMoveCursor(point);
				_right_button_down = true;
				_right_button_clicked = true;
				HandleMouseEvents();
				_right_button_down = false;
				HandleMouseEvents();
				break;
			case ActionType::PanBegin:
				OpenTTDPadStopMomentum();
				/* Enter viewport scrolling without dispatching a right click.
				 * PanMove will preserve the first deliberate drag delta. */
				_cursor.UpdateCursorPosition(point.x, point.y);
				_right_button_down = true;
				_right_button_clicked = false;
				_scrolling_viewport = true;
				_cursor.fix_at = false;
				break;
			case ActionType::PanMove:
				OpenTTDPadMoveCursor(point);
				break;
			case ActionType::PanEnd:
				OpenTTDPadMoveCursor(point);
				_right_button_down = false;
				HandleMouseEvents();
				if (std::hypot(action.delta.x, action.delta.y) >=
						_openttdpad_gestures.GetSettings().momentum_min_velocity) {
					_openttdpad_momentum_active = true;
					_openttdpad_momentum_velocity = action.delta;
					_openttdpad_momentum_last_tick = SDL_GetTicks();
				}
				break;
			case ActionType::DirectDragBegin:
				OpenTTDPadMoveCursor(point);
				_left_button_down = true;
				HandleMouseEvents();
				break;
			case ActionType::DirectDragMove:
				OpenTTDPadMoveCursor(point);
				break;
			case ActionType::DirectDragEnd:
				OpenTTDPadMoveCursor(point);
				_left_button_down = false;
				_left_button_clicked = false;
				HandleMouseEvents();
				if (_thd.place_mode != HT_NONE) OpenTTDPadHaptic(1);
				break;
			case ActionType::DirectDragCancel:
				_left_button_down = false;
				_left_button_clicked = false;
				ResetObjectToPlace();
				break;
			case ActionType::ZoomIn:
			case ActionType::ZoomOut:
				OpenTTDPadMoveCursor(point);
				_cursor.wheel += action.type == ActionType::ZoomIn ? -1 : 1;
				_cursor.wheel_moved = true;
				break;
			case ActionType::PrecisionBegin:
				OpenTTDPadShowPrecisionLoupe(action.position);
				OpenTTDPadHaptic(0);
				OpenTTDPadMoveCursor(point);
				break;
			case ActionType::PrecisionMove:
				OpenTTDPadShowPrecisionLoupe(action.position);
				OpenTTDPadMoveCursor(point);
				break;
			case ActionType::PrecisionCommit:
				OpenTTDPadPrecisionLoupe(false, 0, 0, 0);
				OpenTTDPadPrimaryClick(point);
				OpenTTDPadHaptic(1);
				break;
			case ActionType::Cancel:
				OpenTTDPadStopMomentum();
				OpenTTDPadPrecisionLoupe(false, 0, 0, 0);
				_left_button_down = false;
				_right_button_down = false;
				_left_button_clicked = false;
				_scrolling_viewport = false;
				_cursor.fix_at = false;
				break;
		}
	}
}
#endif
#ifdef __EMSCRIPTEN__
#	include <emscripten.h>
#	include <emscripten/html5.h>
#endif

#include "../safeguards.h"

void VideoDriver_SDL_Base::MakeDirty(int left, int top, int width, int height)
{
	Rect r = {left, top, left + width, top + height};
	this->dirty_rect = BoundingRect(this->dirty_rect, r);
}

void VideoDriver_SDL_Base::CheckPaletteAnim()
{
	if (!CopyPalette(this->local_palette)) return;
	this->MakeDirty(0, 0, _screen.width, _screen.height);
}

static const Dimension default_resolutions[] = {
	{  640,  480 },
	{  800,  600 },
	{ 1024,  768 },
	{ 1152,  864 },
	{ 1280,  800 },
	{ 1280,  960 },
	{ 1280, 1024 },
	{ 1400, 1050 },
	{ 1600, 1200 },
	{ 1680, 1050 },
	{ 1920, 1200 }
};

static void FindResolutions()
{
	_resolutions.clear();

	for (int display = 0; display < SDL_GetNumVideoDisplays(); display++) {
		for (int i = 0; i < SDL_GetNumDisplayModes(display); i++) {
			SDL_DisplayMode mode;
			SDL_GetDisplayMode(display, i, &mode);

			if (mode.w < 640 || mode.h < 480) continue;
			if (std::ranges::find(_resolutions, Dimension(mode.w, mode.h)) != _resolutions.end()) continue;
			_resolutions.emplace_back(mode.w, mode.h);
		}
	}

	/* We have found no resolutions, show the default list */
	if (_resolutions.empty()) {
		_resolutions.assign(std::begin(default_resolutions), std::end(default_resolutions));
	}

	SortResolutions();
}

static void GetAvailableVideoMode(uint *w, uint *h)
{
	/* All modes available? */
	if (!_fullscreen || _resolutions.empty()) return;

	/* Is the wanted mode among the available modes? */
	if (std::ranges::find(_resolutions, Dimension(*w, *h)) != _resolutions.end()) return;

	/* Use the closest possible resolution */
	uint best = 0;
	uint delta = Delta(_resolutions[0].width, *w) * Delta(_resolutions[0].height, *h);
	for (uint i = 1; i != _resolutions.size(); ++i) {
		uint newdelta = Delta(_resolutions[i].width, *w) * Delta(_resolutions[i].height, *h);
		if (newdelta < delta) {
			best = i;
			delta = newdelta;
		}
	}
	*w = _resolutions[best].width;
	*h = _resolutions[best].height;
}

static uint FindStartupDisplay(uint startup_display)
{
	int num_displays = SDL_GetNumVideoDisplays();

	/* If the user indicated a valid monitor, use that. */
	if (IsInsideBS(startup_display, 0, num_displays)) return startup_display;

	/* Mouse position decides which display to use. */
	int mx, my;
	SDL_GetGlobalMouseState(&mx, &my);
	for (int display = 0; display < num_displays; ++display) {
		SDL_Rect r;
		if (SDL_GetDisplayBounds(display, &r) == 0 && IsInsideBS(mx, r.x, r.w) && IsInsideBS(my, r.y, r.h)) {
			Debug(driver, 1, "SDL2: Mouse is at ({}, {}), use display {} ({}, {}, {}, {})", mx, my, display, r.x, r.y, r.w, r.h);
			return display;
		}
	}

	return 0;
}

void VideoDriver_SDL_Base::ClientSizeChanged(int w, int h, bool force)
{
	/* Allocate backing store of the new size. */
	if (this->AllocateBackingStore(w, h, force)) {
		CopyPalette(this->local_palette, true);

		BlitterFactory::GetCurrentBlitter()->PostResize();

		GameSizeChanged();
	}
}

bool VideoDriver_SDL_Base::CreateMainWindow(uint w, uint h, uint flags)
{
	if (this->sdl_window != nullptr) return true;

	flags |= SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE;

#ifdef OPENTTDPAD_IOS
	/* UIKit only hides its status bar for an SDL fullscreen/borderless window.
	 * Keep OpenTTD's toolbar out of the system gesture regions as well. */
	flags |= SDL_WINDOW_FULLSCREEN | SDL_WINDOW_BORDERLESS;
	SDL_SetHint(SDL_HINT_IOS_HIDE_HOME_INDICATOR, "2");
#endif

	if (_fullscreen) {
		flags |= SDL_WINDOW_FULLSCREEN;
	}

	int x = SDL_WINDOWPOS_UNDEFINED, y = SDL_WINDOWPOS_UNDEFINED;
	SDL_Rect r;
	if (SDL_GetDisplayBounds(this->startup_display, &r) == 0) {
		x = r.x + std::max(0, r.w - static_cast<int>(w)) / 2;
		y = r.y + std::max(0, r.h - static_cast<int>(h)) / 4; // decent desktops have taskbars at the bottom
	}

	std::string caption = VideoDriver::GetCaption();
	this->sdl_window = SDL_CreateWindow(
		caption.c_str(),
		x, y,
		w, h,
		flags);

	if (this->sdl_window == nullptr) {
		Debug(driver, 0, "SDL2: Couldn't allocate a window to draw on: {}", SDL_GetError());
		return false;
	}

#ifdef OPENTTDPAD_IOS
	OpenTTDPadAttachSDLWindowToScene(this->sdl_window);
#endif

	std::string icon_path = FioFindFullPath(BASESET_DIR, "openttd.32.bmp");
	if (!icon_path.empty()) {
		/* Give the application an icon */
		SDL_Surface *icon = SDL_LoadBMP(icon_path.c_str());
		if (icon != nullptr) {
			/* Get the colourkey, which will be magenta */
			uint32_t rgbmap = SDL_MapRGB(icon->format, 255, 0, 255);

			SDL_SetColorKey(icon, SDL_TRUE, rgbmap);
			SDL_SetWindowIcon(this->sdl_window, icon);
			SDL_FreeSurface(icon);
		}
	}

	return true;
}

bool VideoDriver_SDL_Base::CreateMainSurface(uint w, uint h, bool resize)
{
	GetAvailableVideoMode(&w, &h);
	Debug(driver, 1, "SDL2: using mode {}x{}", w, h);

	if (!this->CreateMainWindow(w, h)) return false;
	if (resize) SDL_SetWindowSize(this->sdl_window, w, h);
	this->ClientSizeChanged(w, h, true);

	/* When in full screen, we will always have the mouse cursor
	 * within the window, even though SDL does not give us the
	 * appropriate event to know this. */
	if (_fullscreen) _cursor.in_window = true;

	return true;
}

bool VideoDriver_SDL_Base::ClaimMousePointer()
{
	/* Emscripten never claims the pointer, so we do not need to change the cursor visibility. */
#ifndef __EMSCRIPTEN__
	SDL_ShowCursor(0);
#endif
	return true;
}

/**
 * This is called to indicate that an edit box has gained focus, text input mode should be enabled.
 */
void VideoDriver_SDL_Base::EditBoxGainedFocus()
{
	if (!this->edit_box_focused) {
		SDL_StartTextInput();
		this->edit_box_focused = true;
	}
}

/**
 * This is called to indicate that an edit box has lost focus, text input mode should be disabled.
 */
void VideoDriver_SDL_Base::EditBoxLostFocus()
{
	if (this->edit_box_focused) {
		SDL_StopTextInput();
		this->edit_box_focused = false;
	}
}

std::vector<int> VideoDriver_SDL_Base::GetListOfMonitorRefreshRates()
{
	std::vector<int> rates = {};
	for (int i = 0; i < SDL_GetNumVideoDisplays(); i++) {
		SDL_DisplayMode mode = {};
		if (SDL_GetDisplayMode(i, 0, &mode) != 0) continue;
		if (mode.refresh_rate != 0) rates.push_back(mode.refresh_rate);
	}
	return rates;
}


struct SDLVkMapping {
	const SDL_Keycode vk_from;
	const uint8_t vk_count;
	const uint8_t map_to;
	const bool unprintable;

	constexpr SDLVkMapping(SDL_Keycode vk_first, SDL_Keycode vk_last, uint8_t map_first, [[maybe_unused]] uint8_t map_last, bool unprintable)
		: vk_from(vk_first), vk_count(vk_last - vk_first + 1), map_to(map_first), unprintable(unprintable)
	{
		assert((vk_last - vk_first) == (map_last - map_first));
	}
};

#define AS(x, z) {x, x, z, z, false}
#define AM(x, y, z, w) {x, y, z, w, false}
#define AS_UP(x, z) {x, x, z, z, true}
#define AM_UP(x, y, z, w) {x, y, z, w, true}

static constexpr SDLVkMapping _vk_mapping[] = {
	/* Pageup stuff + up/down */
	AS_UP(SDLK_PAGEUP,   WKC_PAGEUP),
	AS_UP(SDLK_PAGEDOWN, WKC_PAGEDOWN),
	AS_UP(SDLK_UP,     WKC_UP),
	AS_UP(SDLK_DOWN,   WKC_DOWN),
	AS_UP(SDLK_LEFT,   WKC_LEFT),
	AS_UP(SDLK_RIGHT,  WKC_RIGHT),

	AS_UP(SDLK_HOME,   WKC_HOME),
	AS_UP(SDLK_END,    WKC_END),

	AS_UP(SDLK_INSERT, WKC_INSERT),
	AS_UP(SDLK_DELETE, WKC_DELETE),

	/* Map letters & digits */
	AM(SDLK_a, SDLK_z, 'A', 'Z'),
	AM(SDLK_0, SDLK_9, '0', '9'),

	AS_UP(SDLK_ESCAPE,    WKC_ESC),
	AS_UP(SDLK_PAUSE,     WKC_PAUSE),
	AS_UP(SDLK_BACKSPACE, WKC_BACKSPACE),

	AS(SDLK_SPACE,     WKC_SPACE),
	AS(SDLK_RETURN,    WKC_RETURN),
	AS(SDLK_TAB,       WKC_TAB),

	/* Function keys */
	AM_UP(SDLK_F1, SDLK_F12, WKC_F1, WKC_F12),

	/* Numeric part. */
	AS(SDLK_KP_1,        '1'),
	AS(SDLK_KP_2,        '2'),
	AS(SDLK_KP_3,        '3'),
	AS(SDLK_KP_4,        '4'),
	AS(SDLK_KP_5,        '5'),
	AS(SDLK_KP_6,        '6'),
	AS(SDLK_KP_7,        '7'),
	AS(SDLK_KP_8,        '8'),
	AS(SDLK_KP_9,        '9'),
	AS(SDLK_KP_0,        '0'),
	AS(SDLK_KP_DIVIDE,   WKC_NUM_DIV),
	AS(SDLK_KP_MULTIPLY, WKC_NUM_MUL),
	AS(SDLK_KP_MINUS,    WKC_NUM_MINUS),
	AS(SDLK_KP_PLUS,     WKC_NUM_PLUS),
	AS(SDLK_KP_ENTER,    WKC_NUM_ENTER),
	AS(SDLK_KP_PERIOD,   WKC_NUM_DECIMAL),

	/* Other non-letter keys */
	AS(SDLK_SLASH,        WKC_SLASH),
	AS(SDLK_SEMICOLON,    WKC_SEMICOLON),
	AS(SDLK_EQUALS,       WKC_EQUALS),
	AS(SDLK_LEFTBRACKET,  WKC_L_BRACKET),
	AS(SDLK_BACKSLASH,    WKC_BACKSLASH),
	AS(SDLK_RIGHTBRACKET, WKC_R_BRACKET),

	AS(SDLK_QUOTE,   WKC_SINGLEQUOTE),
	AS(SDLK_COMMA,   WKC_COMMA),
	AS(SDLK_MINUS,   WKC_MINUS),
	AS(SDLK_PERIOD,  WKC_PERIOD)
};

static uint ConvertSdlKeyIntoMy(SDL_Keysym *sym, char32_t *character)
{
	uint key = 0;
	bool unprintable = false;

	for (const auto &map : _vk_mapping) {
		if (IsInsideBS(sym->sym, map.vk_from, map.vk_count)) {
			key = sym->sym - map.vk_from + map.map_to;
			unprintable = map.unprintable;
			break;
		}
	}

	/* check scancode for BACKQUOTE key, because we want the key left of "1", not anything else (on non-US keyboards) */
	if (sym->scancode == SDL_SCANCODE_GRAVE) key = WKC_BACKQUOTE;

	/* META are the command keys on mac */
	if (sym->mod & KMOD_GUI)   key |= WKC_META;
	if (sym->mod & KMOD_SHIFT) key |= WKC_SHIFT;
	if (sym->mod & KMOD_CTRL)  key |= WKC_CTRL;
	if (sym->mod & KMOD_ALT)   key |= WKC_ALT;

	/* The mod keys have no character. Prevent '?' */
	if (sym->mod & KMOD_GUI ||
		sym->mod & KMOD_CTRL ||
		sym->mod & KMOD_ALT ||
		unprintable) {
		*character = WKC_NONE;
	} else {
		*character = sym->sym;
	}

	return key;
}

/**
 * Like ConvertSdlKeyIntoMy(), but takes an SDL_Keycode as input
 * instead of an SDL_Keysym.
 */
static uint ConvertSdlKeycodeIntoMy(SDL_Keycode kc)
{
	uint key = 0;

	for (const auto &map : _vk_mapping) {
		if (IsInsideBS(kc, map.vk_from, map.vk_count)) {
			key = kc - map.vk_from + map.map_to;
			break;
		}
	}

	/* check scancode for BACKQUOTE key, because we want the key left
	 * of "1", not anything else (on non-US keyboards) */
	SDL_Scancode sc = SDL_GetScancodeFromKey(kc);
	if (sc == SDL_SCANCODE_GRAVE) key = WKC_BACKQUOTE;

	return key;
}

bool VideoDriver_SDL_Base::PollEvent()
{
	SDL_Event ev;

#ifdef OPENTTDPAD_IOS
	if (_game_mode == GM_NORMAL) OpenTTDPadMaybeShowTouchHint();
	OpenTTDPadSetToolOverlay(_thd.place_mode != HT_NONE);
	auto timed_actions = _openttdpad_gestures.Update(SDL_GetTicks());
	if (!timed_actions.empty()) {
		OpenTTDPadApplyTouchActions(timed_actions);
		return true;
	}
	if (OpenTTDPadAdvanceMomentum(SDL_GetTicks())) return true;
#endif

	if (!SDL_PollEvent(&ev)) return false;

	switch (ev.type) {
		case SDL_FINGERDOWN:
		case SDL_FINGERMOTION:
		case SDL_FINGERUP: {
#ifdef OPENTTDPAD_IOS
			Point point = OpenTTDPadTouchPoint(ev.tfinger);
			std::vector<OpenTTDPad::Touch::Action> actions;
			if (ev.type == SDL_FINGERDOWN) {
				OpenTTDPadStopMomentum();
				OpenTTDPadInputProbe("finger-down", ev.tfinger.touchId, ev.tfinger.x, ev.tfinger.y);
				if (!OpenTTDPadTouchIsInRejectedEdge(point)) {
					actions = _openttdpad_gestures.FingerDown(ev.tfinger.fingerId,
						{static_cast<double>(point.x), static_cast<double>(point.y)}, ev.tfinger.timestamp,
						OpenTTDPadTouchUsesDirectDrag(point), OpenTTDPadTouchIsOverMap(point));
				}
			} else if (ev.type == SDL_FINGERMOTION) {
				OpenTTDPadInputProbe("finger-move", ev.tfinger.touchId, ev.tfinger.x, ev.tfinger.y);
				actions = _openttdpad_gestures.FingerMove(ev.tfinger.fingerId,
					{static_cast<double>(point.x), static_cast<double>(point.y)}, ev.tfinger.timestamp);
			} else {
				OpenTTDPadInputProbe("finger-up", ev.tfinger.touchId, ev.tfinger.x, ev.tfinger.y);
				actions = _openttdpad_gestures.FingerUp(ev.tfinger.fingerId,
					{static_cast<double>(point.x), static_cast<double>(point.y)}, ev.tfinger.timestamp);
			}
			OpenTTDPadApplyTouchActions(actions);
#endif
			break;
		}

		case SDL_MOUSEMOTION: {
#ifdef OPENTTDPAD_IOS
			OpenTTDPadInputProbe("mouse-move", ev.motion.which, ev.motion.x, ev.motion.y);
#endif
			int32_t x = ev.motion.x;
			int32_t y = ev.motion.y;

			if (_cursor.fix_at) {
				/* Get all queued mouse events now in case we have to warp the cursor. In the
				 * end, we only care about the current mouse position and not bygone events. */
				while (SDL_PeepEvents(&ev, 1, SDL_GETEVENT, SDL_MOUSEMOTION, SDL_MOUSEMOTION)) {
					x = ev.motion.x;
					y = ev.motion.y;
				}
			}

			if (_cursor.UpdateCursorPosition(x, y)) {
				SDL_WarpMouseInWindow(this->sdl_window, _cursor.pos.x, _cursor.pos.y);
			}
			HandleMouseEvents();
			break;
		}

		case SDL_MOUSEWHEEL: {
#ifdef OPENTTDPAD_IOS
			OpenTTDPadInputProbe("mouse-wheel", ev.wheel.which, ev.wheel.preciseX, ev.wheel.preciseY);
#endif
			if (ev.wheel.y > 0) {
				_cursor.wheel--;
			} else if (ev.wheel.y < 0) {
				_cursor.wheel++;
			}

			/* Handle 2D scrolling. */
			const float SCROLL_BUILTIN_MULTIPLIER = 14.0f;
#if SDL_VERSION_ATLEAST(2, 18, 0)
			_cursor.v_wheel -= ev.wheel.preciseY * SCROLL_BUILTIN_MULTIPLIER * _settings_client.gui.scrollwheel_multiplier;
			_cursor.h_wheel += ev.wheel.preciseX * SCROLL_BUILTIN_MULTIPLIER * _settings_client.gui.scrollwheel_multiplier;
#else
			_cursor.v_wheel -= static_cast<float>(ev.wheel.y * SCROLL_BUILTIN_MULTIPLIER * _settings_client.gui.scrollwheel_multiplier);
			_cursor.h_wheel += static_cast<float>(ev.wheel.x * SCROLL_BUILTIN_MULTIPLIER * _settings_client.gui.scrollwheel_multiplier);
#endif
			_cursor.wheel_moved = true;
			break;
		}

		case SDL_MOUSEBUTTONDOWN:
#ifdef OPENTTDPAD_IOS
			OpenTTDPadInputProbe("mouse-button-down", ev.button.which, ev.button.x, ev.button.y);
#endif
			if (_rightclick_emulate && SDL_GetModState() & KMOD_CTRL) {
				ev.button.button = SDL_BUTTON_RIGHT;
			}

			switch (ev.button.button) {
				case SDL_BUTTON_LEFT:
					_left_button_down = true;
					break;

				case SDL_BUTTON_RIGHT:
					_right_button_down = true;
					_right_button_clicked = true;
					break;

				default: break;
			}
			HandleMouseEvents();
			break;

		case SDL_MOUSEBUTTONUP:
#ifdef OPENTTDPAD_IOS
			OpenTTDPadInputProbe("mouse-button-up", ev.button.which, ev.button.x, ev.button.y);
#endif
			if (_rightclick_emulate) {
				_right_button_down = false;
				_left_button_down = false;
				_left_button_clicked = false;
			} else if (ev.button.button == SDL_BUTTON_LEFT) {
				_left_button_down = false;
				_left_button_clicked = false;
			} else if (ev.button.button == SDL_BUTTON_RIGHT) {
				_right_button_down = false;
			}
			HandleMouseEvents();
			break;

		case SDL_QUIT:
			HandleExitGameRequest();
			break;

#ifdef OPENTTDPAD_IOS
		case SDL_APP_WILLENTERBACKGROUND:
		case SDL_APP_DIDENTERBACKGROUND:
			if (_openttdpad_is_background) break;
			_openttdpad_is_background = true;
			OpenTTDPadApplyTouchActions(_openttdpad_gestures.Cancel());
			if (!_openttdpad_added_background_pause && _pause_mode.None()) {
				_pause_mode.Set(PauseMode::Normal);
				_openttdpad_added_background_pause = true;
			}
			SaveToConfig();
			if (_game_mode == GM_NORMAL && !_networking && !HasModalProgress()) {
				Debug(sl, 1, "Saving iPad background recovery snapshot");
				SaveOrLoad("background.sav", SLO_SAVE, DFT_GAME_FILE, AUTOSAVE_DIR, false);
			}
			break;

		case SDL_APP_WILLENTERFOREGROUND:
		case SDL_APP_DIDENTERFOREGROUND:
			if (!_openttdpad_is_background) break;
			_openttdpad_is_background = false;
			if (_openttdpad_added_background_pause) {
				_pause_mode.Reset(PauseMode::Normal);
				_openttdpad_added_background_pause = false;
			}
			this->MakeDirty(0, 0, _screen.width, _screen.height);
			break;
#endif

		case SDL_KEYDOWN: // Toggle full-screen on ALT + ENTER/F
#ifdef OPENTTDPAD_IOS
			OpenTTDPadInputProbe("key-down", ev.key.windowID, ev.key.keysym.sym, ev.key.keysym.mod);
#endif
			if ((ev.key.keysym.mod & (KMOD_ALT | KMOD_GUI)) &&
					(ev.key.keysym.sym == SDLK_RETURN || ev.key.keysym.sym == SDLK_f)) {
				if (ev.key.repeat == 0) ToggleFullScreen(!_fullscreen);
			} else {
				char32_t character;

				uint keycode = ConvertSdlKeyIntoMy(&ev.key.keysym, &character);
				/* Only handle non-text keys here. Text is handled in
				 * SDL_TEXTINPUT below. */
				if (!this->edit_box_focused ||
					keycode == WKC_DELETE ||
					keycode == WKC_NUM_ENTER ||
					keycode == WKC_LEFT ||
					keycode == WKC_RIGHT ||
					keycode == WKC_UP ||
					keycode == WKC_DOWN ||
					keycode == WKC_HOME ||
					keycode == WKC_END ||
					keycode & WKC_META ||
					keycode & WKC_CTRL ||
					keycode & WKC_ALT ||
					(keycode >= WKC_F1 && keycode <= WKC_F12) ||
					!IsValidChar(character, CS_ALPHANUMERAL)) {
					HandleKeypress(keycode, character);
				}
			}
			break;

		case SDL_TEXTINPUT: {
#ifdef OPENTTDPAD_IOS
			OpenTTDPadInputProbe("text-input", 0, 0, 0);
#endif
			if (!this->edit_box_focused) break;
			SDL_Keycode kc = SDL_GetKeyFromName(ev.text.text);
			uint keycode = ConvertSdlKeycodeIntoMy(kc);

			if (keycode == WKC_BACKQUOTE && FocusedWindowIsConsole()) {
				auto [len, c] = DecodeUtf8(ev.text.text);
				if (len > 0) HandleKeypress(keycode, c);
			} else {
				HandleTextInput(ev.text.text);
			}
			break;
		}
		case SDL_WINDOWEVENT: {
			if (ev.window.event == SDL_WINDOWEVENT_EXPOSED) {
				/* Force a redraw of the entire screen. */
				this->MakeDirty(0, 0, _screen.width, _screen.height);
			} else if (ev.window.event == SDL_WINDOWEVENT_SIZE_CHANGED) {
				int w = std::max(ev.window.data1, 64);
				int h = std::max(ev.window.data2, 64);
				CreateMainSurface(w, h, w != ev.window.data1 || h != ev.window.data2);
			} else if (ev.window.event == SDL_WINDOWEVENT_ENTER) {
				/* mouse entered the window, enable cursor */
				_cursor.in_window = true;
				/* Ensure pointer lock will not occur. */
				SDL_SetRelativeMouseMode(SDL_FALSE);
			} else if (ev.window.event == SDL_WINDOWEVENT_LEAVE) {
				/* mouse left the window, undraw cursor */
				UndrawMouseCursor();
				_cursor.in_window = false;
			} else if (ev.window.event == SDL_WINDOWEVENT_FOCUS_LOST) {
#ifdef OPENTTDPAD_IOS
				OpenTTDPadApplyTouchActions(_openttdpad_gestures.Cancel());
#endif
			}
			break;
		}
	}

	return true;
}

static std::optional<std::string_view> InitializeSDL()
{
	/* Check if the video-driver is already initialized. */
	if (SDL_WasInit(SDL_INIT_VIDEO) != 0) return std::nullopt;

#ifdef SDL_HINT_APP_NAME
	SDL_SetHint(SDL_HINT_APP_NAME, "OpenTTD");
#endif

#ifdef OPENTTDPAD_IOS
	/* Direct touch is routed by GestureState. Genuine indirect pointer events
	 * remain on SDL's upstream mouse path, with no duplicate synthesis. */
	SDL_SetHint(SDL_HINT_AUDIO_CATEGORY, "ambient");
	SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0");
	SDL_SetHint(SDL_HINT_MOUSE_TOUCH_EVENTS, "0");
#endif

	if (SDL_InitSubSystem(SDL_INIT_VIDEO) < 0) return SDL_GetError();
	return std::nullopt;
}

std::optional<std::string_view> VideoDriver_SDL_Base::Initialize()
{
	this->UpdateAutoResolution();

	auto error = InitializeSDL();
	if (error) return error;

	FindResolutions();
	Debug(driver, 2, "Resolution for display: {}x{}", _cur_resolution.width, _cur_resolution.height);

	return std::nullopt;
}

std::optional<std::string_view> VideoDriver_SDL_Base::Start(const StringList &param)
{
	if (BlitterFactory::GetCurrentBlitter()->GetScreenDepth() == 0) return "Only real blitters supported";

	auto error = this->Initialize();
	if (error) return error;

#ifdef SDL_HINT_MOUSE_AUTO_CAPTURE
	if (GetDriverParamBool(param, "no_mouse_capture")) {
		/* By default SDL captures the mouse, while a button is pressed.
		 * This is annoying during debugging, when OpenTTD is suspended while the button was pressed.
		 */
		if (!SDL_SetHint(SDL_HINT_MOUSE_AUTO_CAPTURE, "0")) return SDL_GetError();
	}
#endif

	this->startup_display = FindStartupDisplay(GetDriverParamInt(param, "display", -1));

	if (!CreateMainSurface(_cur_resolution.width, _cur_resolution.height, false)) {
		return SDL_GetError();
	}

	const char *dname = SDL_GetCurrentVideoDriver();
	Debug(driver, 1, "SDL2: using driver '{}'", dname);

	this->driver_info = this->GetName();
	this->driver_info += " (";
	this->driver_info += dname;
	this->driver_info += ")";

	MarkWholeScreenDirty();

	SDL_StopTextInput();
	this->edit_box_focused = false;

#ifdef __EMSCRIPTEN__
	this->is_game_threaded = false;
#else
	this->is_game_threaded = !GetDriverParamBool(param, "no_threads") && !GetDriverParamBool(param, "no_thread");
#endif

	return std::nullopt;
}

void VideoDriver_SDL_Base::Stop()
{
	SDL_QuitSubSystem(SDL_INIT_VIDEO);
	if (SDL_WasInit(SDL_INIT_EVERYTHING) == 0) {
		SDL_Quit(); // If there's nothing left, quit SDL
	}
}

void VideoDriver_SDL_Base::InputLoop()
{
	uint32_t mod = SDL_GetModState();
	const Uint8 *keys = SDL_GetKeyboardState(nullptr);

	bool old_ctrl_pressed = _ctrl_pressed;

	_ctrl_pressed  = !!(mod & KMOD_CTRL);
	_shift_pressed = !!(mod & KMOD_SHIFT);

	/* Speedup when pressing tab, except when using ALT+TAB
	 * to switch to another application. */
	this->fast_forward_key_pressed = keys[SDL_SCANCODE_TAB] && (mod & KMOD_ALT) == 0;

	/* Determine which directional keys are down. */
	_dirkeys =
		(keys[SDL_SCANCODE_LEFT]  ? 1 : 0) |
		(keys[SDL_SCANCODE_UP]    ? 2 : 0) |
		(keys[SDL_SCANCODE_RIGHT] ? 4 : 0) |
		(keys[SDL_SCANCODE_DOWN]  ? 8 : 0);

	if (old_ctrl_pressed != _ctrl_pressed) HandleCtrlChanged();
}

void VideoDriver_SDL_Base::LoopOnce()
{
	if (_exit_game) {
#ifdef __EMSCRIPTEN__
		/* Emscripten is event-driven, and as such the main loop is inside
		 * the browser. So if _exit_game goes true, the main loop ends (the
		 * cancel call), but we still have to call the cleanup that is
		 * normally done at the end of the main loop for non-Emscripten.
		 * After that, Emscripten just halts, and the HTML shows a nice
		 * "bye, see you next time" message. */
		extern void PostMainLoop();
		PostMainLoop();

		emscripten_cancel_main_loop();
		emscripten_exit_pointerlock();
		/* In effect, the game ends here. As emscripten_set_main_loop() caused
		 * the stack to be unwound, the code after MainLoop() in
		 * openttd_main() is never executed. */
		if (_game_mode == GM_BOOTSTRAP) {
			EM_ASM(if (window["openttd_bootstrap_reload"]) openttd_bootstrap_reload());
		} else {
			EM_ASM(if (window["openttd_exit"]) openttd_exit());
		}
#endif
		return;
	}

	this->Tick();

/* Emscripten is running an event-based mainloop; there is already some
 * downtime between each iteration, so no need to sleep. */
#ifndef __EMSCRIPTEN__
	this->SleepTillNextTick();
#endif
}

void VideoDriver_SDL_Base::MainLoop()
{
#ifdef __EMSCRIPTEN__
	/* Run the main loop event-driven, based on RequestAnimationFrame. */
	emscripten_set_main_loop_arg(&this->EmscriptenLoop, this, 0, 1);
#else
	this->StartGameThread();

	while (!_exit_game) {
		LoopOnce();
	}

	this->StopGameThread();
#endif
}

bool VideoDriver_SDL_Base::ChangeResolution(int w, int h)
{
	return CreateMainSurface(w, h, true);
}

bool VideoDriver_SDL_Base::ToggleFullscreen(bool fullscreen)
{
	/* Remember current window size */
	int w, h;
	SDL_GetWindowSize(this->sdl_window, &w, &h);

	if (fullscreen) {
		/* Find fullscreen window size */
		SDL_DisplayMode dm;
		if (SDL_GetCurrentDisplayMode(SDL_GetWindowDisplayIndex(this->sdl_window), &dm) < 0) {
			Debug(driver, 0, "SDL_GetCurrentDisplayMode() failed: {}", SDL_GetError());
		} else {
			SDL_SetWindowSize(this->sdl_window, dm.w, dm.h);
		}
	}

	Debug(driver, 1, "SDL2: Setting {}", fullscreen ? "fullscreen" : "windowed");
	int ret = SDL_SetWindowFullscreen(this->sdl_window, fullscreen ? SDL_WINDOW_FULLSCREEN : 0);
	if (ret == 0) {
		/* Switching resolution succeeded, set fullscreen value of window. */
		_fullscreen = fullscreen;
		if (!fullscreen) SDL_SetWindowSize(this->sdl_window, w, h);
	} else {
		Debug(driver, 0, "SDL_SetWindowFullscreen() failed: {}", SDL_GetError());
	}

	InvalidateWindowClassesData(WC_GAME_OPTIONS, 3);
	return ret == 0;
}

bool VideoDriver_SDL_Base::AfterBlitterChange()
{
	assert(BlitterFactory::GetCurrentBlitter()->GetScreenDepth() != 0);
	int w, h;
	SDL_GetWindowSize(this->sdl_window, &w, &h);
	return CreateMainSurface(w, h, false);
}

Dimension VideoDriver_SDL_Base::GetScreenSize() const
{
	SDL_DisplayMode mode;
	if (SDL_GetCurrentDisplayMode(this->startup_display, &mode) != 0) return VideoDriver::GetScreenSize();

	return { static_cast<uint>(mode.w), static_cast<uint>(mode.h) };
}

bool VideoDriver_SDL_Base::LockVideoBuffer()
{
	if (this->buffer_locked) return false;
	this->buffer_locked = true;

	_screen.dst_ptr = this->GetVideoPointer();
	assert(_screen.dst_ptr != nullptr);

	return true;
}

void VideoDriver_SDL_Base::UnlockVideoBuffer()
{
	if (_screen.dst_ptr != nullptr) {
		/* Hand video buffer back to the drawing backend. */
		this->ReleaseVideoPointer();
		_screen.dst_ptr = nullptr;
	}

	this->buffer_locked = false;
}
