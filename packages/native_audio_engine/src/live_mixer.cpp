#include <iostream>

#define MINIAUDIO_IMPLEMENTATION
#include "live_mixer.h"
#include "soundtouch_wrapper.h"

#ifdef _WIN32
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <mferror.h>
#include <ks.h>
#include <ksmedia.h>

static bool decodeAudioMF(const char* filePath, std::vector<float>& pcmData, int& channels, int& sampleRate, uint64_t& totalFrames) {
    bool coInit = false;
    HRESULT hr = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    if (SUCCEEDED(hr)) coInit = true;
    
    hr = MFStartup(MF_VERSION);
    if (FAILED(hr)) {
        if (coInit) CoUninitialize();
        return false;
    }

    bool success = false;
    IMFSourceReader* pReader = nullptr;
    IMFMediaType* pAudioType = nullptr;
    
    // Convert filePath to wide string
    int wlen = MultiByteToWideChar(CP_UTF8, 0, filePath, -1, NULL, 0);
    wchar_t* wFilePath = new wchar_t[wlen];
    MultiByteToWideChar(CP_UTF8, 0, filePath, -1, wFilePath, wlen);

    hr = MFCreateSourceReaderFromURL(wFilePath, NULL, &pReader);
    delete[] wFilePath;

    if (SUCCEEDED(hr)) {
        hr = MFCreateMediaType(&pAudioType);
    }
    if (SUCCEEDED(hr)) {
        pAudioType->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Audio);
        pAudioType->SetGUID(MF_MT_SUBTYPE, MFAudioFormat_Float);
        hr = pReader->SetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, NULL, pAudioType);
    }
    
    IMFMediaType* pOutputType = nullptr;
    if (SUCCEEDED(hr)) {
        hr = pReader->GetCurrentMediaType((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, &pOutputType);
    }
    
    if (SUCCEEDED(hr)) {
        UINT32 mfChannels = 0;
        UINT32 mfSampleRate = 0;
        pOutputType->GetUINT32(MF_MT_AUDIO_NUM_CHANNELS, &mfChannels);
        pOutputType->GetUINT32(MF_MT_AUDIO_SAMPLES_PER_SECOND, &mfSampleRate);
        channels = (int)mfChannels;
        sampleRate = (int)mfSampleRate;
        
        while (true) {
            IMFSample* pSample = nullptr;
            DWORD flags = 0;
            hr = pReader->ReadSample((DWORD)MF_SOURCE_READER_FIRST_AUDIO_STREAM, 0, NULL, &flags, NULL, &pSample);
            
            if (FAILED(hr) || (flags & MF_SOURCE_READERF_ENDOFSTREAM)) {
                break;
            }
            if (pSample) {
                IMFMediaBuffer* pBuffer = nullptr;
                hr = pSample->ConvertToContiguousBuffer(&pBuffer);
                if (SUCCEEDED(hr)) {
                    BYTE* pData = nullptr;
                    DWORD cbData = 0;
                    hr = pBuffer->Lock(&pData, NULL, &cbData);
                    if (SUCCEEDED(hr)) {
                        int numFloats = cbData / sizeof(float);
                        float* fData = (float*)pData;
                        pcmData.insert(pcmData.end(), fData, fData + numFloats);
                        pBuffer->Unlock();
                    }
                    pBuffer->Release();
                }
                pSample->Release();
            }
        }
        
        if (pcmData.size() > 0) {
            totalFrames = pcmData.size() / channels;
            success = true;
        }
    }
    
    if (pOutputType) pOutputType->Release();
    if (pAudioType) pAudioType->Release();
    if (pReader) pReader->Release();
    
    MFShutdown();
    if (coInit) CoUninitialize();
    
    return success;
}
#endif

using namespace std;

// Forward declaration of callback wrapper
void data_callback_wrapper(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    auto mixer = static_cast<LiveMixer*>(pDevice->pUserData);
    if (mixer) {
        mixer->process(static_cast<float*>(pOutput), frameCount);
    }
}

LiveMixer::LiveMixer() {
    // Initialize SoundTouch
    _soundTouch = soundtouch_create();
    soundtouch_setSampleRate(_soundTouch, 44100);
    soundtouch_setChannels(_soundTouch, 2);
    soundtouch_setTempo(_soundTouch, 1.0f);
    
    _mixBuffer.resize(1024 * 2); // default capacity

    // initialize miniaudio (Only for desktop, not WebAssembly since we use AudioWorklet)
#ifndef __EMSCRIPTEN__
    ma_device_config config = ma_device_config_init(ma_device_type_playback);
    config.playback.format   = ma_format_f32;
    config.playback.channels = 2; // Stereo
    config.sampleRate        = 44100; // Fixed for now
    
    // NATIVE BUFFER TUNING FOR ANDROID UNDERRUNS
    config.periodSizeInMilliseconds = 20; 
    config.periods = 3; 
    
    config.dataCallback      = data_callback_wrapper;
    config.pUserData         = this;

    if (ma_device_init(NULL, &config, &_device) != MA_SUCCESS) {
        std::cerr << "Failed to initialize playback device." << std::endl;
        _deviceInit = false;
    } else {
        _deviceInit = true;
        if (ma_device_start(&_device) != MA_SUCCESS) {
            std::cerr << "Failed to start playback device." << std::endl;
        }
    }
#else
    // For WebAssembly AudioWorklet, we don't need miniaudio to create a WebAudio context
    _deviceInit = false;
    _isPlaying = false;
#endif
}

