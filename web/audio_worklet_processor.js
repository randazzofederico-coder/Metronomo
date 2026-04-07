// Modern WebAudio AudioWorkletProcessor for Flutter/C++ WebAssembly integration
// This runs purely on the Audio thread, immune to Flutter visual UI thread drops.

class LiveMixerWorkletProcessor extends AudioWorkletProcessor {
    constructor(options) {
        super();
        this.module = null;
        this.mixerHandle = null;
        this.isProcessing = false;
        
        this.commandQueue = [];
        this.ticks = 0; 

        this.port.onmessage = async (event) => {
            const data = event.data;
            
            if (data.type === 'init') {
                // Emscripten may require crypto for random numbers, which is absent in AudioWorklets
                if (typeof crypto === 'undefined') {
                    globalThis.crypto = {
                        getRandomValues: function(arr) {
                            for (let i = 0; i < arr.length; i++) {
                                arr[i] = Math.floor(Math.random() * 256);
                            }
                        }
                    };
                }

                const wasmBinary = data.wasmBinary;

                try {
                    // Start the Emscripten WASM engine natively in the audio thread
                    this.module = await LiveMixerModule({ wasmBinary: wasmBinary });
                    this.mixerHandle = this.module._live_mixer_create(sampleRate);
                    
                    this.port.postMessage({ type: 'ready' });
                } catch (e) {
                    console.error("AudioWorklet failed to load Wasm:", e);
                }
            } else if (data.type === 'start') {
                this.isProcessing = true;
                if (this.module && this.mixerHandle) {
                    this.module._live_mixer_start(this.mixerHandle);
                }
            } else if (data.type === 'stop') {
                this.isProcessing = false;
                if (this.module && this.mixerHandle) {
                    this.module._live_mixer_stop(this.mixerHandle);
                }
            } else if (data.type === 'cmd') {
                this.commandQueue.push(data);
            }
        };
    }
    
    _allocateString(str) {
        return this.module.allocateUTF8(str);
    }
    
