/*
 * This file is part of OpenTTDPad and OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License version 2.
 */

/** @file document_manager.mm Native Files, sharing, notices, and touch settings. */

#include "../../stdafx.h"
#include "../../rev.h"
#include "document_manager.h"

#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <atomic>
#include <zlib.h>

#include "../../safeguards.h"

static UIButton *OpenTTDPadOptionsButton;
static std::atomic<uint64_t> OpenTTDPadSettingsGeneration{1};
static int OpenTTDPadToolbarBottom;
static int OpenTTDPadStatusTop;

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

static CGFloat OpenTTDPadOverlayCoordinateScale(UIWindow *window)
{
	if (window == nil || window.screen == nil) return 1.0;
	const CGFloat window_long_edge = std::max(window.bounds.size.width, window.bounds.size.height);
	const CGFloat screen_long_edge = std::max(window.screen.bounds.size.width, window.screen.bounds.size.height);
	return screen_long_edge > 0 ? window_long_edge / screen_long_edge : 1.0;
}

static void OpenTTDPadPositionOptionsButton(UIWindow *window)
{
	if (window == nil || OpenTTDPadOptionsButton == nil) return;
	const UIEdgeInsets safe = window.safeAreaInsets;
	const CGFloat scale = OpenTTDPadOverlayCoordinateScale(window);
	/* Just below the end of the main toolbar (under its Help button, or under
	 * Pause for left-handed play), with a little air on both sides. */
	const CGFloat half = CGRectGetWidth(OpenTTDPadOptionsButton.bounds) / 2.0;
	const CGFloat margin = 10.0 * scale;
	const CGFloat x = OpenTTDPadControlsLeftHanded() ? safe.left + margin + half :
		CGRectGetWidth(window.bounds) - safe.right - margin - half;
	const CGFloat top = std::max<CGFloat>(safe.top, OpenTTDPadToolbarBottom * scale);
	const CGPoint centre = CGPointMake(x, top + margin + half);
	if (CGPointEqualToPoint(OpenTTDPadOptionsButton.center, centre)) return;
	/* Glide when a docked game window moves it; place it outright the first time. */
	static UIButton *placed = nil;
	if (placed == OpenTTDPadOptionsButton) {
		[UIView animateWithDuration:0.18 animations:^{ OpenTTDPadOptionsButton.center = centre; }];
	} else {
		OpenTTDPadOptionsButton.center = centre;
		placed = OpenTTDPadOptionsButton;
	}
}

extern "C" void OpenTTDPadSetChromeEdges(int toolbar_bottom, int status_top)
{
	if (toolbar_bottom == OpenTTDPadToolbarBottom && status_top == OpenTTDPadStatusTop) return;
	OpenTTDPadToolbarBottom = toolbar_bottom;
	OpenTTDPadStatusTop = status_top;
	OpenTTDPadRefreshControlPlacement();
}

extern "C" void OpenTTDPadChromeEdges(double *toolbar_bottom, double *status_top)
{
	*toolbar_bottom = OpenTTDPadToolbarBottom;
	*status_top = OpenTTDPadStatusTop;
}

static UIViewController *OpenTTDPadPresenter()
{
	UIViewController *controller = OpenTTDPadVisibleWindow().rootViewController;
	while (controller.presentedViewController != nil) controller = controller.presentedViewController;
	return controller;
}

