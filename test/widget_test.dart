// Basic widget smoke tests for MoveTraq.
//
// These tests exercise the app's presentational, provider-free widgets
// directly (PrimaryButton, MiniMap, etc). Full-app flows involving
// LocalDataService/AuthProvider (MoveTraqApp/AuthGate) are exercised
// manually / via `flutter run` instead, since they involve async streams
// and multi-screen navigation that are easier to verify by hand.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movetraq/theme/app_theme.dart';
import 'package:movetraq/widgets/mini_map.dart';
import 'package:movetraq/widgets/primary_button.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
  );
}

void main() {
  group('PrimaryButton', () {
    testWidgets('shows its label and fires onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        PrimaryButton(
          label: 'Get started',
          trailingIcon: Icons.arrow_forward,
          onPressed: () => tapped = true,
        ),
      ));

      expect(find.text('Get started'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('shows a spinner instead of the label while loading', (tester) async {
      await tester.pumpWidget(_wrap(
        PrimaryButton(label: 'Sign in', onPressed: () {}, loading: true),
      ));

      expect(find.text('Sign in'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('does not fire onPressed when loading', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        PrimaryButton(label: 'Sign in', onPressed: () => tapped = true, loading: true),
      ));

      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await tester.pump();

      expect(tapped, isFalse);
    });
  });

  group('SecondaryButton', () {
    testWidgets('shows its label and fires onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        SecondaryButton(label: 'I already have an account', onPressed: () => tapped = true),
      ));

      expect(find.text('I already have an account'), findsOneWidget);

      await tester.tap(find.byType(SecondaryButton));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('MiniMap', () {
    testWidgets('renders at a fixed height without throwing', (tester) async {
      await tester.pumpWidget(_wrap(const SizedBox(width: 300, child: MiniMap(height: 150))));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MiniMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fills available space when height is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const SizedBox(width: 300, height: 300, child: MiniMap(height: null)),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(MiniMap), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CircleIconButton', () {
    testWidgets('fires onTap and optionally shows the notification dot', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        CircleIconButton(icon: Icons.notifications_outlined, showDot: true, onTap: () => tapped = true),
      ));

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);

      await tester.tap(find.byType(CircleIconButton));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });

  group('ScreenHeader', () {
    testWidgets('shows the given title', (tester) async {
      await tester.pumpWidget(_wrap(const ScreenHeader(title: 'Wallet')));
      expect(find.text('Wallet'), findsOneWidget);
    });
  });
}
