import 'package:flutter/material.dart';
import '../models/misc_models.dart';
import '../widgets/app_page.dart';
import 'account/account_screens.dart';
import '../features/orders/create_order_screen.dart';
import '../features/addresses/location_search_screen.dart';
import 'booking/p2p_requests_screen.dart';
import '../features/deliverer/application_screen.dart';
import 'deliverer/d_earnings_screen.dart';
import 'deliverer/d_trips_screen.dart';
import '../features/deliverer/insights_screen.dart';
import 'orders/order_tools.dart';
import 'orders/handover_screen.dart';
import 'orders/private_upload_screen.dart';
import 'send/parcel_photo_screen.dart';
import 'shared/feature_screen.dart';
import '../features/support/support_screen.dart';
import 'support/payment_review_screen.dart';
import 'support/safety_reporting_screen.dart';
import 'wallet/payment_confirmation_screen.dart';
import 'wallet/payment_screens.dart';
import '../features/addresses/addresses_screen.dart';
import '../features/profile/personal_screen.dart';
import '../features/settings/blocked_screen.dart';
import '../features/earnings/payout_screen.dart';
import '../features/p2p/ads_screen.dart';
import '../features/p2p/ad_form_screen.dart';

const additionalScreenRoutes = <String>[
  '/personal-details',
  '/saved-addresses',
  '/select-address',
  '/address-edit',
  '/settings',
  '/security',
  '/sessions',
  '/blocked-users',
  '/block-user',
  '/notification-preferences',
  '/delivery-preferences',
  '/display-preferences',
  '/privacy',
  '/account-controls',
  '/delete-account',
  '/about',
  '/location-search',
  '/map-picker',
  '/service-choice',
  '/schedule',
  '/p2p-request',
  '/p2p-requests',
  '/errand',
  '/big-move',
  '/parcel-photo',
  '/payment',
  '/confirm-payment',
  '/transactions',
  '/transaction-detail',
  '/payment-methods',
  '/add-payment-method',
  '/withdraw',
  '/payouts',
  '/membership',
  '/support',
  '/safety',
  '/safety-reporting',
  '/payout-review',
  '/report-issue',
  '/support-case',
  '/delivery-problem',
  '/return-request',
  '/disputes',
  '/delivery-summary',
  '/order-receipt',
  '/delivery-completed',
  '/delivery-contact',
  '/call',
  '/deliverer-public-profile',
  '/share-order',
  '/rate-delivery',
  '/delivery-pickup',
  '/delivery-dropoff',
  '/handover',
  '/delivery-evidence',
  '/evidence-upload',
  '/delivery-opportunities',
  '/deliverer-apply',
  '/verification',
  '/verification-documents',
  '/application-status',
  '/delivery-work',
  '/analytics',
  '/performance',
  '/past-customers',
  '/customer-deliveries',
  '/messages',
  '/deliverer-earnings',
  '/deliverer-orders',
  '/deliverer-work-settings',
  '/p2p-ads',
  '/my-p2p-ads',
  '/create-p2p-ad',
  '/edit-p2p-ad',
  '/verify-email',
  '/password-recovery',
  '/change-password',
];

