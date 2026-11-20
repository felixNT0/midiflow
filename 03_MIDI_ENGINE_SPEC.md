# MIDI Engine Specification

## Supported messages
MVP: Control Change. Add Note On/Off for buttons only if safely implemented. Later: Pitch Bend, Channel Pressure, Program Change, RPN/NRPN and 14-bit CC.

MIDI channels are displayed 1–16; convert correctly to protocol zero-based channel values internally. CC and data values are 0–127.

## Mapping
Each control stores stable ID, type, label, message type, channel, controller number, min/max, inversion, initial normalized value, smoothing/rate limit and optional pickup mode.

Normalize UI input to 0.0–1.0:
`midiValue = round(min + normalizedValue * (max - min))`
Clamp normalized values and MIDI output. Apply inversion before scaling.

## Faders and knobs
- Update UI immediately.
- Send only changed values.
- Rate-limit/coalesce continuous events where needed.
- Always send final gesture value.
- Support fine adjustment on desktop.
- Do not force-send initial values on profile change unless explicitly configured.

## XY pad
Independent X/Y CC and channel mapping; independent range/scaling; large touch target; clear axis labels; avoid perceptible smoothing lag.

## Buttons
Momentary, toggle and latch modes. Momentary CC sends configured on value at press and off value at release. Note buttons must send Note Off on release/cancel and safe cleanup.

## Transports and host routing
- **macOS host:** BLE MIDI via CoreMIDI and the network bridge (virtual source endpoint) are both viable; prefer the bridge for the phone→DAW use case because it does not depend on BLE central quirks.
- **Windows host:** BLE MIDI central support is unreliable in `flutter_midi_command`; the network bridge is effectively required. Windows needs an external virtual MIDI endpoint (Windows MIDI Services or loopMIDI) — see `02_ARCHITECTURE.md` ADR-0001.
- **FL Studio multi-instance:** Kontakt instances inside FL Studio are disambiguated by MIDI channel (or FL channel routing). MIDIFlow profiles should treat channel selection as the instance selector; no FL-specific plugin is required or planned.
- **Bridge protocol:** versioned line-delimited JSON over TCP (`lib/infrastructure/midi/network/bridge_protocol.dart`). Envelope key `v` = protocol version; messages: `hello` (token + controller id/name), `welcome`, `cc` (`ch` 1–16, `cc` 0–127, `val` 0–127), `noteOn`/`noteOff` (`ch`, `n`, `vel`), `ping`/`pong`, `error`, `bye`. Phone sends raw control intent; the bridge performs MIDI encoding and transmission. Never present the socket as a MIDI device.

## Kontakt assignment
Kontakt's own MIDI Learn is authoritative. Guided workflow:
1. Select MIDIFlow control and inspect its CC/channel.
2. Send test CC.
3. In Kontakt right-click target knob/slider → **Learn MIDI CC Automation**.
4. Move the MIDIFlow control.
5. Verify the parameter responds.
6. Save MIDIFlow profile.

For newer NativeUI instruments, provide Automation tab → MIDI Automation → Learn guidance. Do not claim to program Kontakt's internal assignment table automatically.

## Common CC suggestions (editable conventions, not guarantees)
CC1 modulation; CC7 channel volume; CC11 expression; CC64 sustain; CC71 resonance; CC74 brightness/filter; CC91 reverb send. Never imply every library uses these conventions identically.

## Pickup
Only meaningful when MIDI feedback/current target value exists. Do not imply Kontakt sends feedback for every library parameter.

## Diagnostics
Development MIDI monitor: timestamp, direction, port, message type, channel, CC/note and value. Do not log pairing secrets.