static void OpenTTDPadAnchorPopover(UIViewController *controller)
{
	UIPopoverPresentationController *popover = controller.popoverPresentationController;
	if (popover == nil || OpenTTDPadOptionsButton == nil) return;
	popover.sourceView = OpenTTDPadOptionsButton;
	popover.sourceRect = OpenTTDPadOptionsButton.bounds;
	/* The persistent control sits under the toolbar, so menus open below it. */
	popover.permittedArrowDirections = UIPopoverArrowDirectionUp;
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

/** The About page: who made what, which versions, and where the source lives. */
static NSAttributedString *OpenTTDPadAboutText()
{
	NSMutableAttributedString *text = [[[NSMutableAttributedString alloc] init] autorelease];
	NSMutableParagraphStyle *centred = [[[NSMutableParagraphStyle alloc] init] autorelease];
	centred.alignment = NSTextAlignmentCenter;
	centred.paragraphSpacing = 4;
	NSMutableParagraphStyle *body = [[[NSMutableParagraphStyle alloc] init] autorelease];
	body.paragraphSpacing = 10;
	body.lineSpacing = 2;

	auto append = ^(NSString *string, NSDictionary *attributes) {
		[text appendAttributedString:[[[NSAttributedString alloc] initWithString:string attributes:attributes] autorelease]];
	};
	auto heading = ^(NSString *string) {
		append([string stringByAppendingString:@"\n"], @{
			NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold],
			NSForegroundColorAttributeName: UIColor.secondaryLabelColor, NSParagraphStyleAttributeName: body});
	};
	auto paragraph = ^(NSString *string) {
		append([string stringByAppendingString:@"\n\n"], @{NSFontAttributeName: [UIFont systemFontOfSize:16],
			NSForegroundColorAttributeName: UIColor.labelColor, NSParagraphStyleAttributeName: body});
	};
	auto link = ^(NSString *title, NSString *detail, NSString *url) {
		append(title, @{NSFontAttributeName: [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold],
			NSLinkAttributeName: [NSURL URLWithString:url], NSParagraphStyleAttributeName: body});
		append([NSString stringWithFormat:@"  %@\n", detail], @{NSFontAttributeName: [UIFont systemFontOfSize:14],
			NSForegroundColorAttributeName: UIColor.secondaryLabelColor, NSParagraphStyleAttributeName: body});
	};

	UIImage *icon = [UIImage imageNamed:@"AppIcon60x60"];
	if (icon != nil) {
		const CGRect frame = CGRectMake(0, 0, 76, 76);
		UIGraphicsImageRenderer *renderer = [[[UIGraphicsImageRenderer alloc] initWithSize:frame.size] autorelease];
		UIImage *rounded = [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *context) {
			[[UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:17] addClip];
			[icon drawInRect:frame];
		}];
		NSTextAttachment *attachment = [[[NSTextAttachment alloc] init] autorelease];
		attachment.image = rounded;
		attachment.bounds = frame;
		NSMutableAttributedString *picture = [[[NSAttributedString attributedStringWithAttachment:attachment] mutableCopy] autorelease];
		[picture addAttribute:NSParagraphStyleAttributeName value:centred range:NSMakeRange(0, picture.length)];
		[text appendAttributedString:picture];
		append(@"\n", @{NSParagraphStyleAttributeName: centred});
	}

	NSDictionary *info = NSBundle.mainBundle.infoDictionary;
	append(@"OpenTTDPad\n", @{NSFontAttributeName: [UIFont systemFontOfSize:28 weight:UIFontWeightBold],
		NSForegroundColorAttributeName: UIColor.labelColor, NSParagraphStyleAttributeName: centred});
	append([NSString stringWithFormat:@"Version %@ (%@) · OpenTTD %s\n\n", info[@"CFBundleShortVersionString"],
		info[@"CFBundleVersion"], _openttd_revision.c_str()], @{NSFontAttributeName: [UIFont systemFontOfSize:15],
		NSForegroundColorAttributeName: UIColor.secondaryLabelColor, NSParagraphStyleAttributeName: centred});

	paragraph(@"OpenTTD, shaped for iPad: touch-first construction, a precision loupe, Apple Pencil, trackpad and "
		"keyboard, desktop-compatible saves, and free graphics, sound and music.");

	heading(@"LINKS");
	link(@"Source code and releases", @"github.com/chrissotraidis/OpenTTDPad",
		@"https://github.com/chrissotraidis/OpenTTDPad");
	link(@"Report a problem", @"Include your iPad model and what you tapped",
		@"https://github.com/chrissotraidis/OpenTTDPad/issues");
	link(@"Build your own copy", @"With PadMint on an Apple Silicon Mac", @"https://github.com/chrissotraidis/padmint");
	link(@"OpenTTD", @"The open-source game this port is built on", @"https://www.openttd.org/");
	append(@"\n", @{});

	heading(@"CREDITS");
	paragraph(@"OpenTTD is made by the OpenTTD team and its contributors. Graphics by OpenGFX, sound effects by "
		"OpenSFX and music by OpenMSX, played through the TimGM6mb sound font. The iPad port is by Chris Sotraidis.");

	heading(@"LICENSE");
	paragraph(@"OpenTTDPad is free software under the GNU General Public License, version 2. The Components and "
		"OpenTTD License tabs list every bundled library and its license. OpenTTDPad is an independent community "
		"project, not affiliated with or endorsed by OpenTTD, Transport Tycoon Deluxe or their rights holders.");
	return text;
}

