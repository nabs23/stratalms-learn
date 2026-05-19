import 'package:flutter/material.dart';

import '../courses_screen.dart';
import '../home/home_screen.dart';
import '../messages_screen.dart';
import '../profile_screen.dart';
import '../support_screen.dart';

class TabletMainScreen extends StatefulWidget {
  const TabletMainScreen({super.key});

  @override
  State<TabletMainScreen> createState() => _TabletMainScreenState();
}

class _TabletMainScreenState extends State<TabletMainScreen> {
  int _currentIndex = 0;

  final List<({
    String label,
    IconData icon,
    IconData selectedIcon,
    Widget screen,
  })> _items = [
    (
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      screen: const HomeScreen(),
    ),
    (
      label: 'Courses',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
      screen: const CoursesScreen(),
    ),
    (
      label: 'Messages',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      screen: const MessagesScreen(),
    ),
    (
      label: 'Support',
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent,
      screen: const SupportScreen(),
    ),
    (
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      screen: const ProfileScreen(),
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWideTablet = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: isWideTablet ? 260 : 92,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 22,
                            ),
                          ),
                          if (isWideTablet) ...[
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Learn',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: NavigationRail(
                        backgroundColor: Colors.transparent,
                        selectedIndex: _currentIndex,
                        onDestinationSelected: _onDestinationSelected,
                        extended: isWideTablet,
                        labelType: isWideTablet
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.selected,
                        useIndicator: true,
                        minExtendedWidth: 260,
                        groupAlignment: -0.8,
                        destinations: _items
                            .map(
                              (item) => NavigationRailDestination(
                                icon: Icon(item.icon),
                                selectedIcon: Icon(item.selectedIcon),
                                label: Text(item.label),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ColoredBox(
                    color: colorScheme.surface,
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _items.map((item) => item.screen).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
