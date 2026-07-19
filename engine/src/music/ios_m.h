/*
 * This file is part of OpenTTDPad and OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License version 2.
 */

#ifndef MUSIC_IOS_H
#define MUSIC_IOS_H

#include "music_driver.hpp"

class MusicDriver_iOS : public MusicDriver {
public:
	std::optional<std::string_view> Start(const StringList &param) override;
	void Stop() override;
	void PlaySong(const MusicSongInfo &song) override;
	void StopSong() override;
	bool IsSongPlaying() override;
	void SetVolume(uint8_t volume) override;
	std::string_view GetName() const override { return "ios"; }
};

class FMusicDriver_iOS : public DriverFactoryBase {
public:
	FMusicDriver_iOS() : DriverFactoryBase(Driver::DT_MUSIC, 10, "ios", "iPadOS Core Audio MIDI Driver") {}
	std::unique_ptr<Driver> CreateInstance() const override { return std::make_unique<MusicDriver_iOS>(); }
};

#endif /* MUSIC_IOS_H */
