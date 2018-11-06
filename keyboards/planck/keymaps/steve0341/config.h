#pragma once

#ifdef AUDIO_ENABLE
    #define STARTUP_SONG SONG(PLANCK_SOUND)
    // #define STARTUP_SONG SONG(NO_SOUND)

    #define DEFAULT_LAYER_SONGS { SONG(QWERTY_SOUND), \
                                  SONG(COLEMAK_SOUND), \
                                  SONG(DVORAK_SOUND) \
                                }
#endif

/*
 * MIDI options
 */

/* Prevent use of disabled MIDI features in the keymap */
//#define MIDI_ENABLE_STRICT 1

/* enable basic MIDI features:
   - MIDI notes can be sent when in Music mode is on
*/

#define MIDI_BASIC

/* enable advanced MIDI features:
   - MIDI notes can be added to the keymap
   - Octave shift and transpose
   - Virtual sustain, portamento, and modulation wheel
   - etc.
*/
//#define MIDI_ADVANCED

/* override number of MIDI tone keycodes (each octave adds 12 keycodes and allocates 12 bytes) */
//#define MIDI_TONE_KEYCODE_OCTAVES 2

// Most tactile encoders have detents every 4 stages
#define ENCODER_RESOLUTION 4

// mouse speed parameters

// #define MOUSEKEY_DELAY             150
// #define MOUSEKEY_INTERVAL          50
// #define MOUSEKEY_MAX_SPEED         10
// #define MOUSEKEY_TIME_TO_MAX       20
// #define MOUSEKEY_WHEEL_MAX_SPEED   8
// #define MOUSEKEY_WHEEL_TIME_TO_MAX 40

#define MOUSEKEY_MOVE_MAX       127
#define MOUSEKEY_WHEEL_MAX      127

#ifndef MOUSEKEY_MOVE_DELTA
#define MOUSEKEY_MOVE_DELTA     5
#endif
#ifndef MOUSEKEY_WHEEL_DELTA
#define MOUSEKEY_WHEEL_DELTA    1
#endif
#ifndef MOUSEKEY_DELAY
#define MOUSEKEY_DELAY 0
#endif
#ifndef MOUSEKEY_INTERVAL
#define MOUSEKEY_INTERVAL 30
#endif
#ifndef MOUSEKEY_MAX_SPEED
#define MOUSEKEY_MAX_SPEED 14
#endif
#ifndef MOUSEKEY_TIME_TO_MAX
#define MOUSEKEY_TIME_TO_MAX 25
#endif
#ifndef MOUSEKEY_WHEEL_MAX_SPEED
#define MOUSEKEY_WHEEL_MAX_SPEED 6
#endif
#ifndef MOUSEKEY_WHEEL_TIME_TO_MAX
#define MOUSEKEY_WHEEL_TIME_TO_MAX 40
#endif
