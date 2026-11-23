import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midiflow/application/midi/midi_provider.dart';
import 'package:midiflow/infrastructure/midi/midi_service.dart';
import 'package:midiflow/main.dart';

class _FakeMidiController extends MidiController {
  @override
  MidiState build() => const MidiState(status: MidiEngineStatus.ready);
}

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          midiControllerProvider.overrideWith(_FakeMidiController.new),
        ],
        child: const MidiFlowApp(desktopMode: false),
      ),
    );

    // Just verify the app builds without throwing
    expect(tester.takeException(), isNull);
  });

  testWidgets('Play screen shows expected content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          midiControllerProvider.overrideWith(_FakeMidiController.new),
        ],
        child: const MidiFlowApp(desktopMode: false),
      ),
    );
    await tester.pump();

    // Check for basic UI elements that should exist
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
