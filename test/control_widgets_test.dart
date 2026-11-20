import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midiflow/shared/controls/fader_control.dart';
import 'package:midiflow/shared/controls/knob_control.dart';

void main() {
  testWidgets('FaderControl reports drag position as normalized value', (
    tester,
  ) async {
    double? last;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: FaderControl(
              label: 'Test',
              value: 0.5,
              onChanged: (v) => last = v,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FaderControl)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, -50));
    await tester.pump();
    await gesture.up();

    expect(last, isNotNull);
    expect(last!, greaterThan(0.5)); // dragged up = higher value
    expect(last!, lessThanOrEqualTo(1.0));
  });

  testWidgets('KnobControl renders label and value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KnobControl(
            label: 'Cutoff',
            value: 0.5,
            midiValue: 64,
            onChanged: _noop,
          ),
        ),
      ),
    );
    expect(find.text('Cutoff'), findsOneWidget);
    expect(find.text('64'), findsOneWidget);
  });
}

void _noop(double v) {}
