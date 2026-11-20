# MIDIFlow

A local-first cross-platform MIDI controller. Turn a phone or tablet into
a remote control surface — layer faders, on/off toggles, continuous pads,
drum pads, performance knobs, mixer and transport controls — for FL Studio,
Logic Pro, Kontakt instruments and any MIDI-compatible destination.

Built with Flutter. The same codebase runs as the phone controller **and**
as the desktop bridge that creates a real MIDI device your DAW can see.

---

## Features

**Control surface (Play tab)**
- **Instrument** — Kontakt layer volume faders (CC20–27) with per-layer
  On/Off toggles (CC28–35), 12 continuous pads (CC36–47), part volume/pan
- **Transport** — Play/Pause, Stop, Record
- **Performance** — Modulation, Expression, Cutoff, Resonance, Filter Env,
  Attack, Decay, Release, Portamento, Detune, XY Pad, Sustain
- **Drums** — 16 momentary pads (CC48–63)
- **Effects** — 8 assignable knobs + 4 on/off toggles (CC96–107)
- **Mixer** — master + 8 track volume/pan faders
- P1–P8 channel selector retargets instrument controls per FL Studio channel

**Connections**
- **Wi-Fi bridge** — phone ↔ laptop over local TCP; the desktop app creates a
  virtual "MIDIFlow Bridge" MIDI port the DAW selects. Token-paired,
  auto-reconnects.
- **BLE MIDI** — direct phone ↔ BLE MIDI device, no laptop needed.
- **USB MIDI** — direct phone/desktop ↔ USB-MIDI device.

**FL Studio integration**
- Custom Python controller script (`tools/flstudio/device_midiflow.py`)
  handles transport, mixer and channel-rack controls natively, and forwards
  instrument CCs into plugin MIDI port 10 so Kontakt/VSTs receive them as
  real MIDI input for their own Learn workflows.

---

## Quick start

1. **Laptop** — install/run the desktop app (macOS zip in `setup/`, or
   `flutter run -d macos`). The Desktop Bridge screen starts automatically
   and shows a pairing token + address.
2. **Phone** — install the app (Android APK in `setup/`, or
   `flutter run` on iOS). Settings → Connect to computer → enter the
   laptop address + token. Same Wi-Fi network required.
3. **DAW** — see below.

---

## FL Studio setup (one-time)

1. Copy `tools/flstudio/device_midiflow.py` into FL Studio's user data
   folder: `Settings/Hardware/MIDIFlow/` (create the folder if missing).
   Default location:
   `~/Documents/Image-Line/FL Studio/Settings/Hardware/MIDIFlow/` —
   verify against FL's own data-folder setting if customized.
2. Fully quit and reopen FL Studio (scripts load at startup).
3. Options → MIDI Settings → Input = **MIDIFlow Bridge**,
   Controller type = **MIDIFlow**.
4. Transport, mixer and channel-rack controls work automatically.
5. For Kontakt/VST instruments: plugin wrapper settings → MIDI tab →
   **Input port = 10**. Then in Kontakt, right-click a control →
   **Learn MIDI CC** and move the matching MIDIFlow control.

### CC map (MIDI channel 1, or the selected Part channel)

| Control | CCs |
|---|---|
| Layer volumes | 20–27 |
| Layer on/off | 28–35 |
| Continuous pads | 36–47 |
| Drum pads | 48–63 |
| FX knobs | 96–103 |
| FX on/off | 104–107 |
| Performance knobs | 1, 5, 11, 16–19, 64, 71–75, 80 |

## Logic Pro setup

No script needed — "MIDIFlow Bridge" appears as a normal MIDI input.

1. Logic Pro → Settings → MIDI → enable **MIDIFlow Bridge** as input.
2. Software Instrument track with Kontakt receives MIDI directly.
3. Kontakt **Learn MIDI CC** works with no extra setup.
4. Transport/mixer aren't scriptable in Logic — assign them once in
   Logic's Controller Assignments (Environment → Controller Environment,
   learn mode): ch16 CC30 play/pause, CC31 stop, CC32 record, CC14 master.

## Other MIDI connections

- **BLE MIDI** — the app scans for BLE MIDI peripherals on startup;
  connect from the diagnostics device list. No laptop required.
- **USB MIDI** — connect a USB-MIDI interface/device; it appears in the
  device list. Works on phone (USB-C/OTG or Lightning camera adapter)
  and desktop.
- When a direct device is connected and the bridge is not, all controls
  route to that device automatically.

## Building installers

| Platform | Command | Notes |
|---|---|---|
| Android | `flutter build apk --release` | Sideload the APK |
| macOS | `flutter build macos --release` | Zip `build/macos/Build/Products/Release/midiflow.app` |
| Windows | `flutter build windows --release` | Must build **on Windows**; needs loopMIDI or Windows MIDI Services for the virtual port |
| Linux | `flutter build linux --release` | Must build **on Linux** |
| iOS | `flutter build ipa --release` | Needs Apple signing certs; for testing use `flutter run` on a connected iPhone (free 7-day provisioning) |

A GitHub Actions workflow (`.github/workflows/build.yml`) builds APK,
Windows zip, Linux tarball and macOS zip on tag push or manual run.

Prebuilt installers for distribution live in `setup/app-installers/`;
`setup/SETUP.txt` is the end-user setup guide and
`setup/flstudio/device_midiflow.py` is the FL Studio script.

---

## Repository layout

```
lib/
  app/app_shell.dart              # Play + Settings shell (Assign/Profiles commented out)
  application/midi/               # providers: controls, MIDI engine, bridge client/server
  domain/midi/                    # control bank templates, control model
  features/                       # play, settings, bridge, diagnostics, assign, profiles
  infrastructure/midi/            # midi service, device models, network bridge protocol
  shared/controls/                # fader, knob, button, pad widgets
macos/                            # macOS runner (virtual CoreMIDI endpoint)
tools/flstudio/                   # FL Studio controller script
test/                             # widget/unit tests
setup/                            # distribution folder: installers + SETUP.txt + script
```

## Product truth

MIDIFlow sends MIDI — it does not program Kontakt's internals.
A Kontakt parameter must be exposed to MIDI CC (or host automation)
before it can be controlled; assignment is always done through the
target's own Learn workflow. MIDIFlow cannot expose hidden parameters
or guarantee every library uses the same CC map.

## Documentation

The original product/engineering specs remain in this repo:

- `00_MASTER_BUILD_PROMPT.md` — full product brief
- `01_PRODUCT_REQUIREMENTS.md` — scope and acceptance criteria
- `02_ARCHITECTURE.md` — architecture and transport strategy (ADR-0001)
- `03_MIDI_ENGINE_SPEC.md` — MIDI spec and Kontakt assignment workflow
- `04_UX_UI_DESIGN_SYSTEM.md` — UI design system
- `05_DATA_AND_PROFILES.md` — profile schema
- `06_ROADMAP_AND_DELIVERY.md` — phased plan
- `07_TESTING_AND_QA.md` — test matrix
- `08_AI_IDE_RULES.md` — coding-agent rules
- `09_PLATFORM_SETUP.md` — platform setup references

## Research links

- Flutter platforms: https://docs.flutter.dev/reference/supported-platforms
- `flutter_midi_command`: https://pub.dev/packages/flutter_midi_command
- `libremidi_flutter`: https://pub.dev/packages/libremidi_flutter
- Kontakt MIDI Learn: https://docs.native-instruments.com/ni-tech-manuals/kontakt-manual/en/midi-learn
- FL Studio MIDI scripting: https://www.image-line.com/fl-studio-learning/fl-studio-online-manual/html/midi_scripting.htm
