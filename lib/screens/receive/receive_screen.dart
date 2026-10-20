import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';
import '../orders/order_tools.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});
  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  late Stream<List<ParcelOrder>> _orders;
  String _query = '';
  bool _showResults = false;
  final _form = GlobalKey<FormState>();
  final _reference = TextEditingController();
  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _orders = context
        .read<LocalDataService>()
        .watchSenderOrders(context.read<AuthProvider>().profile?.uid ?? '');
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Receive a package', children: [
        const DesignNote(
            title: 'Something on its way?',
            body:
                'Enter a tracking ID shared by your sender. Only deliveries linked to your account are available here.'),
        Form(
            key: _form,
            child: TextFormField(
                controller: _reference,
                decoration: const InputDecoration(
                    labelText: 'Tracking ID', prefixIcon: Icon(Icons.search)),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter a tracking ID'
                    : null)),
        const SizedBox(height: 24),
        PrimaryButton(
            label: 'Find package',
            onPressed: () {
              if (_form.currentState!.validate()) {
                setState(() => _showResults = true);
              }
            }),
        const SizedBox(height: 16),
        SecondaryButton(
            label: 'View incoming deliveries',
            onPressed: () => setState(() {
                  _reference.clear();
                  _query = '';
                  _showResults = true;
                })),
        const SizedBox(height: 18),
        if (_showResults)
          const InfoBand(
              title: 'Your incoming deliveries',
              body: 'Only deliveries linked to your account are shown.',
              icon: Icons.inventory_2_outlined),
        if (_showResults)
          StreamBuilder<List<ParcelOrder>>(
              stream: _orders,
              builder: (context, snapshot) {
                if (snapshot.hasError) return LoadError(error: snapshot.error!);
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = snapshot.data!
                    .where((order) =>
                        order.status != OrderStatus.cancelled &&
                        order.status != OrderStatus.released &&
                        '${order.title} ${order.code}'
                            .toLowerCase()
                            .contains(_query))
                    .toList();
                if (orders.isEmpty) {
                  return const PremiumEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No linked deliveries found',
                      body: 'Check the tracking ID or contact your sender.');
                }
                return Column(children: [
                  for (final order in orders)
                    RouteTile(
                        title: order.title,
                        subtitle:
                            '${order.code} - ${orderStatusLabel(order.status)}',
                        icon: Icons.local_shipping_outlined,
                        route: '/order-tracking',
                        arguments: order.id)
                ]);
              }),
        const RouteTile(
            title: 'Delivery history',
            icon: Icons.history,
            route: '/track-list'),
      ]);
}
