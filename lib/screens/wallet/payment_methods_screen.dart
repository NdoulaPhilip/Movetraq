import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});
  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  late Future<Map<String, dynamic>> _methods;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _methods = FeatureGateway(context.read<LocalDataService>())
        .request('Payment methods', 'GET', '/payments/methods');
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    return AppPage(
        title: 'Payment methods',
        subtitle:
            'Manage the payment options you use for bookings and wallet top-ups.',
        children: [
          DesignCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('MoveTraq Wallet',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 7),
                Text(
                    profile == null
                        ? 'Sign in to view your balance'
                        : 'Balance: ${naira(profile.walletBalance)}',
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 20),
                const DesignBadge('Wallet payment option'),
              ])),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>>(
              future: _methods,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return LoadError(
                      error: snapshot.error!, onRetry: () => setState(_load));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final raw =
                    snapshot.data!['methods'] ?? snapshot.data!['items'];
                final methods =
                    raw is List ? raw.whereType<Map>().toList() : <Map>[];
                if (methods.isEmpty) {
                  return const DesignNote(
                      title: 'No saved payment methods',
                      body:
                          'Add a payment method through secure provider setup when available.');
                }
                return Column(children: [
                  for (final method in methods)
                    DesignNote(
                        title: (method['brand'] ??
                                method['name'] ??
                                'Payment method')
                            .toString(),
                        body: method['last4'] == null
                            ? 'Saved payment option'
                            : 'Ending ${method['last4']}'),
                ]);
              }),
          const SizedBox(height: 18),
          PrimaryButton(
              label: 'Add a payment method',
              onPressed: () =>
                  Navigator.pushNamed(context, '/add-payment-method')),
          const SizedBox(height: 12),
          SecondaryButton(
              label: 'Add money to wallet',
              onPressed: profile == null
                  ? null
                  : () => Navigator.pushNamed(context, '/topup')),
        ]);
  }
}

class AddPaymentMethodScreen extends StatelessWidget {
  const AddPaymentMethodScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
          title: 'Add payment method',
          subtitle:
              'Payment details must be collected through secure provider setup.',
          children: [
            const DesignNote(
                title: 'Secure card setup unavailable',
                body:
                    'Card and bank setup are not connected to this build. Your wallet can still be funded through the available Paystack checkout.'),
            const SizedBox(height: 12),
            const PrimaryButton(label: 'Add payment method', onPressed: null),
            const SizedBox(height: 12),
            SecondaryButton(
                label: 'Back to payment methods',
                onPressed: () => Navigator.maybePop(context)),
            const SizedBox(height: 12),
            SecondaryButton(
                label: 'Add money to wallet',
                onPressed: () => Navigator.pushNamed(context, '/topup')),
          ]);
}
