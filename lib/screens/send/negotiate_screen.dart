import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/send_flow_provider.dart';
import '../../services/feature_gateway.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';
import '../../theme/app_theme.dart';

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

  void _adjust(double delta) {
    final current = (parseMinorUnits(_offer.text) ?? 0) / 100;
    setState(() =>
        _offer.text = (current + delta).clamp(500, 1000000).toStringAsFixed(2));
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<SendFlowProvider>();
    return AppPage(
        title: 'Negotiate price',
        footer: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Expanded(child: Text('Your offer')),
            IconButton.filledTonal(
                tooltip: 'Decrease offer',
                onPressed: () => _adjust(-100),
                icon: const Icon(Icons.remove)),
            const SizedBox(width: 8),
            Text(naira((parseMinorUnits(_offer.text) ?? 0) / 100),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            IconButton.filledTonal(
                tooltip: 'Increase offer',
                onPressed: () => _adjust(100),
                icon: const Icon(Icons.add)),
          ]),
          const SizedBox(height: 10),
          PrimaryButton(
              label: 'Review delivery',
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                flow.setDraftOffer(parseMinorUnits(_offer.text)! / 100);
                Navigator.pushNamed(context, '/confirm-order');
              }),
        ]),
        children: [
          DesignCard(
              child: Row(children: [
            DesignAvatar(flow.selectedDelivererName ?? 'Courier'),
            const SizedBox(width: 12),
            Expanded(
                child: Text(flow.selectedDelivererName ?? 'Choose a deliverer',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600))),
          ])),
          const SizedBox(height: 20),
          const Center(child: DesignBadge('Your offer is a draft')),
          const SizedBox(height: 18),
          Align(
              alignment: Alignment.centerLeft,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F6F2),
                      borderRadius: BorderRadius.circular(18)),
                  child: Text(
                      'Your proposed delivery fee is ${naira((parseMinorUnits(_offer.text) ?? 0) / 100)}.',
                      style: const TextStyle(fontSize: 13, height: 1.5)))),
          const SizedBox(height: 10),
          const Text(
              'The deliverer must accept your request before an agreement is confirmed.',
              style:
                  TextStyle(fontSize: 11, height: 1.6, color: AppColors.muted)),
          const SizedBox(height: 24),
          DesignCard(
              child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 12),
                  title: const Text('Delivery route',
                      style: TextStyle(fontSize: 13)),
                  children: [
                DesignRoute(
                    pickup: flow.pickupAddress,
                    destination: flow.dropoffAddress)
              ])),
          const SizedBox(height: 20),
          Form(
              key: _form,
              child: TextFormField(
                  controller: _offer,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration:
                      const InputDecoration(labelText: 'Your offer (NGN)'),
                  validator: (value) => (parseMinorUnits(value ?? '') ?? 0) <= 0
                      ? 'Enter an amount greater than zero'
                      : null)),
        ]);
  }
}
