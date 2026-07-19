/*
 * This file is part of OpenTTDPad and OpenTTD.
 * OpenTTD is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License version 2.
 */

/** @file ios_m.mm iPadOS MIDI playback through Core Audio and a bundled GPLv2 sound bank. */

#include "../stdafx.h"
#include "ios_m.h"
#include "midifile.hpp"
#include "../debug.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>

#include "../safeguards.h"

static FMusicDriver_iOS iFMusicDriver_iOS;
static MusicPlayer OpenTTDPadMusicPlayer;
static MusicSequence OpenTTDPadMusicSequence;
static MusicTimeStamp OpenTTDPadSequenceLength;
static AUGraph OpenTTDPadMusicGraph;
static AudioUnit OpenTTDPadMixerUnit;
static bool OpenTTDPadMusicPlaying;
static uint8_t OpenTTDPadMusicVolume = 127;

static void OpenTTDPadApplyMusicVolume()
{
	if (OpenTTDPadMixerUnit == nullptr) return;
	const AudioUnitParameterValue gain = static_cast<AudioUnitParameterValue>(OpenTTDPadMusicVolume) / 127.0F;
	const OSStatus status = AudioUnitSetParameter(OpenTTDPadMixerUnit, kMultiChannelMixerParam_Volume,
		kAudioUnitScope_Output, 0, gain, 0);
	if (status != noErr) Debug(driver, 1, "ios_m: could not set mixer volume ({})", status);
}

static void OpenTTDPadDisposeMusicGraph()
{
	if (OpenTTDPadMusicGraph != nullptr) {
		AUGraphStop(OpenTTDPadMusicGraph);
		DisposeAUGraph(OpenTTDPadMusicGraph);
	}
	OpenTTDPadMusicGraph = nullptr;
	OpenTTDPadMixerUnit = nullptr;
}

static std::optional<std::string_view> OpenTTDPadCreateMusicGraph()
{
	if (NewAUGraph(&OpenTTDPadMusicGraph) != noErr) return "failed to create Core Audio graph";

	AudioComponentDescription synth_description{};
	synth_description.componentType = kAudioUnitType_MusicDevice;
	synth_description.componentSubType = kAudioUnitSubType_MIDISynth;
	synth_description.componentManufacturer = kAudioUnitManufacturer_Apple;

	AudioComponentDescription mixer_description{};
	mixer_description.componentType = kAudioUnitType_Mixer;
	mixer_description.componentSubType = kAudioUnitSubType_MultiChannelMixer;
	mixer_description.componentManufacturer = kAudioUnitManufacturer_Apple;

	AudioComponentDescription output_description{};
	output_description.componentType = kAudioUnitType_Output;
	output_description.componentSubType = kAudioUnitSubType_RemoteIO;
	output_description.componentManufacturer = kAudioUnitManufacturer_Apple;

	AUNode synth_node = 0;
	AUNode mixer_node = 0;
	AUNode output_node = 0;
	AudioUnit synth_unit = nullptr;
	if (AUGraphAddNode(OpenTTDPadMusicGraph, &synth_description, &synth_node) != noErr ||
			AUGraphAddNode(OpenTTDPadMusicGraph, &mixer_description, &mixer_node) != noErr ||
			AUGraphAddNode(OpenTTDPadMusicGraph, &output_description, &output_node) != noErr ||
			AUGraphConnectNodeInput(OpenTTDPadMusicGraph, synth_node, 0, mixer_node, 0) != noErr ||
			AUGraphConnectNodeInput(OpenTTDPadMusicGraph, mixer_node, 0, output_node, 0) != noErr ||
			AUGraphOpen(OpenTTDPadMusicGraph) != noErr ||
			AUGraphNodeInfo(OpenTTDPadMusicGraph, synth_node, nullptr, &synth_unit) != noErr || synth_unit == nullptr ||
			AUGraphNodeInfo(OpenTTDPadMusicGraph, mixer_node, nullptr, &OpenTTDPadMixerUnit) != noErr || OpenTTDPadMixerUnit == nullptr) {
		OpenTTDPadDisposeMusicGraph();
		return "failed to configure Core Audio graph";
	}

	NSString *bank_path = [NSBundle.mainBundle pathForResource:@"TimGM6mb" ofType:@"sf2" inDirectory:@"soundfonts"];
	if (bank_path == nil) {
		OpenTTDPadDisposeMusicGraph();
		return "bundled TimGM6mb sound bank not found";
	}
	NSURL *bank_url = [NSURL fileURLWithPath:bank_path];
	CFURLRef value = (__bridge CFURLRef)bank_url;
	const OSStatus bank_status = AudioUnitSetProperty(synth_unit, kMusicDeviceProperty_SoundBankURL,
		kAudioUnitScope_Global, 0, &value, sizeof(value));
	if (bank_status != noErr) {
		Debug(driver, 0, "ios_m: failed to load TimGM6mb sound bank ({})", bank_status);
		OpenTTDPadDisposeMusicGraph();
		return "failed to load bundled TimGM6mb sound bank";
	}

	OpenTTDPadApplyMusicVolume();
	if (AUGraphInitialize(OpenTTDPadMusicGraph) != noErr || AUGraphStart(OpenTTDPadMusicGraph) != noErr) {
		OpenTTDPadDisposeMusicGraph();
		return "failed to start Core Audio graph";
	}
	return std::nullopt;
}

