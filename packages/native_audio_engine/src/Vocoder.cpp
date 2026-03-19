#include "Vocoder.h"
#include <iostream>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Hanning window generator
static void createHanningWindow(std::vector<float>& window, int size) {
    window.resize(size);
    for (int i = 0; i < size; ++i) {
        window[i] = 0.5f * (1.0f - std::cos(2.0f * (float)M_PI * i / (size - 1)));
    }
}

Vocoder::ChannelState::ChannelState(int fftSize) {
    inputBuffer.reserve(fftSize * 2);
    outputBuffer.reserve(fftSize * 2);
    overlapBuffer.assign(fftSize, 0.0f);
    lastPhase.assign(fftSize, 0.0f);
    sumPhase.assign(fftSize, 0.0f);
    magCache.assign(fftSize, 0.0f);
    phaseCache.assign(fftSize, 0.0f);
    createHanningWindow(analysisWindow, fftSize);
    createHanningWindow(synthesisWindow, fftSize);
    lastEnergy = 0.0f;
    transientCooldown = 0;
}

Vocoder::Vocoder(int sampleRate, int channels) 
    : _sampleRate(sampleRate), _channels(channels), _speed(1.0f), _fftSize(2048) {
    
    _fftCfg = kiss_fft_alloc(_fftSize, 0, NULL, NULL);
    _ifftCfg = kiss_fft_alloc(_fftSize, 1, NULL, NULL);
    
    _fftIn.resize(_fftSize);
    _fftOut.resize(_fftSize);
    
    for (int i = 0; i < _channels; ++i) {
        _ch.emplace_back(_fftSize);
    }
    
    _updateHopSizes();
}

Vocoder::~Vocoder() {
    free(_fftCfg);
    free(_ifftCfg);
}

void Vocoder::setTempo(float speed) {
    std::lock_guard<std::mutex> lock(_mutex);
    _speed = speed;
    if (_speed < 0.1f) _speed = 0.1f;
    if (_speed > 4.0f) _speed = 4.0f;
    _updateHopSizes();
}

void Vocoder::_updateHopSizes() {
    // 75% overlap for high quality (hop = size / 4)
    _hopSizeOut = _fftSize / 4; 
    _hopSizeIn = static_cast<int>((float)_hopSizeOut * _speed);
    
    // Safety check
    if (_hopSizeIn < 1) _hopSizeIn = 1;
}

void Vocoder::clear() {
    std::lock_guard<std::mutex> lock(_mutex);
    for (int i = 0; i < _channels; ++i) {
        _ch[i].inputBuffer.clear();
        _ch[i].outputBuffer.clear();
        std::fill(_ch[i].overlapBuffer.begin(), _ch[i].overlapBuffer.end(), 0.0f);
        std::fill(_ch[i].lastPhase.begin(), _ch[i].lastPhase.end(), 0.0f);
        std::fill(_ch[i].sumPhase.begin(), _ch[i].sumPhase.end(), 0.0f);
        _ch[i].lastEnergy = 0.0f;
        _ch[i].transientCooldown = 0;
    }
}

void Vocoder::putSamples(const float* stereoInput, int numFrames) {
    std::lock_guard<std::mutex> lock(_mutex);
    
    // De-interleave and buffer
    for (int i = 0; i < numFrames; ++i) {
        for (int c = 0; c < _channels; ++c) {
            _ch[c].inputBuffer.push_back(stereoInput[i * _channels + c]);
        }
    }
    
    // Process full chunks
    while (true) {
        bool canProcess = true;
        for (int c = 0; c < _channels; ++c) {
            if (_ch[c].inputBuffer.size() < _fftSize) {
                canProcess = false;
                break;
            }
        }
        
        if (!canProcess) break;
        
        for (int c = 0; c < _channels; ++c) {
            _processChannel(c);
            
            // Advance input buffer by Analysis Hop Size
            _ch[c].inputBuffer.erase(_ch[c].inputBuffer.begin(), _ch[c].inputBuffer.begin() + _hopSizeIn);
        }
    }
}

