# MIDIFlow AI Development Kit

MIDIFlow is a cross-platform MIDI control surface for musicians who want phone, tablet or desktop faders, knobs, buttons and XY pads to control Kontakt instruments, DAWs and compatible MIDI devices.

## Files
- `00_MASTER_BUILD_PROMPT.md` — complete instruction to your AI IDE.
- `01_PRODUCT_REQUIREMENTS.md` — product scope and acceptance criteria.
- `02_ARCHITECTURE.md` — Flutter architecture and MIDI transport strategy.
- `03_MIDI_ENGINE_SPEC.md` — MIDI messages, controls and Kontakt assignment workflow.
- `04_UX_UI_DESIGN_SYSTEM.md` — screen layouts and visual design.
- `05_DATA_AND_PROFILES.md` — profile schema and persistence.
- `06_ROADMAP_AND_DELIVERY.md` — phased build plan.
- `07_TESTING_AND_QA.md` — test matrix and definition of done.
- `08_AI_IDE_RULES.md` — persistent coding-agent rules.
- `09_PLATFORM_SETUP.md` — setup and technical references.

## Use
1. Create a Git repository named `midiflow`.
2. Copy this folder's contents into `/docs`; keep `08_AI_IDE_RULES.md` at the repository root as well.
3. Open the repository in Cursor, Windsurf, Claude Code, Codex or your preferred AI IDE.
4. Paste `00_MASTER_BUILD_PROMPT.md` into the agent.
5. Ask it to do Milestone 0 only. Review the technical proof before proceeding.

## Critical product truth
MIDIFlow sends MIDI. Kontakt performs its own MIDI Learn assignment. A Kontakt library parameter must be exposed to MIDI CC or host automation before it can be controlled. MIDIFlow cannot automatically expose hidden parameters or guarantee that every third-party library uses the same CC mapping.

## Research links
- Flutter platforms: https://docs.flutter.dev/reference/supported-platforms
- `flutter_midi_command`: https://pub.dev/packages/flutter_midi_command
- `libremidi_flutter`: https://pub.dev/packages/libremidi_flutter
- Kontakt MIDI Learn: https://docs.native-instruments.com/ni-tech-manuals/kontakt-manual/en/midi-learn
