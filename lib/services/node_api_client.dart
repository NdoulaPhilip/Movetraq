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

class AddressSuggestion {
  const AddressSuggestion({
    required this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
    this.placeId,
    this.syncWarning,
  });

  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final String? syncWarning;

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) {
    return AddressSuggestion(
      id: json['id'] as String? ??
          json['placeId'] as String? ??
          json['address'] as String? ??
          '',
      name: json['name'] as String? ??
          json['label'] as String? ??
          json['address'] as String? ??
          '',
      address: json['address'] as String? ?? json['name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      placeId: json['placeId'] as String?,
    );
  }
}

class HomeContext {
  const HomeContext({
    required this.greeting,
    required this.period,
    required this.serverTime,
    required this.timezone,
  });

  final String greeting;
  final String period;
  final DateTime serverTime;
  final String timezone;

  factory HomeContext.fromJson(Map<String, dynamic> json) {
    return HomeContext(
      greeting: json['greeting'] as String? ?? 'Good day',
      period: json['period'] as String? ?? 'day',
      serverTime: DateTime.tryParse(json['serverTime'] as String? ?? '') ??
          DateTime.now(),
      timezone: json['timezone'] as String? ?? '',
    );
  }
}

class NodeApiClient {
  NodeApiClient({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl ??
            const String.fromEnvironment(
              'MOVETRAQ_API_URL',
              defaultValue: 'https://movetraq-api.onrender.com',
            );

  final http.Client _client;
  final String baseUrl;
  String? _token;

  bool get isAuthenticated => _token != null;
  Future<AddressSuggestion> reverseAddress(LatLng point) async {
    final data = await _post('/places/reverse', point.toJson());
    return AddressSuggestion.fromJson(
        Map<String, dynamic>.from(data['location'] as Map));
  }

  Future<Map<String, dynamic>> route(LatLng pickup, LatLng destination) =>
      _post('/maps/route',
          {'pickup': pickup.toJson(), 'destination': destination.toJson()});
  Future<ParcelOrder> trackedOrder(String id) async {
    final data = await _get('/orders/${Uri.encodeComponent(id)}/tracking');
    return ParcelOrder.fromJson(
        Map<String, dynamic>.from(data['order'] as Map));
  }

  Future<Map<String, dynamic>> delivererAccess() =>
      _send('GET', '/deliverer-access');

  Future<Map<String, dynamic>> initializeWalletTopup(
          int amountMinor, String key) =>
      _send('POST', '/payments/topups',
          body: {'amountMinor': amountMinor},
          headers: {'Idempotency-Key': key});
  Future<Map<String, dynamic>> verifyWalletTopup(String reference) {
    if (!RegExp(r'^mt-[a-f0-9]{64}$').hasMatch(reference)) {
      throw NodeApiException('Invalid payment reference.');
    }
    return _post('/payments/$reference/verify', {});
  }

  Future<HomeContext> homeContext() async {
    final data = await _get('/home/context');
    return HomeContext.fromJson(data);
  }

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

  Future<AppUser> updateProfile({
    required String name,
    required String phone,
  }) async {
    final data = await _patch('/users/me', {
      'name': name,
      'phone': phone,
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

  Future<List<AddressSuggestion>> addressSuggestions(String query) async {
    final encoded = Uri.encodeQueryComponent(query);
    final data = await _get('/places/autocomplete?q=$encoded');
    return (data['suggestions'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AddressSuggestion.fromJson)
        .toList();
  }

  Future<AddressSuggestion> geocodeAddress(String query) async {
    final encoded = Uri.encodeQueryComponent(query);
    final data = await _get('/places/geocode?q=$encoded');
    return AddressSuggestion.fromJson(
      data['location'] as Map<String, dynamic>,
    );
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
    double lng, {
    required double accuracy,
    required DateTime capturedAt,
  }) async {
    final data = await _post('/orders/$orderId/location', {
      'latitude': lat,
      'longitude': lng,
      'accuracy': accuracy,
      'capturedAt': capturedAt.toUtc().toIso8601String(),
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

  Future<AppUser> orderContact(String orderId) async {
    final data = await _get('/orders/$orderId/contact');
    return AppUser.fromJson(data['contact'] as Map<String, dynamic>);
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

  Future<List<SavedAddress>> savedAddresses() async {
    final data = await _get('/users/me/addresses');
    return (data['addresses'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SavedAddress.fromJson)
        .toList();
  }

  Future<SavedAddress> saveAddress({
    String? id,
    required String label,
    required String address,
  }) async {
    final data = await _post('/users/me/addresses', {
      'id': id,
      'label': label,
      'address': address,
    });
    return SavedAddress.fromJson(data['address'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(String id) async {
    await _post('/users/me/addresses/$id/delete', {});
  }

  Future<SecuritySettings> securitySettings() async {
    final data = await _get('/users/me/security');
    return SecuritySettings.fromJson(data['settings'] as Map<String, dynamic>);
  }

  Future<SecuritySettings> updateSecuritySettings({
    required bool biometricsEnabled,
    required bool pinEnabled,
    String? pin,
  }) async {
    final data = await _patch('/users/me/security', {
      'biometricsEnabled': biometricsEnabled,
      'pinEnabled': pinEnabled,
      'pin': pin,
    });
    return SecuritySettings.fromJson(data['settings'] as Map<String, dynamic>);
  }

  Future<List<SupportTicket>> supportTickets() async {
    final data = await _get('/support/tickets');
    return (data['tickets'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SupportTicket.fromJson)
        .toList();
  }

  Future<SupportTicket> createSupportTicket({
    required String subject,
    required String message,
  }) async {
    final data = await _post('/support/tickets', {
      'subject': subject,
      'message': message,
    });
    return SupportTicket.fromJson(data['ticket'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _get(String path) {
    return _send('GET', path);
  }

  Future<Map<String, dynamic>> extendedRequest(String method, String path,
      {Map<String, dynamic>? body}) async {
    final response = await _send(method, '/api/v1$path', body: body);
    return response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;
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
    Map<String, String> headers = const {},
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.Request(method, uri)
      ..headers['content-type'] = 'application/json'
      ..headers.addAll(headers);
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
      final error = decoded['error'];
      throw NodeApiException(
        error is Map<String, dynamic>
            ? error['message']?.toString() ?? 'Node API request failed.'
            : error?.toString() ?? 'Node API request failed.',
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