static NSAttributedString *OpenTTDPadFormattedNotices(NSString *markdown)
{
	NSMutableAttributedString *result = [[[NSMutableAttributedString alloc] init] autorelease];
	NSDictionary *intro = @{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody],
		NSForegroundColorAttributeName: UIColor.labelColor};
	NSDictionary *heading = @{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
		NSForegroundColorAttributeName: UIColor.labelColor};
	NSDictionary *detail = @{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline],
		NSForegroundColorAttributeName: UIColor.secondaryLabelColor};
	NSDictionary *footnote = @{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote],
		NSForegroundColorAttributeName: UIColor.secondaryLabelColor};
	[result appendAttributedString:[[[NSAttributedString alloc]
		initWithString:@"OpenTTDPad is an independent iPad port based on OpenTTD 15.3.\n\nIncluded components\n\n"
		attributes:intro] autorelease]];

	NSCharacterSet *spaces = NSCharacterSet.whitespaceAndNewlineCharacterSet;
	for (NSString *line in [markdown componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
		if (![line hasPrefix:@"|"]) continue;
		NSArray<NSString *> *cells = [line componentsSeparatedByString:@"|"];
		if (cells.count < 6) continue;
		NSString *component = [cells[1] stringByTrimmingCharactersInSet:spaces];
		if ([component isEqualToString:@"Component"] || [component hasPrefix:@"---"]) continue;
		NSString *version = [[cells[2] stringByTrimmingCharactersInSet:spaces]
			stringByReplacingOccurrencesOfString:@"`" withString:@""];
		NSString *role = [[cells[3] stringByTrimmingCharactersInSet:spaces]
			stringByReplacingOccurrencesOfString:@"`" withString:@""];
		NSString *license = [[cells[4] stringByTrimmingCharactersInSet:spaces]
			stringByReplacingOccurrencesOfString:@"`" withString:@""];
		[result appendAttributedString:[[[NSAttributedString alloc]
			initWithString:[NSString stringWithFormat:@"%@ %@\n", component, version] attributes:heading] autorelease]];
		[result appendAttributedString:[[[NSAttributedString alloc]
			initWithString:[NSString stringWithFormat:@"%@\nLicense: %@\n\n", role, license] attributes:detail] autorelease]];
	}
	[result appendAttributedString:[[[NSAttributedString alloc] initWithString:
		@"Exact license texts and corresponding source references are included in the app bundle. OpenTTDPad is not an official OpenTTD project or release."
		attributes:footnote] autorelease]];
	return result;
}

static NSAttributedString *OpenTTDPadFormattedMarkdown(NSString *markdown)
{
	NSAttributedStringMarkdownParsingOptions *options = [[[NSAttributedStringMarkdownParsingOptions alloc] init] autorelease];
	options.interpretedSyntax = NSAttributedStringMarkdownInterpretedSyntaxFull;
	NSAttributedString *parsed = [[[NSAttributedString alloc] initWithMarkdownString:markdown
		options:options baseURL:nil error:nil] autorelease];
	if (parsed == nil) {
		return [[[NSAttributedString alloc] initWithString:markdown attributes:@{
			NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody],
			NSForegroundColorAttributeName: UIColor.labelColor,
		}] autorelease];
	}

	NSMutableAttributedString *styled = [[parsed mutableCopy] autorelease];
	const NSRange full_range = NSMakeRange(0, styled.length);
	[styled addAttribute:NSForegroundColorAttributeName value:UIColor.labelColor range:full_range];
	[styled enumerateAttribute:NSFontAttributeName inRange:full_range options:0
		usingBlock:^(id value, NSRange range, __unused BOOL *stop) {
			if (value == nil) {
				[styled addAttribute:NSFontAttributeName
					value:[UIFont preferredFontForTextStyle:UIFontTextStyleBody] range:range];
			}
		}];
	return styled;
}

