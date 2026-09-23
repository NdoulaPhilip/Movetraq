import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mini_map.dart';
import '../../widgets/primary_button.dart';

class LiveTrackingScreen extends StatelessWidget {
  final String orderId;
  const LiveTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    final data = context.read<LocalDataService>();

    return Scaffold(
      body: StreamBuilder<ParcelOrder?>(
        stream: data.watchOrder(orderId),
        builder: (context, snap) {
          final order = snap.data;
          if (order == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final courierLocation = order.courierLocation;
          final arriving = order.status == OrderStatus.delivered;
          // Stage index: 0 = picked up, 1 = at your door / in transit, 2 = delivered.
          final stageIndex = switch (order.status) {
            OrderStatus.delivered || OrderStatus.released => 2,
            OrderStatus.pickedUp => 1,
            _ => 0,
          };

          return Stack(
            children: [
              Positioned.fill(
                child: MiniMap(
                  height: null,
                  courierLocation: courierLocation,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      CircleIconButton(icon: Icons.arrow_back, onTap: () => Navigator.maybePop(context)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.circle, size: 7, color: AppColors.accent),
                          const SizedBox(width: 7),
                          Text('${order.code} · Live', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const Spacer(),
                      CircleIconButton(
                        icon: Icons.ios_share,
                        onTap: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text:
                                  'Track ${order.code} on MoveTraq. Courier: ${order.delivererName ?? "Courier"}.',
                            ),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tracking details copied.')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              DraggableScrollableSheet(
                initialChildSize: 0.4,
                minChildSize: 0.32,
                maxChildSize: 0.75,
                builder: (context, controller) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
                      children: [
                        Center(
                          child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ARRIVING IN', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                                const SizedBox(height: 2),
                                Text(arriving ? 'Arriving' : '12 min',
                                    style: const TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, fontSize: 26)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Drop-off', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(order.dropoffAddress,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.right),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: courierLocation == null ? const Color(0xFFFBEADA) : const Color(0xFFDCF1E6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                courierLocation == null ? Icons.location_searching : Icons.my_location,
                                color: AppColors.ink,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  courierLocation == null
                                      ? 'Waiting for courier GPS...'
                                      : 'Courier GPS: ${courierLocation.latitude.toStringAsFixed(5)}, ${courierLocation.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ProgressTrack(stageIndex: stageIndex),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const CircleAvatar(radius: 22, backgroundColor: Color(0xFF3A4250), child: Icon(Icons.person, color: Colors.white, size: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(order.delivererName ?? 'Courier', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Row(children: const [
                                    Icon(Icons.star, size: 13, color: AppColors.warning),
                                    SizedBox(width: 4),
                                    Text('4.8 · Bike · LAG 221', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                                  ]),
                                ],
                              ),
                            ),
                            CircleIconButton(icon: Icons.chat_bubble_outline, background: const Color(0xFFF3F2EC), onTap: () => Navigator.pushNamed(context, '/chat', arguments: orderId)),
                            const SizedBox(width: 8),
                            CircleIconButton(
                              icon: Icons.call_outlined,
                              background: AppColors.ink,
                              iconColor: Colors.white,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Calling ${order.delivererName ?? "your courier"} is not available in this prototype.'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        if (order.status == OrderStatus.delivered) ...[
                          const SizedBox(height: 20),
                          PrimaryButton(
                            label: 'Release payment',
                            background: AppColors.accent,
                            foreground: AppColors.ink,
                            onPressed: () => Navigator.pushNamed(context, '/release', arguments: orderId),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  final int stageIndex; // 0, 1, or 2
  const _ProgressTrack({required this.stageIndex});

  @override
  Widget build(BuildContext context) {
    const labels = ['Picked up', 'At your door', 'Delivered'];
    final progress = stageIndex / 2;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: SizedBox(
            height: 4,
            child: Stack(
              children: [
                Container(color: AppColors.border),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.03, 1.0),
                  child: Container(color: AppColors.accent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(labels.length, (i) {
            final active = i <= stageIndex;
            return Text(
              labels[i],
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: i == stageIndex ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.ink : AppColors.faint,
              ),
            );
          }),
        ),
      ],
    );
  }
}
