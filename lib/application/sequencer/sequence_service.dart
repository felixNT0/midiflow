import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    this.yValue,
  });

  final DateTime timestamp;
  final String controlId;
  final double value;
  final double? yValue;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'controlId': controlId,
        'value': value,
        if (yValue != null) 'yValue': yValue,
      };

  factory SequenceEvent.fromJson(Map<String, dynamic> json) {
    return SequenceEvent(
      timestamp: DateTime.parse(json['timestamp'] as String),
      controlId: json['controlId'] as String,
      value: (json['value'] as num).toDouble(),
      yValue: (json['yValue'] as num?)?.toDouble(),
    );
  }
}

/// State for sequence recording and playback.
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

/// Service for recording and playing back control sequences.
/// This is independent of controls_provider to avoid circular dependencies.
class SequenceService extends Notifier<SequenceState> {
  static const _prefsKey = 'midiflow_sequences_v1';

  @override
  SequenceState build() {
    // Load sequences asynchronously
    Future.microtask(loadSequences);
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
        clearCurrentSequence: true,
      );
      saveSequences();
    } else {
      state = state.copyWith(isRecording: false, clearCurrentSequence: true);
    }
  }

  /// Records a control event. Called by controls_provider when recording is active.
  void recordEvent(String controlId, double value, {double? yValue}) {
    if (!state.isRecording || state.currentSequence == null) return;

    final event = SequenceEvent(
      timestamp: DateTime.now(),
      controlId: controlId,
      value: value,
      yValue: yValue,
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

  /// Returns the current sequence being recorded, or null.
  RecordedSequence? get currentSequence => state.currentSequence;

  /// Checks if recording is active.
  bool get isRecording => state.isRecording;

  /// Checks if playback is active.
  bool get isPlaying => state.isPlaying;

  /// Stops playback.
  void stopPlayback() {
    state = state.copyWith(isPlaying: false);
  }

  /// Gets a sequence by ID.
  RecordedSequence? getSequence(String id) {
    try {
      return state.sequences.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Deletes a sequence.
  void deleteSequence(String sequenceId) {
    state = state.copyWith(
      sequences: state.sequences.where((s) => s.id != sequenceId).toList(),
    );
    saveSequences();
  }

  /// Renames a sequence.
  void renameSequence(String sequenceId, String newName) {
    state = state.copyWith(
      sequences: [
        for (final seq in state.sequences)
          seq.id == sequenceId
              ? RecordedSequence(
                  id: seq.id,
                  name: newName,
                  createdAt: seq.createdAt,
                  events: seq.events,
                )
              : seq,
      ],
    );
    saveSequences();
  }
}

final sequenceServiceProvider = NotifierProvider<SequenceService, SequenceState>(
  SequenceService.new,
);
