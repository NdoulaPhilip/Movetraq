import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_bottom_nav.dart';
import '../deliverer/deliverer_shell.dart';
import 'activity_screen.dart';
import 'home_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/deliverer/deliverer_gate.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    ActivityScreen(),
    OrdersScreen(),
    ProfileScreen()
  ];

  static const _items = [
    NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    NavItem(
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        label: 'Activity'),
    NavItem(
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        label: 'Orders'),
    NavItem(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // If the profile's active role flips to deliverer (e.g. via the profile
    // switch), show the deliverer shell instead.
    if (auth.profile?.activeRole == UserRole.deliverer &&
        auth.profile?.isApprovedDeliverer == true) {
      return const DelivererGate(child: DelivererShell());
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
