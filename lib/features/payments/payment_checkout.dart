import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/networking/api.dart';
import 'checkout_request.dart';
import 'paystack_checkout_screen.dart';

class PaymentCheckout {
  const PaymentCheckout(this.api);
  final ApiClient api;
  Future<bool> open(BuildContext context, Map<String, dynamic> payment) async {
    final request = CheckoutRequest.fromJson(payment);
    if (kIsWeb ||
        ![TargetPlatform.android, TargetPlatform.iOS]
            .contains(defaultTargetPlatform)) {
      throw UnsupportedError(
          'Hosted mobile checkout is available on Android and iOS.');
    }
    return await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    PaystackCheckoutScreen(request: request, api: api))) ??
        false;
  }

  Future<Map<String, dynamic>> initializeTopup(int amountMinor, String key) {
    if (amountMinor < 10000 || amountMinor > 100000000) {
      throw ArgumentError('Top-ups must be between NGN 100 and NGN 1,000,000.');
    }
    return api.request('/payments/topups',
        method: 'POST', data: {'amountMinor': amountMinor}, key: key);
  }
}
