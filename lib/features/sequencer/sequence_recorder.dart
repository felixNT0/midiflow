import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/midi/controls_provider.dart';
import '../../application/sequencer/sequence_service.dart';
import '../../domain/midi/midi_control.dart';

/// UI for recording and playing back control sequences.
/// Uses the sequence_service for data management.
class SequenceRecorder extends ConsumerWidget {
  const SequenceRecorder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sequenceServiceProvider);
    final service = ref.read(sequenceServiceProvider.notifier);

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
                    onPressed: service.startRecording,
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Record'),
                  )
                else if (state.isRecording)
                  FilledButton.icon(
                    onPressed: service.stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => service.stopPlayback(),
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
                          _playSequence(ref, id);
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
                      onDeleted: () => service.deleteSequence(seq.id),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _playSequence(WidgetRef ref, String sequenceId) async {
    final service = ref.read(sequenceServiceProvider.notifier);
    final sequence = service.getSequence(sequenceId);
    if (sequence == null) return;

    // Mark as playing
    ref.read(sequenceServiceProvider.notifier).state = ref
        .read(sequenceServiceProvider)
        .copyWith(isPlaying: true);

    final controlsCtrl = ref.read(controlsProvider.notifier);
    final controlsState = ref.read(controlsProvider);

    // Find start time for timing
    final startTime = sequence.events.isNotEmpty
        ? sequence.events.first.timestamp
        : DateTime.now();

    for (final event in sequence.events) {
      final elapsed = event.timestamp.difference(startTime);
      await Future.delayed(Duration(milliseconds: elapsed.inMilliseconds));

      // Find the control across all banks
      for (final bank in controlsState.banks) {
        for (final control in bank.controls) {
          if (control.id == event.controlId) {
            if (event.yValue != null) {
              await controlsCtrl.setXY(control, event.value, event.yValue!);
            } else {
              await controlsCtrl.setNormalized(control, event.value);
            }
            break;
          }
        }
      }
    }

    // Mark as not playing
    ref.read(sequenceServiceProvider.notifier).state = ref
        .read(sequenceServiceProvider)
        .copyWith(isPlaying: false);
  }
}
