/*
 * This file is part of OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, version 2.
 * OpenTTD is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details. You should have received a copy of the GNU General Public License along with OpenTTD. If not, see <https://www.gnu.org/licenses/old-licenses/gpl-2.0>.
 */

/** @file font_ios.mm Select a language-capable iPadOS system font for FreeType. */

#include "../../stdafx.h"
#include "../../debug.h"
#include "../../strings_func.h"
#include "font_ios.h"

#undef Point
#undef Rect
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>
#define Point OTTD_Point
#define Rect OTTD_Rect

#include "../../safeguards.h"

static std::string iOSLanguageCode(const std::string &language_isocode)
{
	if (language_isocode == "zh_TW") return "zh-Hant";
	if (language_isocode == "zh_CN") return "zh-Hans";
	return language_isocode.substr(0, language_isocode.find('_'));
}

bool iOSFindFallbackFont(FontCacheSettings *settings, const std::string &language_isocode, MissingGlyphSearcher *callback)
{
	@autoreleasepool {
		NSString *language = [NSString stringWithUTF8String:iOSLanguageCode(language_isocode).c_str()];
		NSDictionary *attributes = @{(__bridge NSString *)kCTFontLanguagesAttribute : @[language, @"en"]};
		CTFontDescriptorRef query = CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)attributes);
		const void *mandatory_values[] = {kCTFontLanguagesAttribute};
		CFSetRef mandatory = CFSetCreate(kCFAllocatorDefault, mandatory_values, 1, &kCFTypeSetCallBacks);
		CFArrayRef matches = CTFontDescriptorCreateMatchingFontDescriptors(query, mandatory);
		CFRelease(mandatory);
		CFRelease(query);

		bool result = false;
		for (int pass = 0; pass < 2 && !result; pass++) {
			for (CFIndex i = 0; matches != nullptr && i < CFArrayGetCount(matches); i++) {
				CTFontDescriptorRef descriptor = (CTFontDescriptorRef)CFArrayGetValueAtIndex(matches, i);
				NSDictionary *traits = CFBridgingRelease(CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute));
				CTFontSymbolicTraits symbolic_traits = [traits[(__bridge NSString *)kCTFontSymbolicTrait] unsignedIntValue];

				if ((symbolic_traits & kCTFontClassMaskTrait) == kCTFontSymbolicClass || (symbolic_traits & kCTFontVerticalTrait)) continue;
				if (symbolic_traits & kCTFontBoldTrait) continue;
				if (((symbolic_traits & kCTFontMonoSpaceTrait) != 0) != callback->Monospace()) continue;
				if (pass == 0 && (symbolic_traits & kCTFontClassMaskTrait) != kCTFontSansSerifClass) continue;

				NSURL *url = CFBridgingRelease(CTFontDescriptorCopyAttribute(descriptor, kCTFontURLAttribute));
				NSString *display_name = CFBridgingRelease(CTFontDescriptorCopyAttribute(descriptor, kCTFontDisplayNameAttribute));
				if (url == nil || !url.isFileURL || [display_name hasPrefix:@"."] || [display_name hasPrefix:@"LastResort"]) continue;

				std::string path(url.path.UTF8String);
				callback->SetFontNames(settings, path);
				if (!callback->FindMissingGlyphs()) {
					Debug(fontcache, 2, "iPadOS font for {}: {} ({})", language_isocode, display_name.UTF8String, path);
					result = true;
					break;
				}
			}
		}

		if (matches != nullptr) CFRelease(matches);
		callback->FindMissingGlyphs();
		return result;
	}
}
