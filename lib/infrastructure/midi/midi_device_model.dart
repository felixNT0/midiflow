import 'package:flutter_midi_command/flutter_midi_command.dart'
    show MidiConnectionState, MidiDevice, MidiDeviceType;

/// Direction of a MIDI port on a device.
enum MidiPortDirection { input, output }

/// Platform-neutral description of a single MIDI port.
class MidiPortInfo {
  const MidiPortInfo({required this.id, required this.direction});

  final int id;
  final MidiPortDirection direction;
}

/// Transport kind of a MIDI device, mapped from the plugin's enum.
enum MidiDeviceKind { usb, ble, virtual, network, unknown }

/// Connection state of a MIDI device.
enum MidiDeviceConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  unknown,
}

/// Platform-neutral representation of a MIDI device for the application.
class MidiDeviceInfo {
  MidiDeviceInfo({
    required this.id,
    required this.name,
    required this.kind,
    required this.connectionState,
    List<MidiPortInfo> inputPorts = const [],
    List<MidiPortInfo> outputPorts = const [],
  }) : inputPorts = List.unmodifiable(inputPorts),
       outputPorts = List.unmodifiable(outputPorts);

  final String id;
  final String name;
  final MidiDeviceKind kind;
  final MidiDeviceConnectionState connectionState;

  /// Ports that receive MIDI data into this device (sources for input).
  final List<MidiPortInfo> inputPorts;

  /// Ports that send MIDI data out of this device (destinations for output).
  final List<MidiPortInfo> outputPorts;

  bool get isConnected =>
      connectionState == MidiDeviceConnectionState.connected;
  bool get hasInput => inputPorts.isNotEmpty;
  bool get hasOutput => outputPorts.isNotEmpty;

  factory MidiDeviceInfo.fromPlugin(MidiDevice device) {
    return MidiDeviceInfo(
      id: device.id,
      name: device.name,
      kind: _mapDeviceType(device.type),
      connectionState: _mapConnectionState(device.connectionState),
      inputPorts: [
        for (final p in device.inputPorts)
          MidiPortInfo(id: p.id, direction: MidiPortDirection.input),
      ],
      outputPorts: [
        for (final p in device.outputPorts)
          MidiPortInfo(id: p.id, direction: MidiPortDirection.output),
      ],
    );
  }

  static MidiDeviceKind _mapDeviceType(MidiDeviceType type) {
    switch (type) {
      case MidiDeviceType.serial:
        return MidiDeviceKind.usb;
      case MidiDeviceType.ble:
        return MidiDeviceKind.ble;
      case MidiDeviceType.virtual:
      case MidiDeviceType.ownVirtual:
        return MidiDeviceKind.virtual;
      case MidiDeviceType.network:
        return MidiDeviceKind.network;
      case MidiDeviceType.unknown:
        return MidiDeviceKind.unknown;
    }
  }

  static MidiDeviceConnectionState _mapConnectionState(
    MidiConnectionState state,
  ) {
    switch (state) {
      case MidiConnectionState.disconnected:
        return MidiDeviceConnectionState.disconnected;
      case MidiConnectionState.connecting:
        return MidiDeviceConnectionState.connecting;
      case MidiConnectionState.connected:
        return MidiDeviceConnectionState.connected;
      case MidiConnectionState.disconnecting:
        return MidiDeviceConnectionState.disconnecting;
    }
  }
}
