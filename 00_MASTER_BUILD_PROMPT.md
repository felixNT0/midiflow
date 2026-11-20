# MASTER AI IDE PROMPT — Build MIDIFlow

Act as a principal Flutter engineer, MIDI systems engineer, product designer and QA lead. Build **MIDIFlow**, a production-quality cross-platform MIDI control surface. Read all project Markdown specifications before coding and follow `08_AI_IDE_RULES.md`.

## Product vision
MIDIFlow is primarily a **remote performance controller**: a musician plays a physical keyboard into a laptop running FL Studio + Kontakt while using a phone/tablet running MIDIFlow to control instrument parameters in real time. It also works as a general customizable MIDI controller for Kontakt libraries, DAWs, plugins and compatible hardware. The phone→desktop network bridge (real OS MIDI endpoint, never a bare socket) is a first-class transport, not an afterthought.

The core workflow:
1. Connect to a real MIDI destination.
2. Open or create an instrument profile.
3. Add a fader, knob, button or XY pad.
4. Set its outgoing MIDI CC/channel.
5. Use Kontakt's own MIDI Learn/Automation workflow to bind that CC to a parameter.
6. Save the MIDIFlow profile.
7. Return to Play and perform.

MIDIFlow is a controller, not a DAW, synthesizer, sampler, audio player or Kontakt library browser. Do not add a backend, accounts, subscriptions, cloud sync, sequencing, recording or audio processing to the MVP.

## Target platforms
Android, iOS/iPadOS, macOS and Windows 10/11. Use Flutter + Dart for shared UI/domain logic. Use platform-specific MIDI adapters behind an abstraction. Prioritize Android + macOS for the first hardware proof, but preserve cross-platform architecture.

## Required architecture
Feature-first Flutter project:
- `app/`: bootstrap, routing, theme
- `core/`: errors, logging, utilities
- `domain/`: MIDI messages, controls, profiles, connection models
- `application/`: use cases and state
- `infrastructure/midi/`: plugin/native adapters and network bridge
- `infrastructure/storage/`: local profile repository
- `features/play/`, `assign/`, `profiles/`, `settings/`, `diagnostics/`
- `shared/widgets/` and `shared/controls/`

Use Riverpod unless there is a documented reason not to. Keep UI widgets independent of package-specific MIDI types. Define an adapter interface for port discovery, hotplug events, opening/closing ports, sending/receiving messages, transport capabilities and connection/error state.

Evaluate `flutter_midi_command` and `libremidi_flutter` against current docs, APIs, platform matrix, maintenance, licensing and actual device tests. Do not invent package APIs or assume support is identical on every OS. Pin a version only after validation.

## Transport rules
- USB: class-compliant USB MIDI where host/device roles, cables, power and OS support permit.
- BLE: use the standard BLE MIDI profile and platform permissions/pairing.
- Network: distinguish Apple RTP-MIDI/Network MIDI from a MIDIFlow local network bridge.
- A WebSocket is not a MIDI port. If phone events travel over a network, a desktop companion must translate them into real OS MIDI output/virtual MIDI that Kontakt can select.
- Pair network clients explicitly; use local-network scope, pairing token, validation, rate limits and reconnect handling.
- Never claim a transport works on a platform until tested.

## MIDI requirements
MVP:
- Control Change (CC), 16 channels, values 0–127
- faders, rotary knobs, momentary/toggle buttons and continuous XY pad
- per-control CC, channel, min/max, inversion and initial value
- manual assignment and test CC
- input monitor where supported
- device discovery, connect/disconnect and hotplug
- local profiles and JSON import/export

Should-have: Pitch Bend, channel pressure, smoothing/rate limiting, pickup/soft takeover where feedback exists. Later: Program Change, NRPN/RPN, 14-bit CC, MIDI 2.0.

Never leave Note On active; send Note Off on release/cancel/cleanup. Clamp MIDI values. Do not send unchanged values repeatedly. Keep MIDI work off the UI thread.

## Kontakt workflow — be accurate
MIDIFlow does not automatically edit Kontakt's internal assignment database. The supported flow is:
1. User selects a MIDIFlow control.
2. App shows its outgoing CC and channel and sends a test value.
3. In Kontakt, user right-clicks the target knob/slider and chooses **Learn MIDI CC Automation**.
4. User moves the MIDIFlow control.
5. User tests the range and saves the MIDIFlow profile.

For NativeUI instruments, offer the Automation-tab Learn workflow as an alternative. Provide concise instructions in the app. Do not mark an assignment complete until the user confirms that the Kontakt parameter responds.

## Four primary screens
### PLAY
Default screen. Active profile, real connection status, fader bank, knob grid, optional XY pad and performance buttons. Show names and values. Keep clutter low.

### ASSIGN
Select/add control, choose type, CC and channel, send test CC, show Kontakt Learn instructions, manual fallback, Save/Cancel. Distinguish “MIDI sent” from “Kontakt parameter assigned”.

### PROFILES
Create, rename, duplicate, delete, search, import/export. Show instrument label and control count. Mark bundled examples as examples.

### SETTINGS
MIDI input/output, transport, channel default, reconnect, smoothing, haptics, theme and diagnostics.

## UX
Premium but restrained dark studio interface: charcoal/deep navy, teal/cyan accent, high-contrast text, large touch targets, clear labels. Avoid excessive gradients, neon, glass effects and decorative audio graphics. Phone portrait: readable faders and 2–3-column knobs. Landscape/tablet: more controls visible. Desktop: resizable window, wider grid and optional profile rail. Support mouse, keyboard focus and screen readers where practical.

## Profiles
Local-first, versioned JSON. Store profile ID/name/instrument/timestamps and controls. Each control stores ID, label, type, MIDI message type, channel, CC/note, min/max, inversion, initial value, smoothing, pickup and button behavior. Validate imported files and never import executable content or secrets.

## Quality
Real connection states only. Handle permission denial, device removal, reconnect, app lifecycle, duplicate listeners and resource disposal. Add unit tests for scaling/validation/serialization, widget tests for gestures, integration tests for adapters, and real hardware tests. No fake connection state or silent exceptions.

## Required milestones
0. Environment discovery, package comparison, architecture decision and real MIDI loopback proof.
1. UI foundation and responsive control widgets.
2. MIDI adapter, ports, CC output/input monitor and hotplug.
3. Play/Assign and Kontakt 8 validation.
4. Local profiles, CRUD, JSON import/export and migrations.
5. Desktop bridge/virtual MIDI endpoint if direct mobile-to-host MIDI is unavailable.
6. BLE/USB/network hardening, iOS/Windows validation and packaging.

At every milestone: format, analyze, test, build available targets, report exact changes, test results, limitations and next steps. Never mark an unverified platform complete.

## First task: Milestone 0 only
Inspect toolchains and repository; read all docs; compare packages; create an architecture decision record; scaffold Flutter targets; enumerate MIDI ports; send/receive a real test CC on available hardware/loopback; document exact commands, test results and gaps. Do not build the full UI until the MIDI proof is reviewed.
