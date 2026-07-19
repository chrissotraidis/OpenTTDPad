/*
 * This file is part of OpenTTDPad and OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License version 2.
 */

/** @file document_manager.mm Native Files, sharing, notices, and touch settings. */

#include "../../stdafx.h"
#include "document_manager.h"

#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <atomic>
#include <zlib.h>

#include "../../safeguards.h"

static UIButton *OpenTTDPadOptionsButton;
static std::atomic<uint64_t> OpenTTDPadSettingsGeneration{1};

static NSString *OpenTTDPadPersonalDirectory()
{
	NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
	return [documents stringByAppendingPathComponent:@"OpenTTD"];
}

static UIWindow *OpenTTDPadVisibleWindow()
{
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState == UISceneActivationStateUnattached) continue;
		for (UIWindow *window in ((UIWindowScene *)scene).windows) {
			if (window.isKeyWindow) return window;
		}
	}
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:UIWindowScene.class]) continue;
		for (UIWindow *window in ((UIWindowScene *)scene).windows) {
			if (!window.hidden && window.alpha > 0) return window;
		}
	}
	return nil;
}

static UIViewController *OpenTTDPadPresenter()
{
	UIViewController *controller = OpenTTDPadVisibleWindow().rootViewController;
	while (controller.presentedViewController != nil) controller = controller.presentedViewController;
	return controller;
}

static void OpenTTDPadPresentMessage(NSString *title, NSString *message)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIViewController *presenter = OpenTTDPadPresenter();
		if (presenter == nil) return;
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
			preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
		[presenter presentViewController:alert animated:YES completion:nil];
	});
}

static NSString *OpenTTDPadImportSubdirectory(NSString *extension)
{
	if ([extension isEqualToString:@"sav"]) return @"save";
	if ([extension isEqualToString:@"scn"]) return @"scenario";
	if ([extension isEqualToString:@"png"]) return @"scenario/heightmap";
	if ([extension isEqualToString:@"grf"]) return @"newgrf";
	if ([extension isEqualToString:@"zip"] || [extension isEqualToString:@"tar"] || [extension isEqualToString:@"gz"] ||
			[extension isEqualToString:@"xz"]) return @"content_download";
	return nil;
}

static NSURL *OpenTTDPadUniqueDestination(NSURL *directory, NSString *filename)
{
	NSFileManager *manager = NSFileManager.defaultManager;
	NSURL *candidate = [directory URLByAppendingPathComponent:filename];
	if (![manager fileExistsAtPath:candidate.path]) return candidate;
	NSString *stem = filename.stringByDeletingPathExtension;
	NSString *extension = filename.pathExtension;
	for (NSUInteger index = 2; index < 10000; index++) {
		NSString *name = extension.length == 0 ? [NSString stringWithFormat:@"%@ %lu", stem, (unsigned long)index] :
			[NSString stringWithFormat:@"%@ %lu.%@", stem, (unsigned long)index, extension];
		candidate = [directory URLByAppendingPathComponent:name];
		if (![manager fileExistsAtPath:candidate.path]) return candidate;
	}
	return candidate;
}

static void OpenTTDPadImportURLs(NSArray<NSURL *> *urls)
{
	NSFileManager *manager = NSFileManager.defaultManager;
	NSURL *root = [NSURL fileURLWithPath:OpenTTDPadPersonalDirectory() isDirectory:YES];
	NSUInteger imported = 0;
	NSMutableArray<NSString *> *problems = [NSMutableArray array];
	for (NSURL *source in urls) {
		NSString *extension = source.pathExtension.lowercaseString;
		NSString *subdirectory = OpenTTDPadImportSubdirectory(extension);
		if (subdirectory == nil) {
			[problems addObject:[NSString stringWithFormat:@"%@ (unsupported type)", source.lastPathComponent]];
			continue;
		}
		BOOL scoped = [source startAccessingSecurityScopedResource];
		NSURL *directory = [root URLByAppendingPathComponent:subdirectory isDirectory:YES];
		NSError *error = nil;
		[manager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error];
		NSURL *destination = OpenTTDPadUniqueDestination(directory, source.lastPathComponent);
		if (error == nil && [manager copyItemAtURL:source toURL:destination error:&error]) {
			imported++;
		} else {
			[problems addObject:[NSString stringWithFormat:@"%@ (%@)", source.lastPathComponent,
				error.localizedDescription ?: @"copy failed"]];
		}
		if (scoped) [source stopAccessingSecurityScopedResource];
	}
	NSString *message = [NSString stringWithFormat:@"%lu file%@ copied into On My iPad → OpenTTD.",
		(unsigned long)imported, imported == 1 ? @" was" : @"s were"];
	if (problems.count != 0) {
		message = [message stringByAppendingFormat:@"\n\nNot imported:\n%@", [problems componentsJoinedByString:@"\n"]];
	}
	OpenTTDPadPresentMessage(imported == 0 ? @"Nothing Imported" : @"Import Complete", message);
}

