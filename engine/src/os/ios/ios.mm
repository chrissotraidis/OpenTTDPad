/*
 * This file is part of OpenTTDPad and OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License version 2.
 */

/** @file ios.mm Minimal iOS services used by the upstream engine. */

#include "../../stdafx.h"
#include "../../debug.h"
#include "document_manager.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#include <SDL.h>
#include <SDL_syswm.h>

#include "../../safeguards.h"

static UIWindowScene *OpenTTDPadActiveScene;
static UIWindow *OpenTTDPadSDLWindow;
static UIView *OpenTTDPadLoupe;
static UIImageView *OpenTTDPadLoupeImage;
static UIImage *OpenTTDPadLoupeSnapshot;
static UIView *OpenTTDPadTouchHint;
static UIButton *OpenTTDPadCancelToolButton;
static UILabel *OpenTTDPadToolHint;

@interface OpenTTDPadOverlayActions : NSObject
+ (instancetype)shared;
- (void)dismissTouchHint;
- (void)cancelActiveTool;
@end

@implementation OpenTTDPadOverlayActions

+ (instancetype)shared
{
	static OpenTTDPadOverlayActions *actions;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ actions = [[OpenTTDPadOverlayActions alloc] init]; });
	return actions;
}

- (void)dismissTouchHint
{
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"OpenTTDPadTouchHintSeen"];
	[OpenTTDPadTouchHint removeFromSuperview];
	[OpenTTDPadTouchHint release];
	OpenTTDPadTouchHint = nil;
}

- (void)cancelActiveTool
{
	SDL_Event event{};
	event.type = SDL_KEYDOWN;
	event.key.state = SDL_PRESSED;
	event.key.keysym.sym = SDLK_ESCAPE;
	SDL_PushEvent(&event);
	event.type = SDL_KEYUP;
	event.key.state = SDL_RELEASED;
	SDL_PushEvent(&event);
}

@end

static UIWindow *OpenTTDPadGameWindow()
{
	/* SDL's launch window shares the scene until the first frame, so prefer
	 * the game's own window over the first visible one. */
	if (OpenTTDPadSDLWindow != nil && OpenTTDPadSDLWindow.windowScene != nil) return OpenTTDPadSDLWindow;
	UIWindowScene *scene = OpenTTDPadActiveScene;
	for (UIWindow *window in scene.windows) {
		if (!window.hidden && window.alpha > 0) return window;
	}
	return nil;
}

static CGFloat OpenTTDPadOverlayScale(UIWindow *window)
{
	if (window == nil || window.screen == nil) return 1.0;
	const CGSize window_size = window.bounds.size;
	const CGSize screen_size = window.screen.bounds.size;
	const CGFloat window_long_edge = std::max(window_size.width, window_size.height);
	const CGFloat screen_long_edge = std::max(screen_size.width, screen_size.height);
	const CGFloat coordinate_scale = screen_long_edge > 0 ? window_long_edge / screen_long_edge : 1.0;
	return std::clamp(std::max(coordinate_scale, window.screen.scale), 1.0, 3.0);
}

static void OpenTTDPadRequestLandscape(UIWindowScene *scene)
{
	if (scene == nil) return;
	UIWindowSceneGeometryPreferencesIOS *preferences = [[UIWindowSceneGeometryPreferencesIOS alloc]
		initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscape];
	[scene requestGeometryUpdateWithPreferences:preferences errorHandler:^(NSError *error) {
		fmt::print(stderr, "OpenTTDPad: landscape request failed: {}\n", error.localizedDescription.UTF8String);
	}];
	[preferences release];
}

static void OpenTTDPadPushLifecycleEvent(Uint32 type)
{
	SDL_Event event{};
	event.type = type;
	SDL_PushEvent(&event);
}

/* Provided by patches/sdl2-ios-scenes.patch. It starts SDL once the application
 * scene connects, keeps SDL's window sized to that scene as it rotates, resizes
 * or moves to another display, and hands the window to a replacement scene. */
@interface SDLUIKitSceneDelegate : NSObject <UIWindowSceneDelegate>
@end

@interface OpenTTDPadSceneDelegate : SDLUIKitSceneDelegate
@end

