import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/misc_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/design_ui.dart';
import '../../screens/shared/feature_screen.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key, this.safety = false});
  final bool safety;
  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().profile?.uid ?? '';
    if (safety) {
      return AppPage(title: 'Safety & delivery support', children: [
        const DesignNote(
            title: 'Safe pickup and handover',
            body:
                'Check the parcel before pickup. Confirm the recipient and delivery code at handover. Keep customer contact details private.'),
        const DesignNote(
            title: 'A problem on your delivery?',
            body:
                'For an unsafe parcel, failed handover or incident, contact support with the trip reference. If you are in immediate danger, get to safety and contact local emergency services.'),
        const SizedBox(height: 10),
        PrimaryButton(
            label: 'Contact delivery support',
            onPressed: () => Navigator.pushNamed(context, '/report-issue')),
        const SizedBox(height: 12),
        PrimaryButton(
            label: 'Review safety checklist',
            onPressed: () => Navigator.pushNamed(context, '/safety-checklist')),
      ]);
    }
    return AppPage(
        title:
            safety ? 'Safety & delivery support' : 'Delivery help and support',
        children: [
          const DesignNote(
              title: 'We are here to help',
              body: 'Find an answer or tell us what went wrong.'),
          if (safety)
            const InfoBand(
                title: 'Safe pickup and handover',
                body:
                    'Check the parcel before collection. Confirm the recipient and required handover evidence. If you are in immediate danger, get to safety and contact local emergency services.'),
          const DesignNote(
              title: 'Where is my parcel?',
              body: 'Open your order to follow the latest delivery status.'),
          const DesignNote(
              title: 'How does escrow work?',
              body: 'Payment stays on hold until delivery is confirmed.'),
          const DesignNote(
              title: 'Can I change my address?',
              body:
                  'Contact support before your courier reaches the destination.'),
          const SizedBox(height: 20),
          PrimaryButton(
              label: 'Report an issue',
              onPressed: () => Navigator.pushNamed(context, '/report-issue')),
          const SectionTitle('Your support requests'),
          StreamBuilder<List<SupportTicket>>(
              stream: context.read<LocalDataService>().watchSupportTickets(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) return LoadError(error: snapshot.error!);
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return const InfoBand(
                      title: 'No open requests',
                      icon: Icons.chat_bubble_outline);
                }
                return Column(
                    children: snapshot.data!
                        .map((ticket) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(ticket.subject),
                            subtitle: Text(ticket.message),
                            trailing: Text(ticket.status),
                            onTap: () => Navigator.pushNamed(
                                context, '/support-case',
                                arguments: ticket)))
                        .toList());
              }),
        ]);
  }
}

class SafetyChecklistScreen extends StatelessWidget {
  const SafetyChecklistScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AppPage(title: 'Safety checklist', children: [
        DesignNote(
            title: 'Before pickup',
            body:
                'Confirm the order and pickup contact. Check that the parcel matches its description and can be transported safely.'),
        DesignNote(
            title: 'During your delivery',
            body:
                'Keep the parcel secure. Share delivery updates through the order conversation and protect customer contact details.'),
        DesignNote(
            title: 'At handover',
            body:
                'Confirm the recipient and delivery code. Ask permission before taking a handover photo. Report a problem if you cannot complete delivery.'),
      ]);
}

class ReportIssueScreen extends StatelessWidget {
  const ReportIssueScreen({super.key, this.orderId = ''});
  final String orderId;
  @override
  Widget build(BuildContext context) => FeatureFormScreen(
        title: 'Report an issue',
        subtitle: 'Tell us what happened so we can help.',
        intro: orderId.isEmpty
            ? null
            : DesignNote(title: 'Delivery reference', body: orderId),
        action: 'Submit support request',
        fields: const [
          FormFieldSpec('subject', 'Subject'),
          FormFieldSpec('message', 'How can we help?',
              kind: FieldKind.multiline, minLength: 3)
        ],
        initialValues: {'subject': orderId.isEmpty ? '' : 'Delivery $orderId'},
        onSubmit: (context, values) async {
          final uid = context.read<AuthProvider>().profile?.uid;
          if (uid == null) throw StateError('Sign in to contact support.');
          await context.read<LocalDataService>().createSupportTicket(uid,
              subject: values['subject'] as String,
              message: values['message'] as String);
        },
      );
}

class SupportCaseScreen extends StatelessWidget {
  const SupportCaseScreen({super.key, this.ticket});
  final SupportTicket? ticket;
  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Delivery support', children: [
        if (ticket != null) ...[
          DesignNote(
              reference: ticket!.id,
              title: ticket!.status,
              body: ticket!.subject),
          Text(ticket!.message,
              style: const TextStyle(fontSize: 13, height: 1.6)),
          const SizedBox(height: 18),
          const Text(
              'Contact the customer to agree another attempt, a corrected address, or a return. Document any damage before proceeding.',
              style: TextStyle(fontSize: 13, height: 1.65)),
        ] else
          const DesignNote(title: 'Open a support request to see its status.'),
        const SizedBox(height: 24),
        PrimaryButton(
            label: 'Contact support',
            onPressed: () => Navigator.pushNamed(context, '/report-issue')),
        const SizedBox(height: 12),
        SecondaryButton(
            label: 'Back to orders',
            onPressed: () => Navigator.pushNamed(context, '/track-list')),
      ]);
}