extern "C" void OpenTTDPadHandleOpenURLs(NSArray *urls)
{
	if (urls.count == 0) return;
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ OpenTTDPadImportURLs(urls); });
}

static void OpenTTDPadAppend16(NSMutableData *data, uint16_t value)
{
	const uint8_t bytes[] = {static_cast<uint8_t>(value), static_cast<uint8_t>(value >> 8)};
	[data appendBytes:bytes length:sizeof(bytes)];
}

static void OpenTTDPadAppend32(NSMutableData *data, uint32_t value)
{
	const uint8_t bytes[] = {static_cast<uint8_t>(value), static_cast<uint8_t>(value >> 8),
		static_cast<uint8_t>(value >> 16), static_cast<uint8_t>(value >> 24)};
	[data appendBytes:bytes length:sizeof(bytes)];
}

struct OpenTTDPadZipEntry {
	NSData *name;
	NSData *contents;
	uint32_t checksum;
	uint32_t offset;
};

static NSURL *OpenTTDPadCreateSaveArchive(NSError **output_error, NSUInteger *output_count)
{
	NSFileManager *manager = NSFileManager.defaultManager;
	NSURL *save_root = [NSURL fileURLWithPath:[OpenTTDPadPersonalDirectory() stringByAppendingPathComponent:@"save"]
		isDirectory:YES];
	NSDirectoryEnumerator<NSURL *> *enumerator = [manager enumeratorAtURL:save_root
		includingPropertiesForKeys:@[NSURLIsRegularFileKey] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
	NSMutableArray<NSValue *> *entries = [NSMutableArray array];
	for (NSURL *url in enumerator) {
		NSNumber *regular = nil;
		[url getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];
		if (!regular.boolValue || ![url.pathExtension.lowercaseString isEqualToString:@"sav"]) continue;
		NSData *contents = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:output_error];
		if (contents == nil || contents.length > UINT32_MAX) return nil;
		NSString *relative = [url.path substringFromIndex:save_root.path.length + 1];
		NSData *name = [[@"save/" stringByAppendingString:relative] dataUsingEncoding:NSUTF8StringEncoding];
		OpenTTDPadZipEntry *entry = new OpenTTDPadZipEntry{name, contents,
			static_cast<uint32_t>(crc32(0, static_cast<const Bytef *>(contents.bytes), contents.length)), 0};
		[entries addObject:[NSValue valueWithPointer:entry]];
	}
	if (output_count != nullptr) *output_count = entries.count;
	if (entries.count == 0) return nil;

	NSMutableData *archive = [NSMutableData data];
	for (NSValue *value in entries) {
		OpenTTDPadZipEntry *entry = static_cast<OpenTTDPadZipEntry *>(value.pointerValue);
		entry->offset = static_cast<uint32_t>(archive.length);
		OpenTTDPadAppend32(archive, 0x04034b50); OpenTTDPadAppend16(archive, 20); OpenTTDPadAppend16(archive, 0x0800);
		OpenTTDPadAppend16(archive, 0); OpenTTDPadAppend16(archive, 0); OpenTTDPadAppend16(archive, 0x0021);
		OpenTTDPadAppend32(archive, entry->checksum); OpenTTDPadAppend32(archive, static_cast<uint32_t>(entry->contents.length));
		OpenTTDPadAppend32(archive, static_cast<uint32_t>(entry->contents.length));
		OpenTTDPadAppend16(archive, static_cast<uint16_t>(entry->name.length)); OpenTTDPadAppend16(archive, 0);
		[archive appendData:entry->name]; [archive appendData:entry->contents];
	}
	const uint32_t central_offset = static_cast<uint32_t>(archive.length);
	for (NSValue *value in entries) {
		OpenTTDPadZipEntry *entry = static_cast<OpenTTDPadZipEntry *>(value.pointerValue);
		OpenTTDPadAppend32(archive, 0x02014b50); OpenTTDPadAppend16(archive, 20); OpenTTDPadAppend16(archive, 20);
		OpenTTDPadAppend16(archive, 0x0800); OpenTTDPadAppend16(archive, 0); OpenTTDPadAppend16(archive, 0); OpenTTDPadAppend16(archive, 0x0021);
		OpenTTDPadAppend32(archive, entry->checksum); OpenTTDPadAppend32(archive, static_cast<uint32_t>(entry->contents.length));
		OpenTTDPadAppend32(archive, static_cast<uint32_t>(entry->contents.length));
		OpenTTDPadAppend16(archive, static_cast<uint16_t>(entry->name.length)); OpenTTDPadAppend16(archive, 0); OpenTTDPadAppend16(archive, 0);
		OpenTTDPadAppend16(archive, 0); OpenTTDPadAppend16(archive, 0); OpenTTDPadAppend32(archive, 0); OpenTTDPadAppend32(archive, entry->offset);
		[archive appendData:entry->name];
	}
	const uint32_t central_size = static_cast<uint32_t>(archive.length) - central_offset;
	OpenTTDPadAppend32(archive, 0x06054b50); OpenTTDPadAppend16(archive, 0); OpenTTDPadAppend16(archive, 0);
	OpenTTDPadAppend16(archive, static_cast<uint16_t>(entries.count)); OpenTTDPadAppend16(archive, static_cast<uint16_t>(entries.count));
	OpenTTDPadAppend32(archive, central_size); OpenTTDPadAppend32(archive, central_offset); OpenTTDPadAppend16(archive, 0);
	for (NSValue *value in entries) delete static_cast<OpenTTDPadZipEntry *>(value.pointerValue);

	NSURL *destination = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"OpenTTDPad-Saves.zip"]];
	[manager removeItemAtURL:destination error:nil];
	return [archive writeToURL:destination options:NSDataWritingAtomic error:output_error] ? destination : nil;
}

