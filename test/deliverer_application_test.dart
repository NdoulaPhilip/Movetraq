import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:movetraq/features/deliverer/application_screen.dart';
import 'package:movetraq/models/app_user.dart';
import 'package:movetraq/models/misc_models.dart';
import 'package:movetraq/services/node_api_client.dart';
import 'package:movetraq/providers/auth_provider.dart';
import 'package:movetraq/services/local_data_service.dart';
import 'package:movetraq/widgets/app_page.dart';
import 'package:movetraq/widgets/primary_button.dart';

const appId = '18000000-0000-4000-8000-000000000001';

class _DecisionApi extends NodeApiClient {
  bool read = false;
  final user = AppUser(
      uid: 'user_decision',
      name: 'Applicant',
      email: 'applicant@example.test',
      phone: '');
  @override
  bool get isAuthenticated => true;
  @override
  Future<List<NotificationItem>> notifications() async => [];
  @override
  Future<Map<String, dynamic>> delivererAccess() async => {
        'user': user.toJson(),
        'status': 'rejected',
        'canDeliver': false,
        'notifications': [
          {
            'id': appId,
            'type': 'verification_update',
            'title': 'Deliverer application rejected',
            'body': 'Please upload a clear identity document',
            'created_at': '2026-10-20T10:00:00Z',
            'read_at': read ? '2026-10-20T10:01:00Z' : null
          }
        ]
      };
}

class _ApplicationData extends LocalDataService {
  Map<String, dynamic> state = {
    'id': appId,
    'status': 'not_started',
    'requiredDocuments': ['identity'],
    'documents': <Map<String, dynamic>>[]
  };
  final submissions = <String>[];
  bool fail = false;
  @override
  Stream<AppUser?> get authStateChanges => const Stream.empty();
  @override
  Future<Map<String, dynamic>> delivererAccess() async => Map.of(state);
  @override
  Future<Map<String, dynamic>> extendedRequest(String method, String path,
      {Map<String, dynamic>? body}) async {
    submissions.add(path);
    if (fail) throw StateError('Application could not be submitted');
    state = {...state, 'status': 'pending_approval'};
    return Map.of(state);
  }
}

Future<AuthProvider> _open(WidgetTester tester, _ApplicationData data) async {
  final auth = AuthProvider(data)
    ..profile = AppUser(
        uid: 'applicant',
        name: 'Applicant',
        email: 'applicant@example.test',
        phone: '');
  addTearDown(auth.dispose);
  addTearDown(data.dispose);
  await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<LocalDataService>.value(value: data),
        ChangeNotifierProvider<AuthProvider>.value(value: auth)
      ],
      child: MaterialApp(
          home: const VerificationScreen(),
          onGenerateRoute: (settings) {
            if (settings.name == '/verification-documents') {
              return MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () {
                            final args = settings.arguments as Map;
                            expect(args['applicationId'], appId);
                            expect(args['documentType'], 'identity');
                            data.state = {
                              ...data.state,
                              'documents': [
                                {
                                  'document_type': 'identity',
                                  'upload_verified_at': '2026-10-20T10:00:00Z'
                                }
                              ]
                            };
                            Navigator.pop(context);
                          },
                          child: const Text('Finish verified upload'))));
            }
            return null;
          })));
  await tester.pumpAndSettle();
  return auth;
}

PrimaryButton submitButton(WidgetTester tester) => tester
    .widget<AppPage>(find.byType(AppPage))
    .children
    .whereType<PrimaryButton>()
    .singleWhere((button) => button.label == 'Submit for review');
void main() {
  test(
      'approval polling publishes one decision to the applicant inbox and preserves read state',
      () async {
    final api = _DecisionApi();
    final data = LocalDataService(api: api)..currentUser = api.user;
    final snapshots = <List<NotificationItem>>[];
    final subscription =
        data.watchNotifications(api.user.uid).listen(snapshots.add);
    addTearDown(subscription.cancel);
    addTearDown(data.dispose);
    await Future<void>.delayed(Duration.zero);
    await data.delivererAccess();
    await Future<void>.delayed(Duration.zero);
    expect(snapshots.last.single.id, 'verification:$appId');
    expect(snapshots.last.single.read, isFalse);
    await data.delivererAccess();
    await Future<void>.delayed(Duration.zero);
    expect(snapshots.last.length, 1);
    api.read = true;
    await data.delivererAccess();
    await Future<void>.delayed(Duration.zero);
    expect(snapshots.last.single.read, isTrue);
    api.read = false;
    await data.delivererAccess();
    await Future<void>.delayed(Duration.zero);
    expect(snapshots.last.single.read, isTrue);
  });
  testWidgets(
      'document checklist blocks submission until a confirmed upload returns',
      (tester) async {
    final data = _ApplicationData();
    final auth = await _open(tester, data);
    expect(submitButton(tester).onPressed, isNull);
    await tester.scrollUntilVisible(
        find.text('Upload required documents'), 200);
    await tester.tap(find.text('Upload required documents'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish verified upload'));
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNotNull);
    await tester.scrollUntilVisible(find.text('Submit for review'), 200);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('Pending Approval'), findsOneWidget);
    expect(data.submissions, ['/deliverers/me/applications/$appId/submit']);
    expect(auth.profile!.isApprovedDeliverer, isFalse);
    expect(find.text('Open delivery workspace'), findsNothing);
  });
  testWidgets(
      'submission failure retains the draft and never claims pending approval',
      (tester) async {
    final data = _ApplicationData()..fail = true;
    data.state = {
      ...data.state,
      'documents': [
        {'document_type': 'identity', 'upload_verified_at': '2026-10-20'}
      ]
    };
    await _open(tester, data);
    await tester.scrollUntilVisible(find.text('Submit for review'), 200);
    await tester.tap(find.text('Submit for review'));
    await tester.pumpAndSettle();
    expect(data.state['status'], 'not_started');
    expect(find.text('Pending Approval'), findsNothing);
    expect(submitButton(tester).onPressed, isNotNull);
  });
  for (final status in [
    'pending_approval',
    'submitted',
    'under_review',
    'rejected',
    'approved'
  ]) {
    testWidgets(
        'shows the authoritative $status without granting local approval',
        (tester) async {
      final data = _ApplicationData();
      data.state = {
        ...data.state,
        'status': status,
        'review_notes': status == 'rejected'
            ? 'Please upload a clearer identity document'
            : null
      };
      final auth = await _open(tester, data);
      final label =
          ['pending_approval', 'submitted', 'under_review'].contains(status)
              ? 'Pending Approval'
              : status == 'approved'
                  ? 'Approved'
                  : 'Rejected';
      expect(find.text(label), findsOneWidget);
      expect(auth.profile!.isApprovedDeliverer, isFalse);
      expect(find.text('Submit for review'), findsNothing);
      if (status == 'rejected') {
        expect(find.text('Please upload a clearer identity document'),
            findsOneWidget);
      }
    });
  }
}
