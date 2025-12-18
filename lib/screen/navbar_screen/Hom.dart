import 'package:flutter/material.dart';
import 'package:movetrap/Activity.dart';
import 'package:movetrap/screen/Home_screen/Home.dart';
import 'package:movetrap/screen/orders/Order.dart';
import 'package:movetrap/screen/Profiles/Profile.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

class Hom extends StatefulWidget {
  const Hom({super.key});

  @override
  State<Hom> createState() => _storeState();
}

class _storeState extends State<Hom> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabView(
      onTabChanged: (index) {
        if (index == 2) { // Order tab index
          // Use pushScreen from persistent_bottom_nav_bar_v2
          pushScreen(
            context,
            screen: const Order(),
            withNavBar: false, // Hide navbar on Order screen
          );
        }
      },
      tabs: [
        PersistentTabConfig(
          screen: const Home(),
          item: ItemConfig(
            icon: const Icon(Icons.home),
            title: "Home",
          ),
        ),
        PersistentTabConfig(
          screen: const Activity(),
          item: ItemConfig(
            icon: const Icon(Icons.analytics_outlined),
            title: "Activity",
          ),
        ),
        PersistentTabConfig(
          screen: const SizedBox.shrink(),
          item: ItemConfig(
            icon: const Icon(Icons.local_shipping_outlined),
            title: "Order",
          ),
        ),
        PersistentTabConfig(
          screen: const Profile(),
          item: ItemConfig(
            icon: const Icon(Icons.person),
            title: "Profile",
          ),
        ),
      ],
      navBarBuilder: (navBarConfig) => Style1BottomNavBar(
        navBarConfig: navBarConfig,
      ),
    );
  }
}