LiveMixer::~LiveMixer() {
#ifndef __EMSCRIPTEN__
    if (_deviceInit) {
        ma_device_uninit(&_device);
    }
#endif
    
    if (_soundTouch) {
        soundtouch_destroy(_soundTouch);
        _soundTouch = nullptr;
    }

    // Cleanup tracks
    for (auto const& [key, val] : _tracks) {
        delete val;
    }
    _tracks.clear();
}


void LiveMixer::startPlayback() {
    std::lock_guard<std::mutex> lock(_mutex);
    _masterEnvelope = 0.0f;
    _targetEnvelope = 1.0f;
    _isPlaying = true;
}

void LiveMixer::stopPlayback() {
    std::lock_guard<std::mutex> lock(_mutex);
    _isPlaying = false;
}

int64_t LiveMixer::getAtomicPosition() {
    return _atomicFramesWritten.load(std::memory_order_acquire);
}

LiveMixer::WaveformData* LiveMixer::addTrack(const char* id, const char* filePath) {
    if (!id || !filePath) {
        LiveMixer::WaveformData* err = new LiveMixer::WaveformData{nullptr, 0, 0, 0, 0, -1};
        return err;
    }

    ma_decoder decoder;
    ma_decoder_config config = ma_decoder_config_init_default();
    config.format = ma_format_f32; 

    ma_result initResult = ma_decoder_init_file(filePath, &config, &decoder);

    uint64_t totalFrames = 0;
    int channels = 0;
    int sampleRate = 0;
    std::vector<float> pcmData;

    if (initResult != MA_SUCCESS) {
#ifdef _WIN32
        if (!decodeAudioMF(filePath, pcmData, channels, sampleRate, totalFrames)) {
            LiveMixer::WaveformData* err = new LiveMixer::WaveformData{nullptr, 0, 0, 0, 0, (int)initResult};
            return err;
        }
#else
        LiveMixer::WaveformData* err = new LiveMixer::WaveformData{nullptr, 0, 0, 0, 0, (int)initResult};
        return err;
#endif
    } else {
        ma_uint64 mfTotalFrames = 0;
        ma_decoder_get_length_in_pcm_frames(&decoder, &mfTotalFrames);
        totalFrames = mfTotalFrames;
        channels = decoder.outputChannels;
        sampleRate = decoder.outputSampleRate;

        if (totalFrames > 0) {
            pcmData.resize(totalFrames * channels);
            ma_uint64 framesRead = 0;
            ma_decoder_read_pcm_frames(&decoder, pcmData.data(), totalFrames, &framesRead);
            totalFrames = framesRead;
            pcmData.resize(totalFrames * channels);
        } else {
            float chunk[4096];
            ma_uint64 framesRead = 0;
            while (true) {
                ma_result res = ma_decoder_read_pcm_frames(&decoder, chunk, 4096 / channels, &framesRead);
                if (framesRead == 0) break;
                pcmData.insert(pcmData.end(), chunk, chunk + (framesRead * channels));
                if (res != MA_SUCCESS) break;
            }
            totalFrames = pcmData.size() / channels;
        }
        ma_decoder_uninit(&decoder);
    }

    if (totalFrames == 0) {
        LiveMixer::WaveformData* err = new LiveMixer::WaveformData{nullptr, 0, 0, 0, 0, -2};
        return err;
    }

    // Compute Waveform Peaks
    double durationInSeconds = (double)totalFrames / sampleRate;
    int targetPoints = (int)(durationInSeconds * 150.0);
    if (targetPoints < 2000) targetPoints = 2000;
    if (targetPoints > 100000) targetPoints = 100000;

    int step = (int)std::ceil((double)totalFrames / targetPoints);
    if (step < 1) step = 1;

    int actualPoints = (int)((totalFrames + step - 1) / step);
    float* peaks = (float*)malloc(actualPoints * channels * sizeof(float));

    for (int c = 0; c < channels; ++c) {
        float* channelPeaks = peaks + (c * actualPoints);
        for (int p = 0; p < actualPoints; ++p) {
            uint64_t startFrame = p * step;
            uint64_t endFrame = startFrame + step;
            if (endFrame > totalFrames) endFrame = totalFrames;

            float maxVal = 0.0f;
            for (uint64_t f = startFrame; f < endFrame; ++f) {
                float val = std::abs(pcmData[f * channels + c]);
                if (val > maxVal) maxVal = val;
            }
            channelPeaks[p] = maxVal;
        }
    }

    // Assign to track holding the lock
    {
        std::lock_guard<std::mutex> lock(_mutex);
        if (_tracks.find(id) != _tracks.end()) {
            delete _tracks[id];
            _tracks.erase(id);
        }
        Track* track = new Track();
        track->channels = channels;
        track->data = std::move(pcmData); // Zero-copy move!
        _tracks[id] = track;
        _updateMaxTrackSamples();
    } // release lock

    LiveMixer::WaveformData* result = new LiveMixer::WaveformData();
    result->peakData = peaks;
    result->peakDataLength = actualPoints * channels;
    result->channels = channels;
    result->sampleRate = sampleRate;
    result->totalFrames = totalFrames;
    result->error = 0;

    return result;
}

