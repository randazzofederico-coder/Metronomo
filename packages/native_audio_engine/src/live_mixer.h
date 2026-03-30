#ifndef LIVE_MIXER_H
#define LIVE_MIXER_H

#include <vector>
#include <map>
#include <mutex>
#include <algorithm>
#include <cstring>
#include <cmath>
#include <atomic>
#include <random>

#include "miniaudio.h"

#if defined(_WIN32)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

class LiveMixer {
public:
    LiveMixer();
    ~LiveMixer();

    // Track Management
    struct WaveformData {
        float* peakData;
        int peakDataLength;
        int channels;
        int sampleRate;
        uint64_t totalFrames;
        int error;
    };
    
    WaveformData* addTrack(const char* id, const char* filePath);
    WaveformData* addTrackMemory(const char* id, const void* data, size_t dataSize);
    WaveformData* addTrackPCM(const char* id, const float* pcmData, int totalFrames, int channels, int sampleRate);
    void removeTrack(const char* id);
    void setTrackVolume(const char* id, float volume);
    void setTrackPan(const char* id, float pan);
    void setTrackMute(const char* id, bool muted);
    void setTrackSolo(const char* id, bool solo);

    // Global Settings
    void setLoop(int64_t startSample, int64_t endSample, bool enabled);
    void seek(int64_t positionSample);
    int64_t getPosition(); 
    void setMasterVolume(float volume);
    void setMasterMute(bool muted);
    void setMasterSolo(bool solo);
    
    // --- NATIVE OUTPUT CONTROL ---
    void startPlayback();
    void stopPlayback();
    int64_t getAtomicPosition(); // Returns frames played (hardware compensated)
    
    void setSpeed(float speed);
    void setSoundTouchSetting(int settingId, int value);

    // --- METRONOME ---
    void setMetronomeConfig(int bpm);
    void setMetronomeSound(int type, const float* data, int numSamples);
    void setMetronomeVolume(float vol34, float vol68); // keeping for backward compat if needed, or remove? Let's remove
    // New dynamic metronome API
    void addMetronomePattern(int id, const int* flatPatternData, const int* subdivisionsData, const double* durationRatios, int numPulses, float vol, bool mute, bool solo);
    void updateMetronomePattern(int id, const int* flatPatternData, const int* subdivisionsData, const double* durationRatios, int numPulses, float vol, bool mute, bool solo);
    void removeMetronomePattern(int id);
    void clearMetronomePatterns();
    void setMetronomePreviewMode(bool enabled);
    void setRandomSilencePercent(float percent);
    // Audio Processing
    // mix into outputBuffer (interleaved stereo)
    // returns number of frames filled (should match numFrames unless EOS and not looping)
    int process(float* outputBuffer, int numFrames);

private:
   struct Track {
       std::vector<float> data;
       int channels;
       float volume = 1.0f;
       float pan = 0.0f;
       bool muted = false;
       bool solo = false;
       float envelope = 1.0f;
   };

   std::map<std::string, Track*> _tracks;
   std::mutex _mutex;

   int64_t _currentPosition = 0;
   bool _isPlaying = false;
   
   // Loop
   bool _loopEnabled = false;
   int64_t _loopStart = 0;
   int64_t _loopEnd = 0;

   // Envelopes for click-prevention
   float _masterEnvelope = 1.0f;
   float _targetEnvelope = 1.0f;
   float _masterStemEnv = 1.0f;
   
   // Master Volume
   float _masterVolume = 1.0f;
   
   // Internal mixing logic (raw, no speed)
   void _mixInternal(float* outputBuffer, int numFrames);

   // Metronome state
   int _bpm = 0;
   int _lastEighth = -1;
   bool _metronomePreviewMode = false;
   float _randomSilencePercent = 0.0f;
   std::mt19937 _rng{std::random_device{}()};

   struct MetronomePulse {
       std::vector<int> subdivisions;
       double durationRatio = 1.0;
   };

   struct MetronomeTrack {
       int id;
       float volume = 0.0f;
       bool muted = false;
       bool solo = false;
       std::vector<MetronomePulse> pulses;
   };
   std::vector<MetronomeTrack> _metronomeTracks;

   // Track parsing helper for flat FFI arrays
   void _parseFlatPattern(MetronomeTrack& track, const int* flatData, const int* subdivisions, const double* durationRatios, int numPulses);

   struct MetronomeVoice {
       std::vector<float> data;
       int currentPointer = -1;
       float currentVolume = 0.0f;
   };
   MetronomeVoice _clickHigh; // type 0
   MetronomeVoice _clickLow;  // type 1
   MetronomeVoice _clickNoise;// type 2

   // Solo logic helper
   bool _anyTrackSolo = false; // Renamed from _anySolo
   bool _masterMuted = false;
   bool _masterSolo = false;
   
   // STEM Solo tracking
   bool _anyStemSolo = false; // Added
   // _globalAnySolo removed

   void _updateAnySolo();
   void _updateGlobalSolo();
   
   // Track length logic
   int64_t _maxTrackSamples = 0;
   void _updateMaxTrackSamples();
   
   // --- MINIAUDIO ---
   ma_device _device;
   bool _deviceInit = false;
   std::atomic<int64_t> _atomicFramesWritten{0};
   
   // --- SOUNDTOUCH ---
   void* _soundTouch = nullptr; 
   
   float _speed = 1.0f;
   std::vector<float> _mixBuffer; // Intermediate buffer for mixing before SoundTouch

   static void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount);
};

extern "C" {
    EXPORT void live_mixer_set_soundtouch_setting(void* mixer, int settingId, int value);
    
    EXPORT void live_mixer_set_master_mute(void* mixer, bool muted);
    EXPORT void live_mixer_set_master_solo(void* mixer, bool solo);

    EXPORT void live_mixer_set_metronome_config(void* mixer, int bpm);
    EXPORT void live_mixer_set_metronome_sound(void* mixer, int type, const float* data, int numSamples);
    EXPORT void live_mixer_add_metronome_pattern(void* mixer, int id, const int* flatPatternData, const int* subdivisionsData, const double* durationRatios, int numPulses, float vol, bool mute, bool solo);
    EXPORT void live_mixer_update_metronome_pattern(void* mixer, int id, const int* flatPatternData, const int* subdivisionsData, const double* durationRatios, int numPulses, float vol, bool mute, bool solo);
    EXPORT void live_mixer_remove_metronome_pattern(void* mixer, int id);
    EXPORT void live_mixer_clear_metronome_patterns(void* mixer);
    EXPORT void live_mixer_set_metronome_preview_mode(void* mixer, bool enabled);
    EXPORT void live_mixer_set_random_silence_percent(void* mixer, float percent);

    // --- ZERO-COPY AND DECODER ---
    EXPORT LiveMixer::WaveformData* live_mixer_add_track(void* mixer, const char* id, const char* filePath);
    EXPORT LiveMixer::WaveformData* live_mixer_add_track_memory(void* mixer, const char* id, const void* data, size_t dataSize);
    EXPORT void live_mixer_free_waveform_data(LiveMixer::WaveformData* data);
    
    EXPORT int live_mixer_render_offline(void* mixer, const char* outPath);
}

#endif // LIVE_MIXER_H
