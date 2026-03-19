#ifndef SOUNDTOUCH_WRAPPER_H
#define SOUNDTOUCH_WRAPPER_H

#include <stdint.h>

#if defined(_WIN32)
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

extern "C" {
    // Lifecycle
    EXPORT void* soundtouch_create();
    EXPORT void soundtouch_destroy(void* st);

    // Settings
    EXPORT void soundtouch_setTempo(void* st, float tempo);
    EXPORT void soundtouch_setPitch(void* st, float pitch);
    EXPORT void soundtouch_setRate(void* st, float rate);
    
    EXPORT void soundtouch_setChannels(void* st, int numChannels);
    EXPORT void soundtouch_setSampleRate(void* st, int srate);
    
    // Internal WSOLA Tuning
    EXPORT void soundtouch_setSetting(void* st, int settingId, int value);
    
    // Processing
    // Puts samples into the pipeline.
    // 'samples' should be interleaved if channels > 1.
    EXPORT void soundtouch_putSamples(void* st, const float* samples, int numSamples);
    
    // Receives samples from the pipeline.
    // Returns number of samples received (per channel).
    EXPORT int soundtouch_receiveSamples(void* st, float* output, int maxSamples);
    
    // Flushes the last samples from the pipeline.
    EXPORT void soundtouch_flush(void* st);
    
    // Clears the pipeline.
    EXPORT void soundtouch_clear(void* st);
    
    // Returns number of samples currently in the pipeline.
    EXPORT int soundtouch_numSamples(void* st);
}

#endif // SOUNDTOUCH_WRAPPER_H
