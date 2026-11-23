import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/midi/controls_provider.dart';
import '../../domain/midi/midi_control.dart';

/// A recorded sequence of control movements.
class RecordedSequence {
  const RecordedSequence({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.events,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final List<SequenceEvent> events;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'events': events.map((e) => e.toJson()).toList(),
      };

  factory RecordedSequence.fromJson(Map<String, dynamic> json) {
    return RecordedSequence(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      events: (json['events'] as List)
          .map((e) => SequenceEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A single event in a recorded sequence.
class SequenceEvent {
  const SequenceEvent({
    required this.timestamp,
    required this.controlId,
    required this.value,
  });

  final DateTime timestamp;
  final String controlId;
  final double value;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'controlId': controlId,
        'value': value,
      };

  factory SequenceEvent.fromJson(Map<String, dynamic> json) {
    return SequenceEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      controlId: json['controlId'] as String,
      value: (json['value'] as num).toDouble(),
    );
  }
}

/// Controller for recording and playing back control sequences.
class SequenceController extends Notifier<SequenceState> {
  static const _prefsKey = 'midiflow_sequences_v1';

  @override
  SequenceState build() {
    return const SequenceState(
      sequences: [],
      isRecording: false,
      isPlaying: false,
      currentSequence: null,
    );
  }

  Future<void> loadSequences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json != null && json.isNotEmpty) {
        final data = jsonDecode(json) as List;
        final sequences = data
            .map((e) => RecordedSequence.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(sequences: sequences);
      }
    } catch (e) {
      // Ignore load errors
    }
  }

  Future<void> saveSequences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(state.sequences.map((s) => s.toJson()).toList()),
      );
    } catch (e) {
      // Ignore save errors
    }
  }

  void startRecording() {
    state = state.copyWith(
      isRecording: true,
      currentSequence: RecordedSequence(
        id: 'seq-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Sequence ${state.sequences.length + 1}',
        createdAt: DateTime.now(),
        events: [],
      ),
    );
  }

  void stopRecording() {
    if (state.currentSequence != null && state.currentSequence!.events.isNotEmpty) {
      final sequence = state.currentSequence!;
      state = state.copyWith(
        isRecording: false,
        sequences: [...state.sequences, sequence],
        currentSequence: null,
      );
      saveSequences();
    } else {
      state = state.copyWith(isRecording: false, currentSequence: null);
    }
  }

  void recordEvent(String controlId, double value) {
    if (!state.isRecording || state.currentSequence == null) return;

    final event = SequenceEvent(
      timestamp: DateTime.now(),
      controlId: controlId,
      value: value,
    );

    state = state.copyWith(
      currentSequence: RecordedSequence(
        id: state.currentSequence!.id,
        name: state.currentSequence!.name,
        createdAt: state.currentSequence!.createdAt,
        events: [...state.currentSequence!.events, event],
      ),
    );
  }

  Future<void> playSequence(String sequenceId) async {
    final sequence = state.sequences.firstWhere(
      (s) => s.id == sequenceId,
      orElse: () => throw Exception('Sequence not found'),
    );

    state = state.copyWith(isPlaying: true);

    final startTime = DateTime.now();
    for (final event in sequence.events) {
      final elapsed = event.timestamp.difference(sequence.events.first.timestamp);
      final delay = elapsed.inMilliseconds;
      await Future.delayed(Duration(milliseconds: delay));

      // Find and update the control
      final controlsState = ref.read(controlsProvider);
      for (final bank in controlsState.banks) {
        for (final control in bank.controls) {
          if (control.id == event.controlId) {
            await ref
                .read(controlsProvider.notifier)
                .setNormalized(control, event.value);
            break;
          }
        }
      }
    }

    state = state.copyWith(isPlaying: false);
  }

  void stopPlayback() {
    state = state.copyWith(isPlaying: false);
  }

  void deleteSequence(String sequenceId) {
    state = state.copyWith(
      sequences: state.sequences.where((s) => s.id != sequenceId).toList(),
    );
    saveSequences();
  }
}

class SequenceState {
  const SequenceState({
    required this.sequences,
    required this.isRecording,
    required this.isPlaying,
    required this.currentSequence,
  });

  final List<RecordedSequence> sequences;
  final bool isRecording;
  final bool isPlaying;
  final RecordedSequence? currentSequence;

  SequenceState copyWith({
    List<RecordedSequence>? sequences,
    bool? isRecording,
    bool? isPlaying,
    RecordedSequence? currentSequence,
    bool clearCurrentSequence = false,
  }) {
    return SequenceState(
      sequences: sequences ?? this.sequences,
      isRecording: isRecording ?? this.isRecording,
      isPlaying: isPlaying ?? this.isPlaying,
      currentSequence: clearCurrentSequence
          ? null
          : (currentSequence ?? this.currentSequence),
    );
  }
}

final sequenceProvider = NotifierProvider<SequenceController, SequenceState>(
  SequenceController.new,
);

/// UI for recording and playing back control sequences.
class SequenceRecorder extends ConsumerWidget {
  const SequenceRecorder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sequenceProvider);
    final ctrl = ref.read(sequenceProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fiber_manual_record,
                  color: state.isRecording
                      ? Colors.red
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sequence Recorder',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (state.isRecording)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'REC',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.currentSequence != null)
              Text(
                'Recording: ${state.currentSequence!.name} (${state.currentSequence!.events.length} events)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!state.isRecording && !state.isPlaying)
                  FilledButton.icon(
                    onPressed: ctrl.startRecording,
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Record'),
                  )
                else if (state.isRecording)
                  FilledButton.icon(
                    onPressed: ctrl.stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: ctrl.stopPlayback,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                const SizedBox(width: 8),
                if (state.sequences.isNotEmpty)
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Select sequence'),
                      items: [
                        for (final seq in state.sequences)
                          DropdownMenuItem(
                            value: seq.id,
                            child: Text('${seq.name} (${seq.events.length})'),
                          ),
                      ],
                      onChanged: (id) {
                        if (id != null && !state.isPlaying) {
                          ctrl.playSequence(id);
                        }
                      },
                    ),
                  ),
              ],
            ),
            if (state.sequences.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final seq in state.sequences)
                    Chip(
                      label: Text(seq.name),
                      onDeleted: () => ctrl.deleteSequence(seq.id),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
