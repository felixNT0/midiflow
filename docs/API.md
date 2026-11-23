# MIDIFlow API Documentation

## Overview

MIDIFlow is a professional remote MIDI controller application built with Flutter.
It provides real-time MIDI control over Wi-Fi, Bluetooth LE, and USB connections.

## Architecture

### Layer Structure

```
lib/
├── application/          # Business logic and state management
│   ├── midi/            # MIDI-related providers and controllers
│   ├── settings/        # Theme and app settings
│   └── sequencer/       # Sequence recording and playback
├── domain/              # Core domain models and logic
│   └── midi/            # MIDI control definitions and mappings
├── features/            # UI screens and widgets
│   ├── play/            # Main control surface
│   ├── settings/        # Configuration screens
│   ├── assign/          # Control assignment interface
│   ├── profiles/        # Profile management
│   ├── bridge/          # Desktop bridge interface
│   ├── ble/             # BLE MIDI connection
│   ├── usb/             # USB MIDI connection
│   ├── diagnostics/     # MIDI monitoring and testing
│   ├── guide/           # In-app documentation
│   └── sequencer/       # Sequence recorder UI
├── infrastructure/      # External service integrations
│   ├── midi/            # MIDI device and message handling
│   │   └── network/     # Bridge protocol and networking
│   ├── logging/         # Application logging
│   └── storage/         # Data persistence
└── shared/              # Shared UI components and utilities
```

## Core Components

### MIDI Service

The `MidiService` class is the central MIDI engine that manages device connections and message routing.

#### Key Methods

```dart
// Initialize MIDI service
await midiService.initialize();

// Discover devices
final devices = await midiService.refreshDevices();

// Connect to device
await midiService.connect(device);

// Disconnect from device
midiService.disconnect(device);

// Send MIDI messages
await midiService.sendControlChange(
  device: device,
  channel: 1,
  controller: 7,
  value: 100,
);

// Send note messages
await midiService.sendNoteOn(
  device: device,
  channel: 1,
  note: 60,
  velocity: 100,
);
```

#### Connection Modes

The app supports three connection modes:

- **Wi-Fi Bridge**: TCP connection on port 8765
- **BLE MIDI**: Bluetooth LE MIDI standard
- **USB MIDI**: Direct hardware connection

### Bridge Protocol

The bridge protocol is a versioned JSON-based protocol for Wi-Fi connections.

#### Message Types

- `hello`: Client authentication
- `welcome`: Server acknowledgment
- `cc`: Control Change messages
- `noteOn`/`noteOff`: Note messages
- `ping`/`pong`: Connection keepalive
- `error`: Error reporting
- `bye`: Graceful disconnect

#### Security

- Pairing token authentication
- Rate limiting (240 messages/second)
- Message size limits (4KB)
- Local network only

### Control System

The control system manages MIDI mappings for all UI controls.

#### Control Types

- `fader`: Continuous value controls
- `knob`: Rotary controls
- `momentaryButton`: Push buttons
- `toggleButton`: On/off switches
- `latchButton`: Sticky buttons
- `xyPad`: 2D control surface

#### MIDI Mapping

Each control has a `ControlMapping` that defines:

- `channel`: MIDI channel (1-16)
- `controller`: CC number (0-127)
- `minValue`/`maxValue`: Value range
- `inverted`: Reverse direction

### State Management

The app uses Riverpod for state management with the following providers:

#### MIDI Provider

```dart
final midiControllerProvider = NotifierProvider<MidiController, MidiState>();
```

Manages device connections, MIDI state, and message routing.

#### Controls Provider

```dart
final controlsProvider = NotifierProvider<ControlsController, ControlsState>();
```

Manages control configurations, labels, and persistence.

#### Bridge Provider

```dart
final bridgeClientProvider = NotifierProvider<BridgeClientController, BridgeClientState>();
```

Manages Wi-Fi bridge client connections.

#### BLE Bridge Provider

```dart
final bleBridgeProvider = NotifierProvider<BleBridgeController, BleBridgeState>();
```

