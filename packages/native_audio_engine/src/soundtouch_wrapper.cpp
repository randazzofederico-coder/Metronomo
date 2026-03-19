#include "soundtouch_wrapper.h"

// Check where SoundTouch include is located relative to this file
// Usually: ../soundtouch/include/SoundTouch.h
#include "soundtouch/include/SoundTouch.h"

using namespace soundtouch;

extern "C" {
    void* soundtouch_create() {
        return new SoundTouch();
    }

    void soundtouch_destroy(void* st) {
        if (st) {
            delete static_cast<SoundTouch*>(st);
        }
    }

    void soundtouch_setTempo(void* st, float tempo) {
        static_cast<SoundTouch*>(st)->setTempo(tempo);
    }

    void soundtouch_setPitch(void* st, float pitch) {
        static_cast<SoundTouch*>(st)->setPitch(pitch);
    }

    void soundtouch_setRate(void* st, float rate) {
        static_cast<SoundTouch*>(st)->setRate(rate);
    }

    void soundtouch_setChannels(void* st, int numChannels) {
        static_cast<SoundTouch*>(st)->setChannels(numChannels);
    }

    void soundtouch_setSampleRate(void* st, int srate) {
        static_cast<SoundTouch*>(st)->setSampleRate(srate);
    }

    void soundtouch_setSetting(void* st, int settingId, int value) {
        static_cast<SoundTouch*>(st)->setSetting(settingId, value);
    }

    void soundtouch_putSamples(void* st, const float* samples, int numSamples) {
        static_cast<SoundTouch*>(st)->putSamples(samples, numSamples);
    }

    int soundtouch_receiveSamples(void* st, float* output, int maxSamples) {
        return static_cast<SoundTouch*>(st)->receiveSamples(output, maxSamples);
    }

    void soundtouch_flush(void* st) {
        static_cast<SoundTouch*>(st)->flush();
    }

    void soundtouch_clear(void* st) {
        static_cast<SoundTouch*>(st)->clear();
    }

    int soundtouch_numSamples(void* st) {
        return static_cast<SoundTouch*>(st)->numSamples();
    }
}