@interface OpenTTDPadDocumentManager : NSObject <UIDocumentPickerDelegate>
+ (instancetype)shared;
- (void)showOptions;
- (void)showImport;
- (void)showExport;
- (void)showTouchSettings;
- (void)showNotices;
- (void)dismissPresented;
- (void)responseChanged:(UISegmentedControl *)sender;
- (void)holdChanged:(UISegmentedControl *)sender;
- (void)expandedTargetsChanged:(UISwitch *)sender;
- (void)momentumChanged:(UISwitch *)sender;
- (void)controlsSideChanged:(UISegmentedControl *)sender;
- (void)hapticsChanged:(UISwitch *)sender;
- (void)resetTouchTips;
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
	if ([presenter isKindOfClass:UIAlertController.class] && [presenter.title isEqualToString:@"OpenTTDPad"]) {
		[presenter dismissViewControllerAnimated:YES completion:nil];
		return;
	}
	OpenTTDPadOptionsButton.accessibilityLabel = @"OpenTTDPad options";
	UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"OpenTTDPad"
		message:@"Files, touch controls, and project information" preferredStyle:UIAlertControllerStyleActionSheet];
	[menu addAction:[UIAlertAction actionWithTitle:@"Import Save or Content" style:UIAlertActionStyleDefault
		handler:^(__unused UIAlertAction *action) { [self showImport]; }]];
	[menu addAction:[UIAlertAction actionWithTitle:@"Export All Saves" style:UIAlertActionStyleDefault
		handler:^(__unused UIAlertAction *action) { [self showExport]; }]];
	[menu addAction:[UIAlertAction actionWithTitle:@"Touch Controls" style:UIAlertActionStyleDefault
		handler:^(__unused UIAlertAction *action) { [self showTouchSettings]; }]];
	[menu addAction:[UIAlertAction actionWithTitle:@"About OpenTTDPad" style:UIAlertActionStyleDefault
		handler:^(__unused UIAlertAction *action) { [self showNotices]; }]];
	[menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
	OpenTTDPadAnchorPopover(menu);
	menu.popoverPresentationController.passthroughViews = @[OpenTTDPadOptionsButton];
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
			OpenTTDPadAnchorPopover(share);
			[OpenTTDPadPresenter() presentViewController:share animated:YES completion:nil];
			[share release];
		});
	});
}

