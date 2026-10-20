import '../../widgets/design_ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  const PaymentConfirmationScreen({super.key, this.reference = ''});
  final String reference;

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _reference;
  bool _busy = false;
  String? _status;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reference = TextEditingController(text: widget.reference);
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final result = await context
          .read<LocalDataService>()
          .verifyWalletTopup(_reference.text.trim());
      final status = result['status'];
      if (status is! String || status.isEmpty) {
        throw StateError('Payment status could not be confirmed.');
      }
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Confirm payment', children: [
        const DesignNote(
          title: 'Check your payment',
          body: 'Use the reference from your payment checkout.',
        ),
        Form(
            key: _form,
            child: TextFormField(
                controller: _reference,
                enabled: !_busy,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Payment reference'),
                onChanged: (_) => setState(() {
                      _status = null;
                      _error = null;
                    }),
                validator: (value) =>
                    RegExp(r'^mt-[a-f0-9]{64}$').hasMatch((value ?? '').trim())
                        ? null
                        : 'Enter the reference from your checkout')),
        const SizedBox(height: 20),
        if (_error != null) LoadError(error: _error!),
        if (_status != null)
          InfoBand(
              title: _status == 'verified'
                  ? 'Payment confirmed'
                  : 'Payment not confirmed',
              body: _status == 'verified'
                  ? 'Your payment has been verified.'
                  : 'Current status: ${_status!.replaceAll('_', ' ')}',
              icon: _status == 'verified'
                  ? Icons.check_circle_outline
                  : Icons.hourglass_empty),
        PrimaryButton(
            label: 'Check payment status', loading: _busy, onPressed: _verify),
        const SizedBox(height: 12),
        SecondaryButton(
            label: 'Choose another payment method',
            onPressed: _busy
                ? null
                : () => Navigator.pushNamed(context, '/payment-methods')),
        const RouteTile(
            title: 'Transaction records',
            icon: Icons.history,
            route: '/transactions'),
      ]);
}
