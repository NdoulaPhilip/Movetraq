class CheckoutRequest {
  CheckoutRequest.fromJson(Map<String, dynamic> data)
      : url = Uri.parse(data['checkoutUrl'] as String),
        reference = data['reference'] as String,
        callback = data['callbackUrl'] is String
            ? Uri.tryParse(data['callbackUrl'] as String)
            : null,
        cancel = data['cancelUrl'] is String
            ? Uri.tryParse(data['cancelUrl'] as String)
            : null {
    if (url.scheme != 'https' ||
        url.host != 'checkout.paystack.com' ||
        url.userInfo.isNotEmpty ||
        url.port != 443 ||
        url.path.length < 2 ||
        url.hasFragment ||
        !RegExp(r'^mt-[a-f0-9]{64}$').hasMatch(reference)) {
      throw const FormatException('Secure checkout details are invalid.');
    }
    for (final target in [callback, cancel]) {
      if (target != null &&
          (target.scheme != 'https' ||
              target.host.isEmpty ||
              target.userInfo.isNotEmpty ||
              target.hasFragment)) {
        throw const FormatException('Secure payment callback is invalid.');
      }
    }
  }
  final Uri url;
  final String reference;
  final Uri? callback, cancel;
  bool _matches(Uri uri, Uri? target) =>
      target != null &&
      uri.scheme == target.scheme &&
      uri.host == target.host &&
      uri.port == target.port &&
      uri.path == target.path &&
      uri.userInfo.isEmpty;
  bool isCallback(Uri uri) =>
      _matches(uri, callback) && uri.queryParameters['reference'] == reference;
  bool isCancel(Uri uri) => _matches(uri, cancel);
  bool isAuthenticationClose(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == 'standard.paystack.co' &&
      uri.path == '/close' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty;
  bool allowsNavigation(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      uri.port == 443;
}
