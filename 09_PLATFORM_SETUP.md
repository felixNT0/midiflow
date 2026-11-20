# Platform Setup and References

## Flutter
- Install: https://docs.flutter.dev/install
- Supported platforms: https://docs.flutter.dev/reference/supported-platforms
- Desktop: https://docs.flutter.dev/platform-integration/desktop

Flutter supports Android, iOS, macOS and Windows, but platform builds require their respective toolchains. iOS/macOS builds require macOS and Xcode; Windows desktop builds require Windows tooling.

## MIDI package candidates — verify before selecting
### flutter_midi_command
https://pub.dev/packages/flutter_midi_command
Current package documentation describes USB on Android/iOS/macOS/Linux/Windows; BLE on Android/iOS/macOS/Windows; virtual MIDI on Apple platforms and Android; network sessions on Apple platforms. BLE is provided through the optional `flutter_midi_command_ble` package in current documentation. Verify exact package versions, setup and APIs.

### libremidi_flutter
https://pub.dev/packages/libremidi_flutter
Current package documentation describes MIDI input/output and hotplug across Android/iOS/macOS/Windows/Linux. It states that it does not ship its own BLE stack; OS pairing/transport exposure applies. Verify the exact release and platform behavior.

## Kontakt
- MIDI Learn: https://docs.native-instruments.com/ni-tech-manuals/kontakt-manual/en/midi-learn
- Kontakt 8 guide: https://docs.native-instruments.com/pdf-guides/kontakt/Kontakt_8_6_User_Guide_English.pdf

Kontakt supports right-clicking a knob/slider and selecting “Learn MIDI CC Automation”, then moving the external MIDI control. Newer NativeUI instruments may use the Automation tab's Learn button. MIDIFlow should guide the user through Kontakt's own assignment.

## Native MIDI APIs
- Apple CoreMIDI: https://developer.apple.com/documentation/CoreMIDI
- Windows MIDI Services: https://microsoft.github.io/MIDI/
- Windows MIDI developer guide: https://learn.microsoft.com/en-us/windows/apps/develop/media-authoring-processing/midi

## Transport cautions
USB requires compatible host/device roles, cable/adapter, power and OS support. BLE must use standard BLE MIDI. Network MIDI must distinguish RTP-MIDI from a custom app-to-desktop bridge. A WebSocket is not itself a MIDI port; a desktop helper must emit real OS MIDI messages to a port Kontakt can select.

## Environment commands
```bash
flutter doctor -v
flutter devices
flutter create --platforms=android,ios,macos,windows midiflow
flutter analyze
flutter test
flutter run -d <device>
```

Build commands, on hosts with the relevant toolchain:
```bash
flutter build apk
flutter build ios
flutter build macos
flutter build windows
```
