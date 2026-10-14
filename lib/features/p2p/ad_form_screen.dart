import 'package:flutter/material.dart';
import '../../screens/shared/feature_screen.dart';
import '../../widgets/app_page.dart';

class AdFormScreen extends StatelessWidget {
  const AdFormScreen({super.key, this.adId = ''});
  final String adId;
  @override
  Widget build(BuildContext context) => adId.isNotEmpty &&
          !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(adId)
      ? const AppPage(
          title: 'Delivery ad unavailable',
          children: [InfoBand(title: 'A valid delivery ad is required.')])
      : FeatureFormScreen(
          title: adId.isEmpty ? 'Create a delivery ad' : 'Edit delivery ad',
          action: 'Review ad',
          path: adId.isEmpty ? '/ads' : '/ads/$adId',
          method: adId.isEmpty ? 'POST' : 'PATCH',
          review: true,
          reviewTitle: 'Preview your offer',
          reviewAction: adId.isEmpty ? 'Publish offer' : 'Update offer',
          fields: const [
            FormFieldSpec('title', 'Offer title'),
            FormFieldSpec('pickupCoverage', 'Pickup coverage'),
            FormFieldSpec('destinationCoverage', 'Destination coverage'),
            FormFieldSpec('priceMinor', 'Price (NGN)', kind: FieldKind.money),
            FormFieldSpec('transport', 'Transport', options: [
              'motorcycle',
              'bicycle',
              'walking',
              'car',
              'van',
              'other_motor',
              'other_non_motor'
            ]),
            FormFieldSpec('availability', 'Availability'),
            FormFieldSpec('notes', 'Notes',
                kind: FieldKind.multiline, required: false)
          ],
        );
}
