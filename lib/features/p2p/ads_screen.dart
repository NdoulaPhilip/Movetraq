import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';

class AdsScreen extends StatefulWidget {
  const AdsScreen({super.key, this.mine = true});
  final bool mine;
  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  late Future<Map<String, dynamic>> _ads;
  bool _busy = false;
  Object? _error;
  FeatureGateway get _api => FeatureGateway(context.read<LocalDataService>());
  @override
  void initState() {
    super.initState();
    _ads = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final future = _api.request(
        'Delivery ads', 'GET', widget.mine ? '/deliverers/me/ads' : '/ads');
    // Observe early failures until the next frame attaches FutureBuilder.
    future.ignore();
    return future;
  }

  Future<void> _action(Map ad, String action) async {
    if (_busy || !widget.mine) return;
    final id = ad['id'];
    if (id is! String || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      showActionError(context, 'Invalid delivery ad reference.');
      return;
    }
    if (action == 'edit') {
      await Navigator.pushNamed(context, '/edit-p2p-ad', arguments: id);
      if (mounted) {
        setState(() {
          _ads = _load();
        });
      }
      return;
    }
    if (action == 'delete' &&
        (!await confirmAction(
                context, 'Delete delivery ad?', 'This cannot be undone.') ||
            !mounted)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.request('Delivery ad management',
          action == 'delete' ? 'DELETE' : 'PATCH', '/ads/$id',
          body: action == 'delete'
              ? null
              : {'status': action == 'pause' ? 'paused' : 'active'});
      if (mounted) {
        setState(() {
          _ads = _load();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
        title: widget.mine ? 'My delivery offers' : 'P2P delivery offers',
        subtitle: widget.mine
            ? 'Manage your routes, fees and availability.'
            : 'Choose an offer for your route.',
        actions: [
          IconButton(
              tooltip: 'Refresh ads',
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _ads = _load();
                      }),
              icon: const Icon(Icons.refresh)),
          if (widget.mine)
            IconButton(
                tooltip: 'Create delivery ad',
                onPressed: () async {
                  await Navigator.pushNamed(context, '/create-p2p-ad');
                  if (mounted) {
                    setState(() {
                      _ads = _load();
                    });
                  }
                },
                icon: const Icon(Icons.add))
        ],
        children: [
          FutureBuilder<Map<String, dynamic>>(
              future: _ads,
              builder: (context, snapshot) {
                if (snapshot.hasError) return LoadError(error: snapshot.error!);
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final ads = snapshot.data!['ads'];
                if (ads is! List) {
                  return const InfoBand(
                      title: 'Delivery ads could not be loaded.');
                }
                if (ads.isEmpty) {
                  return DesignNote(
                      title: 'No delivery offers yet',
                      body: widget.mine
                          ? 'Create an offer with your route, fee and availability.'
                          : 'No delivery offers are available yet. Published offers will appear here.');
                }
                return Column(
                    children: ads
                        .whereType<Map>()
                        .map((ad) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DesignCard(
                                child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(ad['title']?.toString() ??
                                        'Delivery offer'),
                                    subtitle: Text(ad['status']?.toString() ??
                                        'Status unavailable'),
                                    trailing: widget.mine
                                        ? PopupMenuButton<String>(
                                            enabled: !_busy,
                                            tooltip: 'Ad actions',
                                            onSelected: (action) =>
                                                _action(ad, action),
                                            itemBuilder: (_) => [
                                                  const PopupMenuItem(
                                                      value: 'edit',
                                                      child: Text('Edit')),
                                                  PopupMenuItem(
                                                      value: ad['status'] ==
                                                              'paused'
                                                          ? 'resume'
                                                          : 'pause',
                                                      child: Text(
                                                          ad['status'] ==
                                                                  'paused'
                                                              ? 'Resume'
                                                              : 'Pause')),
                                                  const PopupMenuItem(
                                                      value: 'delete',
                                                      child: Text('Delete')),
                                                ])
                                        : null))))
                        .toList());
              }),
          if (_error != null) LoadError(error: _error!)
        ],
      );
}

class BrowseAdsScreen extends AdsScreen {
  const BrowseAdsScreen({super.key}) : super(mine: false);
}
