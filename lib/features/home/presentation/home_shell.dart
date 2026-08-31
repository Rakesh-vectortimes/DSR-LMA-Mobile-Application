import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-nav shell: LMA | DSR | More.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'LMA',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'DSR',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
