import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;

import '../theme/app_theme.dart';

class ConfiguredGoogleMap extends StatefulWidget {
  const ConfiguredGoogleMap({
    super.key,
    required this.map,
    this.compact = false,
  });

  final maps.GoogleMap map;
  final bool compact;

  static const MethodChannel _channel = MethodChannel('movetraq/map_config');
  static Future<bool>? _configuredFuture;

  @visibleForTesting
  static void resetConfigurationCache() => _configuredFuture = null;

  static Future<bool> _isConfigured() {
    _configuredFuture ??= _channel
        .invokeMethod<bool>('isGoogleMapsApiKeyConfigured')
        .then((value) => value == true)
        .catchError((_) => false);
    return _configuredFuture!;
  }

  static Future<Map<String, Object?>> diagnostics() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'googleMapsDiagnostics',
    );
    return result ?? const <String, Object?>{};
  }

  @override
  State<ConfiguredGoogleMap> createState() => _ConfiguredGoogleMapState();
}

class _ConfiguredGoogleMapState extends State<ConfiguredGoogleMap> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ConfiguredGoogleMap._isConfigured(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ColoredBox(
            color: const Color(0xFFE8EAED),
            child: Padding(
                padding: widget.map.padding,
                child: const Center(child: CircularProgressIndicator())),
          );
        }

        if (snapshot.data == false) {
          return ColoredBox(
              color: const Color(0xFFE8EAED),
              child: Padding(
                  padding: widget.map.padding,
                  child: LayoutBuilder(
                      builder: (context, constraints) => MapUnavailablePanel(
                          compact:
                              widget.compact || constraints.maxHeight < 200,
                          onRetry: () => setState(
                              ConfiguredGoogleMap.resetConfigurationCache)))));
        }

        return Stack(
          children: [
            Positioned.fill(child: widget.map),
            if (kDebugMode)
              Positioned(
                left: 12,
                top: widget.compact ? 10 : 58,
                child: _MapDiagnosticsButton(compact: widget.compact),
              ),
          ],
        );
      },
    );
  }
}

class _MapDiagnosticsButton extends StatelessWidget {
  const _MapDiagnosticsButton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () => _showDiagnostics(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 11,
            vertical: compact ? 6 : 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 15,
              ),
              if (!compact) ...[
                const SizedBox(width: 6),
                const Text(
                  'Map help',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDiagnostics(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    Map<String, Object?> data;
    try {
      data = await ConfiguredGoogleMap.diagnostics();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to read map diagnostics: $e')),
      );
      return;
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final packageName = data['packageName']?.toString() ?? '';
        final sha1 = data['sha1']?.toString() ?? '';
        final keyConfigured = data['keyConfigured'] == true;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Google Maps diagnostics',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _DiagnosticRow(
                  label: 'API key',
                  value: keyConfigured ? 'Configured' : 'Missing',
                ),
                _DiagnosticRow(label: 'Package', value: packageName),
                _DiagnosticRow(label: 'SHA-1', value: sha1),
                const SizedBox(height: 12),
                const Text(
                  'If the map is blank, enable Maps SDK for Android and add this package name plus SHA-1 to the API key restrictions in Google Cloud.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapUnavailablePanel extends StatelessWidget {
  const MapUnavailablePanel({
    super.key,
    this.compact = false,
    this.onRetry,
  });

  final bool compact;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) => Container(
              color: const Color(0xFFE8EAED),
              padding: EdgeInsets.all(compact ? 12 : 22),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (constraints.maxHeight >= 100) ...[
                        Icon(
                          Icons.map_outlined,
                          size: compact ? 24 : 38,
                          color: AppColors.ink,
                        ),
                        SizedBox(height: compact ? 6 : 12),
                      ],
                      Text(
                        'Map unavailable',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 12 : 16,
                        ),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Unable to load the map right now.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (onRetry != null)
                          TextButton.icon(
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try again')),
                      ],
                    ],
                  ),
                ),
              ),
            ));
  }
}
