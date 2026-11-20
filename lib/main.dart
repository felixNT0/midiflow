import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_shell.dart';
import 'features/bridge/bridge_screen.dart';
import 'application/midi/bridge_provider.dart';
import 'application/settings/theme_mode_provider.dart';
import 'shared/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: MidiFlowApp()));
}

bool get _isDesktop =>
    !kIsWeb &&
    (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

class MidiFlowApp extends ConsumerWidget {
  const MidiFlowApp({super.key, this.desktopMode});

  /// Overrides platform detection — used by widget tests to force the
  /// mobile shell on a desktop test host.
  final bool? desktopMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // Instantiates the desktop bridge provider so it auto-starts.
    ref.watch(bridgeServerProvider);
    return MaterialApp(
      title: 'MIDIFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      // On desktop the app is only the bridge companion — phones do the
      // performing, so the laptop shows just the bridge panel.
      home: (desktopMode ?? _isDesktop)
          ? const BridgeScreen()
          : const AppShell(),
    );
  }
}