@interface OpenTTDPadDocumentManager : NSObject <UIDocumentPickerDelegate>
+ (instancetype)shared;
- (void)showOptions;
- (void)showImport;
- (void)showExport;
- (void)showTouchSettings;
- (void)showNotices;
- (void)dismissPresented;
@end

@implementation OpenTTDPadDocumentManager

+ (instancetype)shared
{
	static OpenTTDPadDocumentManager *manager;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ manager = [[OpenTTDPadDocumentManager alloc] init]; });
	return manager;
}

- (void)showOptions
{
	UIViewController *presenter = OpenTTDPadPresenter();
	if (presenter == nil) return;
	OpenTTDPadOptionsButton.accessibilityLabel = @"OpenTTDPad options";
	UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"OpenTTDPad"
		message:@"Files, touch controls, and project information" preferredStyle:UIAlertControllerStyleActionSheet];
	[menu addAction:[UIAlertAction actionWithTitle:@"Import Save or Content" style:UIAlertActionStyleDefault
		handler:^(__unused UIAlertAction *action) { [self showImport]; }]];
	[menu addAction:[UIAlertAction actionWithTitle:@"Export All Saves" style:UIAlertActionStyleDefault
		handler:^(__unused UIAlertAction *action) { [self showExport]; }]];
	[menu addAction:[UIAlertAction actionWithTitle:@"Touch Controls" style:UIAlertActionStyleDefault
		handler:^(__unused UIAlertAction *action) { [self showTouchSettings]; }]];
	[menu addAction:[UIAlertAction actionWithTitle:@"Licenses & Credits" style:UIAlertActionStyleDefault
		handler:^(__unused UIAlertAction *action) { [self showNotices]; }]];
	[menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	menu.popoverPresentationController.sourceView = OpenTTDPadOptionsButton;
	menu.popoverPresentationController.sourceRect = OpenTTDPadOptionsButton.bounds;
	[presenter presentViewController:menu animated:YES completion:nil];
}

