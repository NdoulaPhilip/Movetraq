import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/parcel_order.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/automatic_location_map.dart';

class DHomeScreen extends StatelessWidget {
  const DHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    return AppPage(title: 'Available deliveries', embedded: true, actions: [
      IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
          icon: const Icon(Icons.notifications_outlined))
    ], children: [
      const AutomaticLocationMap(),
      const SizedBox(height: 18),
      SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(profile?.delivererOnline == true
              ? 'You are online'
              : 'You are offline'),
          value: profile?.delivererOnline ?? false,
          onChanged: profile == null || auth.isBusy
              ? null
              : (value) async {
                  final ok = await auth.setDelivererOnline(value);
                  if (context.mounted && !ok) {
                    showActionError(context,
                        auth.errorMessage ?? 'Unable to update availability.');
                  }
                }),
      const SizedBox(height: 18),
      if (profile?.delivererOnline != true)
        const InfoBand(
            title: 'Ready when you are',
            body: 'Go online to receive available deliveries.')
      else
        StreamBuilder<List<ParcelOrder>>(
            stream: context.read<LocalDataService>().watchOpenJobs(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final jobs = snapshot.data!;
              if (jobs.isEmpty) {
                return const PremiumEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No deliveries available',
                    body: 'New opportunities will appear here.');
              }
              return Column(children: [
                for (final order in jobs)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: PremiumSurface(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(order.title,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            DetailRow('Pickup', order.pickupAddress),
                            DetailRow('Destination', order.dropoffAddress),
                            DetailRow('Your payout',
                                'NGN ${order.payout.toStringAsFixed(2)}'),
                            RouteTile(
                                title: 'View delivery',
                                icon: Icons.arrow_forward,
                                route: '/d-job',
                                arguments: order.id),
                          ])))
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
      const SizedBox(height: 80),
    ]);
  }
}
