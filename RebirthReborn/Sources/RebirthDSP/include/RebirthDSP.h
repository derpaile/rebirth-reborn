#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct RBEngine RBEngine;
RBEngine *rb_create(void);
void rb_destroy(RBEngine *engine);
// Commands are queued from one UI thread; applied by the audio thread.
int rb_parameter(RBEngine *engine, int device, int parameter, float value);
int rb_note_step(RBEngine *engine, int device, int step, int midiNote, int enabled, int accent, int slide);
int rb_drum_step(RBEngine *engine, int device, int lane, int step, int enabled, float velocity);
int rb_drum_step_strength(RBEngine *engine, int device, int lane, int step, int enabled, float velocity, int strong);
int rb_sample(RBEngine *engine, int device, int lane, int sampleIndex);
int rb_drum_parameter(RBEngine *engine, int device, int parameter, int value);
int rb_drum_accent(RBEngine *engine, int device, int step, int accented);
// Effects: 0 Distortion [on, amount, shape]; 1 Delay [on, steps, straight, feedback, pan];
// 2 Compressor [on, ratio, threshold]; 3 PCF [on, freq, Q, amount, pattern, decay, lowpass].
// All continuous controls are original integers 0..127; PCF pattern is 0..54.
int rb_effect_parameter(RBEngine *engine, int effect, int parameter, int value);
int rb_channel_effects(RBEngine *engine, int device, int delaySend, int distortion);
// PCF: 0 none, 1..4 devices. Compressor: 0 none, 1 master, 2..5 devices.
int rb_effect_routes(RBEngine *engine, int pcf, int compressor);
int rb_pattern_meta(RBEngine *,int device,int pattern,int length,int shuffled);
int rb_pattern_select(RBEngine *,int device,int pattern,int enabled);
int rb_note_pattern_step(RBEngine *,int device,int pattern,int step,int midi,int enabled,int accent,int slide);
int rb_drum_pattern_step(RBEngine *,int device,int pattern,int lane,int step,int strength);
int rb_drum_pattern_accent(RBEngine *,int device,int pattern,int step,int accent);
int rb_channel_enabled(RBEngine *,int device,int enabled);
int rb_song_clear(RBEngine *);
int rb_song_event(RBEngine *,int tick,int device,int parameter,int value);
int rb_song_mode(RBEngine *,int enabled,int loopStart,int loopEnd,int looping);
int rb_current_device_step(RBEngine *,int device);
int rb_current_pattern(RBEngine *,int device);
int rb_is_playing(RBEngine *);
uint32_t rb_faults(RBEngine *);
int rb_tick(RBEngine *);
int rb_seek(RBEngine *,int tick);
int rb_midi_sync(RBEngine *,int enabled);
int rb_midi_clock(RBEngine *);
int rb_song_notes_clear(RBEngine *);
int rb_song_note_event(RBEngine *,int tick,int device,int note,int velocity,int on);
int rb_song_baseline(RBEngine *,int device,int parameter,int value);
int rb_controller(RBEngine *,int device,int parameter);
int rb_set_controller(RBEngine *,int device,int parameter,int value);
int rb_quality(RBEngine *,int highQuality);
int rb_live_note(RBEngine *,int device,int midi,int on,int accent,int slide);
int rb_live_drum(RBEngine *,int device,int lane,float velocity,int accent,int strong);
// Sample mutation requires rendering stopped; the bank commits all 46 slots atomically.
typedef struct RBSampleBank RBSampleBank;
RBSampleBank *rb_sample_bank_create(void);
void rb_sample_bank_destroy(RBSampleBank *bank);
int rb_sample_bank_aiff(RBSampleBank *,int sampleIndex,const uint8_t *bytes,uint32_t length);
int rb_sample_bank_commit(RBEngine *,RBSampleBank *);
int rb_load_aiff(RBEngine *engine, int sampleIndex, const char *path);
void rb_render(RBEngine *engine, float *left, float *right, uint32_t frames);
int rb_current_step(RBEngine *engine);
float rb_peak(RBEngine *engine);
#ifdef __cplusplus
}
#endif
