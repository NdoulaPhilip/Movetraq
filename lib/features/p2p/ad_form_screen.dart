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
          title:
              adId.isEmpty ? 'Create a delivery offer' : 'Edit delivery offer',
          subtitle:
              'Help senders choose you with a clear route, price and availability.',
          action: 'Preview ad',
          path: adId.isEmpty ? '/ads' : '/ads/$adId',
          method: adId.isEmpty ? 'POST' : 'PATCH',
          review: true,
          reviewStartAction: 'Preview ad',
          reviewTitle: 'Preview your offer',
          reviewAction: adId.isEmpty ? 'Publish offer' : 'Update offer',
          fields: const [
            FormFieldSpec('title', 'Offer title'),
            FormFieldSpec('pickupCoverage', 'Pickup area'),
            FormFieldSpec('destinationCoverage', 'Destination area'),
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
            FormFieldSpec('notes', 'Parcel notes',
                kind: FieldKind.multiline, required: false)
          ],
        );
}