- (void)showTouchSettings
{
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	[defaults registerDefaults:@{@"OpenTTDPadGestureResponse": @1, @"OpenTTDPadLongPressMS": @500,
		@"OpenTTDPadExpandedTargets": @YES, @"OpenTTDPadMomentum": @YES,
		@"OpenTTDPadControlsLeftHanded": @NO, @"OpenTTDPadHaptics": @YES}];
	UIViewController *controller = [[UIViewController alloc] init];
	controller.title = @"Touch Controls";
	controller.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
	controller.preferredContentSize = CGSizeMake(520, 570);

	UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:CGRectZero];
	scroll.translatesAutoresizingMaskIntoConstraints = NO;
	UIStackView *stack = [[UIStackView alloc] initWithFrame:CGRectZero];
	stack.translatesAutoresizingMaskIntoConstraints = NO;
	stack.axis = UILayoutConstraintAxisVertical;
	stack.spacing = 10;
	[scroll addSubview:stack];
	[controller.view addSubview:scroll];

	void (^addSection)(NSString *) = ^(NSString *title) {
		UILabel *label = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
		label.text = title.uppercaseString;
		label.textColor = UIColor.secondaryLabelColor;
		label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
		[stack addArrangedSubview:label];
	};
	void (^addRow)(NSString *, UIView *) = ^(NSString *title, UIView *control) {
		UIStackView *row = [[[UIStackView alloc] initWithFrame:CGRectZero] autorelease];
		row.axis = UILayoutConstraintAxisHorizontal;
		row.alignment = UIStackViewAlignmentCenter;
		row.spacing = 14;
		row.layoutMargins = UIEdgeInsetsMake(10, 14, 10, 14);
		row.layoutMarginsRelativeArrangement = YES;
		row.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
		row.layer.cornerRadius = 12;
		UILabel *label = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
		label.text = title;
		label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
		[label setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
		[row addArrangedSubview:label];
		[row addArrangedSubview:control];
		[[row.heightAnchor constraintGreaterThanOrEqualToConstant:52] setActive:YES];
		[stack addArrangedSubview:row];
	};

	UILabel *explanation = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
	explanation.text = @"One finger taps and builds. Two fingers move and zoom the map.";
	explanation.numberOfLines = 0;
	explanation.textColor = UIColor.secondaryLabelColor;
	explanation.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
	[stack addArrangedSubview:explanation];

	addSection(@"Gestures");
	UISegmentedControl *response = [[[UISegmentedControl alloc] initWithItems:@[@"Relaxed", @"Balanced", @"Quick"]] autorelease];
	response.selectedSegmentIndex = std::clamp<NSInteger>([defaults integerForKey:@"OpenTTDPadGestureResponse"], 0, 2);
	response.accessibilityLabel = @"Gesture response";
	[response addTarget:self action:@selector(responseChanged:) forControlEvents:UIControlEventValueChanged];
	addRow(@"Response", response);

	UISegmentedControl *hold = [[[UISegmentedControl alloc] initWithItems:@[@"0.35s", @"0.50s", @"0.70s"]] autorelease];
	const NSInteger hold_ms = [defaults integerForKey:@"OpenTTDPadLongPressMS"];
	hold.selectedSegmentIndex = hold_ms <= 350 ? 0 : hold_ms >= 700 ? 2 : 1;
	hold.accessibilityLabel = @"Precision hold";
	[hold addTarget:self action:@selector(holdChanged:) forControlEvents:UIControlEventValueChanged];
	addRow(@"Precision hold", hold);

	UISwitch *momentum = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
	momentum.on = [defaults boolForKey:@"OpenTTDPadMomentum"];
	momentum.accessibilityLabel = @"Map glide";
	[momentum addTarget:self action:@selector(momentumChanged:) forControlEvents:UIControlEventValueChanged];
	addRow(@"Glide after pan", momentum);

	addSection(@"Interface");
	UISwitch *expanded = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
	expanded.on = [defaults boolForKey:@"OpenTTDPadExpandedTargets"];
	expanded.accessibilityLabel = @"Enlarged controls";
	[expanded addTarget:self action:@selector(expandedTargetsChanged:) forControlEvents:UIControlEventValueChanged];
	addRow(@"Larger tap targets", expanded);

	UISegmentedControl *side = [[[UISegmentedControl alloc] initWithItems:@[@"Left", @"Right"]] autorelease];
	side.selectedSegmentIndex = [defaults boolForKey:@"OpenTTDPadControlsLeftHanded"] ? 0 : 1;
	side.accessibilityLabel = @"Controls side";
	[side addTarget:self action:@selector(controlsSideChanged:) forControlEvents:UIControlEventValueChanged];
	addRow(@"Controls side", side);

	UISwitch *haptics = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
	haptics.on = [defaults boolForKey:@"OpenTTDPadHaptics"];
	haptics.accessibilityLabel = @"Haptics";
	[haptics addTarget:self action:@selector(hapticsChanged:) forControlEvents:UIControlEventValueChanged];
	addRow(@"Haptic feedback", haptics);

	UIButton *tips = [UIButton buttonWithType:UIButtonTypeSystem];
	[tips setTitle:@"Show Touch Tips Again" forState:UIControlStateNormal];
	tips.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
	[tips addTarget:self action:@selector(resetTouchTips) forControlEvents:UIControlEventTouchUpInside];
	addRow(@"Help", tips);

	[NSLayoutConstraint activateConstraints:@[
		[scroll.leadingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.leadingAnchor],
		[scroll.trailingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.trailingAnchor],
		[scroll.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor],
		[scroll.bottomAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.bottomAnchor],
		[stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20],
		[stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20],
		[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
		[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-20],
		[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40],
	]];
	controller.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
		target:self action:@selector(dismissPresented)];
	UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:controller];
	navigation.modalPresentationStyle = UIModalPresentationFormSheet;
	[OpenTTDPadPresenter() presentViewController:navigation animated:YES completion:nil];
	[scroll release]; [stack release]; [controller.navigationItem.rightBarButtonItem release];
	[controller release]; [navigation release];
}