- (void)showImport
{
	NSArray<UTType *> *types = @[UTTypeData, UTTypePNG, UTTypeArchive];
	UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
		initForOpeningContentTypes:types asCopy:YES];
	picker.delegate = self;
	picker.allowsMultipleSelection = YES;
	[OpenTTDPadPresenter() presentViewController:picker animated:YES completion:nil];
	[picker release];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
	OpenTTDPadHandleOpenURLs(urls);
}

- (void)showExport
{
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSError *error = nil;
		NSUInteger count = 0;
		NSURL *archive = OpenTTDPadCreateSaveArchive(&error, &count);
		if (archive == nil) {
			OpenTTDPadPresentMessage(@"No Saves to Export", error.localizedDescription ?:
				@"Create or import a save before exporting.");
			return;
		}
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 350 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
				UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[archive]
					applicationActivities:nil];
				OpenTTDPadOptionsButton.accessibilityLabel = [NSString stringWithFormat:@"OpenTTDPad options, %lu saves ready to share",
					(unsigned long)count];
				UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
					[NSString stringWithFormat:@"Save archive ready with %lu saves", (unsigned long)count]);
				share.popoverPresentationController.sourceView = OpenTTDPadOptionsButton;
				share.popoverPresentationController.sourceRect = OpenTTDPadOptionsButton.bounds;
				[OpenTTDPadPresenter() presentViewController:share animated:YES completion:nil];
			[share release];
		});
	});
}

