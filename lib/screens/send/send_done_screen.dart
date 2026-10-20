import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/send_flow_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_page.dart';
import '../../widgets/completion_layout.dart';
import '../../widgets/primary_button.dart';

class SendDoneScreen extends StatefulWidget {
  const SendDoneScreen({super.key});

  @override
  State<SendDoneScreen> createState() => _SendDoneScreenState();
}

class _SendDoneScreenState extends State<SendDoneScreen> {
  String? _id;
  Stream<ParcelOrder?>? _order;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.watch<SendFlowProvider>().createdOrderId;
    if (id != _id) {
      _id = id;
      _load();
    }
  }

  void _load() => _order =
      _id == null ? null : context.read<LocalDataService>().watchOrder(_id!);

  void _home() =>
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: StreamBuilder<ParcelOrder?>(
          key: ValueKey(_id),
          stream: _order,
          builder: (context, snapshot) {
            final order = snapshot.data;
            if (_id == null ||
                snapshot.hasError ||
                (snapshot.connectionState == ConnectionState.done &&
                    order == null)) {
              return CompletionLayout(children: [
                Text(
                    _id == null
                        ? 'No delivery request yet'
                        : 'Order details unavailable',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 23, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                if (_id != null)
                  LoadError(
                      error: 'Unable to load your order details.',
                      onRetry: () => setState(_load)),
                TextButton(onPressed: _home, child: const Text('Back to home')),
              ]);
            }
            if (order == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final pending = order.status == OrderStatus.pendingOffer ||
                order.status == OrderStatus.negotiating;
            return CompletionLayout(children: [
              Container(
                  width: 98,
                  height: 98,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                      border:
                          Border.all(color: const Color(0xFFF2FBD3), width: 6)),
                  child:
                      const Icon(Icons.check, size: 39, color: AppColors.ink)),
              const SizedBox(height: 25),
              const Text('You’re all set!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 265),
                  child: Text(
                      pending
                          ? 'Your delivery request is live. ${order.targetDelivererId == null ? 'Nearby deliverers can accept it now' : 'Your selected deliverer can accept it now'}; tracking starts when one accepts.'
                          : 'Your delivery request has been created. Follow the latest updates from your order.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: AppColors.inkSoft))),
              const SizedBox(height: 22),
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 266),
                  child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFEDEDEB)),
                          borderRadius: BorderRadius.circular(17)),
                      child: Row(children: [
                        Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                                color: const Color(0xFFF0F4D9),
                                borderRadius: BorderRadius.circular(11)),
                            child: Center(
                                child: SvgPicture.string(
                                    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#101319" stroke-width="1.1" stroke-linejoin="round"><path d="M12 2 22 7.5v10L12 23 2 17.5v-10L12 2ZM2 7.5l10 5.5 10-5.5M12 13v10"/></svg>',
                                    width: 18,
                                    height: 18))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('${order.code} created',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Text(
                                  '${order.isExpress ? 'Express' : 'P2P'} · ${_amount(order.price)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                            ])),
                      ]))),
              const SizedBox(height: 23),
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 266),
                  child: PrimaryButton(
                      label: 'Track it live',
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pushNamedAndRemoveUntil(
                            '/home', (_) => false);
                        navigator.pushNamed('/live', arguments: order.id);
                      })),
              const SizedBox(height: 9),
              TextButton(
                  onPressed: _home,
                  child: const Text('Back to home',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600))),
            ]);
          },
        )),
      );

  static String _amount(double value) {
    final parts = value
        .toStringAsFixed(value == value.roundToDouble() ? 0 : 2)
        .split('.');
    final whole = parts.first.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');
    return '₦$whole${parts.length > 1 ? '.${parts.last}' : ''}';
  }
}
