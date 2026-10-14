import 'package:flutter/material.dart';
import '../orders/order_tools.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;
  @override
  Widget build(BuildContext context) => OrderToolsScreen(orderId: orderId);
}
