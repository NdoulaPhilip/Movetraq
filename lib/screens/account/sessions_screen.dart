import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late Future<Map<String, dynamic>> _sessions;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _sessions = FeatureGateway(context.read<LocalDataService>())
      .request('Devices & sessions', 'GET', '/users/me/sessions');
  @override
  Widget build(BuildContext context) => AppPage(
          title: 'Devices & sessions',
          subtitle: 'Review the devices connected to your account.',
          children: [
            FutureBuilder<Map<String, dynamic>>(
                future: _sessions,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return LoadError(
                        error: snapshot.error!, onRetry: () => setState(_load));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final records =
                      snapshot.data!['sessions'] ?? snapshot.data!['items'];
                  if (records is! List) {
                    return const DesignNote(
                        title: 'Session information unavailable');
                  }
                  if (records.isEmpty) {
                    return const DesignNote(
                        title: 'No sessions returned',
                        body:
                            'Refresh this page to check your connected devices.');
                  }
                  return Column(children: [
                    for (final session in records.whereType<Map>())
                      DesignNote(
                          title: session['device']?.toString() ?? 'Device',
                          body: session['last_active_at'] == null
                              ? 'Last active time unavailable'
                              : 'Last active: ${session['last_active_at']}'),
                  ]);
                }),
            const SizedBox(height: 16),
            const Text(
                'Connected-device information is provided by your account service.',
                style: TextStyle(fontSize: 13, height: 1.7)),
          ]);
}