Widget? additionalScreen(String? route, Object? arguments) {
  final id = arguments is String ? arguments : '';
  final values =
      arguments is Map<String, dynamic> ? arguments : <String, dynamic>{};
  const reason = [
    FormFieldSpec('reason', 'Reason', kind: FieldKind.multiline, minLength: 3)
  ];
  return switch (route) {
    '/personal-details' => const PersonalScreen(),
    '/saved-addresses' => const AddressesScreen(),
    '/select-address' => const AddressesScreen(selectForBooking: true),
    '/address-edit' =>
      AddressEditScreen(address: arguments is SavedAddress ? arguments : null),
    '/settings' => const SettingsScreen(),
    '/security' => const SecurityScreen(),
    '/sessions' => const FeatureListScreen(
        title: 'Devices & sessions',
        path: '/users/me/sessions',
        fields: ['device', 'last_active_at']),
    '/blocked-users' => const BlockedScreen(),
    '/block-user' => FeatureFormScreen(
          title: 'Block a person',
          action: 'Block person',
          path: '/users/me/blocked-users',
          dangerous: true,
          initialValues: {
            'blockedId': id
          },
          fields: const [
            FormFieldSpec('blockedId', 'User ID'),
            FormFieldSpec('reason', 'Reason',
                kind: FieldKind.multiline, required: false)
          ]),
    '/notification-preferences' => const PreferenceScreen(
          title: 'Notification preferences',
          group: 'notifications',
          toggles: {
            'push_enabled': 'Push notifications',
            'email_enabled': 'Email notifications',
            'sms_enabled': 'SMS notifications'
          }),
    '/delivery-preferences' => const PreferenceScreen(
          title: 'Delivery preferences',
          group: 'delivery_preferences',
          toggles: {
            'scheduled_reminders': 'Scheduled reminders',
            'contact_before_pickup': 'Contact before pickup'
          },
          choices: {
            'preferred_service': ['p2p', 'express', 'errand', 'big_move']
          }),
    '/display-preferences' => const PreferenceScreen(
          title: 'Display & accessibility',
          group: 'display_preferences',
          toggles: {
            'reduce_motion': 'Reduce motion',
            'high_contrast': 'High contrast'
          },
          choices: {
            'theme': ['system', 'light', 'dark']
          }),
    '/privacy' => const PreferenceScreen(
          title: 'Privacy',
          group: 'privacy_preferences',
          toggles: {
            'share_active_delivery_location': 'Share active delivery location',
            'marketing_consent': 'Marketing messages'
          }),
    '/account-controls' => const AccountControlsScreen(),
    '/delete-account' => const DeleteAccountScreen(),
    '/about' => const AboutScreen(),
    '/location-search' => const LocationSearchScreen(),
    '/map-picker' => const MapPickerScreen(),
    '/service-choice' => const ServiceChoiceScreen(),
    '/schedule' => const ScheduleScreen(),
    '/p2p-request' => BookingScreen(
        service: 'p2p',
        initialSchedule: arguments is DateTime ? arguments : null),
    '/p2p-requests' => const P2PRequestsScreen(),
    '/errand' => const BookingScreen(service: 'errand'),
    '/big-move' => const BookingScreen(service: 'big_move'),
    '/parcel-photo' => const ParcelPhotoScreen(),
    '/payment' => PaymentScreen(quote: values.isEmpty ? null : values),
    '/confirm-payment' => PaymentConfirmationScreen(reference: id),
    '/transactions' => const TransactionsScreen(),
    '/transaction-detail' => TransactionDetailScreen(
        transaction: arguments is WalletTransaction ? arguments : null),
    '/payment-methods' => const FeatureListScreen(
        title: 'Payment methods',
        path: '/payments/methods',
        createRoute: '/add-payment-method',
        fields: ['brand', 'last4']),
    '/add-payment-method' =>
      const AppPage(title: 'Add a payment method', children: [
        InfoBand(
            title: 'Secure card setup unavailable',
            body:
                'Card details must be collected by the payment provider. Card setup is not connected yet.',
            icon: Icons.credit_card)
      ]),
    '/withdraw' => const FeatureFormScreen(
          title: 'Withdraw earnings',
          action: 'Review withdrawal',
          path: '/payouts',
          review: true,
          dangerous: true,
          fields: [
            FormFieldSpec('amountMinor', 'Amount (NGN)', kind: FieldKind.money),
            FormFieldSpec('bankCode', 'Bank code'),
            FormFieldSpec('accountNumber', 'Account number')
          ]),
    '/payouts' => const PayoutScreen(),
    '/membership' => const MembershipScreen(),
    '/support' => const SupportScreen(),
    '/safety' => const SupportScreen(safety: true),
    '/safety-reporting' => SafetyReportingScreen(orderId: id),
    '/payout-review' => PaymentReviewScreen(orderId: id),
    '/report-issue' => ReportIssueScreen(orderId: id),
    '/support-case' =>
      SupportCaseScreen(ticket: arguments is SupportTicket ? arguments : null),
    '/delivery-problem' => FeatureFormScreen(
          title: 'Report a delivery problem',
          action: 'Send report',
          path: '/support/cases',
          fixedValues: {
            'orderId': id
          },
          fields: const [
            FormFieldSpec('category', 'Problem', options: [
              'recipient_unreachable',
              'incorrect_address',
              'damaged_parcel',
              'failed_delivery',
              'return',
              'payment_issue',
              'deliverer_issue',
              'sender_issue',
              'other'
            ]),
            FormFieldSpec('description', 'What happened?',
                kind: FieldKind.multiline, minLength: 3)
          ]),
    '/return-request' => FeatureFormScreen(
        title: 'Request a return',
        action: 'Request return',
        path: '/orders/$id/returns',
        fields: reason,
        review: true),
    '/disputes' => const FeatureListScreen(
        title: 'Delivery disputes',
        path: '/support/cases',
        itemKey: 'cases',
        fields: ['category', 'status', 'priority']),
    '/delivery-summary' => OrderToolsScreen(orderId: id),
    '/order-receipt' => OrderToolsScreen(orderId: id, receipt: true),
    '/delivery-completed' => OrderToolsScreen(orderId: id, completed: true),
    '/delivery-contact' => ContactScreen(orderId: id),
    '/call' => ContactScreen(orderId: id, call: true),
    '/deliverer-public-profile' => ContactScreen(orderId: id, profile: true),
    '/share-order' => ShareOrderScreen(orderId: id),
    '/rate-delivery' => RatingScreen(orderId: id),
    '/delivery-pickup' => DeliveryStageScreen(orderId: id),
    '/delivery-dropoff' => DeliveryStageScreen(orderId: id, dropoff: true),
    '/handover' => HandoverScreen(orderId: id),
    '/delivery-evidence' => FeatureListScreen(
        title: 'Delivery evidence',
        path: '/orders/$id/evidence',
        itemKey: 'evidence',
        createRoute: '/evidence-upload',
        createArguments: id,
        fields: const ['recipient_name', 'captured_at']),
    '/evidence-upload' => PrivateUploadScreen(entityId: id),
    '/delivery-opportunities' => const DeliveryOpportunitiesScreen(),
    '/deliverer-apply' => const DelivererApplicationScreen(),
    '/verification' ||
    '/application-status' =>
      VerificationScreen(applicationId: id),
    '/verification-documents' =>
      PrivateUploadScreen(entityId: id, verification: true),
    '/delivery-work' => const DeliveryWorkScreen(),
    '/analytics' => const DelivererAnalyticsScreen(),
    '/performance' => const DelivererAnalyticsScreen(performance: true),
    '/past-customers' => const PastCustomersScreen(),
    '/customer-deliveries' => PastCustomersScreen(customerId: id),
    '/messages' => const MessagesScreen(),
    '/deliverer-earnings' => const DEarningsScreen(),
    '/deliverer-orders' => const DTripsScreen(),
    '/deliverer-work-settings' => const PreferenceScreen(
          title: 'Work preferences',
          group: 'delivery_preferences',
          toggles: {
            'p2p': 'P2P deliveries',
            'express': 'Express deliveries',
            'errand': 'Errands',
            'big_move': 'Big moves'
          },
          choices: {
            'transport': [
              'motorcycle',
              'bicycle',
              'walking',
              'car',
              'van',
              'other_motor',
              'other_non_motor'
            ]
          }),
    '/p2p-ads' => const BrowseAdsScreen(),
    '/my-p2p-ads' => const AdsScreen(),
    '/create-p2p-ad' || '/edit-p2p-ad' => AdFormScreen(adId: id),
    '/verify-email' => const FeatureFormScreen(
          title: 'Verify your email',
          action: 'Verify email',
          path: '/auth/verify',
          fixedValues: {
            'type': 'signup'
          },
          fields: [
            FormFieldSpec('email', 'Email address', kind: FieldKind.email),
            FormFieldSpec('token', 'Verification code', kind: FieldKind.code)
          ]),
    '/password-recovery' => const FeatureFormScreen(
          title: 'Reset password',
          action: 'Send reset email',
          path: '/auth/recover',
          fields: [
            FormFieldSpec('email', 'Email address', kind: FieldKind.email)
          ]),
    '/change-password' => const FeatureFormScreen(
          title: 'Change password',
          action: 'Update password',
          path: '/auth/password',
          fields: [
            FormFieldSpec('password', 'New password',
                kind: FieldKind.password, minLength: 12)
          ]),
    _ => null,
  };
}