Manages BLE MIDI peripheral for desktop bridge.

## Data Models

### MidiDeviceInfo

```dart
class MidiDeviceInfo {
  final String id;
  final String name;
  final MidiDeviceKind kind;
  final List<MidiPort> inputPorts;
  final List<MidiPort> outputPorts;
  final MidiDeviceConnectionState connectionState;
}
```

### MidiControl

```dart
class MidiControl {
  final String id;
  final String label;
  final MidiControlType type;
  final ControlMapping mapping;
  final ControlMapping? xMapping;
  final ControlMapping? yMapping;
}
```

### ControlBank

```dart
class ControlBank {
  final String id;
  final String name;
  final List<MidiControl> controls;
}
```

## Persistence

### SharedPreferences

The app uses SharedPreferences for local data persistence:

- Control labels and values
- User profiles
- Connection preferences
- App settings

### Profile System

Profiles allow saving and loading different control layouts:

```dart
// Save profile
await profileService.saveProfile(name, state);

// Load profile
final profile = await profileService.loadProfile(name);
```

## Logging

The app includes a centralized logging system:

```dart
// Log messages
appLogger.debug('Debug message');
appLogger.info('Info message');
appLogger.warning('Warning message');
appLogger.error('Error message', error, stackTrace);
```

## Testing

### Unit Tests

```bash
flutter test
```

### Widget Tests

```bash
flutter test test/widget_test.dart
```

### Integration Tests

```bash
flutter test integration_test/
```

## Build Configuration

### Android

```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

### macOS

```bash
flutter build macos --release
```

### Windows

```bash
flutter build windows --release
```

### Linux

```bash
flutter build linux --release
```

## Dependencies

### Core Dependencies

- `flutter_riverpod`: State management
- `flutter_midi_command`: MIDI device communication
- `flutter_midi_command_ble`: BLE MIDI support
- `universal_ble`: BLE peripheral mode
- `shared_preferences`: Local storage
- `flutter_markdown_plus`: Markdown rendering

### Development Dependencies

- `flutter_test`: Testing framework
- `flutter_lints`: Code analysis

## Security Considerations

### Network Security

- Local network only for Wi-Fi bridge
- Pairing token authentication
- Rate limiting on messages
- No external network access

### Data Security

- No sensitive data stored locally
- Profiles stored in SharedPreferences
- No cloud synchronization

### BLE Security

- BLE MIDI standard encryption
- Device pairing required
- No sensitive data transmitted

## Performance

### Optimization

- Tree-shaking for unused code
- ProGuard/R8 for Android
- Asset optimization
- Lazy loading for large lists

### Memory Management

- Stream controllers properly disposed
- Provider lifecycle management
- Efficient state updates

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Supported | API 21+ |
| iOS | ✅ Supported | iOS 12+ |
| macOS | ✅ Supported | macOS 10.15+ |
| Windows | ✅ Supported | Windows 10+ |
| Linux | ✅ Supported | Ubuntu 20.04+ |

## Troubleshooting

### Common Issues

#### Connection Problems

- Check network connectivity
- Verify pairing token
- Ensure firewall allows connection
- Try different connection mode

#### MIDI Not Working

- Check DAW MIDI settings
- Verify plugin MIDI port
- Test with MIDI monitor
- Re-learn controls if needed

#### App Crashes

- Check logs for errors
- Clear app data
- Reinstall if needed
- Report bug with logs

## Contributing

### Development Setup

```bash
# Clone repository
git clone https://github.com/felixNT0/midiflow.git

# Install dependencies
flutter pub get

# Run in development mode
flutter run
```

### Code Style

- Follow Flutter/Dart style guide
- Use `flutter analyze` for linting
- Write tests for new features
- Update documentation

### Pull Requests

- Create feature branch
- Write clear commit messages
- Include tests
- Update documentation

## License

This project is licensed under the MIT License.

## Support

For support and questions:

- GitHub Issues: https://github.com/felixNT0/midiflow/issues
- Documentation: README.md
- In-app guide: Settings → App Guide
