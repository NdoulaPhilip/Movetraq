import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';

class SafetyReportingScreen extends StatefulWidget {
  const SafetyReportingScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<SafetyReportingScreen> createState() => _SafetyReportingScreenState();
}

class _SafetyReportingScreenState extends State<SafetyReportingScreen> {
  final _form = GlobalKey<FormState>();
  final _details = TextEditingController();
  late final Future<AppUser> _contact;
  String? _reason;
  bool _busy = false;
  bool _reported = false;
  bool _blocked = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _contact = context.read<LocalDataService>().orderContact(widget.orderId);
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _report(AppUser contact) async {
    if (_busy || !_form.currentState!.validate()) return;
    final uid = context.read<AuthProvider>().profile?.uid;
    if (uid == null) {
      showActionError(context, 'Sign in to report a concern.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<LocalDataService>().createSupportTicket(uid,
          subject: 'Safety report / $_reason',
          message:
              'Order: ${widget.orderId}\nContact: ${contact.uid}\n${_details.text.trim()}');
      if (mounted) setState(() => _reported = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _block(AppUser contact) async {
    if (_busy || _blocked) return;
    if (!await confirmAction(context, 'Block ${contact.name}?',
            'Existing orders and conversations remain accessible.') ||
        !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FeatureGateway(context.read<LocalDataService>()).request(
          'Blocking contacts', 'POST', '/users/me/blocked-users', body: {
        'blockedId': contact.uid,
        if (_reason != null) 'reason': _reason
      });
      if (mounted) setState(() => _blocked = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Safety & reporting', children: [
        FutureBuilder<AppUser>(
            future: _contact,
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final contact = snapshot.data!;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DesignNote(title: contact.name, body: 'Delivery contact'),
                    DesignCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const SectionTitle('Report a concern'),
                          if (_reported)
                            const InfoBand(
                                title: 'Report submitted',
                                body: 'Follow your request in Help & support.',
                                icon: Icons.check_circle_outline)
                          else ...[
                            Form(
                                key: _form,
                                child: Column(children: [
                                  DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                          labelText: 'Reason'),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'unsafe_behavior',
                                            child: Text('Unsafe behavior')),
                                        DropdownMenuItem(
                                            value: 'harassment',
                                            child: Text('Harassment')),
                                        DropdownMenuItem(
                                            value: 'fraud',
                                            child: Text('Suspected fraud')),
                                        DropdownMenuItem(
                                            value: 'other',
                                            child: Text('Other concern')),
                                      ],
                                      validator: (value) => value == null
                                          ? 'Choose a reason'
                                          : null,
                                      onChanged: _busy
                                          ? null
                                          : (value) =>
                                              setState(() => _reason = value)),
                                  const SizedBox(height: 18),
                                  TextFormField(
                                      controller: _details,
                                      enabled: !_busy,
                                      maxLines: 4,
                                      maxLength: 2000,
                                      decoration: const InputDecoration(
                                          labelText: 'Details (optional)')),
                                ])),
                            PrimaryButton(
                                label: 'Save report',
                                loading: _busy,
                                onPressed: () => _report(contact)),
                          ],
                        ])),
                    const SizedBox(height: 14),
                    DesignCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const SectionTitle('Block this contact'),
                          const Text(
                              'Blocking prevents future matching. Existing deliveries remain available.'),
                          const SizedBox(height: 16),
                          if (_blocked)
                            const InfoBand(
                                title: 'Contact blocked', icon: Icons.block)
                          else
                            SecondaryButton(
                                label: 'Block contact',
                                onPressed:
                                    _busy ? null : () => _block(contact)),
                        ])),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      LoadError(error: _error!),
                    ],
                  ]);
            }),
        const RouteTile(
            title: 'Help & support',
            icon: Icons.support_agent,
            route: '/support'),
      ]);
}
