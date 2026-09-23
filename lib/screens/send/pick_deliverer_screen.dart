import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/send_flow_provider.dart';
import '../../services/local_data_service.dart';
import '../../theme/app_theme.dart';

enum _SortFilter { all, topRated, nearest, cheapest }

class PickDelivererScreen extends StatefulWidget {
  const PickDelivererScreen({super.key});

  @override
  State<PickDelivererScreen> createState() => _PickDelivererScreenState();
}

class _PickDelivererScreenState extends State<PickDelivererScreen> {
  final _searchCtrl = TextEditingController();
  _SortFilter _filter = _SortFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AppUser> _applyFilters(List<AppUser> input) {
    var list = input.where((d) {
      if (_query.isEmpty) return true;
      return d.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    switch (_filter) {
      case _SortFilter.topRated:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _SortFilter.nearest:
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case _SortFilter.cheapest:
        list.sort((a, b) => a.rate.compareTo(b.rate));
        break;
      case _SortFilter.all:
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.read<LocalDataService>();
    final flow = context.read<SendFlowProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                'Choose a deliverer',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
            ),
            StreamBuilder<List<AppUser>>(
              stream: data.watchAvailableDeliverers(),
              builder: (context, snap) {
                final count = snap.data?.length ?? 0;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    '$count peers available for this route',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 20, color: AppColors.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search by name or vehicle...',
                          hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const Icon(Icons.tune, size: 18, color: AppColors.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == _SortFilter.all,
                    onTap: () => setState(() => _filter = _SortFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Top rated',
                    icon: Icons.star,
                    selected: _filter == _SortFilter.topRated,
                    onTap: () => setState(() => _filter = _SortFilter.topRated),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Nearest',
                    icon: Icons.location_on,
                    selected: _filter == _SortFilter.nearest,
                    onTap: () => setState(() => _filter = _SortFilter.nearest),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Cheapest',
                    icon: Icons.local_offer,
                    selected: _filter == _SortFilter.cheapest,
                    onTap: () => setState(() => _filter = _SortFilter.cheapest),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<AppUser>>(
                stream: data.watchAvailableDeliverers(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final deliverers = _applyFilters(snap.data!);
                  if (deliverers.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No deliverers online right now. Try instant match instead, or check back shortly.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: deliverers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 11),
                    itemBuilder: (context, i) {
                      final d = deliverers[i];
                      return _DelivererCard(
                        deliverer: d,
                        onSelect: () {
                          flow.pickDeliverer(d.uid, d.name);
                          Navigator.pushNamed(context, '/negotiate');
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? AppColors.ink : AppColors.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? Colors.white : AppColors.muted),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DelivererCard extends StatelessWidget {
  const _DelivererCard({required this.deliverer, required this.onSelect});

  final AppUser deliverer;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final d = deliverer;
    final vehicleIcon = d.vehicleType == 'car' ? Icons.directions_car : Icons.pedal_bike;
    final vehicleLabel = d.vehicleType == 'car' ? 'Car' : 'Bike';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.accent,
                    child: Text(
                      d.initials,
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (d.delivererOnline)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6FCF3B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            d.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                          ),
                        ),
                        if (d.verified) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tint['mint'],
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'Verified',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF5A7A10),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.star, size: 13, color: AppColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        '${d.rating.toStringAsFixed(1)} · ${d.totalDeliveries} trips',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                      ),
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₦${d.rate.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                  const Text('their rate', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(vehicleIcon, size: 14, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(vehicleLabel, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(width: 10),
              _pill('${d.distanceKm.toStringAsFixed(1)} km'),
              const SizedBox(width: 6),
              _pill('~${d.etaMinutes} min'),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Select ${d.name.split(' ').first}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
    );
  }
}