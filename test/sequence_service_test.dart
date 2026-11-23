import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midiflow/application/sequencer/sequence_service.dart';

void main() {
  group('SequenceService', () {
    late ProviderContainer container;
    late SequenceService service;

    setUp(() {
      container = ProviderContainer();
      service = container.read(sequenceServiceProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('starts with empty state', () {
      expect(service.state.sequences, isEmpty);
      expect(service.state.isRecording, isFalse);
      expect(service.state.isPlaying, isFalse);
      expect(service.state.currentSequence, isNull);
    });

    test('starts recording', () {
      service.startRecording();

      expect(service.state.isRecording, isTrue);
      expect(service.state.currentSequence, isNotNull);
      expect(service.state.currentSequence!.name, contains('Sequence'));
      expect(service.state.currentSequence!.events, isEmpty);
    });

    test('records events', () {
      service.startRecording();

      service.recordEvent('control-1', 0.5);
      service.recordEvent('control-2', 0.8);

      expect(service.state.currentSequence!.events.length, 2);
      expect(service.state.currentSequence!.events[0].controlId, 'control-1');
      expect(service.state.currentSequence!.events[0].value, 0.5);
      expect(service.state.currentSequence!.events[1].controlId, 'control-2');
      expect(service.state.currentSequence!.events[1].value, 0.8);
    });

    test('stops recording and saves sequence', () {
      service.startRecording();
      service.recordEvent('control-1', 0.5);
      service.stopRecording();

      expect(service.state.isRecording, isFalse);
      expect(service.state.currentSequence, isNull);
      expect(service.state.sequences.length, 1);
      expect(service.state.sequences[0].events.length, 1);
    });

    test('does not save empty sequences', () {
      service.startRecording();
      service.stopRecording();

      expect(service.state.sequences, isEmpty);
    });

    test('gets sequence by id', () {
      service.startRecording();
      service.recordEvent('control-1', 0.5);
      service.stopRecording();

      final sequenceId = service.state.sequences[0].id;
      final sequence = service.getSequence(sequenceId);

      expect(sequence, isNotNull);
      expect(sequence!.id, sequenceId);
      expect(sequence.events.length, 1);
    });

    test('returns null for non-existent sequence', () {
      final sequence = service.getSequence('non-existent');
      expect(sequence, isNull);
    });

    test('deletes sequence', () {
      service.startRecording();
      service.recordEvent('control-1', 0.5);
      service.stopRecording();

      final sequenceId = service.state.sequences[0].id;
      service.deleteSequence(sequenceId);

      expect(service.state.sequences, isEmpty);
    });

    test('renames sequence', () {
      service.startRecording();
      service.recordEvent('control-1', 0.5);
      service.stopRecording();

      final sequenceId = service.state.sequences[0].id;
      service.renameSequence(sequenceId, 'My Custom Sequence');

      expect(service.state.sequences[0].name, 'My Custom Sequence');
    });

    test('records XY pad with Y value', () {
      service.startRecording();
      service.recordEvent('xy-pad', 0.5, yValue: 0.8);
      service.stopRecording();

      expect(service.state.sequences[0].events[0].value, 0.5);
      expect(service.state.sequences[0].events[0].yValue, 0.8);
    });
  });
}
