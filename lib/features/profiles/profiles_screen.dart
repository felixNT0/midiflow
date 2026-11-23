import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/midi/controls_provider.dart';
import '../../domain/midi/control_bank.dart';
import '../../domain/midi/midi_control.dart';

/// Profile management: save, load, delete, and switch between control layouts.
/// Profiles persist to SharedPreferences for offline use.
class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  static const _prefsKey = 'midiflow_profiles_v1';
  static const _activeProfileKey = 'midiflow_active_profile';

  List<Map<String, dynamic>> _profiles = [];
  String? _activeProfileName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      final activeName = prefs.getString(_activeProfileKey);

      setState(() {
        if (json != null && json.isNotEmpty) {
          final data = jsonDecode(json) as List;
          _profiles = data.cast<Map<String, dynamic>>();
        }
        _activeProfileName = activeName;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_profiles));
      if (_activeProfileName != null) {
        await prefs.setString(_activeProfileKey, _activeProfileName!);
      }
    } catch (e) {
      // Ignore save errors
    }
  }

  Future<void> _saveCurrentAsProfile(String name) async {
    final controlsState = ref.read(controlsProvider);
    final banksData = <Map<String, dynamic>>[];

    for (final bank in controlsState.banks) {
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

    final profile = {
      'name': name,
      'createdAt': DateTime.now().toIso8601String(),
      'banks': banksData,
      'activeBankIndex': controlsState.activeBankIndex,
    };

    setState(() {
      // Remove existing profile with same name
      _profiles.removeWhere((p) => p['name'] == name);
      _profiles.add(profile);
      _activeProfileName = name;
    });

    await _saveProfiles();
  }

  Future<void> _loadProfile(String name) async {
    final profile = _profiles.firstWhere(
      (p) => p['name'] == name,
      orElse: () => {},
    );

    if (profile.isEmpty) return;

    final banksData = (profile['banks'] as List).cast<Map<String, dynamic>>();
    final banks = <ControlBank>[];

    for (final bankData in banksData) {
      final controls = <MidiControl>[];
      for (final ctrlData in (bankData['controls'] as List).cast<Map<String, dynamic>>()) {
        controls.add(MidiControl(
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
        ));
      }
      banks.add(ControlBank(
        id: bankData['id'] as String,
        name: bankData['name'] as String,
        controls: controls,
      ));
    }

    // Update controls provider
    ref.read(controlsProvider.notifier).loadFromBanks(
      banks,
      activeBankIndex: (profile['activeBankIndex'] as num?)?.toInt() ?? 0,
    );

    setState(() {
      _activeProfileName = name;
    });

    await _saveProfiles();
  }

  Future<void> _deleteProfile(String name) async {
    setState(() {
      _profiles.removeWhere((p) => p['name'] == name);
      if (_activeProfileName == name) {
        _activeProfileName = null;
      }
    });
    await _saveProfiles();
  }

  void _showSaveDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Profile'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Profile name',
            hintText: 'e.g., Sunday Service, Wedding, Practice',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                _saveCurrentAsProfile(name);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _showSaveDialog,
            tooltip: 'Save current layout as profile',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_profiles.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.folder_copy_outlined,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No saved profiles yet',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Save your current control layout as a profile to quickly switch between different setups (e.g., different songs, instruments, or venues).',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _showSaveDialog,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Current Layout'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Saved Profiles',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap a profile to load it. Long-press to delete.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  for (final profile in _profiles)
                    _ProfileCard(
                      profile: profile,
                      isActive: profile['name'] == _activeProfileName,
                      onTap: () => _loadProfile(profile['name'] as String),
                      onDelete: () => _deleteProfile(profile['name'] as String),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _showSaveDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Save Current as New Profile'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> profile;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = profile['name'] as String;
    final createdAt = DateTime.tryParse(profile['createdAt'] as String? ?? '');
    final banks = (profile['banks'] as List?)?.length ?? 0;
    final controls = (profile['banks'] as List?)
            ?.fold<int>(0, (sum, bank) => sum + ((bank['controls'] as List?)?.length ?? 0)) ??
        0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isActive ? Icons.check_circle : Icons.folder_copy_outlined,
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(name),
        subtitle: Text(
          '${banks} banks • ${controls} controls${createdAt != null ? ' • ${_formatDate(createdAt)}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive)
              const Chip(
                label: Text('Active'),
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: 'Delete profile',
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}
