import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/midi/midi_provider.dart';
import '../../domain/midi/control_bank.dart';
import '../../domain/midi/midi_control.dart';
import 'bridge_provider.dart';

/// State for the editable control surface: a list of banks (pages) plus the
/// active bank and the selected control within it.
class ControlsState {
  const ControlsState({
    this.banks = const [],
    this.activeBankIndex = 0,
    this.selectedControlId,
  });

  final List<ControlBank> banks;
  final int activeBankIndex;
  final String? selectedControlId;

  ControlBank? get activeBank {
    if (banks.isEmpty) return null;
    return banks[activeBankIndex.clamp(0, banks.length - 1)];
  }

  /// Controls of the active bank — kept as a convenience getter so existing
  /// consumers can keep reading `state.controls`.
  List<MidiControl> get controls => activeBank?.controls ?? const [];

  MidiControl? get selectedControl {
    for (final c in controls) {
      if (c.id == selectedControlId) return c;
    }
    return null;
  }

  ControlsState copyWith({
    List<ControlBank>? banks,
    int? activeBankIndex,
    String? selectedControlId,
    bool clearSelection = false,
  }) {
    return ControlsState(
      banks: banks ?? this.banks,
      activeBankIndex: activeBankIndex ?? this.activeBankIndex,
      selectedControlId: clearSelection
          ? null
          : (selectedControlId ?? this.selectedControlId),
    );
  }
}

/// Holds the in-memory control layout and routes control gestures to the
/// MIDI engine. Persists control labels and values to SharedPreferences.
class ControlsController extends Notifier<ControlsState> {
  static const _prefsKey = 'midiflow_controls_v1';

  @override
  ControlsState build() {
    return ControlsState(
      banks: [
        ControlBankTemplates.instrument(),
        ControlBankTemplates.transport(),
        ControlBankTemplates.drums(),
        ControlBankTemplates.mixer(),
        ControlBankTemplates.performance(),
        ControlBankTemplates.effects(),
      ],
      activeBankIndex: 0,
      selectedControlId: 'layer-vol-1',
    );
  }

  /// Loads control banks from a saved profile.
  void loadFromBanks(List<ControlBank> banks, {int activeBankIndex = 0}) {
    state = ControlsState(
      banks: banks,
      activeBankIndex: activeBankIndex.clamp(0, banks.length - 1),
      selectedControlId: banks.isNotEmpty && banks[activeBankIndex.clamp(0, banks.length - 1)].controls.isNotEmpty
          ? banks[activeBankIndex.clamp(0, banks.length - 1)].controls.first.id
          : null,
    );
    unawaited(savePersisted());
  }

