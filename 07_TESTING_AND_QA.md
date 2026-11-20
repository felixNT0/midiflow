# Testing and QA

## Unit tests
Normalized-to-MIDI scaling, inversion, min/max, channel/CC validation, serialization, schema migration, duplicate mappings, button state and XY axis independence.

## Widget tests
Fader/knob gestures, XY pad, momentary release, connection status, assignment flow, profile CRUD and responsive layouts.

## Adapter integration
Enumerate, open/close, send/receive, hotplug, reconnect, permission denial and listener cleanup.

## Hardware matrix
- Samsung Android phone + Apple Silicon Mac
- Android + Windows 10/11
- iPhone/iPad + macOS
- USB class-compliant MIDI device
- BLE MIDI device
- local network bridge (Android phone → macOS bridge → FL Studio/Kontakt)
- local network bridge (Android phone → Windows bridge, when endpoint available)
- two simultaneous bridge controllers (channel collision check)

## Kontakt test
1. Open Kontakt 8 and load an instrument with a visible assignable control.
2. Ensure the MIDIFlow output/desktop bridge is selected as Kontakt input.
3. Right-click parameter → Learn MIDI CC Automation (or use Automation tab Learn).
4. Move the MIDIFlow control.
5. Test low/high values.
6. Save/reload MIDIFlow profile and retest.
7. Repeat for volume, expression, cutoff and any library-exposed release/reverb parameters.

A parameter not exposed by a library is a library limitation, not automatically an app defect.

## Performance
No UI freeze, redundant event flood, stuck notes or lost final values. Measure perceived latency and network jitter — target < 50 ms phone→DAW for bridge path; record measured values in the test report. Run a 30-minute stability session.

## Test report
```text
Platform / OS:
Device:
App build:
Adapter and version:
Transport:
MIDI destination:
Kontakt version:
Library:
Control / CC / channel:
Expected / actual:
Pass or fail:
Notes:
```

## Definition of done
Code, tests, UI states, real MIDI verification where applicable, and documented platform limits. No fake data presented as real connection.
