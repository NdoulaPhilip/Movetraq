import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_bottom_nav.dart';
import '../home/home_shell.dart';
import '../home/profile_screen.dart';
import 'workspace_screens.dart';
import 'd_home_screen.dart';

class DelivererShell extends StatefulWidget {
  const DelivererShell({super.key});

  @override
  State<DelivererShell> createState() => _DelivererShellState();
}

class _DelivererShellState extends State<DelivererShell> {
  int _index = 0;

  final _screens = const [
    DHomeScreen(),
    DeliveryWorkScreen(embedded: true),
    DelivererAnalyticsScreen(embedded: true),
    MessagesScreen(embedded: true),
    ProfileScreen()
  ];

  static const _items = [
    NavItem(
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        label: 'Deliveries'),
    NavItem(
        icon: Icons.work_outline, selectedIcon: Icons.work, label: 'My work'),
    NavItem(
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights,
        label: 'Analytics'),
    NavItem(
        icon: Icons.chat_bubble_outline,
        selectedIcon: Icons.chat_bubble,
        label: 'Messages'),
    NavItem(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.profile?.activeRole == UserRole.sender) {
      return const HomeShell();
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _index,
        items: _items,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
