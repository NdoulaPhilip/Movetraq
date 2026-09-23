import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/parcel_order.dart';
import '../../providers/deliverer_tracking_provider.dart';
import '../../services/local_data_service.dart';

class DActiveScreen extends StatefulWidget {
  const DActiveScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<DActiveScreen> createState() => _DActiveScreenState();
}

class _DActiveScreenState extends State<DActiveScreen> {
  int currentStage = 0;
  bool trackingStarted = false;

  final List<String> stageLabels = const [
    'PICK UP FROM',
    'DELIVER TO',
    'COMPLETED',
  ];

  final List<String> stageTitles = const [
    'Shoprite, Ikeja',
    '7 Freedom Way, Lekki',
    'Awaiting payment release',
  ];

  final List<String> buttonLabels = const [
    'Confirm pickup',
    'Mark as delivered',
    'Back to jobs',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!trackingStarted) {
      trackingStarted = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startTracking();
      });
    }
  }

  Future<void> _startTracking() async {
    try {
      await context
          .read<DelivererTrackingProvider>()
          .startTracking(widget.orderId);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to start tracking: $error'),
        ),
      );
    }
  }

  Future<void> _advanceStage() async {
    final data = context.read<LocalDataService>();
    final stage = data.getOrder(widget.orderId)?.dStage ?? currentStage;
    if (stage < 2) {
      final nextStage = stage + 1;
      await data.advanceDelivererStage(
            widget.orderId,
            nextStage,
          );

      if (nextStage == 2) {
        await context.read<DelivererTrackingProvider>().stopTracking();
      }

      if (!mounted) return;
      setState(() {
        currentStage = nextStage;
      });

      return;
    }

    await context
        .read<DelivererTrackingProvider>()
        .stopTracking();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracking = context.watch<DelivererTrackingProvider>();
    final data = context.read<LocalDataService>();

    final double? latitude = tracking.latitude;
    final double? longitude = tracking.longitude;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0F14),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Active delivery',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: tracking.isTracking
                  ? const Color(0xFFCBF24A)
                  : const Color(0xFF2B323F),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              tracking.isTracking ? 'Live' : 'Offline',
              style: TextStyle(
                color: tracking.isTracking
                    ? const Color(0xFF101319)
                    : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<ParcelOrder?>(
        stream: data.watchOrder(widget.orderId),
        builder: (context, snapshot) {
          final order = snapshot.data;
          final stage = (order?.dStage ?? currentStage).clamp(0, 2).toInt();
          final stageTitles = [
            order?.pickupAddress ?? 'Pickup address',
            order?.dropoffAddress ?? 'Drop-off address',
            'Awaiting payment release',
          ];
          final payout = order?.payout ?? 0;

          return Stack(
            children: [
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0C0F14),
              alignment: Alignment.center,
              child: tracking.isLoading
                  ? const CircularProgressIndicator(
                      color: Color(0xFFCBF24A),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.navigation_rounded,
                          color: Color(0xFFCBF24A),
                          size: 55,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          latitude != null && longitude != null
                              ? '${latitude.toStringAsFixed(6)}, '
                                  '${longitude.toStringAsFixed(6)}'
                              : 'Waiting for location...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stageLabels[stage],
                              style: const TextStyle(
                                color: Color(0xFF9AA3AF),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              stageTitles[stage],
                              style: const TextStyle(
                                color: Color(0xFF101319),
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'PAYOUT',
                            style: TextStyle(
                              color: Color(0xFF9AA3AF),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₦${payout.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Color(0xFF101319),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (tracking.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      tracking.errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFF2544B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _advanceStage,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFCBF24A),
                        foregroundColor: const Color(0xFF101319),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        buttonLabels[stage],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
          );
        },
      ),
    );
  }
}