- (void)showResponseChoices
{
	UIAlertController *choices = [UIAlertController alertControllerWithTitle:@"Gesture Response" message:nil
		preferredStyle:UIAlertControllerStyleActionSheet];
	NSArray<NSString *> *names = @[@"Relaxed", @"Balanced", @"Responsive"];
	for (NSInteger index = 0; index < (NSInteger)names.count; index++) {
		[choices addAction:[UIAlertAction actionWithTitle:names[index] style:UIAlertActionStyleDefault
			handler:^(__unused UIAlertAction *action) {
				[[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"OpenTTDPadGestureResponse"];
				OpenTTDPadSettingsGeneration++;
				[self showTouchSettings];
			}]];
	}
	choices.popoverPresentationController.sourceView = OpenTTDPadOptionsButton;
	choices.popoverPresentationController.sourceRect = OpenTTDPadOptionsButton.bounds;
	[OpenTTDPadPresenter() presentViewController:choices animated:YES completion:nil];
}

- (void)showHoldChoices
{
	UIAlertController *choices = [UIAlertController alertControllerWithTitle:@"Precision Hold" message:nil
		preferredStyle:UIAlertControllerStyleActionSheet];
	NSArray<NSNumber *> *values = @[@350, @500, @700];
	NSArray<NSString *> *names = @[@"Quick · 0.35 seconds", @"Balanced · 0.50 seconds", @"Deliberate · 0.70 seconds"];
	for (NSInteger index = 0; index < (NSInteger)names.count; index++) {
		[choices addAction:[UIAlertAction actionWithTitle:names[index] style:UIAlertActionStyleDefault
			handler:^(__unused UIAlertAction *action) {
				[[NSUserDefaults standardUserDefaults] setInteger:values[index].integerValue forKey:@"OpenTTDPadLongPressMS"];
				OpenTTDPadSettingsGeneration++;
				[self showTouchSettings];
			}]];
	}
	choices.popoverPresentationController.sourceView = OpenTTDPadOptionsButton;
	choices.popoverPresentationController.sourceRect = OpenTTDPadOptionsButton.bounds;
	[OpenTTDPadPresenter() presentViewController:choices animated:YES completion:nil];
}

- (void)showTouchSettings
{
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	[defaults registerDefaults:@{@"OpenTTDPadGestureResponse": @1, @"OpenTTDPadLongPressMS": @500,
		@"OpenTTDPadExpandedTargets": @YES, @"OpenTTDPadMomentum": @YES}];
	NSArray<NSString *> *responses = @[@"Relaxed", @"Balanced", @"Responsive"];
	NSInteger response = std::clamp<NSInteger>([defaults integerForKey:@"OpenTTDPadGestureResponse"], 0, 2);
	UIAlertController *settings = [UIAlertController alertControllerWithTitle:@"Touch Controls"
		message:@"Interface and font scale remain independent in OpenTTD's Game Options. Pinch changes only the map zoom."
		preferredStyle:UIAlertControllerStyleActionSheet];
	[settings addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Gesture response: %@", responses[response]]
		style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { [self showResponseChoices]; }]];
	[settings addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Precision hold: %.2f seconds",
		[defaults integerForKey:@"OpenTTDPadLongPressMS"] / 1000.0] style:UIAlertActionStyleDefault
		handler:^(__unused UIAlertAction *action) { [self showHoldChoices]; }]];
	BOOL expanded = [defaults boolForKey:@"OpenTTDPadExpandedTargets"];
	[settings addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Enlarged controls: %@", expanded ? @"On" : @"Off"]
		style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
			[defaults setBool:!expanded forKey:@"OpenTTDPadExpandedTargets"];
			OpenTTDPadSettingsGeneration++;
			[self showTouchSettings];
		}]];
	BOOL momentum = [defaults boolForKey:@"OpenTTDPadMomentum"];
	[settings addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Map momentum: %@", momentum ? @"On" : @"Off"]
		style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
			[defaults setBool:!momentum forKey:@"OpenTTDPadMomentum"];
			OpenTTDPadSettingsGeneration++;
			[self showTouchSettings];
		}]];
	[settings addAction:[UIAlertAction actionWithTitle:@"Show Touch Tips Again" style:UIAlertActionStyleDefault
		handler:^(__unused UIAlertAction *action) {
			[defaults setBool:NO forKey:@"OpenTTDPadTouchHintSeen"];
			[defaults setBool:NO forKey:@"OpenTTDPadToolHintSeen"];
			OpenTTDPadPresentMessage(@"Touch Tips Reset", @"The touch coach will appear the next time the app starts a game.");
		}]];
	[settings addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
	settings.popoverPresentationController.sourceView = OpenTTDPadOptionsButton;
	settings.popoverPresentationController.sourceRect = OpenTTDPadOptionsButton.bounds;
	[OpenTTDPadPresenter() presentViewController:settings animated:YES completion:nil];
}

- (void)showNotices
{
	NSString *notices_path = [NSBundle.mainBundle pathForResource:@"THIRD_PARTY_NOTICES" ofType:@"md" inDirectory:@"docs"];
	NSString *copying_path = [NSBundle.mainBundle pathForResource:@"COPYING-OpenTTD" ofType:@"md" inDirectory:@"docs"];
	NSString *notices = [NSString stringWithContentsOfFile:notices_path encoding:NSUTF8StringEncoding error:nil] ?: @"";
	NSString *copying = [NSString stringWithContentsOfFile:copying_path encoding:NSUTF8StringEncoding error:nil] ?: @"";
	UIViewController *controller = [[UIViewController alloc] init];
	controller.title = @"Licenses & Credits";
	controller.view.backgroundColor = UIColor.systemBackgroundColor;
	UITextView *text = [[UITextView alloc] initWithFrame:CGRectZero];
	text.translatesAutoresizingMaskIntoConstraints = NO;
	text.editable = NO;
	text.selectable = YES;
	text.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
	text.adjustsFontForContentSizeCategory = YES;
	text.text = [NSString stringWithFormat:@"%@\n\n%@", notices, copying];
	text.accessibilityLabel = @"OpenTTDPad licenses and credits";
	[controller.view addSubview:text];
	[NSLayoutConstraint activateConstraints:@[
		[text.leadingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.leadingAnchor constant:16],
		[text.trailingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
		[text.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor],
		[text.bottomAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.bottomAnchor],
	]];
	controller.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
		target:self action:@selector(dismissPresented)];
	UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:controller];
	navigation.modalPresentationStyle = UIModalPresentationFormSheet;
	[OpenTTDPadPresenter() presentViewController:navigation animated:YES completion:nil];
	[text release]; [controller.navigationItem.rightBarButtonItem release]; [controller release]; [navigation release];
}