LiveMixer::WaveformData* LiveMixer::addTrackMemory(const char* id, const void* data, size_t dataSize) {
    if (!id || !data || dataSize == 0) {
        LiveMixer::WaveformData* err = new LiveMixer::WaveformData{nullptr, 0, 0, 0, 0, -1};
        return err;
    }

    ma_decoder decoder;
    ma_decoder_config config = ma_decoder_config_init_default();
    config.format = ma_format_f32;

    ma_result initResult = ma_decoder_init_memory(data, dataSize, &config, &decoder);

    uint64_t totalFrames = 0;
    int channels = 0;
    int sampleRate = 0;
    std::vector<float> pcmData;

    if (initResult != MA_SUCCESS) {
        LiveMixer::WaveformData* err = new LiveMixer::WaveformData{nullptr, 0, 0, 0, 0, (int)initResult};
        return err;
    } else {
        ma_uint64 mfTotalFrames = 0;
        ma_decoder_get_length_in_pcm_frames(&decoder, &mfTotalFrames);
        totalFrames = mfTotalFrames;
        channels = decoder.outputChannels;
        sampleRate = decoder.outputSampleRate;

        if (totalFrames > 0) {
            pcmData.resize(totalFrames * channels);
            ma_uint64 framesRead = 0;
            ma_decoder_read_pcm_frames(&decoder, pcmData.data(), totalFrames, &framesRead);
            totalFrames = framesRead;
            pcmData.resize(totalFrames * channels);
        } else {
            float chunk[4096];
            ma_uint64 framesRead = 0;
            while (true) {
                ma_result res = ma_decoder_read_pcm_frames(&decoder, chunk, 4096 / channels, &framesRead);
                if (framesRead == 0) break;
                pcmData.insert(pcmData.end(), chunk, chunk + (framesRead * channels));
                if (res != MA_SUCCESS) break;
            }
            totalFrames = pcmData.size() / channels;
        }
        ma_decoder_uninit(&decoder);
    }

    if (totalFrames == 0) {
        LiveMixer::WaveformData* err = new LiveMixer::WaveformData{nullptr, 0, 0, 0, 0, -2};
        return err;
    }

    // Compute Waveform Peaks
    double durationInSeconds = (double)totalFrames / sampleRate;
    int targetPoints = (int)(durationInSeconds * 150.0);
    if (targetPoints < 2000) targetPoints = 2000;
    if (targetPoints > 100000) targetPoints = 100000;

    int step = (int)std::ceil((double)totalFrames / targetPoints);
    if (step < 1) step = 1;

    int actualPoints = (int)((totalFrames + step - 1) / step);
    float* peaks = (float*)malloc(actualPoints * channels * sizeof(float));

    for (int c = 0; c < channels; ++c) {
        float* channelPeaks = peaks + (c * actualPoints);
        for (int p = 0; p < actualPoints; ++p) {
            uint64_t startFrame = p * step;
            uint64_t endFrame = startFrame + step;
            if (endFrame > totalFrames) endFrame = totalFrames;

            float maxVal = 0.0f;
            for (uint64_t f = startFrame; f < endFrame; ++f) {
                float val = std::abs(pcmData[f * channels + c]);
                if (val > maxVal) maxVal = val;
            }
            channelPeaks[p] = maxVal;
        }
    }

    // Assign to track holding the lock
    {
        std::lock_guard<std::mutex> lock(_mutex);
        if (_tracks.find(id) != _tracks.end()) {
            delete _tracks[id];
            _tracks.erase(id);
        }
        Track* track = new Track();
        track->channels = channels;
        track->data = std::move(pcmData); // Zero-copy move!
        _tracks[id] = track;
        _updateMaxTrackSamples();
    } // release lock

    LiveMixer::WaveformData* result = new LiveMixer::WaveformData();
    result->peakData = peaks;
    result->peakDataLength = actualPoints * channels;
    result->channels = channels;
    result->sampleRate = sampleRate;
    result->totalFrames = totalFrames;
    result->error = 0;

    return result;
}

LiveMixer::WaveformData* LiveMixer::addTrackPCM(const char* id, const float* pcmData, int totalFrames, int channels, int sampleRate) {
    if (!id || !pcmData || totalFrames <= 0 || channels <= 0) {
        LiveMixer::WaveformData* err = new LiveMixer::WaveformData{nullptr, 0, 0, 0, 0, -1};
        return err;
    }

    std::vector<float> pcmVec;
    pcmVec.assign(pcmData, pcmData + (totalFrames * channels));

    // Compute Waveform Peaks
    double durationInSeconds = (double)totalFrames / sampleRate;
    int targetPoints = (int)(durationInSeconds * 150.0);
    if (targetPoints < 2000) targetPoints = 2000;
    if (targetPoints > 100000) targetPoints = 100000;

    int step = (int)std::ceil((double)totalFrames / targetPoints);
    if (step < 1) step = 1;

    int actualPoints = (int)((totalFrames + step - 1) / step);
    float* peaks = (float*)malloc(actualPoints * channels * sizeof(float));

    for (int c = 0; c < channels; ++c) {
        float* channelPeaks = peaks + (c * actualPoints);
        for (int p = 0; p < actualPoints; ++p) {
            uint64_t startFrame = p * step;
            uint64_t endFrame = startFrame + step;
            if (endFrame > totalFrames) endFrame = totalFrames;

            float maxVal = 0.0f;
            for (uint64_t f = startFrame; f < endFrame; ++f) {
                float val = std::abs(pcmVec[f * channels + c]);
                if (val > maxVal) maxVal = val;
            }
            channelPeaks[p] = maxVal;
        }
    }

    // Assign to track holding the lock
    {
        std::lock_guard<std::mutex> lock(_mutex);
        if (_tracks.find(id) != _tracks.end()) {
            delete _tracks[id];
            _tracks.erase(id);
        }
        Track* track = new Track();
        track->channels = channels;
        track->data = std::move(pcmVec); // Zero-copy move!
        _tracks[id] = track;
        _updateMaxTrackSamples();
    } // release lock

    LiveMixer::WaveformData* result = new LiveMixer::WaveformData();
    result->peakData = peaks;
    result->peakDataLength = actualPoints * channels;
    result->channels = channels;
    result->sampleRate = sampleRate;
    result->totalFrames = totalFrames;
    result->error = 0;

    return result;
}

