import 'package:flutter/services.dart';

class CallService {
  static const MethodChannel _channel = MethodChannel('movetraq/calls');

  const CallService();

  Future<void> dial(String phone) async {
    final normalized = phone.trim().replaceAll(RegExp(r'[\s()-]'), '');
    if (normalized.isEmpty) {
      throw StateError('No phone number is available for this contact.');
    }

    await _channel.invokeMethod<void>('dialPhone', {
      'phone': normalized,
    });
  }
}