@implementation OpenTTDPadSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
	if (![scene isKindOfClass:[UIWindowScene class]] ||
		![session.role isEqualToString:UIWindowSceneSessionRoleApplication]) return;

	OpenTTDPadActiveScene = (UIWindowScene *)scene;
	OpenTTDPadRequestLandscape(OpenTTDPadActiveScene);
	[super scene:scene willConnectToSession:session options:connectionOptions];
	NSMutableArray<NSURL *> *urls = [NSMutableArray array];
	for (UIOpenURLContext *context in connectionOptions.URLContexts) [urls addObject:context.URL];
	if (urls.count != 0) OpenTTDPadHandleOpenURLs(urls);
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts
{
	NSMutableArray<NSURL *> *urls = [NSMutableArray array];
	for (UIOpenURLContext *context in URLContexts) [urls addObject:context.URL];
	OpenTTDPadHandleOpenURLs(urls);
}

- (void)sceneDidDisconnect:(UIScene *)scene
{
	[super sceneDidDisconnect:scene];
	if (scene == OpenTTDPadActiveScene) OpenTTDPadActiveScene = nil;
}

- (void)sceneWillResignActive:(UIScene *)scene
{
	OpenTTDPadPushLifecycleEvent(SDL_APP_WILLENTERBACKGROUND);
}

- (void)sceneDidEnterBackground:(UIScene *)scene
{
	OpenTTDPadPushLifecycleEvent(SDL_APP_DIDENTERBACKGROUND);
}

- (void)sceneWillEnterForeground:(UIScene *)scene
{
	OpenTTDPadPushLifecycleEvent(SDL_APP_WILLENTERFOREGROUND);
}

- (void)sceneDidBecomeActive:(UIScene *)scene
{
	OpenTTDPadPushLifecycleEvent(SDL_APP_DIDENTERFOREGROUND);
}

@end

extern "C" void OpenTTDPadAttachSDLWindowToScene(SDL_Window *window)
{
	if (window == nullptr) return;

	SDL_SysWMinfo info{};
	SDL_VERSION(&info.version);
	if (SDL_GetWindowWMInfo(window, &info) != SDL_TRUE || info.subsystem != SDL_SYSWM_UIKIT) return;

	UIWindowScene *scene = OpenTTDPadActiveScene;
	if (scene == nil) {
		for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
			if ([candidate isKindOfClass:[UIWindowScene class]] && candidate.activationState != UISceneActivationStateUnattached) {
				scene = (UIWindowScene *)candidate;
				break;
			}
		}
	}
	/* SDL normally creates its window on the owning scene already. */
	UIWindow *window_ui = info.info.uikit.window;
	OpenTTDPadSDLWindow = window_ui;
	if (window_ui.windowScene == nil && scene != nil) window_ui.windowScene = scene;
	if (window_ui.windowScene != nil) OpenTTDPadRequestLandscape(window_ui.windowScene);
	OpenTTDPadEnsureOptionsButton();
}

extern "C" const char *OpenTTDPadCACertificatePath()
{
	static std::string path;
	NSString *bundle_path = [[NSBundle mainBundle] pathForResource:@"cacert" ofType:@"pem"];
	if (bundle_path == nil) return nullptr;
	path = bundle_path.UTF8String;
	return path.c_str();
}

extern "C" void OpenTTDPadHaptic(int kind)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
		[defaults registerDefaults:@{@"OpenTTDPadHaptics": @YES}];
		if (![defaults boolForKey:@"OpenTTDPadHaptics"]) return;
		if (kind == 0) {
			UISelectionFeedbackGenerator *feedback = [[UISelectionFeedbackGenerator alloc] init];
			[feedback prepare];
			[feedback selectionChanged];
			[feedback release];
		} else {
			UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc]
				initWithStyle:UIImpactFeedbackStyleLight];
			[feedback prepare];
			[feedback impactOccurred];
			[feedback release];
		}
	});
}

