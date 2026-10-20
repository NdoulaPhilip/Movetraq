import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/payments/checkout_request.dart';
import '../../features/payments/paystack_checkout_screen.dart';
import '../../features/wallet/deposit_amount.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/design_ui.dart';
import '../../theme/app_theme.dart';

typedef WalletCheckout = Future<bool> Function(
    BuildContext context, CheckoutRequest request);

class TopupScreen extends StatefulWidget {
  const TopupScreen({super.key, this.checkout});
  final WalletCheckout? checkout;
  @override
  State<TopupScreen> createState() => _TopupScreenState();
}

class _TopupScreenState extends State<TopupScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String? _key;
  int? _requestedAmount;
  bool _busy = false;
  Object? _error;
  String? _notice;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_busy || !_form.currentState!.validate()) return;
    final owner = context.read<AuthProvider>().profile?.uid;
    if (owner == null) {
      setState(() => _error = StateError('Sign in before adding money.'));
      return;
    }
    final data = context.read<LocalDataService>();
    final amount = depositMinorUnits(_amount.text)!;
    if (_key == null || _requestedAmount != amount) {
      _requestedAmount = amount;
      final random = Random.secure();
      _key =
          'topup-${List.generate(24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final payment = await data.initializeWalletTopup(amount, _key!);
      if (!mounted || context.read<AuthProvider>().profile?.uid != owner) {
        return;
      }
      bool verified;
      if (payment['status'] == 'verified') {
        final result =
            await data.verifyWalletTopup(payment['reference'] as String);
        verified = result['status'] == 'verified' &&
            result['reference'] == payment['reference'];
      } else {
        final request = CheckoutRequest.fromJson(payment);
        verified = await (widget.checkout?.call(context, request) ??
            Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => PaystackCheckoutScreen(
                        request: request,
                        verifyPayment: (reference) {
                          if (data.currentUser?.uid != owner) {
                            throw StateError('Your account changed.');
                          }
                          return data.verifyWalletTopup(reference);
                        }))).then((value) => value ?? false));
        // Navigation alone is not proof of payment.
        if (verified) {
          final result = await data.verifyWalletTopup(request.reference);
          verified = result['status'] == 'verified' &&
              result['reference'] == request.reference;
        }
      }
      if (!mounted || context.read<AuthProvider>().profile?.uid != owner) {
        return;
      }
      if (verified) {
        _key = null;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment verified. Your wallet has been credited.')));
        Navigator.pop(context);
      } else {
        setState(() => _notice =
            'Payment is not confirmed. You can retry or check its reference.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
          title: 'Add money',
          subtitle: 'Top up your wallet to fund deliveries instantly.',
          footer: PrimaryButton(
              label: 'Continue to Paystack',
              loading: _busy,
              onPressed: _busy ? null : _pay),
          children: [
            DesignCard(
                dark: true,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AMOUNT TO ADD',
                          style:
                              TextStyle(fontSize: 11, color: Colors.white54)),
                      const SizedBox(height: 12),
                      Text(naira((depositMinorUnits(_amount.text) ?? 0) / 100),
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final amount in [2000, 5000, 10000])
                          ChoiceChip(
                              label: Text(naira(amount)),
                              selected: _amount.text == amount.toString(),
                              selectedColor: AppColors.accent,
                              onSelected: _busy
                                  ? null
                                  : (_) => setState(
                                      () => _amount.text = amount.toString())),
                      ]),
                    ])),
            const SizedBox(height: 20),
            const InfoBand(
                title: 'Pay with Paystack',
                body: 'Your wallet is credited only after server verification.',
                icon: Icons.lock_outline),
            Form(
                key: _form,
                child: TextFormField(
                    controller: _amount,
                    onChanged: (_) => setState(() {}),
                    enabled: !_busy,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Amount (NGN)'),
                    validator: (value) => depositMinorUnits(value ?? '') == null
                        ? 'Enter NGN 100 to NGN 1,000,000, with up to 2 decimal places.'
                        : null)),
            const SizedBox(height: 20),
            if (_error != null) LoadError(error: _error!),
            if (_notice != null)
              InfoBand(title: _notice!, icon: Icons.hourglass_empty),
            const SizedBox(height: 15),
            const DesignNote(
                title: 'Payment method',
                body:
                    'Choose a supported card or bank payment securely during checkout.'),
            const RouteTile(
                title: 'Manage payment methods',
                icon: Icons.credit_card,
                route: '/payment-methods'),
            const RouteTile(
                title: 'Check a payment',
                icon: Icons.fact_check_outlined,
                route: '/confirm-payment'),
          ]);
}
