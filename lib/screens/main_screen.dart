import 'package:flutter/material.dart';
import 'home/home_screen.dart';
import 'courses_screen.dart';
import 'messages_screen.dart';
import 'support_screen.dart';
import 'profile_screen.dart';
import '../utils/responsive.dart';
import 'tablet/main_screen_tablet.dart';

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<_NavItem> _items = [
    const _NavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      screen: HomeScreen(),
    ),
    const _NavItem(
      label: 'Courses',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
      screen: CoursesScreen(),
    ),
    const _NavItem(
      label: 'Messages',
      icon: Icons.chat_bubble_outline,
      selectedIcon: Icons.chat_bubble,
      screen: MessagesScreen(),
    ),
    const _NavItem(
      label: 'Support',
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent,
      screen: SupportScreen(),
    ),
    const _NavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      screen: ProfileScreen(),
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildContent() {
    return IndexedStack(
      index: _currentIndex,
      children: _items.map((item) => item.screen).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Responsive.isTablet(context)) {
      return const TabletMainScreen();
    }

    return Scaffold(
      body: _buildContent(),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onDestinationSelected,
            destinations: _items
                .map(
                  (item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