- (void)responseChanged:(UISegmentedControl *)sender
{
	[NSUserDefaults.standardUserDefaults setInteger:sender.selectedSegmentIndex forKey:@"OpenTTDPadGestureResponse"];
	OpenTTDPadSettingsGeneration++;
}

- (void)holdChanged:(UISegmentedControl *)sender
{
	const NSInteger values[] = {350, 500, 700};
	[NSUserDefaults.standardUserDefaults setInteger:values[std::clamp<NSInteger>(sender.selectedSegmentIndex, 0, 2)]
		forKey:@"OpenTTDPadLongPressMS"];
	OpenTTDPadSettingsGeneration++;
}

- (void)expandedTargetsChanged:(UISwitch *)sender
{
	[NSUserDefaults.standardUserDefaults setBool:sender.isOn forKey:@"OpenTTDPadExpandedTargets"];
	OpenTTDPadSettingsGeneration++;
}

- (void)momentumChanged:(UISwitch *)sender
{
	[NSUserDefaults.standardUserDefaults setBool:sender.isOn forKey:@"OpenTTDPadMomentum"];
	OpenTTDPadSettingsGeneration++;
}

- (void)controlsSideChanged:(UISegmentedControl *)sender
{
	[NSUserDefaults.standardUserDefaults setBool:sender.selectedSegmentIndex == 0 forKey:@"OpenTTDPadControlsLeftHanded"];
	OpenTTDPadRefreshControlPlacement();
}

- (void)hapticsChanged:(UISwitch *)sender
{
	[NSUserDefaults.standardUserDefaults setBool:sender.isOn forKey:@"OpenTTDPadHaptics"];
}

- (void)resetTouchTips
{
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	[defaults setBool:NO forKey:@"OpenTTDPadTouchHintSeen"];
	[defaults setBool:NO forKey:@"OpenTTDPadToolHintSeen"];
	OpenTTDPadPresentMessage(@"Touch Tips Reset", @"The touch coach will appear the next time the app starts a game.");
}

