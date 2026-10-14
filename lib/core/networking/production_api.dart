import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ProductionApiError implements Exception {
  const ProductionApiError(this.code, this.message, {this.status});
  final String code;
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class ProductionApi {
  ProductionApi({required String baseUrl, Dio? dio}) : _dio = dio ?? Dio() {
    final uri = Uri.parse(baseUrl);
    final local = ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host);
    if (uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' && local && !kReleaseMode))) {
      throw ArgumentError(
          'Use an HTTPS API URL (local HTTP is development-only).');
    }
    _dio.options = BaseOptions(
      baseUrl: baseUrl.replaceFirst(RegExp(r'/+$'), ''),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      followRedirects: false,
      headers: {'Accept': 'application/json'},
    );
  }
  final Dio _dio;

  static void validatePath(String path) {
    final uri = Uri.parse(path);
    if (!path.startsWith('/') ||
        path.startsWith('//') ||
        uri.hasScheme ||
        uri.hasFragment ||
        path.contains('\\') ||
        uri.pathSegments.any((segment) =>
            segment == '..' || segment == '.' || segment.contains('\\'))) {
      throw ArgumentError('API requests require a relative endpoint path.');
    }
  }

  Future<Map<String, dynamic>> request(String method, String path,
      {Map<String, dynamic>? body,
      String? token,
      String? idempotencyKey}) async {
    validatePath(path);
    if (idempotencyKey != null &&
        !RegExp(r'^[A-Za-z0-9-]{16,128}$').hasMatch(idempotencyKey)) {
      throw ArgumentError('Invalid idempotency key.');
    }
    try {
      final response = await _dio.request<dynamic>(path,
          data: body,
          options: Options(method: method, headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey
          }));
      final envelope = response.data;
      if (envelope is! Map ||
          envelope['success'] != true ||
          envelope['data'] is! Map) {
        throw const ProductionApiError(
            'INVALID_RESPONSE', 'MoveTraq returned an invalid response.');
      }
      return Map<String, dynamic>.from(envelope['data'] as Map);
    } on DioException catch (error) {
      final response = error.response;
      if (response != null) {
        final envelope = response.data;
        final detail = envelope is Map ? envelope['error'] : null;
        throw ProductionApiError(
            detail is Map && detail['code'] is String
                ? detail['code'] as String
                : 'REQUEST_FAILED',
            detail is Map && detail['message'] is String
                ? detail['message'] as String
                : 'The request failed.',
            status: response.statusCode);
      }
      throw const ProductionApiError(
          'NETWORK_UNAVAILABLE', 'Could not reach MoveTraq. Please try again.');
    }
  }

  void dispose() => _dio.close(force: true);
}
