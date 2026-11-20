# Architecture

## Decision
Flutter/Dart for shared UI, state, domain and profile logic. Native/plugin MIDI adapters behind a platform-neutral contract. Do not couple UI to a specific MIDI package.

## Suggested structure
```text
lib/
  main.dart
  app/                 # bootstrap, router, theme
  core/                # errors, logging, utilities
  domain/
    midi/ controls/ profiles/ connection/
  application/
    connection/ controller/ assignment/ profiles/
  infrastructure/
    midi/
      midi_adapter.dart
      plugin_adapter/
      native_adapter/
      network/
        bridge_protocol.dart      # versioned phone→bridge message envelope
        bridge_client.dart        # mobile-side sender
      bridge/                     # desktop bridge server mode (same app)
    storage/
  features/
    play/ assign/ profiles/ settings/ diagnostics/
  shared/
    widgets/ controls/
test/
  unit/ widget/ integration/
```

## Adapter contract
Define a platform-independent interface for:
- enumerate input/output ports;
- port added/removed events;
- open/close ports;
- send MIDI messages;
- subscribe to input messages;
- report capabilities, connection and errors;
- dispose resources.

Exact signatures must be adapted to the chosen package API.

## Package candidates
Evaluate current `flutter_midi_command` and `libremidi_flutter`. Check package source, changelog, examples, minimum OS versions, permissions, license and actual hardware. `flutter_midi_command` currently documents USB across Android/iOS/macOS/Windows/Linux, BLE on Android/iOS/macOS/Windows, virtual MIDI on Apple platforms and Android, and network sessions on Apple platforms. `libremidi_flutter` documents MIDI input/output and hotplug across Android/iOS/macOS/Windows/Linux, but says it does not ship its own BLE stack. Verify all of this against the version you install.

## Transport
USB requires compatible host/device role, cable/adapter, power and OS support. BLE must use the standard BLE MIDI profile. Network MIDI must distinguish RTP-MIDI from a custom app-to-desktop bridge.

If a phone sends app events over Wi-Fi, a desktop companion must convert them into actual OS MIDI messages and expose a MIDI input that Kontakt can select. A socket alone is not a MIDI device.

## Primary use case (clarified)
The primary persona is a performer running FL Studio + Kontakt on a laptop while playing a physical keyboard, using a phone/tablet as a remote control surface for instrument parameters. The phone does not need to be a USB MIDI host; it needs a path to the DAW. Direct USB/BLE MIDI transports remain supported but are secondary to the desktop bridge for this use case.

## Desktop bridge decision (ADR-0001)
The bridge runs inside the same Flutter app as a desktop entrypoint (`lib/app/bridge_main.dart`), reusing `MidiService` and the profile/control model.

- **macOS/iOS (darwin plugin):** `MidiCommand.addVirtualDevice(name:)` creates an "own-virtual" endpoint pair; the virtual *source* publishes MIDI that other apps see as a real input (verified in `flutter_midi_command_darwin` Swift sources — `MIDISourceCreate` + `MIDIReceived`). This gives a pure-Flutter bridge path on macOS. The Dart doc comment saying "iOS only" is stale; the implementation is shared across darwin.
- **Windows:** `flutter_midi_command_windows` explicitly does not implement virtual device creation or network sessions. The bridge must target an externally provided endpoint (Windows MIDI Services virtual endpoints where available, or loopMIDI as a documented prerequisite) and send to that device by ID. A small native helper may be required later; do not block the protocol design on it.
- **Android as bridge host:** not supported (no virtual endpoint creation in the Android backend).
- **iOS as bridge host:** `addVirtualDevice` works, but iOS background suspension makes it unreliable as a bridge; treat iOS bridge as experimental.

Bridge protocol requirements: versioned JSON or compact binary envelope, explicit pairing token, local-network scope only, reconnect with backoff, per-session controller ID (multiple phones), rate limiting, and channel-per-controller guidance to avoid CC collisions in the DAW.

## Desktop
Test direct MIDI endpoint creation on macOS and Windows. macOS CoreMIDI/IAC can help with routing. On Windows, evaluate Windows MIDI Services and available virtual MIDI endpoints. If a desktop Flutter app cannot provide the required endpoint, implement a small native companion/helper.

## State and persistence
Use Riverpod or document an alternative. Keep high-frequency controller updates targeted to avoid rebuilding the whole UI. Use SQLite/local persistence; JSON is the portable profile format. Never include pairing secrets in exported profiles.

## Reliability
Handle hotplug, lifecycle, permissions, reconnect, listener cancellation, port disposal, rate limiting, duplicate events and errors. Do not report connected until the output port is actually open.