std::optional<std::string_view> MusicDriver_iOS::Start(const StringList &)
{
	NSError *error = nil;
	AVAudioSession *session = AVAudioSession.sharedInstance;
	if (![session setCategory:AVAudioSessionCategoryAmbient mode:AVAudioSessionModeDefault options:AVAudioSessionCategoryOptionMixWithOthers error:&error]) {
		Debug(driver, 1, "ios_m: audio session category failed: {}", error.localizedDescription.UTF8String);
	}
	if (![session setActive:YES error:&error]) {
		Debug(driver, 1, "ios_m: audio session activation failed: {}", error.localizedDescription.UTF8String);
	}
	if (NewMusicPlayer(&OpenTTDPadMusicPlayer) != noErr) return "failed to create Core Audio music player";
	if (auto graph_error = OpenTTDPadCreateMusicGraph(); graph_error.has_value()) {
		DisposeMusicPlayer(OpenTTDPadMusicPlayer);
		OpenTTDPadMusicPlayer = nullptr;
		return graph_error;
	}
	Debug(driver, 2, "ios_m: TimGM6mb GM synthesizer ready");
	return std::nullopt;
}

void MusicDriver_iOS::Stop()
{
	this->StopSong();
	if (OpenTTDPadMusicSequence != nullptr) DisposeMusicSequence(OpenTTDPadMusicSequence);
	if (OpenTTDPadMusicPlayer != nullptr) DisposeMusicPlayer(OpenTTDPadMusicPlayer);
	OpenTTDPadMusicSequence = nullptr;
	OpenTTDPadMusicPlayer = nullptr;
	OpenTTDPadDisposeMusicGraph();
}

bool MusicDriver_iOS::IsSongPlaying()
{
	if (!OpenTTDPadMusicPlaying) return false;
	MusicTimeStamp time = 0;
	if (MusicPlayerGetTime(OpenTTDPadMusicPlayer, &time) != noErr || time >= OpenTTDPadSequenceLength) {
		OpenTTDPadMusicPlaying = false;
	}
	return OpenTTDPadMusicPlaying;
}

void MusicDriver_iOS::PlaySong(const MusicSongInfo &song)
{
	const std::string filename = MidiFile::GetSMFFile(song);
	this->StopSong();
	if (OpenTTDPadMusicSequence != nullptr) {
		DisposeMusicSequence(OpenTTDPadMusicSequence);
		OpenTTDPadMusicSequence = nullptr;
	}
	if (filename.empty() || NewMusicSequence(&OpenTTDPadMusicSequence) != noErr) return;

	NSURL *midi_url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:filename.c_str()]];
	if (MusicSequenceFileLoad(OpenTTDPadMusicSequence, (__bridge CFURLRef)midi_url, kMusicSequenceFile_AnyType, 0) != noErr) {
		Debug(driver, 0, "ios_m: failed to load MIDI '{}'", filename);
		return;
	}
	if (MusicSequenceSetAUGraph(OpenTTDPadMusicSequence, OpenTTDPadMusicGraph) != noErr) {
		Debug(driver, 0, "ios_m: failed to attach the iPadOS MIDI graph");
		return;
	}

	UInt32 track_count = 0;
	MusicSequenceGetTrackCount(OpenTTDPadMusicSequence, &track_count);
	OpenTTDPadSequenceLength = 0;
	for (UInt32 index = 0; index < track_count; index++) {
		MusicTrack track = nullptr;
		MusicTimeStamp length = 0;
		UInt32 size = sizeof(length);
		MusicSequenceGetIndTrack(OpenTTDPadMusicSequence, index, &track);
		MusicTrackGetProperty(track, kSequenceTrackProperty_TrackLength, &length, &size);
		OpenTTDPadSequenceLength = std::max(OpenTTDPadSequenceLength, length);
	}
	OpenTTDPadSequenceLength += 8;
	MusicPlayerSetSequence(OpenTTDPadMusicPlayer, OpenTTDPadMusicSequence);
	MusicPlayerPreroll(OpenTTDPadMusicPlayer);
	if (MusicPlayerStart(OpenTTDPadMusicPlayer) == noErr) {
		OpenTTDPadMusicPlaying = true;
		Debug(driver, 2, "ios_m: playing '{}'", filename);
	}
}

void MusicDriver_iOS::StopSong()
{
	if (OpenTTDPadMusicPlayer != nullptr) {
		MusicPlayerStop(OpenTTDPadMusicPlayer);
		MusicPlayerSetSequence(OpenTTDPadMusicPlayer, nullptr);
	}
	OpenTTDPadMusicPlaying = false;
}

void MusicDriver_iOS::SetVolume(uint8_t volume)
{
	OpenTTDPadMusicVolume = volume;
	OpenTTDPadApplyMusicVolume();
}
