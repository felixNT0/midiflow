# Roadmap and Delivery

## Phase 0 — Technical proof
Inspect Flutter/Dart/Xcode/Android SDK and Windows build environment. Compare MIDI packages and current platform matrices. Scaffold Flutter targets. Enumerate ports and send/receive a real test CC via loopback or hardware. Document limitations.
**Exit:** at least one real MIDI send/receive path works; no mocked success.

## Phase 1 — UI foundation
Theme, responsive shell, Play/Assign/Profiles/Settings, fader/knob/button/XY widgets, accessibility and widget tests.
**Exit:** usable phone and desktop layouts; no fake connection state.

## Phase 2 — MIDI engine
Adapter, port discovery, connect/disconnect, CC output, input monitor, hotplug and reconnect. **Includes bridge feasibility proof:** verify the macOS virtual source endpoint is visible to other apps (e.g. Audio MIDI Setup / FL Studio) and document the Windows endpoint prerequisite.
**Exit:** correct CC values verified, disconnect handled, and bridge virtual endpoint confirmed selectable as a MIDI input on at least macOS.

## Phase 3 — Desktop bridge
Bridge protocol, pairing, mobile client, desktop server mode, virtual endpoint injection, reconnect, multi-controller sessions, latency measurement. Test Android→macOS end-to-end into FL Studio/Kontakt.
**Exit:** Kontakt receives bridge MIDI on a real OS endpoint; reconnect works; latency measured.

## Phase 4 — Kontakt workflow
Manual mapping, guided Learn, test CC, assignment verification and Kontakt 8 standalone/plugin testing inside FL Studio.
**Exit:** real Kontakt parameter responds after user completes Kontakt Learn.

## Phase 5 — Profiles
Typed models, local persistence, CRUD, JSON import/export, migration and examples.
**Exit:** profile survives restart and round-trips; malformed files rejected.

## Phase 6 — Cross-platform hardening
BLE/USB/network on validated platform combinations, iOS permissions, Windows MIDI Services compatibility, packaging, accessibility and performance.
**Exit:** per-platform test report and documented limitations.

## Every milestone
Format, analyze, test, build available targets, report files changed, tests passed, unverified behavior and next task. Never call a generated file or untested platform a completed feature.
