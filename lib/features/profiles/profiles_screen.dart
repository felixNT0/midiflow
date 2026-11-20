import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/midi/controls_provider.dart';

/// Profile management. Persistence, CRUD and JSON import/export arrive in the
/// profiles milestone; this screen shows the current in-memory layout honestly.
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controls = ref.watch(controlsProvider).controls;
    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.dashboard_customize),
              title: const Text('Default Performance Layout'),
              subtitle: Text('${controls.length} controls (in memory)'),
              trailing: const Chip(label: Text('Active')),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Saved profiles, instrument presets (Piano, Strings, Brass, '
                'Synths, Pads), JSON import/export and cloud-free local '
                'storage arrive in the profiles milestone. The layout above '
                'is the current unsaved working set.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
