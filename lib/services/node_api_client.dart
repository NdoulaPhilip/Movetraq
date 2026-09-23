import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../models/misc_models.dart';
import '../models/parcel_order.dart';

class NodeApiException implements Exception {
  NodeApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NodeApiClient {
  NodeApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? const String.fromEnvironment(
          'MOVETRAQ_API_URL',
          defaultValue: 'https://movetraq-api.onrender.com',
        );

  final http.Client _client;
  final String baseUrl;
  String? _token;

  bool get isAuthenticated => _token != null;

  Future<AppUser> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final data = await _post('/auth/signup', {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
    });
    _token = data['token'] as String?;
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> signIn({
    required String emailOrPhone,
    required String password,
  }) async {
    final data = await _post('/auth/signin', {
      'emailOrPhone': emailOrPhone,
      'password': password,
    });
    _token = data['token'] as String?;
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> resetPassword({
    required String emailOrPhone,
    required String newPassword,
  }) async {
    await _post('/auth/reset-password', {
      'emailOrPhone': emailOrPhone,
      'newPassword': newPassword,
    });
  }

  Future<void> signOut() async {
    _token = null;
  }

  Future<AppUser?> me() async {
    if (_token == null) return null;
    final data = await _get('/auth/me');
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> updateRole(UserRole role) async {
    final data = await _patch('/users/me', {
      'activeRole': userRoleToJson(role),
    });
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> setDelivererOnline(bool online) async {
    final data = await _patch('/users/me', {
      'delivererOnline': online,
    });
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> updateCurrentLocation(double lat, double lng) async {
    final data = await _patch('/users/me/location', {
      'latitude': lat,
      'longitude': lng,
    });
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<List<AppUser>> availableDeliverers() async {
    final data = await _get('/deliverers');
    return (data['deliverers'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AppUser.fromJson)
        .toList();
  }

  Future<List<ParcelOrder>> orders() async {
    final data = await _get('/orders');
    return (data['orders'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ParcelOrder.fromJson)
        .toList();
  }

  Future<ParcelOrder> createOrder(ParcelOrder draft) async {
    final data = await _post('/orders', draft.toJson());
    return ParcelOrder.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<ParcelOrder> acceptJob({
    required String orderId,
    required String delivererId,
    required String delivererName,
  }) async {
    final data = await _post('/orders/$orderId/accept', {
      'delivererId': delivererId,
      'delivererName': delivererName,
    });
    return ParcelOrder.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<ParcelOrder> advanceDelivererStage(
    String orderId,
    int newStage,
  ) async {
    final data = await _post('/orders/$orderId/stage', {
      'stage': newStage,
    });
    return ParcelOrder.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<ParcelOrder> updateCourierLocation(
    String orderId,
    double lat,
    double lng,
  ) async {
    final data = await _post('/orders/$orderId/location', {
      'latitude': lat,
      'longitude': lng,
    });
    return ParcelOrder.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<ParcelOrder> negotiatePrice(String orderId, double newPrice) async {
    final data = await _post('/orders/$orderId/negotiate', {
      'price': newPrice,
    });
    return ParcelOrder.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<ParcelOrder> confirmOrderPrice(
    String orderId,
    double agreedPrice,
  ) async {
    final data = await _post('/orders/$orderId/confirm-price', {
      'price': agreedPrice,
    });
    return ParcelOrder.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<ParcelOrder> releaseEscrow(String orderId) async {
    final data = await _post('/orders/$orderId/release', {});
    return ParcelOrder.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<ParcelOrder> cancelOrder(String orderId) async {
    final data = await _post('/orders/$orderId/cancel', {});
    return ParcelOrder.fromJson(data['order'] as Map<String, dynamic>);
  }

  Future<List<ChatMessage>> messages(String orderId) async {
    final data = await _get('/orders/$orderId/messages');
    return (data['messages'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((json) => ChatMessage(
              id: json['id'] as String,
              senderId: json['senderId'] as String,
              text: json['text'] as String,
              createdAt: DateTime.parse(json['createdAt'] as String),
            ))
        .toList();
  }

  Future<ChatMessage> sendMessage(
    String orderId,
    String senderId,
    String text,
  ) async {
    final data = await _post('/orders/$orderId/messages', {
      'senderId': senderId,
      'text': text,
    });
    final json = data['message'] as Map<String, dynamic>;
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Future<List<WalletTransaction>> walletTransactions() async {
    final data = await _get('/wallet/transactions');
    return (data['transactions'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_walletTxFromJson)
        .toList();
  }

  Future<AppUser> addWalletTransaction({
    required WalletTransaction tx,
    required double balanceDelta,
  }) async {
    if (tx.type == WalletTxType.topup) {
      final data = await _post('/wallet/topup', {
        'title': tx.title,
        'sub': tx.sub,
        'amount': tx.amount.abs(),
      });
      return AppUser.fromJson(data['user'] as Map<String, dynamic>);
    }

    if (tx.type == WalletTxType.withdrawal) {
      final data = await _post('/wallet/withdraw', {
        'title': tx.title,
        'sub': tx.sub,
        'amount': tx.amount.abs(),
      });
      return AppUser.fromJson(data['user'] as Map<String, dynamic>);
    }

    final data = await _post('/wallet/transactions', {
      'type': tx.type.name,
      'title': tx.title,
      'sub': tx.sub,
      'amount': tx.amount,
      'balanceDelta': balanceDelta,
    });
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<List<NotificationItem>> notifications() async {
    final data = await _get('/notifications');
    return (data['notifications'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_notificationFromJson)
        .toList();
  }

  Future<void> addNotification(NotificationItem notification) async {
    await _post('/notifications', {
      'title': notification.title,
      'body': notification.body,
      'type': notification.type,
      'read': notification.read,
    });
  }

  Future<void> markNotificationRead(String notifId) async {
    await _post('/notifications/$notifId/read', {});
  }

  Future<Map<String, dynamic>> _get(String path) {
    return _send('GET', path);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) {
    return _send('POST', path, body: body);
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) {
    return _send('PATCH', path, body: body);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.Request(method, uri)
      ..headers['content-type'] = 'application/json';
    if (_token != null) {
      request.headers['authorization'] = 'Bearer $_token';
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }

    late http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } on http.ClientException catch (error) {
      throw NodeApiException(
        'Could not reach the MoveTraq API at $baseUrl. '
        'Check your internet connection or confirm the hosted API is awake. '
        'Details: ${error.message}',
      );
    }
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NodeApiException(
        decoded['error'] as String? ?? 'Node API request failed.',
      );
    }

    return decoded;
  }

  WalletTransaction _walletTxFromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      type: WalletTxType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => WalletTxType.topup,
      ),
      title: json['title'] as String? ?? '',
      sub: json['sub'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  NotificationItem _notificationFromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'delivery',
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
