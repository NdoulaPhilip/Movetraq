import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';

class OrderDetailScreen extends StatelessWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final data = context.read<LocalDataService>();

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<ParcelOrder?>(
          stream: data.watchOrder(orderId),
          builder: (context, snap) {
            final order = snap.data;
            if (order == null) return const Center(child: CircularProgressIndicator());

            final steps = [
              ('Order placed', _fmtTime(order.createdAt), true),
              ('Courier assigned', order.delivererName != null ? '${_fmtTime(order.createdAt.add(const Duration(minutes: 3)))} · ${order.delivererName}' : 'Pending', order.status != OrderStatus.pendingOffer && order.status != OrderStatus.negotiating),
              ('Picked up', _fmtTime(order.createdAt.add(const Duration(minutes: 17))), [OrderStatus.pickedUp, OrderStatus.delivered, OrderStatus.released].contains(order.status)),
              ('In transit', order.status == OrderStatus.pickedUp ? 'Now · 1 min away' : 'Completed', [OrderStatus.pickedUp, OrderStatus.delivered, OrderStatus.released].contains(order.status)),
              ('Delivered', order.status == OrderStatus.delivered || order.status == OrderStatus.released ? _fmtTime(order.deliveredAt ?? order.createdAt) : 'Estimated ${_fmtTime(order.createdAt.add(const Duration(minutes: 63)))}', [OrderStatus.delivered, OrderStatus.released].contains(order.status)),
            ];
            final currentIndex = switch (order.status) {
              OrderStatus.pendingOffer || OrderStatus.negotiating => 0,
              OrderStatus.accepted => 1,
              OrderStatus.pickedUp => 3,
              OrderStatus.delivered || OrderStatus.released => 4,
              OrderStatus.cancelled => -1,
            };

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleIconButton(icon: Icons.arrow_back, onTap: () => Navigator.maybePop(context)),
                    CircleIconButton(icon: Icons.chat_bubble_outline, onTap: () => Navigator.pushNamed(context, '/chat', arguments: orderId)),
                  ],
                ),
                const SizedBox(height: 16),
                // Map preview with "Open live map" pill
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(context, '/live', arguments: order.id),
                    child: SizedBox(
                      height: 158,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Positioned.fill(child: MiniMap(height: null)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.navigation, size: 17, color: AppColors.ink),
                              SizedBox(width: 7),
                              Text('Open live map', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.ink)),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(order.title, style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 24)),
                const SizedBox(height: 6),
                Row(children: [
                  Text(order.code, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(width: 8),
                  Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.faint, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Row(children: [
                    Container(width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(_statusLabel(order.status), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F9D58))),
                  ]),
                ]),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.borderSoft)),
                  child: Column(
                    children: List.generate(steps.length, (i) {
                      final (label, time, done) = steps[i];
                      final isCurrent = i == currentIndex;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCurrent ? AppColors.accent : (done ? AppColors.ink : Colors.white),
                                  border: Border.all(color: done || isCurrent ? Colors.transparent : AppColors.border, width: 2),
                                ),
                                child: done && !isCurrent
                                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                                    : (isCurrent ? const Icon(Icons.circle, size: 8, color: AppColors.ink) : null),
                              ),
                              if (i != steps.length - 1)
                                Container(width: 2, height: 30, color: done ? AppColors.ink : AppColors.border),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label,
                                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: done || isCurrent ? AppColors.ink : AppColors.muted)),
                                  const SizedBox(height: 2),
                                  Text(time, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.pushNamed(context, '/chat', arguments: orderId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.borderSoft)),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 22, backgroundColor: Color(0xFF3A4250), child: Icon(Icons.person, color: Colors.white, size: 20)),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.delivererName ?? 'Courier', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                              const SizedBox(height: 2),
                              Row(children: const [
                                Icon(Icons.star, size: 13, color: AppColors.warning),
                                SizedBox(width: 5),
                                Text('4.8 · Tap to view profile', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                              ]),
                            ],
                          ),
                        ),
                        CircleIconButton(icon: Icons.chat_bubble_outline, background: const Color(0xFFF3F2EC), onTap: () => Navigator.pushNamed(context, '/chat', arguments: orderId)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.borderSoft)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Payment', style: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 12),
                      _paymentRow('Delivery fee', '₦${(order.price - 500).clamp(0, order.price).toStringAsFixed(0)}'),
                      _paymentRow('Service', '₦500'),
                      _paymentRow('Gold discount', '−₦0', color: AppColors.success),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: AppColors.borderSoft)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Held in escrow', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          Text('₦${order.price.toStringAsFixed(0)}', style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 20)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (order.status == OrderStatus.delivered)
                  PrimaryButton(
                    label: 'Confirm delivery & release payment',
                    trailingIcon: null,
                    onPressed: () => Navigator.pushNamed(context, '/release', arguments: order.id),
                  )
                else if (order.status == OrderStatus.accepted || order.status == OrderStatus.pickedUp)
                  PrimaryButton(label: 'Track live', onPressed: () => Navigator.pushNamed(context, '/live', arguments: order.id)),
              ],
            );
          },
        ),
      ),
    );
  }

  String _statusLabel(OrderStatus s) {
    switch (s) {
      case OrderStatus.pickedUp:
        return 'In transit';
      case OrderStatus.accepted:
        return 'Picking up';
      case OrderStatus.delivered:
        return 'Arriving';
      case OrderStatus.released:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Finding courier';
    }
  }

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:${d.minute.toString().padLeft(2, '0')} $ap';
  }

  Widget _paymentRow(String k, String v, {Color color = AppColors.ink}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
          Text(v, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}