- (void)dismissPresented
{
	[OpenTTDPadPresenter() dismissViewControllerAnimated:YES completion:nil];
}

@end

extern "C" void OpenTTDPadEnsureOptionsButton()
{
	dispatch_async(dispatch_get_main_queue(), ^{
		UIWindow *window = OpenTTDPadVisibleWindow();
		if (window == nil) return;
		if (OpenTTDPadOptionsButton != nil && OpenTTDPadOptionsButton.window == window) return;
		[OpenTTDPadOptionsButton removeFromSuperview];
		[OpenTTDPadOptionsButton release];
		OpenTTDPadOptionsButton = [[UIButton buttonWithType:UIButtonTypeSystem] retain];
		OpenTTDPadOptionsButton.frame = CGRectMake(0, 0, 52, 52);
		OpenTTDPadOptionsButton.layer.cornerRadius = 16;
		OpenTTDPadOptionsButton.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.88];
		OpenTTDPadOptionsButton.layer.borderWidth = 1;
		OpenTTDPadOptionsButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.24].CGColor;
		[OpenTTDPadOptionsButton setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
		OpenTTDPadOptionsButton.tintColor = UIColor.whiteColor;
		OpenTTDPadOptionsButton.accessibilityLabel = @"OpenTTDPad options";
		[OpenTTDPadOptionsButton addTarget:[OpenTTDPadDocumentManager shared] action:@selector(showOptions)
			forControlEvents:UIControlEventTouchUpInside];
		UIEdgeInsets safe = window.safeAreaInsets;
		OpenTTDPadOptionsButton.center = CGPointMake(CGRectGetWidth(window.bounds) - safe.right - 34,
			CGRectGetMidY(window.bounds));
		[window addSubview:OpenTTDPadOptionsButton];
	});
}

extern "C" void OpenTTDPadSetConstructionPalette(int transport_type)
{
	static int previous = -1;
	if (previous == transport_type) return;
	previous = transport_type;
	dispatch_async(dispatch_get_main_queue(), ^{
		static NSArray<NSString *> *names;
		static dispatch_once_t once;
		dispatch_once(&once, ^{ names = [@[@"Rail", @"Road", @"Water", @"Air"] retain]; });
		OpenTTDPadOptionsButton.accessibilityValue = transport_type >= 0 && transport_type < (int)names.count ?
			[names[transport_type] stringByAppendingString:@" construction palette open"] : nil;
	});
}

extern "C" uint64_t OpenTTDPadTouchSettingsGeneration()
{
	return OpenTTDPadSettingsGeneration.load();
}

extern "C" void OpenTTDPadLoadTouchSettings(double *threshold_scale, uint32_t *long_press_ms,
	bool *expanded_targets, bool *momentum)
{
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	[defaults registerDefaults:@{@"OpenTTDPadGestureResponse": @1, @"OpenTTDPadLongPressMS": @500,
		@"OpenTTDPadExpandedTargets": @YES, @"OpenTTDPadMomentum": @YES}];
	const NSInteger response = std::clamp<NSInteger>([defaults integerForKey:@"OpenTTDPadGestureResponse"], 0, 2);
	if (threshold_scale != nullptr) *threshold_scale = response == 0 ? 1.25 : response == 2 ? 0.75 : 1.0;
	if (long_press_ms != nullptr) *long_press_ms = static_cast<uint32_t>([defaults integerForKey:@"OpenTTDPadLongPressMS"]);
	if (expanded_targets != nullptr) *expanded_targets = [defaults boolForKey:@"OpenTTDPadExpandedTargets"];
	if (momentum != nullptr) *momentum = [defaults boolForKey:@"OpenTTDPadMomentum"];
}
