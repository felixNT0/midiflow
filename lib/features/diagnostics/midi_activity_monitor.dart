import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/midi/bridge_provider.dart';
import '../../application/midi/midi_provider.dart';
import '../../infrastructure/midi/midi_message_model.dart';

/// MIDI activity monitor: shows recent incoming/outgoing MIDI messages.
/// Helps debug connection issues and verify controls are working.
class MidiActivityMonitor extends ConsumerWidget {
  const MidiActivityMonitor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final midi = ref.watch(midiControllerProvider);
    final bridge = ref.watch(bridgeClientProvider);
    final connected = midi.isConnected || bridge.isConnected;
    final messages = midi.messages;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_heart,
                  color: connected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'MIDI Activity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (messages.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    onPressed: () => ref.read(midiControllerProvider.notifier).clearMessageLog(),
                    tooltip: 'Clear messages',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (!connected)
              Text(
                'No MIDI device connected. Connect in Settings to see activity.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              )
            else if (messages.isEmpty)
              Text(
                'No MIDI messages yet. Move a control to see activity.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    // Show most recent first
                    final msg = messages[messages.length - 1 - index];
                    return _MessageTile(message: msg);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message});

  final MidiIncomingMessage message;

  @override
  Widget build(BuildContext context) {
    final type = _messageType(message);
    final color = _messageColor(context, message);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}:${message.timestamp.second.toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              type,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _messageDetails(message),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _messageType(MidiIncomingMessage msg) {
    return switch (msg.kind) {
      MidiMessageKind.noteOn => 'NOTE ON',
      MidiMessageKind.noteOff => 'NOTE OFF',
      MidiMessageKind.controlChange => 'CC',
      MidiMessageKind.programChange => 'PC',
      MidiMessageKind.pitchBend => 'PITCH',
      MidiMessageKind.channelPressure => 'PRESS',
      MidiMessageKind.polyPressure => 'POLY',
      MidiMessageKind.aftertouch => 'AFTER',
      MidiMessageKind.system => 'SYS',
      MidiMessageKind.sysex => 'SYSEX',
      _ => 'OTHER',
    };
  }

  Color _messageColor(BuildContext context, MidiIncomingMessage msg) {
    return switch (msg.kind) {
      MidiMessageKind.noteOn => Colors.green,
      MidiMessageKind.noteOff => Colors.orange,
      MidiMessageKind.controlChange => Colors.blue,
      MidiMessageKind.programChange => Colors.purple,
      MidiMessageKind.pitchBend => Colors.teal,
      MidiMessageKind.channelPressure => Colors.pink,
      MidiMessageKind.polyPressure => Colors.indigo,
      MidiMessageKind.aftertouch => Colors.amber,
      MidiMessageKind.system => Colors.grey,
      MidiMessageKind.sysex => Colors.brown,
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  String _messageDetails(MidiIncomingMessage msg) {
    final buffer = StringBuffer();
    if (msg.direction == MidiMessageDirection.incoming) {
      buffer.write('IN ');
    } else {
      buffer.write('OUT ');
    }
    if (msg.channel != null) buffer.write('Ch${msg.channel} ');
    if (msg.controller != null) buffer.write('CC${msg.controller} ');
    if (msg.note != null) buffer.write('Note${msg.note} ');
    if (msg.value != null) buffer.write('=${msg.value}');
    if (msg.detail != null) buffer.write(' (${msg.detail})');
    return buffer.toString().trim();
  }
}
