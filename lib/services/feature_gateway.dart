import 'local_data_service.dart';

class FeatureUnavailable implements Exception {
  const FeatureUnavailable(this.feature);
  final String feature;
  @override
  String toString() => '$feature is not connected to the mobile API yet.';
}

/// New API contracts remain gated until mobile authentication is migrated.
class FeatureGateway {
  const FeatureGateway(this.data);
  final LocalDataService data;
  static const enabled = bool.fromEnvironment('MOVETRAQ_EXTENDED_API_ENABLED',
      defaultValue: false);

  Future<Map<String, dynamic>> request(
      String feature, String method, String path,
      {Map<String, dynamic>? body}) {
    final verification =
        RegExp(r'^/deliverers/me/applications(?:/[0-9a-fA-F-]{36}(?:/(?:documents|submit))?)?$')
                .hasMatch(path) ||
            RegExp(r'^/verification-documents/[0-9a-fA-F-]{36}/confirm$')
                .hasMatch(path);
    final workPreferences = path == '/users/me/preferences?scope=work' &&
        (method == 'GET' || method == 'PATCH');
    if (!enabled && !verification && !workPreferences) {
      return Future.error(FeatureUnavailable(feature));
    }
    return data.extendedRequest(method, path, body: body);
  }
}

int? parseMinorUnits(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}