- (void)showNotices
{
	NSString *notices_path = [NSBundle.mainBundle pathForResource:@"THIRD_PARTY_NOTICES" ofType:@"md" inDirectory:@"docs"];
	NSString *copying_path = [NSBundle.mainBundle pathForResource:@"COPYING-OpenTTD" ofType:@"md" inDirectory:@"docs"];
	NSString *notices = [NSString stringWithContentsOfFile:notices_path encoding:NSUTF8StringEncoding error:nil] ?: @"";
	NSString *copying = [NSString stringWithContentsOfFile:copying_path encoding:NSUTF8StringEncoding error:nil] ?: @"";
	UIViewController *controller = [[UIViewController alloc] init];
	controller.title = @"About OpenTTDPad";
	controller.view.backgroundColor = UIColor.systemBackgroundColor;
	controller.preferredContentSize = CGSizeMake(620, 620);
	UISegmentedControl *section = [[UISegmentedControl alloc] initWithItems:@[@"About", @"Components", @"OpenTTD License"]];
	section.translatesAutoresizingMaskIntoConstraints = NO;
	section.selectedSegmentIndex = 0;
	section.accessibilityLabel = @"License section";
	UITextView *text = [[UITextView alloc] initWithFrame:CGRectZero];
	text.translatesAutoresizingMaskIntoConstraints = NO;
	text.editable = NO;
	text.selectable = YES;
	text.adjustsFontForContentSizeCategory = YES;
	text.attributedText = OpenTTDPadAboutText();
	text.textContainerInset = UIEdgeInsetsMake(18, 18, 24, 18);
	text.accessibilityLabel = @"OpenTTDPad licenses and credits";
	[section addAction:[UIAction actionWithHandler:^(UIAction *action) {
		UISegmentedControl *control = (UISegmentedControl *)action.sender;
		if (control.selectedSegmentIndex == 0) {
			text.attributedText = OpenTTDPadAboutText();
		} else if (control.selectedSegmentIndex == 1) {
			text.attributedText = OpenTTDPadFormattedNotices(notices);
		} else {
			text.attributedText = OpenTTDPadFormattedMarkdown(copying);
		}
		[text setContentOffset:CGPointZero animated:NO];
	}] forControlEvents:UIControlEventValueChanged];
	[controller.view addSubview:section];
	[controller.view addSubview:text];
	[NSLayoutConstraint activateConstraints:@[
		[text.leadingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.leadingAnchor constant:16],
		[text.trailingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
		[section.leadingAnchor constraintEqualToAnchor:text.leadingAnchor],
		[section.trailingAnchor constraintEqualToAnchor:text.trailingAnchor],
		[section.topAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.topAnchor constant:12],
		[text.topAnchor constraintEqualToAnchor:section.bottomAnchor constant:10],
		[text.bottomAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.bottomAnchor],
	]];
	controller.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
		target:self action:@selector(dismissPresented)];
	UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:controller];
	navigation.modalPresentationStyle = UIModalPresentationFormSheet;
	[OpenTTDPadPresenter() presentViewController:navigation animated:YES completion:nil];
	[section release]; [text release]; [controller.navigationItem.rightBarButtonItem release];
	[controller release]; [navigation release];
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
		if (OpenTTDPadOptionsButton != nil && OpenTTDPadOptionsButton.window == window) {
			OpenTTDPadPositionOptionsButton(window);
			return;
		}
		[OpenTTDPadOptionsButton removeFromSuperview];
		[OpenTTDPadOptionsButton release];
		OpenTTDPadOptionsButton = [[UIButton buttonWithType:UIButtonTypeSystem] retain];
		const CGFloat scale = OpenTTDPadOverlayCoordinateScale(window);
		OpenTTDPadOptionsButton.frame = CGRectMake(0, 0, 44.0 * scale, 44.0 * scale);
		OpenTTDPadOptionsButton.layer.cornerRadius = 13.0 * scale;
		OpenTTDPadOptionsButton.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.88];
		OpenTTDPadOptionsButton.layer.borderWidth = scale;
		OpenTTDPadOptionsButton.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.24].CGColor;
		UIImageSymbolConfiguration *symbol = [UIImageSymbolConfiguration configurationWithPointSize:17.0 * scale
			weight:UIImageSymbolWeightSemibold];
		[OpenTTDPadOptionsButton setImage:[[UIImage systemImageNamed:@"ellipsis"] imageWithConfiguration:symbol]
			forState:UIControlStateNormal];
		OpenTTDPadOptionsButton.tintColor = UIColor.whiteColor;
		OpenTTDPadOptionsButton.accessibilityLabel = @"OpenTTDPad options";
		[OpenTTDPadOptionsButton addTarget:[OpenTTDPadDocumentManager shared] action:@selector(showOptions)
			forControlEvents:UIControlEventTouchUpInside];
		[window addSubview:OpenTTDPadOptionsButton];
		OpenTTDPadPositionOptionsButton(window);
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
		@"OpenTTDPadExpandedTargets": @YES, @"OpenTTDPadMomentum": @YES,
		@"OpenTTDPadControlsLeftHanded": @NO, @"OpenTTDPadHaptics": @YES}];
	const NSInteger response = std::clamp<NSInteger>([defaults integerForKey:@"OpenTTDPadGestureResponse"], 0, 2);
	if (threshold_scale != nullptr) *threshold_scale = response == 0 ? 1.25 : response == 2 ? 0.75 : 1.0;
	if (long_press_ms != nullptr) *long_press_ms = static_cast<uint32_t>([defaults integerForKey:@"OpenTTDPadLongPressMS"]);
	if (expanded_targets != nullptr) *expanded_targets = [defaults boolForKey:@"OpenTTDPadExpandedTargets"];
	if (momentum != nullptr) *momentum = [defaults boolForKey:@"OpenTTDPadMomentum"];
}

extern "C" bool OpenTTDPadControlsLeftHanded()
{
	NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
	[defaults registerDefaults:@{@"OpenTTDPadControlsLeftHanded": @NO}];
	return [defaults boolForKey:@"OpenTTDPadControlsLeftHanded"];
}