    _processCommand(data) {
        const handle = this.mixerHandle;
        const m = this.module;
        if (!handle || !m) return;

        switch(data.cmd) {
            case 'addTrackMemory': {
                const idPtr = this._allocateString(data.id);
                const pcm = data.pcm; // Float32Array from Dart
                const pcmBytes = pcm.byteLength;
                const pcmPtr = m._malloc(pcmBytes);
                m.HEAPF32.set(pcm, pcmPtr / 4);
                
                const resultPtr = m._live_mixer_add_track_pcm(handle, idPtr, pcmPtr, data.length, data.channels, data.sampleRate);
                
                m._free(pcmPtr);
                m._free(idPtr);

                let error = m.getValue(resultPtr + 24, 'i32');
                if (error === 0) {
                    let peakDataPtr = m.getValue(resultPtr, 'i32');
                    let peakDataLength = m.getValue(resultPtr + 4, 'i32');
                    let peaks = new Float32Array(peakDataLength);
                    if (peakDataPtr !== 0) {
                       for(let i=0; i<peakDataLength; i++) {
                           peaks[i] = m.getValue(peakDataPtr + (i*4), 'float');
                       }
                    }
                    this.port.postMessage({
                        type: 'trackAdded',
                        reqId: data.reqId,
                        peaks: peaks,
                        peakDataLength: peakDataLength,
                        channels: data.channels,
                        sampleRate: data.sampleRate,
                        totalFrames: data.length,
                        error: 0
                    });
                } else {
                    this.port.postMessage({
                        type: 'trackAdded',
                        reqId: data.reqId,
                        error: error
                    });
                }
                m._live_mixer_free_waveform_data(resultPtr);
                break;
            }
            case 'removeTrack': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_remove_track(handle, idPtr);
                m._free(idPtr);
                break;
            }
            case 'setVolume': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_set_volume(handle, idPtr, data.volume);
                m._free(idPtr);
                break;
            }
            case 'setPan': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_set_pan(handle, idPtr, data.pan);
                m._free(idPtr);
                break;
            }
            case 'setMute': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_set_mute(handle, idPtr, data.muted);
                m._free(idPtr);
                break;
            }
            case 'setSolo': {
                const idPtr = this._allocateString(data.id);
                m._live_mixer_set_solo(handle, idPtr, data.solo);
                m._free(idPtr);
                break;
            }
            case 'setMasterVolume':
                m._live_mixer_set_master_volume(handle, data.volume);
                break;
            case 'setMasterMute':
                m._live_mixer_set_master_mute(handle, data.muted);
                break;
            case 'setMasterSolo':
                m._live_mixer_set_master_solo(handle, data.solo);
                break;
            case 'setLoop':
                m._live_mixer_set_loop(handle, data.startSample, data.endSample, data.enabled);
                break;
            case 'seek':
                m._live_mixer_seek(handle, data.positionSample);
                break;
            case 'setSpeed':
                m._live_mixer_set_speed(handle, data.speed);
                break;
            case 'setSoundTouchSetting':
                m._live_mixer_set_soundtouch_setting(handle, data.settingId, data.value);
                break;
            case 'setMetronomeConfig':
                m._live_mixer_set_metronome_config(handle, data.bpm);
                break;
            case 'setMetronomeSound': {
                const soundData = data.data; // Float32Array
                const ptr = m._malloc(soundData.byteLength);
                m.HEAPF32.set(soundData, ptr / 4);
                m._live_mixer_set_metronome_sound(handle, data.trackType, ptr, soundData.length);
                m._free(ptr);
                break;
            }
            case 'addMetronomePattern':
            case 'updateMetronomePattern': {
                let flatPtr = 0;
                if (data.flatPattern && data.flatPattern.length > 0) {
                    flatPtr = m._malloc(data.flatPattern.length * 4);
                    m.HEAP32.set(data.flatPattern, flatPtr / 4);
                }
                let subPtr = 0;
                let numPulses = 0;
                if (data.subdivisions && data.subdivisions.length > 0) {
                    numPulses = data.subdivisions.length;
                    subPtr = m._malloc(numPulses * 4);
                    m.HEAP32.set(data.subdivisions, subPtr / 4);
                }
                let durPtr = 0;
                if (data.durationRatios && data.durationRatios.length > 0) {
                    durPtr = m._malloc(data.durationRatios.length * 8);
                    m.HEAPF64.set(data.durationRatios, durPtr / 8);
                }
                
                if (data.cmd === 'addMetronomePattern') {
                    m._live_mixer_add_metronome_pattern(handle, data.id, flatPtr, subPtr, durPtr, numPulses, data.vol, data.mute, data.solo);
                } else {
                    m._live_mixer_update_metronome_pattern(handle, data.id, flatPtr, subPtr, durPtr, numPulses, data.vol, data.mute, data.solo);
                }
                
                if (flatPtr !== 0) m._free(flatPtr);
                if (subPtr !== 0) m._free(subPtr);
                if (durPtr !== 0) m._free(durPtr);
                break;
            }
            case 'removeMetronomePattern':
                m._live_mixer_remove_metronome_pattern(handle, data.id);
                break;
            case 'clearMetronomePatterns':
                m._live_mixer_clear_metronome_patterns(handle);
                break;
            case 'setMetronomePreviewMode':
                m._live_mixer_set_metronome_preview_mode(handle, data.enabled);
                break;
            case 'dispose':
                m._live_mixer_destroy(handle);
                this.mixerHandle = null;
                break;
        }
    }

    process(inputs, outputs, parameters) {
        // Execute pending commands from Dart
        while (this.commandQueue.length > 0) {
            const cmd = this.commandQueue.shift();
            this._processCommand(cmd);
        }

        if (!this.module || !this.mixerHandle || !this.isProcessing) {
            for (let channel = 0; channel < outputs[0].length; ++channel) {
                outputs[0][channel].fill(0.0);
            }
            return true;
        }

        const outputBuffer = outputs[0];
        if (!outputBuffer || outputBuffer.length === 0) return true;
        const framesToProcess = outputBuffer[0].length;
        
        let bytesToAlloc = framesToProcess * 2 * 4; 
        let outputPtr = this.module._malloc(bytesToAlloc);
        
        // C++ audio generation directly on the lowest-latency thread
        let framesWritten = this.module._live_mixer_process(this.mixerHandle, outputPtr, framesToProcess);
        
        if (framesWritten > 0) {
            let leftChannel = outputBuffer[0];
            let rightChannel = outputBuffer.length > 1 ? outputBuffer[1] : null;
            let heapF32 = this.module.HEAPF32;
            let offset = outputPtr / 4;
            
            for (let i = 0; i < framesWritten; ++i) {
                leftChannel[i] = heapF32[offset + i * 2];
                if (rightChannel) {
                    rightChannel[i] = heapF32[offset + i * 2 + 1];
                }
            }
        } else {
            for (let channel = 0; channel < outputs[0].length; ++channel) {
                outputs[0][channel].fill(0.0);
            }
        }
        
        this.module._free(outputPtr);

        // Every 10 ticks (~29ms at 44.1kHz), emit the current time positions up to Dart
        this.ticks++;
        if (this.ticks % 10 === 0) {
            this.port.postMessage({
                type: 'state',
                position: this.module._live_mixer_get_position(this.mixerHandle),
                atomicPosition: this.module._live_mixer_get_atomic_position(this.mixerHandle)
            });
        }

        return true;
    }
}

registerProcessor('live-mixer-worklet', LiveMixerWorkletProcessor);
