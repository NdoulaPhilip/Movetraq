import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/misc_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';
import '../../screens/shared/feature_screen.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key, this.safety = false});
  final bool safety;
  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().profile?.uid ?? '';
    return AppPage(
        title:
            safety ? 'Safety & delivery support' : 'Delivery help and support',
        children: [
          if (safety)
            const InfoBand(
                title: 'Safe pickup and handover',
                body:
                    'Check the parcel before collection. Confirm the recipient and required handover evidence. If you are in immediate danger, get to safety and contact local emergency services.'),
          const ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Where is my parcel?'),
              children: [
                ListTile(
                    title: Text(
                        'Follow the latest delivery status from your order.'),
                    trailing: Icon(Icons.chevron_right),
                    onTap: null)
              ]),
          const ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('How do held payments work?'),
              children: [
                Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                        'Funds stay held until the delivery is confirmed. A reported issue prevents release while support reviews it.'))
              ]),
          const ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Can I change my address?'),
              children: [
                Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                        'Contact support before your courier reaches the destination.'))
              ]),
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

class ReportIssueScreen extends StatelessWidget {
  const ReportIssueScreen({super.key, this.orderId = ''});
  final String orderId;
  @override
  Widget build(BuildContext context) => FeatureFormScreen(
        title: 'Report an issue',
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
          DetailRow('Reference', ticket!.id),
          DetailRow('Status', ticket!.status),
          const SizedBox(height: 18),
          Text(ticket!.subject,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text(ticket!.message),
        ] else
          const InfoBand(
              title: 'Open a support request to see its status.',
              icon: Icons.support_agent),
        const SizedBox(height: 24),
        PrimaryButton(
            label: 'Contact support',
            onPressed: () => Navigator.pushNamed(context, '/report-issue')),
      ]);
}