void LiveMixer::removeTrack(const char* id) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_tracks.find(id) != _tracks.end()) {
        delete _tracks[id];
        _tracks.erase(id);
    }
    _updateAnySolo();
    _updateMaxTrackSamples();
}

void LiveMixer::setTrackVolume(const char* id, float volume) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_tracks.find(id) != _tracks.end()) {
        _tracks[id]->volume = volume;
    }
}

void LiveMixer::setTrackPan(const char* id, float pan) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_tracks.find(id) != _tracks.end()) {
        _tracks[id]->pan = pan;
    }
}

void LiveMixer::setTrackMute(const char* id, bool muted) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_tracks.find(id) != _tracks.end()) {
        _tracks[id]->muted = muted;
    }
}

void LiveMixer::setTrackSolo(const char* id, bool solo) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_tracks.find(id) != _tracks.end()) {
        _tracks[id]->solo = solo;
        _updateAnySolo();
    }
}

void LiveMixer::setMasterMute(bool muted) {
    std::lock_guard<std::mutex> lock(_mutex);
    _masterMuted = muted;
}

void LiveMixer::setMasterSolo(bool solo) {
    std::lock_guard<std::mutex> lock(_mutex);
    _masterSolo = solo;
    _updateGlobalSolo();
}

void LiveMixer::setMasterVolume(float volume) {
    std::lock_guard<std::mutex> lock(_mutex);
    _masterVolume = volume;
}

void LiveMixer::_updateAnySolo() {
    _anyTrackSolo = false;
    for (auto const& [key, track] : _tracks) {
        if (track->solo) {
            _anyTrackSolo = true;
            break;
        }
    }
}

void LiveMixer::_updateGlobalSolo() {
    _anyStemSolo = _masterSolo;
    for (const auto& track : _metronomeTracks) {
        if (track.solo) {
            _anyStemSolo = true;
            break;
        }
    }
}

void LiveMixer::_updateMaxTrackSamples() {
    _maxTrackSamples = 0;
    for (auto const& [key, track] : _tracks) {
        int64_t trackFrames = track->data.size() / track->channels;
        if (trackFrames > _maxTrackSamples) {
            _maxTrackSamples = trackFrames;
        }
    }
}

void LiveMixer::setLoop(int64_t startSample, int64_t endSample, bool enabled) {
    std::lock_guard<std::mutex> lock(_mutex);
    _loopStart = startSample;
    _loopEnd = endSample;
    _loopEnabled = enabled;
    
    // Safety clamp current position if needed? Or let process handle it.
    if (_loopEnabled && _loopEnd > _loopStart && _currentPosition >= _loopEnd) {
         _currentPosition = _loopStart;
    }
}

void LiveMixer::seek(int64_t positionSample) {
    std::lock_guard<std::mutex> lock(_mutex);
    _currentPosition = positionSample;
    
    if (_soundTouch) {
        soundtouch_clear(_soundTouch);
    }
    
    // Clear any temporary buffers
    _mixBuffer.assign(_mixBuffer.size(), 0.0f);
    
    // Reset envelope to 0 for a quick 20ms fade-in of the new audio 
    // to prevent any pops from non-zero crossings
    _masterEnvelope = 0.0f;
    
    // Update UI shadow
    _atomicFramesWritten.store(_currentPosition, std::memory_order_release);
}
int64_t LiveMixer::getPosition() {
    // This is the old locked getter. 
    // We should implement new atomic getter.
    return _atomicFramesWritten.load(std::memory_order_acquire); 
    // Wait, I reused the variable name from header but confused logic.
    // Header has `_atomicFramesWritten`. 
    // Let's use THAT as the "File Position" shadow? No, that's confusing.
    
    // I will use `_atomicFramesWritten` to mean "Current File Position Atomic Shadow".
    // In `process`, I will update it to match `_currentPosition`.
}

void LiveMixer::setSpeed(float speed) {
    std::lock_guard<std::mutex> lock(_mutex);
    _speed = speed;
    if (_soundTouch) {
        soundtouch_setTempo(_soundTouch, speed);
    }
}

void LiveMixer::setSoundTouchSetting(int settingId, int value) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_soundTouch) {
        soundtouch_setSetting(_soundTouch, settingId, value);
    }
}

// --- METRONOME ---
void LiveMixer::setMetronomeConfig(int bpm) {
    std::lock_guard<std::mutex> lock(_mutex);
    
    // If we are in isolated mode (Home Screen), seamlessly scale position 
    // rather than resetting the pattern, so changing BPM doesn't restart the measure!
    if (_metronomePreviewMode && _bpm > 0) {
        double ratio = (double)_bpm / (double)bpm;
        _currentPosition = (int64_t)(_currentPosition * ratio);
        // Do NOT reset _lastEighth, so the trigger engine seamlessly picks up the new rate
    } else {
        _lastEighth = -1; // reset trigger absolute alignment for Exercises
    }
    
    _bpm = bpm;
}

