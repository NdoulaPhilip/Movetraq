import 'package:flutter/foundation.dart';

class AppEnvironment {
  const AppEnvironment(
      {required this.apiUrl,
      this.supabaseUrl = '',
      this.supabaseAnonKey = '',
      this.mapsEnabled = false,
      this.pushEnabled = false});
  final String apiUrl, supabaseUrl, supabaseAnonKey;
  final bool mapsEnabled, pushEnabled;
  Uri get apiBaseUri {
    final uri = Uri.parse(apiUrl);
    final local = ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host);
    if (uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' && local && !kReleaseMode))) {
      throw ArgumentError(
          'Use HTTPS for the production API; local HTTP is development-only.');
    }
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.isNotEmpty && path != '/api/v1') {
      throw ArgumentError('Use the API origin or its /api/v1 base path.');
    }
    return uri.replace(path: '/api/v1');
  }

  Uri get storageOrigin {
    final uri = Uri.parse(supabaseUrl);
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError(
          'Configure a secure Supabase project origin for private uploads.');
    }
    return uri.replace(path: '');
  }

  bool get configured {
    try {
      apiBaseUri;
      storageOrigin;
      return supabaseAnonKey.isNotEmpty;
    } on ArgumentError {
      return false;
    } on FormatException {
      return false;
    }
  }
}

abstract final class Environment {
  static const apiUrl = String.fromEnvironment('MOVETRAQ_PRODUCTION_API_URL',
      defaultValue: String.fromEnvironment('API_URL'));
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const mapsEnabled = bool.fromEnvironment('MAPS_ENABLED');
  static const pushEnabled = bool.fromEnvironment('PUSH_ENABLED');
  static const values = AppEnvironment(
      apiUrl: apiUrl,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      mapsEnabled: mapsEnabled,
      pushEnabled: pushEnabled);
  static bool get configured => values.configured;
}
