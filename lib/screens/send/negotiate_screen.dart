import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/send_flow_provider.dart';
import '../../services/feature_gateway.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';

class NegotiateScreen extends StatefulWidget {
  const NegotiateScreen({super.key});
  @override
  State<NegotiateScreen> createState() => _NegotiateScreenState();
}

class _NegotiateScreenState extends State<NegotiateScreen> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _offer;
  @override
  void initState() {
    super.initState();
    _offer = TextEditingController(
        text: context.read<SendFlowProvider>().offer.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _offer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<SendFlowProvider>();
    return AppPage(title: 'Delivery offer', children: [
      InfoBand(
          title: flow.selectedDelivererName ?? 'Choose a deliverer',
          body: 'Your offer is a draft until accepted by the deliverer.',
          dark: true,
          icon: Icons.local_shipping_outlined),
      DetailRow('Pickup', flow.pickupAddress),
      DetailRow('Destination', flow.dropoffAddress),
      const SizedBox(height: 18),
      Form(
          key: _form,
          child: TextFormField(
              controller: _offer,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Your offer (NGN)'),
              validator: (value) => (parseMinorUnits(value ?? '') ?? 0) <= 0
                  ? 'Enter an amount greater than zero'
                  : null)),
      const SizedBox(height: 24),
      PrimaryButton(
          label: 'Review delivery',
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            flow.setDraftOffer(parseMinorUnits(_offer.text)! / 100);
            Navigator.pushNamed(context, '/confirm-order');
          }),
    ]);
  }
}