void LiveMixer::setMetronomeSound(int type, const float* data, int numSamples) {
    if (!data || numSamples <= 0) return;
    std::lock_guard<std::mutex> lock(_mutex);
    if (type == 0) { // High
        _clickHigh.data.assign(data, data + numSamples);
    } else if (type == 1) { // Low
        _clickLow.data.assign(data, data + numSamples);
    } else { // Noise (2)
        _clickNoise.data.assign(data, data + numSamples);
    }
}

void LiveMixer::_parseFlatPattern(MetronomeTrack& track, const int* flatData, const int* subdivisions, const double* durationRatios, int numPulses) {
    track.pulses.clear();
    if (numPulses <= 0 || !flatData || !subdivisions) return;
    
    int dataIndex = 0;
    for (int i = 0; i < numPulses; i++) {
        MetronomePulse pulse;
        int m = subdivisions[i];
        for (int j = 0; j < m; j++) {
            pulse.subdivisions.push_back(flatData[dataIndex++]);
        }
        pulse.durationRatio = (durationRatios && i < numPulses) ? durationRatios[i] : 1.0;
        track.pulses.push_back(pulse);
    }
}

void LiveMixer::addMetronomePattern(int id, const int* flatPatternData, const int* subdivisionsData, const double* durationRatios, int numPulses, float vol, bool mute, bool solo) {
    std::lock_guard<std::mutex> lock(_mutex);
    MetronomeTrack track;
    track.id = id;
    track.volume = vol;
    track.muted = mute;
    track.solo = solo;
    _parseFlatPattern(track, flatPatternData, subdivisionsData, durationRatios, numPulses);
    _metronomeTracks.push_back(track);
    _updateGlobalSolo();
}

void LiveMixer::updateMetronomePattern(int id, const int* flatPatternData, const int* subdivisionsData, const double* durationRatios, int numPulses, float vol, bool mute, bool solo) {
    std::lock_guard<std::mutex> lock(_mutex);
    for (auto& track : _metronomeTracks) {
        if (track.id == id) {
            track.volume = vol;
            track.muted = mute;
            track.solo = solo;
            _parseFlatPattern(track, flatPatternData, subdivisionsData, durationRatios, numPulses);
            break;
        }
    }
    _updateGlobalSolo();
}

void LiveMixer::removeMetronomePattern(int id) {
    std::lock_guard<std::mutex> lock(_mutex);
    _metronomeTracks.erase(std::remove_if(_metronomeTracks.begin(), _metronomeTracks.end(), 
        [id](const MetronomeTrack& track) { return track.id == id; }), _metronomeTracks.end());
    _updateGlobalSolo();
}

void LiveMixer::clearMetronomePatterns() {
    std::lock_guard<std::mutex> lock(_mutex);
    _metronomeTracks.clear();
    _updateGlobalSolo();
}

void LiveMixer::setMetronomePreviewMode(bool enabled) {
    std::lock_guard<std::mutex> lock(_mutex);
    _metronomePreviewMode = enabled;
}

