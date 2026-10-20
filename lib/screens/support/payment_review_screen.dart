import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/design_ui.dart';

class PaymentReviewScreen extends StatefulWidget {
  const PaymentReviewScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<PaymentReviewScreen> createState() => _PaymentReviewScreenState();
}

class _PaymentReviewScreenState extends State<PaymentReviewScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  late final Stream<ParcelOrder?> _order;
  bool _busy = false;
  bool _sent = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _order = context.read<LocalDataService>().watchOrder(widget.orderId);
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit(ParcelOrder order) async {
    if (_busy || !_form.currentState!.validate()) return;
    final uid = context.read<AuthProvider>().profile?.uid;
    if (uid == null) {
      showActionError(context, 'Sign in to request a payment review.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<LocalDataService>().createSupportTicket(uid,
          subject: 'Payment review / ${order.code}',
          message: 'Order: ${order.id}\n${_description.text.trim()}');
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
          title: 'Request a payout review',
          subtitle:
              'Request a review of a pending delivery payment and add relevant details.',
          children: [
            StreamBuilder<ParcelOrder?>(
                stream: _order,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return LoadError(error: snapshot.error!);
                  }
                  if (!snapshot.hasData &&
                      snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final order = snapshot.data;
                  if (order == null) {
                    return const InfoBand(
                        title: 'Open a delivery to request a payment review.');
                  }
                  if (_sent) {
                    return const InfoBand(
                        title: 'Payment review requested',
                        body: 'Follow your request in Help & support.',
                        icon: Icons.check_circle_outline);
                  }
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DesignNote(
                            reference: order.code,
                            title: 'Need help with your payment?',
                            body:
                                'Explain why payment needs review. Include when the item arrived and any contact attempts.'),
                        DetailRow('Payment status', order.status.name),
                        Form(
                            key: _form,
                            child: TextFormField(
                                controller: _description,
                                enabled: !_busy,
                                maxLines: 5,
                                maxLength: 2000,
                                decoration: const InputDecoration(
                                    labelText: 'Tell us what happened'),
                                validator: (value) =>
                                    (value ?? '').trim().length < 3
                                        ? 'Describe why payment needs review'
                                        : null)),
                        const SizedBox(height: 18),
                        if (_error != null) LoadError(error: _error!),
                        PrimaryButton(
                            label: 'Request payment review',
                            loading: _busy,
                            onPressed: () => _submit(order)),
                      ]);
                }),
            const RouteTile(
                title: 'Contact support',
                icon: Icons.support_agent,
                route: '/support'),
          ]);
}
