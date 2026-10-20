import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/send_flow_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../widgets/primary_button.dart';

class PickDelivererScreen extends StatefulWidget {
  const PickDelivererScreen({super.key});
  @override
  State<PickDelivererScreen> createState() => _PickDelivererScreenState();
}

class _PickDelivererScreenState extends State<PickDelivererScreen> {
  String _query = '', _sort = 'All deliverers';
  late final Stream<List<AppUser>> _stream;
  @override
  void initState() {
    super.initState();
    _stream = context.read<LocalDataService>().watchAvailableDeliverers();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<AppUser>>(
      stream: _stream,
      builder: (context, snapshot) {
        final peers = (snapshot.data ?? [])
            .where((peer) => '${peer.name} ${peer.vehicleType}'
                .toLowerCase()
                .contains(_query))
            .toList();
        switch (_sort) {
          case 'Top rated':
            peers.sort((a, b) => b.rating.compareTo(a.rating));
          case 'Closest to pickup':
            peers.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
          case 'Lowest price':
            peers.sort((a, b) => a.rate.compareTo(b.rate));
        }
        return AppPage(
            title: 'Choose your deliverer',
            subtitle: snapshot.hasData
                ? '${peers.length} available deliverers'
                : null,
            children: [
              TextField(
                  decoration: const InputDecoration(
                      hintText: 'Name or vehicle',
                      prefixIcon: Icon(Icons.search)),
                  onChanged: (value) =>
                      setState(() => _query = value.toLowerCase())),
              const SizedBox(height: 14),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final filter in [
                      'All deliverers',
                      'Top rated',
                      'Closest to pickup',
                      'Lowest price'
                    ])
                      Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: ChoiceChip(
                              label: Text(filter),
                              selected: _sort == filter,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _sort = filter))),
                  ])),
              const SizedBox(height: 17),
              if (snapshot.hasError)
                LoadError(error: snapshot.error!)
              else if (!snapshot.hasData)
                const Center(child: CircularProgressIndicator())
              else if (peers.isEmpty)
                const DesignNote(
                    title: 'No deliverers available',
                    body: 'Try another search or check back shortly.')
              else
                for (final peer in peers) ...[
                  DesignCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          DesignAvatar(peer.name),
                          const SizedBox(width: 11),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(peer.name,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                Text(
                                    peer.totalDeliveries == 0
                                        ? 'Not rated yet'
                                        : '★ ${peer.rating.toStringAsFixed(1)} · ${peer.totalDeliveries} trips',
                                    style: const TextStyle(fontSize: 11)),
                              ])),
                          if (peer.rate > 0)
                            Text(naira(peer.rate),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 13),
                        Wrap(spacing: 7, runSpacing: 7, children: [
                          if (peer.verified)
                            const DesignBadge('Verified profile'),
                          DesignBadge(peer.vehicleType),
                          if (peer.distanceKm > 0)
                            DesignBadge(
                                '${peer.distanceKm.toStringAsFixed(1)} km'),
                          if (peer.etaMinutes > 0)
                            DesignBadge('~${peer.etaMinutes} min'),
                        ]),
                        const SizedBox(height: 14),
                        PrimaryButton(
                            label: 'Select ${peer.name.split(' ').first} →',
                            onPressed: () {
                              context
                                  .read<SendFlowProvider>()
                                  .pickDeliverer(peer.uid, peer.name);
                              Navigator.pushNamed(context, '/negotiate');
                            }),
                      ])),
                  const SizedBox(height: 12),
                ],
            ]);
      });
}