void Vocoder::_processChannel(int chIdx) {
    ChannelState& state = _ch[chIdx];
    
    // 1. Ingest, Window and FFT
    for (int i = 0; i < _fftSize; ++i) {
        _fftIn[i].r = state.inputBuffer[i] * state.analysisWindow[i];
        _fftIn[i].i = 0.0f;
    }
    
    kiss_fft(_fftCfg, _fftIn.data(), _fftOut.data());
    
    // 2. Magnitude, Phase and Transient Detection (Optimized with Nyquist Mirrors)
    float currentEnergy = 0.0f;
    int halfSize = _fftSize / 2;
    
    // Process only up to Nyquist limit (0 to N/2) since input is purely real
    for (int k = 0; k <= halfSize; ++k) {
        state.magCache[k] = std::sqrt(_fftOut[k].r * _fftOut[k].r + _fftOut[k].i * _fftOut[k].i);
        state.phaseCache[k] = std::atan2(_fftOut[k].i, _fftOut[k].r);
        currentEnergy += state.magCache[k] * state.magCache[k];
    }
    
    float energyRatio = currentEnergy / (state.lastEnergy + 1e-7f);
    bool isTransient = (energyRatio > 2.5f);
    state.lastEnergy = currentEnergy;
    
    float expectedPhaseAdvance = 2.0f * (float)M_PI * _hopSizeIn / _fftSize;
    // float expectedSynthesisAdvance = 2.0f * (float)M_PI * _hopSizeOut / _fftSize; // not used

    
    if (isTransient && state.transientCooldown == 0) {
        // Transient Hit: Force Phase Reset to preserve punch
        state.transientCooldown = 3; 
        for (int k = 0; k <= halfSize; ++k) {
            state.sumPhase[k] = state.phaseCache[k];
            state.lastPhase[k] = state.phaseCache[k];
            
            _fftOut[k].r = state.magCache[k] * std::cos(state.sumPhase[k]);
            _fftOut[k].i = state.magCache[k] * std::sin(state.sumPhase[k]);
        }
    } else {
        if (state.transientCooldown > 0) {
            state.transientCooldown--;
        }
        
        // Standard Phase Vocoder Advance
        for (int k = 0; k <= halfSize; ++k) {
            float phaseDiff = state.phaseCache[k] - state.lastPhase[k];
            state.lastPhase[k] = state.phaseCache[k];
            
            float binDeviation = phaseDiff - (float)k * expectedPhaseAdvance;
            
            // Fast wrap to [-pi, pi]
            while (binDeviation > (float)M_PI) binDeviation -= 2.0f * (float)M_PI;
            while (binDeviation < -(float)M_PI) binDeviation += 2.0f * (float)M_PI;
            
            float trueFreqDev = binDeviation / _hopSizeIn; 
            
            state.sumPhase[k] += ((float)k * 2.0f * (float)M_PI / _fftSize + trueFreqDev) * _hopSizeOut;
            
            // Fast wrap synthesize phase
            while (state.sumPhase[k] > (float)M_PI) state.sumPhase[k] -= 2.0f * (float)M_PI;
            while (state.sumPhase[k] < -(float)M_PI) state.sumPhase[k] += 2.0f * (float)M_PI;
            
            _fftOut[k].r = state.magCache[k] * std::cos(state.sumPhase[k]);
            _fftOut[k].i = state.magCache[k] * std::sin(state.sumPhase[k]);
        }
    }
    
    // Reconstruct the top half using complex conjugates (Real FFT symmetry)
    for (int k = halfSize + 1; k < _fftSize; ++k) {
        _fftOut[k].r = _fftOut[_fftSize - k].r;
        _fftOut[k].i = -_fftOut[_fftSize - k].i;
    }
    
    // 3. IFFT and Windowing
    // Note: KissFFT in-place or out-of-place. We put modified frequency data in _fftOut,
    // so we must configure KissFFT to read from _fftOut and write to _fftIn (time domain).
    kiss_fft(_ifftCfg, _fftOut.data(), _fftIn.data());
    
    // 4. Overlap-Add Output Generation
    // KissFFT's inverse transform scales by N, so we must divide by N (_fftSize)
    // The overlap of Hanning windows (hop = N/4) sums to roughly 1.5, we tune the scale.
    float scale = 1.0f / ((float)_fftSize * 1.5f); 
    
    for (int i = 0; i < _fftSize; ++i) {
        state.overlapBuffer[i] += _fftIn[i].r * state.synthesisWindow[i] * scale;
    }
    
    // Extract finished hop to the output FIFO
    for (int i = 0; i < _hopSizeOut; ++i) {
        state.outputBuffer.push_back(state.overlapBuffer[i]);
    }
    
    // Shift accumulator left 
    for (int i = 0; i < _fftSize - _hopSizeOut; ++i) {
        state.overlapBuffer[i] = state.overlapBuffer[i + _hopSizeOut];
    }
    
    // Zero out the tail
    for (int i = _fftSize - _hopSizeOut; i < _fftSize; ++i) {
        state.overlapBuffer[i] = 0.0f;
    }
}

int Vocoder::receiveSamples(float* stereoOutput, int maxFrames) {
    std::lock_guard<std::mutex> lock(_mutex);
    
    // Find how many frames we can actually output
    int availableFrames = (int)_ch[0].outputBuffer.size(); 
    for (int c = 1; c < _channels; ++c) {
        int avail = (int)_ch[c].outputBuffer.size();
        if (avail < availableFrames) availableFrames = avail;
    }
    
    if (availableFrames <= 0) return 0;
    
    int framesToOutput = std::min(availableFrames, maxFrames);
    
    // Interleave and output
    for (int i = 0; i < framesToOutput; ++i) {
        for (int c = 0; c < _channels; ++c) {
            stereoOutput[i * _channels + c] = _ch[c].outputBuffer[i];
        }
    }
    
    // Erase consumed frames
    for (int c = 0; c < _channels; ++c) {
        _ch[c].outputBuffer.erase(_ch[c].outputBuffer.begin(), _ch[c].outputBuffer.begin() + framesToOutput);
    }
    
    return framesToOutput;
}
