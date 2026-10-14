import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user.dart';
import '../../providers/send_flow_provider.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/premium_ui.dart';
import '../../widgets/primary_button.dart';

class PickDelivererScreen extends StatefulWidget {
  const PickDelivererScreen({super.key});
  @override
  State<PickDelivererScreen> createState() => _PickDelivererScreenState();
}

class _PickDelivererScreenState extends State<PickDelivererScreen> {
  String _query = '';
  String _sort = 'All';
  late Stream<List<AppUser>> _stream;
  @override
  void initState() {
    super.initState();
    _stream = context.read<LocalDataService>().watchAvailableDeliverers();
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Choose a deliverer', children: [
        TextField(
            decoration: const InputDecoration(
                hintText: 'Name or transport', prefixIcon: Icon(Icons.search)),
            onChanged: (value) => setState(() => _query = value.toLowerCase())),
        const SizedBox(height: 14),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All', 'Top rated', 'Nearest', 'Lowest price']
                .map((value) => ChoiceChip(
                    label: Text(value),
                    selected: value == _sort,
                    onSelected: (_) => setState(() => _sort = value)))
                .toList()),
        const SizedBox(height: 18),
        StreamBuilder<List<AppUser>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final peers = snapshot.data!
                  .where((user) => '${user.name} ${user.vehicleType}'
                      .toLowerCase()
                      .contains(_query))
                  .toList();
              if (_sort == 'Top rated') {
                peers.sort((a, b) => b.rating.compareTo(a.rating));
              }
              if (_sort == 'Nearest') {
                peers.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
              }
              if (_sort == 'Lowest price') {
                peers.sort((a, b) => a.rate.compareTo(b.rate));
              }
              if (peers.isEmpty) {
                return const PremiumEmptyState(
                    icon: Icons.person_outline,
                    title: 'No deliverers available',
                    body: '');
              }
              return Column(children: [
                for (final peer in peers)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: PremiumSurface(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Row(children: [
                              CircleAvatar(child: Text(peer.initials)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(peer.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600))),
                              if (peer.verified)
                                const Tooltip(
                                    message: 'Verified',
                                    child:
                                        Icon(Icons.verified_outlined, size: 20))
                            ]),
                            const SizedBox(height: 12),
                            DetailRow('Transport', peer.vehicleType),
                            DetailRow(
                                'Rating',
                                peer.totalDeliveries == 0
                                    ? 'Not rated yet'
                                    : '${peer.rating.toStringAsFixed(1)} / ${peer.totalDeliveries} deliveries'),
                            if (peer.distanceKm > 0)
                              DetailRow('Distance',
                                  '${peer.distanceKm.toStringAsFixed(1)} km'),
                            if (peer.etaMinutes > 0)
                              DetailRow('Estimated arrival',
                                  '${peer.etaMinutes} min'),
                            if (peer.rate > 0)
                              DetailRow('Delivery rate',
                                  'NGN ${peer.rate.toStringAsFixed(2)}'),
                            const SizedBox(height: 12),
                            PrimaryButton(
                                label: 'Select deliverer',
                                onPressed: () {
                                  context
                                      .read<SendFlowProvider>()
                                      .pickDeliverer(peer.uid, peer.name);
                                  Navigator.pushNamed(context, '/negotiate');
                                }),
                          ])))
              ]);
            }),
      ]);
}