// Internal mixing logic (Raw audio from tracks)
void LiveMixer::_mixInternal(float* outputBuffer, int numFrames) {
    // Assumes mutex is ALREADY LOCKED by caller (process)
    
    // Auto-stop if we reached the end of the longest track, unless we are looping
    // If we have 0 tracks (_maxTrackSamples == 0) and we are not in preview mode, we should stop
    if (!_loopEnabled && _maxTrackSamples > 0 && _currentPosition >= _maxTrackSamples) {
        if (!_metronomePreviewMode) {
            _isPlaying = false;
            memset(outputBuffer, 0, numFrames * 2 * sizeof(float));
            return;
        }
    }
    
    // Auto-stop if no tracks and not previewing
    if (!_loopEnabled && _maxTrackSamples == 0 && !_metronomePreviewMode) {
        _isPlaying = false;
        memset(outputBuffer, 0, numFrames * 2 * sizeof(float));
        return;
    }
    
    memset(outputBuffer, 0, numFrames * 2 * sizeof(float)); // Stereo output

    // We no longer return early if _tracks is empty, so the Metronome can always play.
    
    for (int i = 0; i < numFrames; i++) {
        // Handle Loop
        if (_loopEnabled && _loopEnd > _loopStart) {
             // WRAP CHECK: If we are AT or PAST the end, wrap!
             if (_currentPosition >= _loopEnd) {
                 _currentPosition = _loopStart;
             }
        }
        
        float leftSum = 0.0f;
        float rightSum = 0.0f;
        
        bool playTracks = true;
        
        if (_metronomePreviewMode) {
            playTracks = false;
        }
        float envelopeStep = 1.0f / (44100.0f * 0.02f); // 20ms fade
        
        // 1. MIX TRACK BUS
        if (playTracks) {
            // Iterate tracks
            for (auto const& [key, track] : _tracks) {
                 // Solo-in-place logic FOR TRACKS ONLY:
                 bool playThisTrack = true;
                 if (_anyTrackSolo) {
                     if (!track->solo) playThisTrack = false; 
                 } else {
                     if (track->muted) playThisTrack = false;
                 }
                 
                 float targetTrackEnv = playThisTrack ? 1.0f : 0.0f;
                 if (track->envelope < targetTrackEnv) {
                     track->envelope += envelopeStep;
                     if (track->envelope > targetTrackEnv) track->envelope = targetTrackEnv;
                 } else if (track->envelope > targetTrackEnv) {
                     track->envelope -= envelopeStep;
                     if (track->envelope < targetTrackEnv) track->envelope = targetTrackEnv;
                 }

                 if (track->envelope <= 0.0001f) continue;
                 
                 int64_t framesAvailable = static_cast<int64_t>(track->data.size()) / track->channels;
                 
                 if (_currentPosition < 0) _currentPosition = 0;

                 if (_currentPosition < framesAvailable) {
                     float lVal = 0.0f;
                     float rVal = 0.0f;
                     
                     size_t sampleIdx = static_cast<size_t>(_currentPosition * track->channels);
                     
                     if (sampleIdx < track->data.size() && (sampleIdx + track->channels) <= track->data.size()) {
                         if (track->channels == 1) {
                             lVal = track->data[sampleIdx];
                             rVal = lVal;
                         } else {
                             lVal = track->data[sampleIdx];
                             rVal = track->data[sampleIdx + 1];
                         }
                      }
                     
                     float lGain = 1.0f;
                     float rGain = 1.0f;
                     if (track->pan > 0) lGain = 1.0f - track->pan;
                     else if (track->pan < 0) rGain = 1.0f + track->pan;
                     
                     // Apply track volume, pan, and mute/solo envelope
                     lVal *= track->volume * lGain * track->envelope;
                     rVal *= track->volume * rGain * track->envelope;
                     
                     leftSum += lVal;
                     rightSum += rVal;
                 }
             }
        } // close if playTracks
        
        // --- APPLY MASTER ENVELOPE AND VOLUME TO TRACKS ---
        if (_masterEnvelope < _targetEnvelope) {
            _masterEnvelope += envelopeStep;
            if (_masterEnvelope > _targetEnvelope) _masterEnvelope = _targetEnvelope;
        } else if (_masterEnvelope > _targetEnvelope) {
            _masterEnvelope -= envelopeStep;
            if (_masterEnvelope < _targetEnvelope) _masterEnvelope = _targetEnvelope;
        }
        
        leftSum *= _masterEnvelope * _masterVolume;
        rightSum *= _masterEnvelope * _masterVolume;
        
        // HANDLE STEM SOLO/MUTE
        bool playMaster = true;
        if (_anyStemSolo) {
            playMaster = _masterSolo;
        } else {
            playMaster = !_masterMuted;
        }
        
        float targetMasterStem = playMaster ? 1.0f : 0.0f;
        if (_masterStemEnv < targetMasterStem) {
            _masterStemEnv += envelopeStep;
            if (_masterStemEnv > targetMasterStem) _masterStemEnv = targetMasterStem;
        } else if (_masterStemEnv > targetMasterStem) {
            _masterStemEnv -= envelopeStep;
            if (_masterStemEnv < targetMasterStem) _masterStemEnv = targetMasterStem;
        }
        
        leftSum *= _masterStemEnv;
        rightSum *= _masterStemEnv;
        
        // Handle Metronome Trigger (Stateless Analytical Polyrhythm Engine)
        if (_bpm > 0 && !_metronomeTracks.empty()) {
            double framesPerBeat = (44100.0 * 60.0) / _bpm;
            
            float volHigh = 0.0f;
            float volLow = 0.0f;
            float volNoise = 0.0f;
            
            double prevBeatFloat = (double)(_currentPosition - 1) / framesPerBeat;
            double currBeatFloat = (double)_currentPosition / framesPerBeat;
            
            for (const auto& track : _metronomeTracks) {
                if (track.pulses.empty()) continue;
                
                bool playTrack = true;
                if (_anyStemSolo) {
                    playTrack = track.solo;
                } else {
                    playTrack = !track.muted;
                }
                
                if (playTrack && track.volume > 0.0f) {
                    int numPulses = (int)track.pulses.size();
                    
                    // Compute total cycle duration in beats (sum of all durationRatios)
                    double cycleDuration = 0.0;
                    for (int p = 0; p < numPulses; p++) {
                        cycleDuration += track.pulses[p].durationRatio;
                    }
                    if (cycleDuration <= 0.0) cycleDuration = (double)numPulses;
                    
                    // Current and previous position within the cycle
                    double currCyclePos = fmod(currBeatFloat, cycleDuration);
                    if (currCyclePos < 0.0) currCyclePos += cycleDuration;
                    double prevCyclePos = fmod(prevBeatFloat, cycleDuration);
                    if (prevCyclePos < 0.0) prevCyclePos += cycleDuration;
                    
                    // Find which pulse and subdivision we are in
                    auto findPulseAndSub = [&](double pos, int& outPulse, int& outSub) {
                        double accum = 0.0;
                        for (int p = 0; p < numPulses; p++) {
                            double pulseEnd = accum + track.pulses[p].durationRatio;
                            if (pos < pulseEnd || p == numPulses - 1) {
                                outPulse = p;
                                double fractInPulse = (pos - accum) / track.pulses[p].durationRatio;
                                int m = (int)track.pulses[p].subdivisions.size();
                                outSub = (int)(fractInPulse * m);
                                if (outSub >= m) outSub = m - 1;
                                if (outSub < 0) outSub = 0;
                                return;
                            }
                            accum = pulseEnd;
                        }
                        outPulse = 0;
                        outSub = 0;
                    };
                    
                    int currPulse = 0, currSub = 0;
                    findPulseAndSub(currCyclePos, currPulse, currSub);
                    
                    int prevPulse = -1, prevSub = -1;
                    if (_currentPosition > 0 && prevBeatFloat >= 0.0) {
                        // Handle cycle wrap: if prev is in a different cycle than curr
                        int currCycle = (int)(currBeatFloat / cycleDuration);
                        int prevCycle = (int)(prevBeatFloat / cycleDuration);
                        if (currCycle != prevCycle) {
                            // Wrapped around — force trigger
                            prevPulse = -1;
                            prevSub = -1;
                        } else {
                            findPulseAndSub(prevCyclePos, prevPulse, prevSub);
                        }
                    }
                    
                    // Trigger on pulse/subdivision change
                    if (currPulse != prevPulse || currSub != prevSub) {
                        int m = (int)track.pulses[currPulse].subdivisions.size();
                        if (m > 0) {
                            int type = track.pulses[currPulse].subdivisions[currSub];
                            if (type == 1) volHigh = (std::max)(volHigh, track.volume);
                            else if (type == 2) volLow = (std::max)(volLow, track.volume);
                            else if (type == 3) volNoise = (std::max)(volNoise, track.volume);
                        }
                    }
                }
            }
            
            if (volHigh > 0.0f && !_clickHigh.data.empty()) {
                _clickHigh.currentPointer = 0;
                _clickHigh.currentVolume = volHigh;
            }
            if (volLow > 0.0f && !_clickLow.data.empty()) {
                _clickLow.currentPointer = 0;
                _clickLow.currentVolume = volLow;
            }
            if (volNoise > 0.0f && !_clickNoise.data.empty()) {
                _clickNoise.currentPointer = 0;
                _clickNoise.currentVolume = volNoise;
            }
            
            float clickL = 0.0f;
            float clickR = 0.0f;
            
            if (_clickHigh.currentPointer >= 0 && _clickHigh.currentPointer < _clickHigh.data.size()) {
                float sample = _clickHigh.data[_clickHigh.currentPointer] * _clickHigh.currentVolume;
                clickL += sample;
                clickR += sample;
                _clickHigh.currentPointer++;
            }
            if (_clickLow.currentPointer >= 0 && _clickLow.currentPointer < _clickLow.data.size()) {
                float sample = _clickLow.data[_clickLow.currentPointer] * _clickLow.currentVolume;
                clickL += sample;
                clickR += sample;
                _clickLow.currentPointer++;
            }
            if (_clickNoise.currentPointer >= 0 && _clickNoise.currentPointer < _clickNoise.data.size()) {
                float sample = _clickNoise.data[_clickNoise.currentPointer] * _clickNoise.currentVolume;
                clickL += sample;
                clickR += sample;
                _clickNoise.currentPointer++;
            }
            
            leftSum += clickL;
            rightSum += clickR;
        }
        
        outputBuffer[i*2] = leftSum;
        outputBuffer[i*2+1] = rightSum;
        _currentPosition++;
    }
}

