import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:movetraq/models/app_user.dart';
import 'package:movetraq/providers/auth_provider.dart';
import 'package:movetraq/screens/account/account_screens.dart';
import 'package:movetraq/services/local_data_service.dart';

class _Data extends LocalDataService {
  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();
}

class _Auth extends AuthProvider {
  _Auth(super.data);
  final submissions = <Map<String, String>>[];
  Completer<bool>? pending;
  bool succeeds = true;
  @override
  Future<bool> updateProfile(
      {required String name, required String phone}) async {
    submissions.add({'name': name, 'phone': phone});
    errorMessage = succeeds ? null : 'Profile update failed';
    if (pending != null) return await pending!.future;
    return succeeds;
  }
}

Future<_Auth> _open(WidgetTester tester, {bool signedIn = true}) async {
  final data = _Data();
  final auth = _Auth(data);
  if (signedIn) {
    auth.profile = AppUser(
        uid: 'test-user',
        name: 'Test Sender',
        email: 'sender@example.test',
        phone: '+2348000000000');
  }
  addTearDown(auth.dispose);
  addTearDown(data.dispose);
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const PersonalDetailsScreen())),
                      child: const Text('Open details')))))));
  await tester.tap(find.text('Open details'));
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('prefills current profile and validates before saving',
      (tester) async {
    final auth = await _open(tester);
    expect(find.text('sender@example.test'), findsOneWidget);
    expect(find.text('Test Sender'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'A');
    await tester.enterText(find.byType(TextFormField).last, 'bad-number');
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter a valid phone number'), findsOneWidget);
    expect(auth.submissions, isEmpty);
  });

  testWidgets(
      'saves trimmed fields, optional phone and returns only on success',
      (tester) async {
    final auth = await _open(tester);
    await tester.enterText(
        find.byType(TextFormField).first, '  Updated Sender  ');
    await tester.enterText(find.byType(TextFormField).last, '   ');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(auth.submissions.single, {'name': 'Updated Sender', 'phone': ''});
    expect(find.text('Open details'), findsOneWidget);
    expect(find.text('Personal details updated'), findsOneWidget);
  });

  testWidgets('failed save keeps edits and allows retry', (tester) async {
    final auth = await _open(tester);
    auth.succeeds = false;
    await tester.enterText(find.byType(TextFormField).first, 'Edited Sender');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Profile update failed'), findsOneWidget);
    expect(find.text('Edited Sender'), findsOneWidget);
    expect(find.text('Personal details updated'), findsNothing);
    auth.succeeds = true;
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(auth.submissions.length, 2);
  });

  testWidgets('pending save cannot be submitted twice', (tester) async {
    final auth = await _open(tester);
    auth.pending = Completer<bool>();
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    expect(auth.submissions.length, 1);
    auth.pending!.complete(true);
    await tester.pumpAndSettle();
  });

  testWidgets('signed-out account cannot save', (tester) async {
    final auth = await _open(tester, signedIn: false);
    expect(find.text('Sign in to edit your personal details.'), findsOneWidget);
    expect(find.text('Save changes'), findsNothing);
    expect(auth.submissions, isEmpty);
  });
}
