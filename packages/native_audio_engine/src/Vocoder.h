#ifndef VOCODER_H
#define VOCODER_H

#include "kiss_fft.h"
#include <vector>
#include <cmath>
#include <cstring>
#include <mutex>

class Vocoder {
public:
    Vocoder(int sampleRate, int channels);
    ~Vocoder();

    void setTempo(float speed);
    void clear();

    // Ingest stereo interleaved samples. 
    // Internally buffers them.
    void putSamples(const float* stereoInput, int numFrames);

    // Retrieve processed stereo interleaved samples.
    // Returns the actual number of frames retrieved (up to maxFrames).
    int receiveSamples(float* stereoOutput, int maxFrames);

private:
    int _sampleRate;
    int _channels;
    float _speed;
    
    // Core parameters
    int _fftSize;
    int _hopSizeIn;
    int _hopSizeOut;
    
    // KissFFT states
    kiss_fft_cfg _fftCfg;
    kiss_fft_cfg _ifftCfg;
    
    // Buffers per channel
    struct ChannelState {
        std::vector<float> inputBuffer;
        std::vector<float> outputBuffer;
        std::vector<float> overlapBuffer;
        std::vector<float> lastPhase;
        std::vector<float> sumPhase;
        std::vector<float> analysisWindow;
        std::vector<float> synthesisWindow;
        std::vector<float> magCache;
        std::vector<float> phaseCache;
        float lastEnergy;
        int transientCooldown;
        
        ChannelState(int fftSize);
    };
    
    std::vector<ChannelState> _ch;
    std::vector<kiss_fft_cpx> _fftIn;
    std::vector<kiss_fft_cpx> _fftOut;
    
    std::mutex _mutex;

    void _processChannel(int chIdx);
    void _updateHopSizes();
};

#endif // VOCODER_H