int LiveMixer::process(float* outputBuffer, int numFrames) {
    std::lock_guard<std::mutex> lock(_mutex);
    
    if (!_isPlaying) {
        memset(outputBuffer, 0, numFrames * 2 * sizeof(float));
        // Reset envelope so it fades in again when starting
        _masterEnvelope = 0.0f;
        return numFrames;
    }
    
    // --- 1.0x SOUNDTOUCH BYPASS OVERRIDE ---
    // If speed is practically 1.0, bypass SoundTouch and its WSOLA artifacts entirely.
    bool bypassSoundTouch = std::abs(_speed - 1.0f) < 0.001f;
    
    if (bypassSoundTouch) {
        // Direct Mixing to Output Buffer
        _mixInternal(outputBuffer, numFrames);
        
        if (_soundTouch) {
            soundtouch_clear(_soundTouch);
        }
    } else {
        if (!_soundTouch) return 0;
        
        int samplesReceived = 0;
        int maxIt = 100; // Safety break
        
        // Option 4 Micro-Processing chunk logic applies perfectly to Vocoder as well
        const int MAX_CHUNK_FRAMES = 512; 
        
        while (samplesReceived < numFrames && maxIt-- > 0) {
            int neededFrames = numFrames - samplesReceived;
            
            // Try receive what's available from SoundTouch
            int got = soundtouch_receiveSamples(_soundTouch, outputBuffer + (samplesReceived * 2), neededFrames);
            samplesReceived += got;
            
            if (samplesReceived >= numFrames) break;
            
            // Ingest more data
            int chunkFrames = MAX_CHUNK_FRAMES; 
            if (_speed > 1.0f) {
                chunkFrames = (int)(MAX_CHUNK_FRAMES * _speed);
                if (chunkFrames > 1024) chunkFrames = 1024;
            }
            
            if (_mixBuffer.size() < chunkFrames * 2) {
                _mixBuffer.resize(chunkFrames * 2);
            }
            
            _mixInternal(_mixBuffer.data(), chunkFrames);
            
            // Feed to SoundTouch
            soundtouch_putSamples(_soundTouch, _mixBuffer.data(), chunkFrames);
        }
        
        // Fill remaining with silence if we somehow failed to generate enough (e.g. max iterations reached)
        if (samplesReceived < numFrames) {
             memset(outputBuffer + (samplesReceived * 2), 0, (numFrames - samplesReceived) * 2 * sizeof(float));
        }
    }
    
    // (Master envelope and volume are now applied inside _mixInternal before the metronome)
    
    // Update Atomic Shadow for UI
    _atomicFramesWritten.store(_currentPosition, std::memory_order_release);
    
    return numFrames;
}

