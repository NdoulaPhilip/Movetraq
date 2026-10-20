import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';

class DHomeScreen extends StatefulWidget {
  const DHomeScreen({super.key});
  @override
  State<DHomeScreen> createState() => _DHomeScreenState();
}

class _DHomeScreenState extends State<DHomeScreen> {
  late final Stream<List<ParcelOrder>> _jobs;
  @override
  void initState() {
    super.initState();
    _jobs = context.read<LocalDataService>().watchOpenJobs();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    return AppPage(
        title: 'Available deliveries',
        eyebrow: 'DELIVERER WORKSPACE',
        embedded: true,
        actions: [
          Container(
              decoration: BoxDecoration(
                  color: const Color(0xFFEAF3DF),
                  border: Border.all(color: AppColors.accent),
                  borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.only(left: 10, right: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(profile?.delivererOnline == true ? 'Online' : 'Offline',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF608109))),
                Switch(
                    value: profile?.delivererOnline ?? false,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.accent,
                    onChanged: profile == null || auth.isBusy
                        ? null
                        : (enabled) async {
                            final ok = await auth.setDelivererOnline(enabled);
                            if (context.mounted && !ok) {
                              showActionError(
                                  context,
                                  auth.errorMessage ??
                                      'Unable to update availability.');
                            }
                          }),
              ]))
        ],
        children: [
          const SectionTitle('Available jobs near you'),
          if (profile?.delivererOnline != true)
            const DesignNote(
                title: 'Ready when you are',
                body: 'Go online to receive available deliveries.')
          else
            StreamBuilder<List<ParcelOrder>>(
                stream: _jobs,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return LoadError(error: snapshot.error!);
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final jobs = snapshot.data!;
                  return Column(children: [
                    Align(
                        alignment: Alignment.centerRight,
                        child: Text('${jobs.length} deliveries available',
                            style: const TextStyle(fontSize: 11))),
                    const SizedBox(height: 12),
                    if (jobs.isEmpty)
                      const DesignNote(
                          title: 'No deliveries available',
                          body: 'New opportunities will appear here.'),
                    for (final order in jobs) ...[
                      DesignCard(
                          child: Column(children: [
                        Row(children: [
                          ParcelIcon(order.category),
                          const SizedBox(width: 11),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(order.title,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(order.senderName,
                                    style: const TextStyle(fontSize: 11)),
                              ])),
                          const SizedBox(width: 8),
                          Text(naira(order.payout),
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 16),
                        DesignRoute(
                            pickup: order.pickupAddress,
                            destination: order.dropoffAddress,
                            compact: true),
                        const SizedBox(height: 16),
                        PrimaryButton(
                            label: 'View delivery details',
                            onPressed: () => Navigator.pushNamed(
                                context, '/d-job',
                                arguments: order.id)),
                      ])),
                      const SizedBox(height: 12),
                    ],
                  ]);
                }),
          const RouteTile(
              title: 'Browse P2P ads',
              icon: Icons.campaign_outlined,
              route: '/p2p-ads'),
          const RouteTile(
              title: 'Work preferences',
              icon: Icons.tune,
              route: '/deliverer-work-settings'),
        ]);
  }
}
