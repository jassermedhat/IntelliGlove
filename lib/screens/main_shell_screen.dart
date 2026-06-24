// lib/screens/main_shell_screen.dart
// Shell screen that wraps the 4 persistent tabs (Home / Services /
// Translate / Profile) in a StatefulShellRoute / IndexedStack.
// The BottomNav widget is rendered here; tapping a tab calls
// navigationShell.goBranch() which preserves each branch's widget state.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../components/bottom_nav.dart';

class MainShellScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // let content flow under the floating BottomNav
      resizeToAvoidBottomInset:
          false, // prevent bottom nav from being pushed above keyboard
      body: Stack(
        children: [
          // The StatefulNavigationShell internally maintains an IndexedStack,
          // keeping each branch alive when switching tabs.
          Positioned.fill(child: navigationShell),

          // BottomNav floats over the content (matches the TSX Stack pattern)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNav(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
