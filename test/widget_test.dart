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
  testWidgets('App renders Play screen with default controls', (
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

    expect(find.text('MIDIFlow'), findsOneWidget);
    expect(find.text('FADERS'), findsOneWidget);
    expect(find.text('KNOBS'), findsOneWidget);
    expect(find.textContaining('Vol'), findsWidgets);
    expect(find.text('Play'), findsWidgets);
    expect(find.text('Assign'), findsWidgets);
  });

  testWidgets('Assign tab shows control editor', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          midiControllerProvider.overrideWith(_FakeMidiController.new),
        ],
        child: const MidiFlowApp(desktopMode: false),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Assign').last);
    await tester.pump();

    expect(find.text('Send test CC'), findsOneWidget);
    expect(find.text('CC controller (0-127)'), findsOneWidget);
  });
}
