# Product Requirements

## Product
MIDIFlow is a local-first cross-platform MIDI controller. It gives musicians customizable touch faders, knobs, buttons and XY pads to control exposed parameters in Kontakt, DAWs and MIDI-compatible devices.

## Primary user/job
A keyboardist or producer who wants quick access to volume, expression, modulation, cutoff, resonance, attack, release, reverb and other parameters while performing—without repeatedly navigating a Kontakt library interface.

## Principles
1. Play screen first.
2. Setup should be short and guided.
3. Real MIDI, not simulated success.
4. Portable local profiles.
5. Honest platform and library compatibility.
6. Avoid feature creep.

## MVP must-have
- Flutter app architecture for Android, iOS/iPadOS, macOS and Windows.
- Real MIDI port discovery and output on implemented platforms.
- CC output on 16 channels, values 0–127.
- Faders, knobs, buttons and XY pad.
- Manual CC/channel assignment.
- Guided Kontakt MIDI Learn workflow.
- Local profile create/edit/duplicate/delete.
- JSON import/export and schema validation.
- Connection status, hotplug and reconnect.
- Responsive phone/tablet/desktop UI.
- MIDI input monitor where supported.

## Later
BLE MIDI and network bridge on validated platform combinations; bidirectional DAW feedback; Program Change; NRPN/RPN; 14-bit CC; MIDI 2.0; profile sharing if a backend becomes justified.

## Non-goals
Audio playback, synthesis, sampling, DAW, piano roll, sequencing, recording, library browsing, automatic reverse engineering, hidden parameter discovery, login/subscriptions/cloud sync in MVP.

## Acceptance criteria
- Profile persists across app restart.
- Fader/knob sends correct CC values 0–127.
- XY axes send independent mappings.
- Momentary button sends press and release values.
- No stuck Note On.
- Manual CC/channel setup works.
- Kontakt receives CC through a real selected MIDI input.
- User can bind a Kontakt control using Kontakt's Learn workflow.
- Device disconnect does not crash app.
- App never says “Kontakt assigned” solely because it sent a CC.
