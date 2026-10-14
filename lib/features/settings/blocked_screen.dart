import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';

class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});
  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  late Future<Map<String, dynamic>> _people;
  String? _busy;
  Object? _error;
  FeatureGateway get _api => FeatureGateway(context.read<LocalDataService>());
  @override
  void initState() {
    super.initState();
    _people = _load();
  }

  Future<Map<String, dynamic>> _load() {
    final future =
        _api.request('Blocked people', 'GET', '/users/me/blocked-users');
    // Observe early failures until the next frame attaches FutureBuilder.
    future.ignore();
    return future;
  }

  Future<void> _unblock(String id) async {
    if (_busy != null ||
        !await confirmAction(context, 'Unblock this person?',
            'They may appear in future eligible matching.') ||
        !mounted) {
      return;
    }
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      showActionError(context, 'Invalid account reference.');
      return;
    }
    setState(() {
      _busy = id;
      _error = null;
    });
    try {
      await _api.request(
          'Unblock person', 'DELETE', '/users/me/blocked-users/$id');
      if (mounted) {
        setState(() {
          _people = _load();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) =>
      AppPage(title: 'Blocked people', children: [
        FutureBuilder<Map<String, dynamic>>(
            future: _people,
            builder: (context, snapshot) {
              if (snapshot.hasError) return LoadError(error: snapshot.error!);
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final people = snapshot.data!['blockedUsers'];
              if (people is! List) {
                return const InfoBand(
                    title: 'Blocked accounts could not be loaded.');
              }
              if (people.isEmpty) {
                return const InfoBand(title: 'You have not blocked anyone.');
              }
              return Column(
                  children: people
                      .whereType<Map>()
                      .map((person) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                                person['blocked_id']?.toString() ?? 'Account'),
                            subtitle: Text(person['reason']?.toString() ??
                                'Excluded from future matching'),
                            trailing: IconButton(
                                tooltip: 'Unblock',
                                onPressed: _busy == null &&
                                        person['blocked_id'] is String
                                    ? () =>
                                        _unblock(person['blocked_id'] as String)
                                    : null,
                                icon: const Icon(Icons.person_remove_outlined)),
                          ))
                      .toList());
            }),
        if (_error != null) LoadError(error: _error!),
        const RouteTile(
            title: 'Block a person', icon: Icons.block, route: '/block-user'),
      ]);
}
