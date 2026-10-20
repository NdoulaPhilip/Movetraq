import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:movetraq/models/app_user.dart';
import 'package:movetraq/providers/auth_provider.dart';
import 'package:movetraq/screens/account/account_screens.dart';
import 'package:movetraq/services/local_data_service.dart';
import 'package:movetraq/widgets/primary_button.dart';

class _PreferencesData extends LocalDataService {
  Map<String, dynamic> saved = {
    'p2p': true,
    'transport': 'walking',
    'delivery_area': 'Yaba'
  };
  bool failRead = false, failWrite = false;
  final paths = <String>[];
  @override
  Future<Map<String, dynamic>> extendedRequest(String method, String path,
      {Map<String, dynamic>? body}) async {
    paths.add('$method $path');
    if (method == 'GET' && failRead) {
      throw StateError('Preferences API unavailable');
    }
    if (method == 'PATCH') {
      if (failWrite) throw StateError('Preferences were not saved');
      saved = {
        ...saved,
        ...Map<String, dynamic>.from(body!['delivery_preferences'] as Map)
      };
    }
    return {'delivery_preferences': Map<String, dynamic>.of(saved)};
  }
}

class _ApprovalData extends LocalDataService {
  final auth = StreamController<AppUser?>.broadcast();
  final profiles = StreamController<AppUser?>.broadcast();
  String state = 'pending_approval';
  bool fail = false;
  int reads = 0;
  @override
  Stream<AppUser?> get authStateChanges => auth.stream;
  @override
  Stream<AppUser?> profileStream(String uid) async* {
    yield currentUser;
    yield* profiles.stream;
  }

  @override
  Future<Map<String, dynamic>> delivererAccess() async {
    reads++;
    if (fail) throw StateError('Authority unavailable');
    currentUser = currentUser!.copyWith(
        canDeliver: state == 'approved',
        verified: state == 'approved',
        delivererVerificationStatus: state,
        activeRole: UserRole.sender);
    auth.add(currentUser);
    profiles.add(currentUser);
    return {
      'status': state,
      'canDeliver': state == 'approved',
      'user': currentUser!.toJson()
    };
  }

  @override
  void dispose() {
    auth.close();
    profiles.close();
    super.dispose();
  }
}

Future<void> _open(WidgetTester tester, _PreferencesData data,
    {Key? screenKey}) async {
  await tester.binding.setSurfaceSize(const Size(440, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(Provider<LocalDataService>.value(
      value: data,
      child: MaterialApp(
          home: PreferenceScreen(
              key: screenKey,
              title: 'Delivery work preferences',
              work: true,
              group: 'delivery_preferences',
              toggles: const {
            'p2p': 'P2P deliveries'
          },
              choices: const {
            'transport': ['walking', 'car']
          }))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'work preferences use the mobile endpoint and persist across screen reopening',
      (tester) async {
    final data = _PreferencesData();
    addTearDown(data.dispose);
    await _open(tester, data);
    expect(data.paths, ['GET /users/me/preferences?scope=work']);
    expect(find.text('Yaba'), findsOneWidget);
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>))
            .onChanged,
        isNull);
    await tester.tap(find.text('P2P deliveries'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Lekki');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save preferences'));
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    expect(data.saved['p2p'], false);
    expect(data.saved['delivery_area'], 'Lekki');
    expect(data.paths.last, 'PATCH /users/me/preferences?scope=work');
    await _open(tester, data, screenKey: const ValueKey('reopened'));
    expect(find.text('Lekki'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false);
  });
  testWidgets(
      'failed loads cannot save defaults and retry loads authoritative preferences',
      (tester) async {
    final data = _PreferencesData()..failRead = true;
    addTearDown(data.dispose);
    await _open(tester, data);
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNull);
    expect(find.textContaining('Preferences API unavailable'), findsOneWidget);
    data.failRead = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
        isNotNull);
    data.failWrite = true;
    await tester.ensureVisible(find.text('Save preferences'));
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Preferences were not saved'), findsOneWidget);
    expect(find.text('Preferences updated.'), findsNothing);
  });
  testWidgets(
      'approval polling survives profile events, resumes promptly and recovers from outages',
      (tester) async {
    final data = _ApprovalData();
    final auth = AuthProvider(data);
    addTearDown(data.dispose);
    data.currentUser = AppUser(
        uid: 'user_fixture',
        name: 'Applicant',
        email: 'fixture@example.test',
        phone: '');
    data.auth.add(data.currentUser);
    await tester.pump();
    await tester.pump();
    expect(data.reads, 1);
    expect(auth.profile!.isApprovedDeliverer, false);
    data.state = 'approved';
    for (var i = 0; i < 4; i++) {
      data.auth.add(data.currentUser);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    }
    expect(data.reads, 2);
    expect(auth.profile!.isApprovedDeliverer, true);
    data.fail = true;
    await auth.refreshApproval();
    await tester.pump();
    expect(auth.profile!.isApprovedDeliverer, false);
    expect(auth.profile!.activeRole, UserRole.sender);
    expect(auth.approvalErrorMessage, isNotNull);
    data.fail = false;
    await auth.refreshApproval();
    await tester.pump();
    expect(auth.profile!.isApprovedDeliverer, true);
    expect(auth.approvalErrorMessage, isNull);
    data.state = 'rejected';
    auth.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(auth.profile!.isApprovedDeliverer, false);
    expect(auth.profile!.delivererVerificationStatus, 'rejected');
    auth.dispose();
    await tester.pump();
  });
}
