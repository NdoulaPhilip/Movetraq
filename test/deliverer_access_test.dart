import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:movetraq/features/deliverer/deliverer_gate.dart';
import 'package:movetraq/models/app_user.dart';
import 'package:movetraq/providers/auth_provider.dart';
import 'package:movetraq/services/local_data_service.dart';

void main() {
  AppUser user({String status = 'not_started', bool permission = false}) =>
      AppUser(
          uid: 'fixture',
          name: 'Sender',
          email: 'sender@example.test',
          phone: '',
          activeRole: UserRole.deliverer,
          verified: true,
          canDeliver: permission,
          delivererVerificationStatus: status);
  test('registration defaults to sender with no delivery capability', () {
    final profile = AppUser(
        uid: 'new', name: 'New user', email: 'new@example.test', phone: '');
    expect(profile.activeRole, UserRole.sender);
    expect(profile.isApprovedDeliverer, isFalse);
  });
  for (final status in [
    'not_started',
    'submitted',
    'under_review',
    'rejected',
    'suspended'
  ]) {
    testWidgets(
        '$status cannot open the deliverer workspace even with stale flags',
        (tester) async {
      final auth = AuthProvider(LocalDataService())
        ..profile = user(status: status, permission: true);
      addTearDown(auth.dispose);
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: auth,
          child: const MaterialApp(
              home:
                  DelivererGate(child: Text('Protected delivery dashboard')))));
      expect(find.text('Protected delivery dashboard'), findsNothing);
      expect(find.text('Delivery access'), findsOneWidget);
    });
  }
  testWidgets('current approved capability opens the same account workspace',
      (tester) async {
    final auth = AuthProvider(LocalDataService())
      ..profile = user(status: 'approved', permission: true);
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: auth,
        child: const MaterialApp(
            home: DelivererGate(child: Text('Protected delivery dashboard')))));
    expect(find.text('Protected delivery dashboard'), findsOneWidget);
  });
}
