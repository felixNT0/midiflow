import 'package:flutter/material.dart';

import '../features/play/play_screen.dart';
import '../features/settings/settings_screen.dart';
import '../shared/theme/app_theme.dart';

/// Responsive shell with two primary destinations: Play and Settings.
/// Assign and Profiles are accessed via Settings screen.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.play_circle_outline, label: 'Play'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  void _goTo(int index) => setState(() => _index = index);

  Widget _body() {
    return switch (_index) {
      0 => PlayScreen(
        key: const ValueKey('play'),
        onOpenSettings: () => _goTo(1),
      ),
      _ => const SettingsScreen(key: ValueKey('settings')),
    };
  }

  Widget _animatedBody(Widget child) {
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      switchInCurve: AppMotion.curve,
      switchOutCurve: AppMotion.standard,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        final body = _animatedBody(_body());
        if (wide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _goTo,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }
        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _goTo,
            destinations: [
              for (final d in _destinations)
                NavigationDestination(icon: Icon(d.icon), label: d.label),
            ],
          ),
        );
      },
    );
  }
}
