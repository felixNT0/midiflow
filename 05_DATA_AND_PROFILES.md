# Data Model and Profiles

## Principles
Local-first; versioned JSON import/export; stable IDs; validation; migrations; never export device pairing secrets.

## Example JSON
```json
{
  "schemaVersion": 1,
  "profileId": "warm-pad-example",
  "name": "Warm Worship Pad",
  "instrument": "User's Kontakt Library",
  "createdAt": "2026-01-01T00:00:00Z",
  "updatedAt": "2026-01-01T00:00:00Z",
  "controls": [
    {
      "id": "volume",
      "label": "Volume",
      "type": "fader",
      "messageType": "controlChange",
      "channel": 1,
      "controller": 7,
      "min": 0,
      "max": 127,
      "inverted": false,
      "initialNormalizedValue": 0.8,
      "smoothingMs": 0
    },
    {
      "id": "cutoff",
      "label": "Cutoff",
      "type": "knob",
      "messageType": "controlChange",
      "channel": 1,
      "controller": 74,
      "min": 0,
      "max": 127,
      "inverted": false,
      "initialNormalizedValue": 0.5,
      "smoothingMs": 0
    },
    {
      "id": "expression-pad",
      "label": "Expression Pad",
      "type": "xyPad",
      "xMapping": {"messageType": "controlChange", "channel": 1, "controller": 1, "min": 0, "max": 127},
      "yMapping": {"messageType": "controlChange", "channel": 1, "controller": 11, "min": 0, "max": 127}
    }
  ]
}
```

This is illustrative. Implement typed Dart models and validate all fields.

## Control types
`fader`, `knob`, `momentaryButton`, `toggleButton`, `latchButton`, `xyPad`.

## Operations
Create, list/search, update, duplicate, delete with confirmation, import, export, migrate.

## Validation
Validate file size, schema version, unique IDs, channel 1–16, CC/data 0–127, supported types and ranges. Reject unknown message types safely. Never execute imported content or allow path traversal.