static void OpenTTDPadPositionToolOverlay(UIWindow *window)
{
	if (window == nil || OpenTTDPadCancelToolButton == nil) return;
	const UIEdgeInsets safe = window.safeAreaInsets;
	const CGFloat scale = OpenTTDPadOverlayScale(window);
	const bool left_handed = OpenTTDPadControlsLeftHanded();
	OpenTTDPadCancelToolButton.center = CGPointMake(
		left_handed ? safe.left + 72.0 * scale : CGRectGetWidth(window.bounds) - safe.right - 72.0 * scale,
		CGRectGetHeight(window.bounds) - safe.bottom - 42.0 * scale);
	if (OpenTTDPadToolHint == nil) return;
	const CGFloat half_width = CGRectGetWidth(OpenTTDPadToolHint.bounds) / 2.0;
	const CGFloat proposed_x = OpenTTDPadCancelToolButton.center.x + (left_handed ? 180.0 : -180.0) * scale;
	const CGFloat minimum_x = safe.left + half_width + 8.0 * scale;
	const CGFloat maximum_x = CGRectGetWidth(window.bounds) - safe.right - half_width - 8.0 * scale;
	OpenTTDPadToolHint.center = CGPointMake(std::clamp(proposed_x, minimum_x, maximum_x),
		OpenTTDPadCancelToolButton.center.y);
}

extern "C" void OpenTTDPadRefreshControlPlacement()
{
	OpenTTDPadEnsureOptionsButton();
	dispatch_async(dispatch_get_main_queue(), ^{ OpenTTDPadPositionToolOverlay(OpenTTDPadGameWindow()); });
}

extern "C" void OpenTTDPadMaybeShowTouchHint()
{
	static bool requested = false;
	if (requested) return;
	requested = true;
	dispatch_async(dispatch_get_main_queue(), ^{
		const bool force = getenv("OPENTTDPAD_FORCE_HINTS") != nullptr;
		if (!force && (getenv("OPENTTDPAD_SKIP_HINTS") != nullptr ||
				[[NSUserDefaults standardUserDefaults] boolForKey:@"OpenTTDPadTouchHintSeen"])) return;
		UIWindow *window = OpenTTDPadGameWindow();
		if (window == nil || OpenTTDPadTouchHint != nil) return;

		const CGFloat scale = OpenTTDPadOverlayScale(window);
		/* Leave both thumb-control lanes clear, including on the compact iPad
		 * Simulator canvas where the previous coach covered the options button. */
		const CGFloat width = std::min<CGFloat>(520.0 * scale, CGRectGetWidth(window.bounds) - 176.0 * scale);
		OpenTTDPadTouchHint = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 104.0 * scale)];
		OpenTTDPadTouchHint.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.94];
		OpenTTDPadTouchHint.layer.cornerRadius = 18.0 * scale;
		OpenTTDPadTouchHint.layer.borderWidth = scale;
		OpenTTDPadTouchHint.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
		OpenTTDPadTouchHint.accessibilityViewIsModal = NO;

		UILabel *title = [[[UILabel alloc] initWithFrame:CGRectMake(20.0 * scale, 14.0 * scale,
			width - 120.0 * scale, 24.0 * scale)] autorelease];
		title.text = @"Built for touch";
		title.textColor = UIColor.whiteColor;
		title.font = [UIFont boldSystemFontOfSize:18.0 * scale];
		[OpenTTDPadTouchHint addSubview:title];

		UILabel *body = [[[UILabel alloc] initWithFrame:CGRectMake(20.0 * scale, 39.0 * scale,
			width - 120.0 * scale, 52.0 * scale)] autorelease];
		body.text = @"Tap to interact · Drag with tools to build\nTwo-finger drag to move · Pinch to zoom · Hold for precision";
		body.numberOfLines = 2;
		body.textColor = [UIColor colorWithWhite:0.86 alpha:1.0];
		body.font = [UIFont systemFontOfSize:14.0 * scale];
		[OpenTTDPadTouchHint addSubview:body];

		UIButton *dismiss = [UIButton buttonWithType:UIButtonTypeSystem];
		dismiss.frame = CGRectMake(width - 94.0 * scale, 28.0 * scale, 74.0 * scale, 48.0 * scale);
		dismiss.layer.cornerRadius = 12.0 * scale;
		dismiss.backgroundColor = UIColor.systemBlueColor;
		[dismiss setTitle:@"Got it" forState:UIControlStateNormal];
		[dismiss setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
		dismiss.titleLabel.font = [UIFont boldSystemFontOfSize:16.0 * scale];
		[dismiss addTarget:[OpenTTDPadOverlayActions shared] action:@selector(dismissTouchHint)
			forControlEvents:UIControlEventTouchUpInside];
		[OpenTTDPadTouchHint addSubview:dismiss];

		const UIEdgeInsets safe = window.safeAreaInsets;
		OpenTTDPadTouchHint.center = CGPointMake(CGRectGetMidX(window.bounds),
			CGRectGetMaxY(window.bounds) - safe.bottom - 72.0 * scale);
		[window addSubview:OpenTTDPadTouchHint];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
			if (OpenTTDPadTouchHint != nil) [[OpenTTDPadOverlayActions shared] dismissTouchHint];
		});
	});
}