  /// Loads persisted control labels and values from SharedPreferences.
  /// Call this after the provider is first built.
  Future<void> loadPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json == null || json.isEmpty) return;

      final data = jsonDecode(json) as Map<String, dynamic>;
      final banks = <ControlBank>[];

      for (final bankData in (data['banks'] as List).cast<Map<String, dynamic>>()) {
        final controls = <MidiControl>[];
        for (final ctrlData in (bankData['controls'] as List).cast<Map<String, dynamic>>()) {
          final control = MidiControl(
            id: ctrlData['id'] as String,
            label: ctrlData['label'] as String,
            type: MidiControlType.values.firstWhere(
              (t) => t.name == ctrlData['type'],
            ),
            mapping: ControlMapping(
              channel: ctrlData['channel'] as int,
              controller: ctrlData['controller'] as int,
            ),
            normalizedValue: (ctrlData['normalizedValue'] as num?)?.toDouble() ?? 0.0,
          );
          controls.add(control);
        }
        banks.add(ControlBank(
          id: bankData['id'] as String,
          name: bankData['name'] as String,
          controls: controls,
        ));
      }

      state = ControlsState(
        banks: banks,
        activeBankIndex: (data['activeBankIndex'] as num?)?.toInt() ?? 0,
        selectedControlId: data['selectedControlId'] as String?,
      );
    } catch (e) {
      // Persistence load failed — keep default state
    }
  }

  /// Saves control labels and values to SharedPreferences.
  Future<void> savePersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final banksData = <Map<String, dynamic>>[];

      for (final bank in state.banks) {
        final controlsData = <Map<String, dynamic>>[];
        for (final ctrl in bank.controls) {
          controlsData.add({
            'id': ctrl.id,
            'label': ctrl.label,
            'type': ctrl.type.name,
            'channel': ctrl.mapping.channel,
            'controller': ctrl.mapping.controller,
            'normalizedValue': ctrl.normalizedValue,
          });
        }
        banksData.add({
          'id': bank.id,
          'name': bank.name,
          'controls': controlsData,
        });
      }

      final data = {
        'banks': banksData,
        'activeBankIndex': state.activeBankIndex,
        'selectedControlId': state.selectedControlId,
      };

      await prefs.setString(_prefsKey, jsonEncode(data));
    } catch (e) {
      // Persistence save failed — ignore
    }
  }

  // ------------------------------------------------------------------ banks

  void switchBank(int index) {
    if (index < 0 ||
        index >= state.banks.length ||
        index == state.activeBankIndex) {
      return;
    }
    state = state.copyWith(activeBankIndex: index, clearSelection: true);
  }

  void addBank({required String name, List<MidiControl> controls = const []}) {
    final id = 'bank-${DateTime.now().microsecondsSinceEpoch}';
    final bank = ControlBank(id: id, name: name, controls: controls);
    state = state.copyWith(
      banks: [...state.banks, bank],
      activeBankIndex: state.banks.length,
      clearSelection: true,
    );
    unawaited(savePersisted());
  }

  void renameBank(int index, String name) {
    if (index < 0 || index >= state.banks.length || name.trim().isEmpty) return;
    final banks = [...state.banks];
    banks[index] = banks[index].copyWith(name: name.trim());
    state = state.copyWith(banks: banks);
    unawaited(savePersisted());
  }

  void removeBank(int index) {
    if (state.banks.length <= 1 || index < 0 || index >= state.banks.length) {
      return;
    }
    final banks = [...state.banks]..removeAt(index);
    var active = state.activeBankIndex;
    if (index == active) {
      active = index.clamp(0, banks.length - 1);
    } else if (index < active) {
      active -= 1;
    }
    state = state.copyWith(
      banks: banks,
      activeBankIndex: active,
      clearSelection: true,
    );
    unawaited(savePersisted());
  }

  // ---------------------------------------------------------------- controls

  void selectControl(String? id) {
    state = state.copyWith(selectedControlId: id, clearSelection: id == null);
  }

  void _updateActiveBank(List<MidiControl> Function(List<MidiControl>) update) {
    final idx = state.activeBankIndex.clamp(0, state.banks.length - 1);
    final banks = [...state.banks];
    final bank = banks[idx];
    banks[idx] = bank.copyWith(controls: update(bank.controls));
    state = state.copyWith(banks: banks);
  }

  /// Replaces a control's editable fields (used by the Assign screen).
  void updateControl(MidiControl updated) {
    _updateActiveBank(
      (controls) => [
        for (final c in controls) c.id == updated.id ? updated : c,
      ],
    );
    unawaited(savePersisted());
  }

  /// Updates only the label of a control.
  void updateControlLabel(String id, String newLabel) {
    _updateActiveBank(
      (controls) => [
        for (final c in controls)
          c.id == id ? c.copyWith(label: newLabel) : c,
      ],
    );
    unawaited(savePersisted());
  }

  void addControl(MidiControlType type) {
    final id = 'control-${DateTime.now().microsecondsSinceEpoch}';
    final control = MidiControl(
      id: id,
      label: _defaultLabel(type),
      type: type,
      mapping: const ControlMapping(channel: 1, controller: 20),
      xMapping: type == MidiControlType.xyPad
          ? const ControlMapping(channel: 1, controller: 20)
          : null,
      yMapping: type == MidiControlType.xyPad
          ? const ControlMapping(channel: 1, controller: 21)
          : null,
    );
    _updateActiveBank((controls) => [...controls, control]);
    state = state.copyWith(selectedControlId: id);
    unawaited(savePersisted());
  }

  void removeControl(String id) {
    _updateActiveBank(
      (controls) => [
        for (final c in controls)
          if (c.id != id) c,
      ],
    );
    if (state.selectedControlId == id) {
      state = state.copyWith(clearSelection: true);
    }
    unawaited(savePersisted());
  }

  /// Ids of the Instrument bank's "lead" performance controls — these
  /// follow the lead-channel selector rather than the per-part
  /// Vol/Expr pairs, so they can be aimed at whichever FL Studio channel
  /// hosts the instrument being played.
  static const _leadControlIds = {
    'modulation',
    'pan',
    'filter-cutoff',
    'filter-resonance',
    'filter-env-amount',
    'attack',
    'decay',
    'release',
    'portamento',
    'detune',
    'xy-expression',
    'sustain',
    'expression',
    'layer-vol-1',
    'layer-vol-2',
    'layer-vol-3',
    'layer-vol-4',
    'layer-vol-5',
    'layer-vol-6',
    'layer-vol-7',
    'layer-vol-8',
    'layer-toggle-1',
    'layer-toggle-2',
    'layer-toggle-3',
    'layer-toggle-4',
    'layer-toggle-5',
    'layer-toggle-6',
    'layer-toggle-7',
    'layer-toggle-8',
    'pad-1',
    'pad-2',
    'pad-3',
    'pad-4',
    'pad-5',
    'pad-6',
    'pad-7',
    'pad-8',
    'pad-9',
    'pad-10',
    'pad-11',
    'pad-12',
    'pad-volume',
  };

  /// Current lead channel (1-16) used by the Instrument/Performance
  /// controls. Scans every bank so it works while either tab is active.
  int get leadChannel {
    for (final bank in state.banks) {
      for (final c in bank.controls) {
        if (_leadControlIds.contains(c.id)) return c.mapping.channel;
      }
    }
    return 1;
  }

  /// Re-targets every lead performance control to [channel] across all
  /// banks, so the Part selector works from either the Instrument or the
  /// Performance tab.
  void setLeadChannel(int channel) {
    if (channel < 1 || channel > 16) return;
    state = state.copyWith(
      banks: [
        for (final bank in state.banks)
          bank.copyWith(
            controls: [
              for (final c in bank.controls)
                _leadControlIds.contains(c.id)
                    ? c.copyWith(
                        mapping: c.mapping.copyWith(channel: channel),
                        xMapping: c.xMapping?.copyWith(channel: channel),
                        yMapping: c.yMapping?.copyWith(channel: channel),
                      )
                    : c,
            ],
          ),
      ],
    );
  }

  /// Sends the control's current value. For XY pads pass [xNormalized] and
  /// [yNormalized]; for buttons this is unused.
  Future<void> sendControl(
    MidiControl control, {
    double? xNormalized,
    double? yNormalized,
  }) async {
    if (control.type == MidiControlType.xyPad) {
      final x = xNormalized ?? control.normalizedValue;
      final y = yNormalized ?? control.yNormalized;
      final xm = control.xMapping ?? control.mapping;
      final ym = control.yMapping ?? control.mapping;
      await _sendCc(xm.channel, xm.controller, normalizedToMidi(x, xm));
      await _sendCc(ym.channel, ym.controller, normalizedToMidi(y, ym));
      _updateAxisValues(control, x, y);
      return;
    }

    await _sendCc(
      control.mapping.channel,
      control.mapping.controller,
      normalizedToMidi(control.normalizedValue, control.mapping),
    );
  }

  /// Routes a CC to the desktop bridge when connected, otherwise to the
  /// local MIDI service (BLE/USB device).
  Future<void> _sendCc(int channel, int controller, int value) {
    final clientState = ref.read(bridgeClientProvider);
    if (clientState.isConnected) {
      ref
          .read(bridgeClientProvider.notifier)
          .sendCc(channel: channel, controller: controller, value: value);
      return Future.value();
    }
    return ref
        .read(midiControllerProvider.notifier)
        .sendCc(channel: channel, controller: controller, value: value);
  }

  /// Routes a Note On to the desktop bridge when connected, otherwise to
  /// the local MIDI service (BLE/USB device).
  void noteOn({
    required int channel,
    required int note,
    int velocity = 100,
  }) {
    final clientState = ref.read(bridgeClientProvider);
    if (clientState.isConnected) {
      ref
          .read(bridgeClientProvider.notifier)
          .sendNoteOn(channel: channel, note: note, velocity: velocity);
      return;
    }
    unawaited(
      ref
          .read(midiControllerProvider.notifier)
          .sendNoteOn(channel: channel, note: note, velocity: velocity),
    );
  }

  /// Routes a Note Off alongside [noteOn].
  void noteOff({required int channel, required int note}) {
    final clientState = ref.read(bridgeClientProvider);
    if (clientState.isConnected) {
      ref
          .read(bridgeClientProvider.notifier)
          .sendNoteOff(channel: channel, note: note);
      return;
    }
    unawaited(
      ref
          .read(midiControllerProvider.notifier)
          .sendNoteOff(channel: channel, note: note),
    );
  }

  /// Continuous-value gesture entry point: updates state and sends.
  Future<void> setNormalized(MidiControl control, double normalized) async {
    _updateNormalized(control, normalized);
    await sendControl(control.copyWith(normalizedValue: normalized));
    unawaited(savePersisted());
  }

  /// XY pad gesture entry point: updates both axes and sends both CCs.
  Future<void> setXY(MidiControl control, double x, double y) async {
    _updateAxisValues(control, x, y);
    await sendControl(
      control.copyWith(
        normalizedValue: x.clamp(0.0, 1.0),
        yNormalized: y.clamp(0.0, 1.0),
      ),
      xNormalized: x,
      yNormalized: y,
    );
    unawaited(savePersisted());
  }

  /// Momentary button: sends on value at press, off value at release.
  Future<void> buttonPress(MidiControl control) =>
      _sendButtonValue(control, down: true);

  Future<void> buttonRelease(MidiControl control) =>
      _sendButtonValue(control, down: false);

  /// Toggle/latch button: flips state and sends the corresponding value.
  Future<void> buttonToggle(MidiControl control) async {
    final on = control.normalizedValue >= 0.5;
    await _sendButtonValue(control, down: !on);
    _updateNormalized(control, on ? 0.0 : 1.0);
    unawaited(savePersisted());
  }

  Future<void> _sendButtonValue(MidiControl control, {required bool down}) {
    final mapping = control.mapping;
    return _sendCc(
      mapping.channel,
      mapping.controller,
      down ? buttonOnValue(mapping) : buttonOffValue(mapping),
    );
  }

  void _updateAxisValues(MidiControl control, double x, double y) {
    _updateActiveBank(
      (controls) => [
        for (final c in controls)
          c.id == control.id
              ? c.copyWith(
                  normalizedValue: x.clamp(0.0, 1.0),
                  yNormalized: y.clamp(0.0, 1.0),
                )
              : c,
      ],
    );
  }

  void _updateNormalized(MidiControl control, double normalized) {
    final clamped = normalized.clamp(0.0, 1.0);
    _updateActiveBank(
      (controls) => [
        for (final c in controls)
          c.id == control.id ? c.copyWith(normalizedValue: clamped) : c,
      ],
    );
  }

  /// Sends a single test CC for the Assign screen without touching control
  /// state. Uses the bridge when connected so the test reaches the DAW.
  Future<void> sendTestCc(ControlMapping mapping, {double? normalized}) {
    final value = normalizedToMidi(normalized ?? 0.5, mapping);
    return _sendCc(mapping.channel, mapping.controller, value);
  }

  String _defaultLabel(MidiControlType type) => switch (type) {
    MidiControlType.fader => 'Fader',
    MidiControlType.knob => 'Knob',
    MidiControlType.momentaryButton => 'Button',
    MidiControlType.toggleButton => 'Toggle',
    MidiControlType.latchButton => 'Latch',
    MidiControlType.xyPad => 'XY Pad',
  };
}

final controlsProvider = NotifierProvider<ControlsController, ControlsState>(
  ControlsController.new,
);
