import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:movetraq/models/app_user.dart';
import 'package:movetraq/providers/auth_provider.dart';
import 'package:movetraq/services/local_data_service.dart';
import 'package:movetraq/screens/wallet/topup_screen.dart';

class _Data extends LocalDataService {
  final calls = <String>[];
  final amounts = <int>[];
  String status = 'pending';
  bool fail = false;
  Completer<Map<String, dynamic>>? pending;
  static final reference = 'mt-${'a' * 64}';
  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();
  @override
  Future<Map<String, dynamic>> initializeWalletTopup(
      int amount, String key) async {
    calls.add(key);
    amounts.add(amount);
    if (fail) throw StateError('Network unavailable');
    return pending?.future ??
        Future.value({
          'reference': reference,
          'checkoutUrl': 'https://checkout.paystack.com/test-checkout'
        });
  }

  @override
  Future<Map<String, dynamic>> verifyWalletTopup(String reference) async =>
      {'reference': reference, 'status': status};
}

Future<void> _open(WidgetTester tester, _Data data,
    {bool checkout = false}) async {
  final auth = AuthProvider(data)
    ..profile = AppUser(
        uid: 'sender', name: 'Sender', email: 'sender@example.test', phone: '');
  addTearDown(auth.dispose);
  addTearDown(data.dispose);
  await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<LocalDataService>.value(value: data),
        ChangeNotifierProvider<AuthProvider>.value(value: auth)
      ],
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TopupScreen(
                                  checkout: (_, __) async => checkout))),
                      child: const Text('Wallet')))))));
  await tester.tap(find.text('Wallet'));
  await tester.pumpAndSettle();
}

Future<void> _pay(WidgetTester tester, String amount) async {
  await tester.enterText(find.byType(TextFormField), amount);
  tester.testTextInput.hide();
  await tester.ensureVisible(find.text('Continue to Paystack'));
  await tester.tap(find.text('Continue to Paystack'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'validates integer kobo limits and never initializes invalid money',
      (tester) async {
    final data = _Data();
    await _open(tester, data);
    await _pay(tester, '99.99');
    expect(data.calls, isEmpty);
    await _pay(tester, '100.001');
    expect(data.calls, isEmpty);
    await _pay(tester, '1234.56');
    expect(data.amounts.single, 123456);
    expect(find.textContaining('Payment is not confirmed'), findsOneWidget);
  });
  testWidgets(
      'retries keep the same request key and changing amount uses a new one',
      (tester) async {
    final data = _Data()..fail = true;
    await _open(tester, data);
    await _pay(tester, '100');
    await _pay(tester, '100');
    expect(data.calls[0], data.calls[1]);
    await _pay(tester, '200');
    expect(data.calls[2], isNot(data.calls[0]));
    expect(data.calls.first, matches(RegExp(r'^[A-Za-z0-9-]{16,128}$')));
  });
  testWidgets(
      'checkout return cannot claim success without server verification',
      (tester) async {
    final data = _Data();
    await _open(tester, data, checkout: true);
    await _pay(tester, '100');
    expect(find.text('Add money'), findsOneWidget);
    expect(find.textContaining('Payment is not confirmed'), findsOneWidget);
  });
  testWidgets(
      'verified payment returns to wallet only after server confirmation',
      (tester) async {
    final data = _Data()..status = 'verified';
    await _open(tester, data, checkout: true);
    await _pay(tester, '100');
    expect(find.text('Wallet'), findsOneWidget);
    expect(find.text('Add money'), findsNothing);
    expect(find.text('Payment verified. Your wallet has been credited.'),
        findsOneWidget);
  });
}