extern "C" void OpenTTDPadSetToolOverlay(bool active)
{
	static bool previous = false;
	if (previous == active) return;
	previous = active;
	dispatch_async(dispatch_get_main_queue(), ^{
		if (!active) {
			[OpenTTDPadCancelToolButton removeFromSuperview];
			[OpenTTDPadCancelToolButton release];
			OpenTTDPadCancelToolButton = nil;
			[OpenTTDPadToolHint removeFromSuperview];
			[OpenTTDPadToolHint release];
			OpenTTDPadToolHint = nil;
			return;
		}

		UIWindow *window = OpenTTDPadGameWindow();
		if (window == nil || OpenTTDPadCancelToolButton != nil) return;
		const CGFloat scale = OpenTTDPadOverlayScale(window);
		OpenTTDPadCancelToolButton = [[UIButton buttonWithType:UIButtonTypeSystem] retain];
		OpenTTDPadCancelToolButton.frame = CGRectMake(0, 0, 112.0 * scale, 52.0 * scale);
		OpenTTDPadCancelToolButton.backgroundColor = [UIColor colorWithRed:0.70 green:0.12 blue:0.10 alpha:0.94];
		OpenTTDPadCancelToolButton.layer.cornerRadius = 16.0 * scale;
		OpenTTDPadCancelToolButton.layer.borderWidth = scale;
		OpenTTDPadCancelToolButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.32].CGColor;
		[OpenTTDPadCancelToolButton setTitle:@"✕  Cancel" forState:UIControlStateNormal];
		[OpenTTDPadCancelToolButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
		OpenTTDPadCancelToolButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.0 * scale];
		OpenTTDPadCancelToolButton.accessibilityLabel = @"Cancel active construction tool";
		[OpenTTDPadCancelToolButton addTarget:[OpenTTDPadOverlayActions shared] action:@selector(cancelActiveTool)
			forControlEvents:UIControlEventTouchUpInside];
		[window addSubview:OpenTTDPadCancelToolButton];
		OpenTTDPadPositionToolOverlay(window);

		if (![[NSUserDefaults standardUserDefaults] boolForKey:@"OpenTTDPadToolHintSeen"]) {
			[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"OpenTTDPadToolHintSeen"];
			OpenTTDPadToolHint = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 280.0 * scale, 40.0 * scale)];
			OpenTTDPadToolHint.text = @"Drag to build · Two fingers cancel";
			OpenTTDPadToolHint.textAlignment = NSTextAlignmentCenter;
			OpenTTDPadToolHint.textColor = UIColor.whiteColor;
			OpenTTDPadToolHint.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.92];
			OpenTTDPadToolHint.font = [UIFont systemFontOfSize:15.0 * scale weight:UIFontWeightSemibold];
			OpenTTDPadToolHint.layer.cornerRadius = 12.0 * scale;
			OpenTTDPadToolHint.layer.masksToBounds = YES;
			[window addSubview:OpenTTDPadToolHint];
			OpenTTDPadPositionToolOverlay(window);
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				[OpenTTDPadToolHint removeFromSuperview];
				[OpenTTDPadToolHint release];
				OpenTTDPadToolHint = nil;
			});
		}
	});
}

static void OpenTTDPadDestroyLoupe()
{
	[OpenTTDPadLoupe removeFromSuperview];
	[OpenTTDPadLoupe release];
	OpenTTDPadLoupe = nil;
	OpenTTDPadLoupeImage = nil;
	[OpenTTDPadLoupeSnapshot release];
	OpenTTDPadLoupeSnapshot = nil;
}