extern "C" {
    // C Binding Wrappers
    
    EXPORT void* live_mixer_create() {
        return new LiveMixer();
    }
    
    EXPORT void live_mixer_destroy(void* mixer) {
        if (mixer) delete static_cast<LiveMixer*>(mixer);
    }
    
    EXPORT LiveMixer::WaveformData* live_mixer_add_track(void* mixer, const char* id, const char* filePath) {
        return static_cast<LiveMixer*>(mixer)->addTrack(id, filePath);
    }
    
    EXPORT LiveMixer::WaveformData* live_mixer_add_track_memory(void* mixer, const char* id, const void* data, size_t dataSize) {
        return static_cast<LiveMixer*>(mixer)->addTrackMemory(id, data, dataSize);
    }

    EXPORT LiveMixer::WaveformData* live_mixer_add_track_pcm(void* mixer, const char* id, const float* pcmData, int totalFrames, int channels, int sampleRate) {
        return static_cast<LiveMixer*>(mixer)->addTrackPCM(id, pcmData, totalFrames, channels, sampleRate);
    }
    
    EXPORT void live_mixer_remove_track(void* mixer, const char* id) {
        static_cast<LiveMixer*>(mixer)->removeTrack(id);
    }
    
    EXPORT void live_mixer_set_volume(void* mixer, const char* id, float volume) {
        static_cast<LiveMixer*>(mixer)->setTrackVolume(id, volume);
    }

    EXPORT void live_mixer_set_master_volume(void* mixer, float volume) {
        static_cast<LiveMixer*>(mixer)->setMasterVolume(volume);
    }

    EXPORT void live_mixer_set_pan(void* mixer, const char* id, float pan) {
        static_cast<LiveMixer*>(mixer)->setTrackPan(id, pan);
    }
    
    EXPORT void live_mixer_set_mute(void* mixer, const char* id, bool muted) {
        static_cast<LiveMixer*>(mixer)->setTrackMute(id, muted);
    }

    EXPORT void live_mixer_set_solo(void* mixer, const char* id, bool solo) {
        static_cast<LiveMixer*>(mixer)->setTrackSolo(id, solo);
    }

    EXPORT void live_mixer_set_loop(void* mixer, double start, double end, bool enabled) {
        static_cast<LiveMixer*>(mixer)->setLoop((int64_t)start, (int64_t)end, enabled);
    }
    
    EXPORT void live_mixer_seek(void* mixer, double position) {
        static_cast<LiveMixer*>(mixer)->seek((int64_t)position);
    }

    EXPORT double live_mixer_get_position(void* mixer) {
        // DEPRECATED -> Redirect to Atomic 
        return (double)static_cast<LiveMixer*>(mixer)->getAtomicPosition();
    }
    
    EXPORT int live_mixer_process(void* mixer, float* output, int frames) {
        return static_cast<LiveMixer*>(mixer)->process(output, frames);
    }
    
    // --- NEW EXPORTS ---
    EXPORT void live_mixer_start(void* mixer) {
        static_cast<LiveMixer*>(mixer)->startPlayback();
    }
    
    EXPORT void live_mixer_stop(void* mixer) {
        static_cast<LiveMixer*>(mixer)->stopPlayback();
    }
    
    EXPORT double live_mixer_get_atomic_position(void* mixer) {
        return (double)static_cast<LiveMixer*>(mixer)->getAtomicPosition();
    }

    EXPORT void live_mixer_set_speed(void* mixer, float speed) {
        static_cast<LiveMixer*>(mixer)->setSpeed(speed);
    }

    EXPORT void live_mixer_set_soundtouch_setting(void* mixer, int settingId, int value) {
        static_cast<LiveMixer*>(mixer)->setSoundTouchSetting(settingId, value);
    }
    
    EXPORT void live_mixer_set_metronome_config(void* mixer, int bpm) {
        static_cast<LiveMixer*>(mixer)->setMetronomeConfig(bpm);
    }

    EXPORT void live_mixer_set_metronome_sound(void* mixer, int type, const float* data, int numSamples) {
        static_cast<LiveMixer*>(mixer)->setMetronomeSound(type, data, numSamples);
    }

EXPORT void live_mixer_add_metronome_pattern(void* mixer, int id, const int* flatPatternData, const int* subdivisionsData, const double* durationRatios, int numPulses, float vol, bool mute, bool solo) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->addMetronomePattern(id, flatPatternData, subdivisionsData, durationRatios, numPulses, vol, mute, solo);
    }
}

EXPORT void live_mixer_update_metronome_pattern(void* mixer, int id, const int* flatPatternData, const int* subdivisionsData, const double* durationRatios, int numPulses, float vol, bool mute, bool solo) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->updateMetronomePattern(id, flatPatternData, subdivisionsData, durationRatios, numPulses, vol, mute, solo);
    }
}

EXPORT void live_mixer_remove_metronome_pattern(void* mixer, int id) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->removeMetronomePattern(id);
    }
}

EXPORT void live_mixer_clear_metronome_patterns(void* mixer) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->clearMetronomePatterns();
    }
}

EXPORT void live_mixer_set_master_mute(void* mixer, bool muted) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->setMasterMute(muted);
    }
}

EXPORT void live_mixer_set_master_solo(void* mixer, bool solo) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->setMasterSolo(solo);
    }
}

EXPORT void live_mixer_set_metronome_preview_mode(void* mixer, bool enabled) {
    if (mixer) {
        static_cast<LiveMixer*>(mixer)->setMetronomePreviewMode(enabled);
    }
}

    EXPORT void live_mixer_free_waveform_data(LiveMixer::WaveformData* data) {
        if (data) {
            if (data->peakData) {
                free(data->peakData);
            }
            delete data;
        }
    }
    
    EXPORT int live_mixer_render_offline(void* mixer, const char* outPath) {
        // To be implemented later.
        return 0;
    }

}
