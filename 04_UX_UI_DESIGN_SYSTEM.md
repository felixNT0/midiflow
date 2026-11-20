# UX / UI Design System

## Design goal
A musician should understand the app at a glance while playing. The controller is the product; configuration is secondary.

## Visual language
Dark studio theme: deep navy/charcoal surfaces, restrained teal/cyan accent, readable white text and muted grey secondary labels. High contrast, minimal shadows, no clutter, no excessive neon/gradients/glassmorphism.

## Navigation
Four destinations: **Play**, **Assign**, **Profiles**, **Settings**. Play is the default after connection/profile selection.

## Play
Header: MIDIFlow, actual connection status, active profile, connection shortcut.
Main area: customizable fader bank, knob grid, optional XY pad and performance buttons.
Each control has a large hit target, editable label and value display. Hide technical CC/channel details until edit mode.

Phone portrait: prioritize a few large faders and 2–3-column knob grid. Landscape/tablet: show more controls. Desktop: resizable layout, wider control grid and optional profile rail.

## Assign
One clear flow: select/add control → choose type → set CC/channel → send test CC → follow Kontakt Learn steps → user verifies → save. Clearly distinguish “MIDI sent” from “Kontakt parameter assigned”. Include manual CC entry.

## Profiles
Searchable cards with instrument label and control count. Create, rename, duplicate, delete, import/export. Mark sample profiles as examples.

## Settings
MIDI input/output, transport, default channel, reconnect, response/smoothing, haptics, theme and diagnostics.

## Control interaction
- Fader: visible track/thumb, value, min/max, mouse and touch.
- Knob: predictable rotary gesture, large hit target, accessible value; optional reset with confirmation.
- XY: large area, visible marker and axis labels.
- Button: visibly distinguish momentary/toggle/latch; safely release on gesture cancellation.

## Accessibility
Aim for 44–48 logical-pixel touch targets, semantic labels, visible desktop focus, keyboard navigation and adequate contrast. Do not rely on colour alone.

## Microcopy
“Connect device”, “Choose profile”, “Add control”, “Send test CC”, “Start Learn guide”, “Save profile”, “Not connected”, “Waiting for Kontakt”, “Control ready”.
