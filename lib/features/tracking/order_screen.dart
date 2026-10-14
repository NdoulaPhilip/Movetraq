import 'package:flutter/material.dart';
import '../../screens/orders/order_tools.dart';
import '../../screens/track/live_tracking_screen.dart';

class OrderScreen extends StatelessWidget {
  const OrderScreen({super.key, required this.id, this.liveTracking = false});
  final String id;
  final bool liveTracking;
  @override
  Widget build(BuildContext context) => liveTracking
      ? LiveTrackingScreen(orderId: id)
      : OrderToolsScreen(orderId: id);
}
