import 'package:flutter/material.dart';

import '../models/parcel_order.dart';
import '../theme/app_theme.dart';

class DeliveryProgress extends StatelessWidget {
  const DeliveryProgress({super.key, required this.status});
  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final stage = switch (status) {
      OrderStatus.accepted => 1,
      OrderStatus.pickedUp => 2,
      OrderStatus.delivered || OrderStatus.released => 3,
      _ => -1,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry
              in ['Accepted', 'Pickup', 'Drop-off', 'Complete'].asMap().entries)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 3, vertical: 11),
                  decoration: BoxDecoration(
                    color: entry.key <= stage
                        ? AppColors.accent
                        : const Color(0xFFF3F2EC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(entry.value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: entry.key == stage
                              ? FontWeight.w600
                              : FontWeight.w400)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