extern "C" void OpenTTDPadPrecisionLoupe(bool visible, double normalized_x, double normalized_y, double magnification)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if (!visible) {
			OpenTTDPadDestroyLoupe();
			return;
		}

		UIWindow *window = OpenTTDPadGameWindow();
		if (window == nil) return;
		const CGRect bounds = window.bounds;
		const CGFloat overlay_scale = OpenTTDPadOverlayScale(window);
		const CGFloat diameter = 132.0 * overlay_scale;
		const CGFloat radius = diameter / 2.0;
		const CGPoint finger = CGPointMake(normalized_x * CGRectGetWidth(bounds), normalized_y * CGRectGetHeight(bounds));
		const CGPoint target = CGPointMake(finger.x, finger.y - 60.0 * overlay_scale);

		if (OpenTTDPadLoupe == nil) {
			UIGraphicsBeginImageContextWithOptions(bounds.size, YES, 0);
			[window drawViewHierarchyInRect:bounds afterScreenUpdates:NO];
			OpenTTDPadLoupeSnapshot = [UIGraphicsGetImageFromCurrentImageContext() retain];
			UIGraphicsEndImageContext();

			OpenTTDPadLoupe = [[UIView alloc] initWithFrame:CGRectMake(0, 0, diameter, diameter)];
			OpenTTDPadLoupe.userInteractionEnabled = NO;
			OpenTTDPadLoupe.accessibilityLabel = @"Precision target loupe";
			OpenTTDPadLoupe.layer.cornerRadius = radius;
			OpenTTDPadLoupe.layer.masksToBounds = YES;
			OpenTTDPadLoupe.layer.borderWidth = 3.0 * overlay_scale;
			OpenTTDPadLoupe.layer.borderColor = UIColor.whiteColor.CGColor;
			OpenTTDPadLoupe.layer.shadowColor = UIColor.blackColor.CGColor;
			OpenTTDPadLoupe.layer.shadowOpacity = 0.45;

			OpenTTDPadLoupeImage = [[[UIImageView alloc] initWithImage:OpenTTDPadLoupeSnapshot] autorelease];
			OpenTTDPadLoupeImage.contentMode = UIViewContentModeScaleToFill;
			[OpenTTDPadLoupe addSubview:OpenTTDPadLoupeImage];

			UIView *horizontal = [[[UIView alloc] initWithFrame:CGRectMake(radius - 16.0 * overlay_scale,
				radius - overlay_scale, 32.0 * overlay_scale, 2.0 * overlay_scale)] autorelease];
			UIView *vertical = [[[UIView alloc] initWithFrame:CGRectMake(radius - overlay_scale,
				radius - 16.0 * overlay_scale, 2.0 * overlay_scale, 32.0 * overlay_scale)] autorelease];
			horizontal.backgroundColor = UIColor.systemYellowColor;
			vertical.backgroundColor = UIColor.systemYellowColor;
			[OpenTTDPadLoupe addSubview:horizontal];
			[OpenTTDPadLoupe addSubview:vertical];
			[window addSubview:OpenTTDPadLoupe];
		}

		const CGFloat scale = std::clamp(magnification, 1.5, 3.0);
		OpenTTDPadLoupeImage.frame = CGRectMake(radius - target.x * scale, radius - target.y * scale,
			CGRectGetWidth(bounds) * scale, CGRectGetHeight(bounds) * scale);
		const CGFloat margin = 8.0 * overlay_scale;
		const CGFloat center_x = std::clamp(target.x, radius + margin, CGRectGetWidth(bounds) - radius - margin);
		const CGFloat center_y = std::clamp(target.y - radius - 16.0 * overlay_scale, radius + margin,
			CGRectGetHeight(bounds) - radius - margin);
		OpenTTDPadLoupe.center = CGPointMake(center_x, center_y);
		[window bringSubviewToFront:OpenTTDPadLoupe];
	});
}

void OSOpenBrowser(const std::string &url)
{
	NSString *value = [NSString stringWithUTF8String:url.c_str()];
	NSURL *target = value == nil ? nil : [NSURL URLWithString:value];
	if (target == nil) return;

	dispatch_async(dispatch_get_main_queue(), ^{
		[[UIApplication sharedApplication] openURL:target options:@{} completionHandler:nil];
	});
}
