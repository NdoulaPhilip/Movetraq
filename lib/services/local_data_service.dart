import 'dart:async';
import 'dart:math';

import '../models/app_user.dart';
import '../models/misc_models.dart';
import '../models/parcel_order.dart';
import 'node_api_client.dart';
import 'location_service.dart';

/// App data gateway.
///
/// Normal builds always use the hosted Node API. The in-memory fallback is
/// available only for isolated development with
/// `--dart-define=MOVETRAQ_ALLOW_LOCAL_FALLBACK=true`.
class LocalDataService {
  Future<Map<String, dynamic>> delivererAccess() async {
    final api = _api;
    final owner = currentUser?.uid;
    if (api == null || owner == null || !api.isAuthenticated) {
      throw StateError('Sign in to check delivery approval.');
    }
    final result = await api.delivererAccess();
    if (currentUser?.uid != owner) throw StateError('Your account changed.');
    final user =
        AppUser.fromJson(Map<String, dynamic>.from(result['user'] as Map));
    if (user.uid != owner) {
      throw StateError('Delivery approval account mismatch.');
    }
    _storeUser(user, makeCurrent: true);
    final events = result['notifications'];
    if (events is List) {
      final inbox = List<NotificationItem>.of(_notifs[owner] ?? []);
      var changed = false;
      for (final event in events.whereType<Map>()) {
        if (event['id'] is! String || event['type'] != 'verification_update') {
          continue;
        }
        final id = 'verification:${event['id']}';
        final index = inbox.indexWhere((item) => item.id == id);
        if (index < 0) {
          final createdAt =
              DateTime.tryParse(event['created_at']?.toString() ?? '');
          if (createdAt == null) continue;
          inbox.add(NotificationItem(
              id: id,
              title: event['title']?.toString() ?? 'Application update',
              body: event['body']?.toString() ?? '',
              type: 'verification_update',
              read: event['read_at'] != null,
              createdAt: createdAt));
          changed = true;
        } else if (!inbox[index].read && event['read_at'] != null) {
          inbox[index] = inbox[index].copyWith(read: true);
          changed = true;
        }
      }
      if (changed) {
        _notifs[owner] = inbox;
        _notifsController.add(Map<String, List<NotificationItem>>.of(_notifs));
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> initializeWalletTopup(
      int amountMinor, String key) async {
    final api = _api;
    final owner = currentUser?.uid;
    if (api == null || owner == null || !api.isAuthenticated) {
      throw StateError('Sign in before adding money.');
    }
    final result = await api.initializeWalletTopup(amountMinor, key);
    if (currentUser?.uid != owner) {
      throw StateError('Your account changed. Please sign in again.');
    }
    return result;
  }

  Future<Map<String, dynamic>> verifyWalletTopup(String reference) async {
    final api = _api;
    final owner = currentUser?.uid;
    if (api == null || owner == null || !api.isAuthenticated) {
      throw StateError('Sign in before checking payment.');
    }
    final result = await api.verifyWalletTopup(reference);
    if (currentUser?.uid != owner) {
      throw StateError('Your account changed. Please sign in again.');
    }
    if (result['status'] == 'verified' && result['reference'] == reference) {
      final user =
          AppUser.fromJson(Map<String, dynamic>.from(result['user'] as Map));
      if (user.uid != owner) {
        throw StateError('Payment account does not match.');
      }
      _storeUser(user, makeCurrent: true);
    }
    return result;
  }

  Future<Map<String, dynamic>> extendedRequest(String method, String path,
      {Map<String, dynamic>? body}) {
    final api = _api;
    if (api == null) throw StateError('A connected API is required.');
    return api.extendedRequest(method, path, body: body);
  }

  LocalDataService({
    NodeApiClient? api,
    bool useRemote = true,
  }) : _api = useRemote || !_allowLocalFallback ? api ?? NodeApiClient() : null;

  final NodeApiClient? _api;
  static const bool _allowLocalFallback = bool.fromEnvironment(
    'MOVETRAQ_ALLOW_LOCAL_FALLBACK',
    defaultValue: false,
  );

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  final Map<String, AppUser> _users = {};

  final StreamController<Map<String, AppUser>> _usersController =
      StreamController<Map<String, AppUser>>.broadcast();

  // ---------------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------------

  final Map<String, ParcelOrder> _orders = {};

  final StreamController<Map<String, ParcelOrder>> _ordersController =
      StreamController<Map<String, ParcelOrder>>.broadcast();

  // ---------------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------------

  final Map<String, List<ChatMessage>> _messages = {};

  final StreamController<Map<String, List<ChatMessage>>> _messagesController =
      StreamController<Map<String, List<ChatMessage>>>.broadcast();

  // ---------------------------------------------------------------------------
  // Wallet
  // ---------------------------------------------------------------------------

  final Map<String, List<WalletTransaction>> _walletTx = {};

  final StreamController<Map<String, List<WalletTransaction>>>
      _walletController =
      StreamController<Map<String, List<WalletTransaction>>>.broadcast();

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  final Map<String, List<NotificationItem>> _notifs = {};

  final StreamController<Map<String, List<NotificationItem>>>
      _notifsController =
      StreamController<Map<String, List<NotificationItem>>>.broadcast();

  final Map<String, List<SavedAddress>> _savedAddresses = {};

  final StreamController<Map<String, List<SavedAddress>>> _addressesController =
      StreamController<Map<String, List<SavedAddress>>>.broadcast();

  final Map<String, SecuritySettings> _securitySettings = {};

  final StreamController<Map<String, SecuritySettings>> _securityController =
      StreamController<Map<String, SecuritySettings>>.broadcast();

  final Map<String, List<SupportTicket>> _supportTickets = {};

  final StreamController<Map<String, List<SupportTicket>>> _supportController =
      StreamController<Map<String, List<SupportTicket>>>.broadcast();

  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  AppUser? currentUser;

  final StreamController<AppUser?> _authController =
      StreamController<AppUser?>.broadcast();

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  final Random _rand = Random();

  // ---------------------------------------------------------------------------
  // Generic stream helper
  // ---------------------------------------------------------------------------

  /// Emits the current value immediately and then emits future updates.
  ///
  /// This makes the local service behave similarly to a live database
  /// subscription.
  Stream<T> _withInitial<T>(
    T Function() getCurrent,
    Stream<T> updates,
  ) async* {
    yield getCurrent();
    yield* updates;
  }

  Stream<T> _withLocalTracking<T>(
    T Function() getCurrent,
    Stream<T> updates,
  ) {
    return _withInitial(getCurrent, updates);
  }

  void _storeUser(AppUser user, {bool makeCurrent = false}) {
    _users[user.uid] = user;
    _usersController.add(Map<String, AppUser>.of(_users));

    if (makeCurrent || currentUser?.uid == user.uid) {
      currentUser = user;
      _authController.add(user);
    }
  }

  void _storeUsers(Iterable<AppUser> users) {
    for (final user in users) {
      _users[user.uid] = user;
    }
    _usersController.add(Map<String, AppUser>.of(_users));
  }

  void _storeOrder(ParcelOrder order) {
    _orders[order.id] = order;
    _ordersController.add(Map<String, ParcelOrder>.of(_orders));
  }

  void _storeOrders(Iterable<ParcelOrder> orders) {
    _orders
      ..clear()
      ..addEntries(
        orders.map((order) => MapEntry(order.id, order)),
      );
    _ordersController.add(Map<String, ParcelOrder>.of(_orders));
  }

  Future<void> refreshRemoteState() async {
    final api = _api;
    if (api == null || !api.isAuthenticated) return;

    final user = await api.me();
    if (user != null) {
      _storeUser(user, makeCurrent: true);
    }

    _storeUsers(await api.availableDeliverers());
    _storeOrders(await api.orders());

    if (currentUser != null) {
      _walletTx[currentUser!.uid] = await api.walletTransactions();
      _walletController.add(
        Map<String, List<WalletTransaction>>.of(_walletTx),
      );

      _notifs[currentUser!.uid] = await api.notifications();
      _notifsController.add(
        Map<String, List<NotificationItem>>.of(_notifs),
      );
    }
  }

  Future<HomeContext> homeContext() async {
    final api = _api;
    if (api != null) {
      try {
        return await api.homeContext();
      } catch (_) {
        // Keep the home screen friendly while the hosted API wakes up.
      }
    }
    return _localHomeContext();
  }

  HomeContext _localHomeContext() {
    final now = DateTime.now();
    final hour = now.hour;
    if (hour < 12) {
      return HomeContext(
        greeting: 'Good morning',
        period: 'morning',
        serverTime: now,
        timezone: 'local',
      );
    }
    if (hour < 17) {
      return HomeContext(
        greeting: 'Good afternoon',
        period: 'afternoon',
        serverTime: now,
        timezone: 'local',
      );
    }
    return HomeContext(
      greeting: 'Good evening',
      period: 'evening',
      serverTime: now,
      timezone: 'local',
    );
  }

  // ---------------------------------------------------------------------------
  // ID generators
  // ---------------------------------------------------------------------------

  String _genOrderId() {
    return 'order_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _genOrderCode() {
    return 'MT-${1000 + _rand.nextInt(9000)}';
  }

  String _genMessageId() {
    return 'msg_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _genTransactionId() {
    return 'tx_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _genNotificationId() {
    return 'notif_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _genAddressId() {
    return 'addr_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _genTicketId() {
    return 'ticket_${DateTime.now().microsecondsSinceEpoch}';
  }

  // ===========================================================================
  // AUTHENTICATION
  // ===========================================================================

  /// Emits whenever the authentication state changes.
  Stream<AppUser?> get authStateChanges => _authController.stream;

  /// Watches a user's profile.
  Stream<AppUser?> profileStream(String uid) {
    return _withInitial(
      () => _users[uid],
      _usersController.stream.map((users) => users[uid]),
    );
  }

  /// Gets a user profile immediately.
  AppUser? fetchProfile(String uid) {
    return _users[uid];
  }

  /// Creates a new local user.
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final api = _api;
    if (api != null) {
      final user = await api.signUp(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      _storeUser(user, makeCurrent: true);
      await refreshRemoteState();
      return user;
    }

    await Future.delayed(const Duration(milliseconds: 300));

    // Password is intentionally not stored because this is a local demo.
    // A real backend must handle password hashing and authentication.
    password;

    final normalizedEmail = email.trim().toLowerCase();

    final emailExists = _users.values.any(
      (user) => user.email.trim().toLowerCase() == normalizedEmail,
    );

    if (emailExists) {
      throw StateError(
        'An account already exists for that email.',
      );
    }

    final uid = 'user_${DateTime.now().microsecondsSinceEpoch}';

    final user = AppUser(
      uid: uid,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      createdAt: DateTime.now(),
      walletBalance: 0,
      memberTier: 'Bronze',
      totalDeliveries: 0,
    );

    _users[uid] = user;

    _usersController.add(
      Map<String, AppUser>.of(_users),
    );

    currentUser = user;

    _authController.add(user);

    return user;
  }

  /// Local fallback sign-in.
  ///
  /// Matches an existing local fallback account by email or phone.
  /// If no account exists, a temporary local account is created.
  Future<AppUser> signIn({
    required String emailOrPhone,
    required String password,
  }) async {
    final api = _api;
    if (api != null) {
      final user = await api.signIn(
        emailOrPhone: emailOrPhone,
        password: password,
      );
      _storeUser(user, makeCurrent: true);
      await refreshRemoteState();
      return user;
    }

    await Future.delayed(
      const Duration(milliseconds: 300),
    );

    // Password authentication is intentionally omitted in this
    // frontend-only implementation.
    password;

    final login = emailOrPhone.trim();

    final existingUsers = _users.values.where(
      (user) =>
          user.email.trim().toLowerCase() == login.toLowerCase() ||
          user.phone.trim() == login,
    );

    AppUser user;

    if (existingUsers.isNotEmpty) {
      user = existingUsers.first;
    } else {
      final uid = 'user_${DateTime.now().microsecondsSinceEpoch}';

      user = AppUser(
        uid: uid,
        name: 'MoveTraq User',
        email: login,
        phone: '',
        createdAt: DateTime.now(),
      );

      _users[uid] = user;

      _usersController.add(
        Map<String, AppUser>.of(_users),
      );
    }

    currentUser = user;

    _authController.add(user);

    return user;
  }

  /// Resets an existing account password.
  Future<void> resetPassword({
    required String emailOrPhone,
    required String newPassword,
  }) async {
    final api = _api;
    if (api != null) {
      await api.resetPassword(
        emailOrPhone: emailOrPhone,
        newPassword: newPassword,
      );
      return;
    }

    await Future.delayed(
      const Duration(milliseconds: 300),
    );

    if (newPassword.length < 6) {
      throw StateError('Password must be at least 6 characters.');
    }

    final login = emailOrPhone.trim();
    final exists = _users.values.any(
      (user) =>
          user.email.trim().toLowerCase() == login.toLowerCase() ||
          user.phone.trim() == login,
    );

    if (!exists) {
      throw StateError(
          'No MoveTraq account was found for that email or phone.');
    }
  }

  /// Changes the active role of a user.
  Future<void> updateRole(
    String uid,
    UserRole role,
  ) async {
    final api = _api;
    if (api != null && api.isAuthenticated && currentUser?.uid == uid) {
      _storeUser(await api.updateRole(role), makeCurrent: true);
      return;
    }

    final user = _users[uid];

    if (user == null) {
      return;
    }

    final updatedUser = user.copyWith(
      activeRole: role,
    );

    _users[uid] = updatedUser;

    _usersController.add(
      Map<String, AppUser>.of(_users),
    );

    if (currentUser?.uid == uid) {
      currentUser = updatedUser;
      _authController.add(updatedUser);
    }
  }

  /// Updates editable profile fields for the signed-in user.
  Future<void> updateProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();

    if (trimmedName.isEmpty) {
      throw StateError('Name is required.');
    }

    final api = _api;
    if (api != null && api.isAuthenticated && currentUser?.uid == uid) {
      _storeUser(
        await api.updateProfile(name: trimmedName, phone: trimmedPhone),
        makeCurrent: true,
      );
      return;
    }

    final user = _users[uid];

    if (user == null) {
      return;
    }

    final updatedUser = user.copyWith(
      name: trimmedName,
      phone: trimmedPhone,
    );

    _storeUser(updatedUser, makeCurrent: currentUser?.uid == uid);
  }

  /// Sets a deliverer's online/offline status.
  Future<void> setDelivererOnline(
    String uid,
    bool online,
  ) async {
    final api = _api;
    if (api != null && api.isAuthenticated && currentUser?.uid == uid) {
      _storeUser(await api.setDelivererOnline(online), makeCurrent: true);
      return;
    }

    final user = _users[uid];

    if (user == null) {
      return;
    }

    final updatedUser = user.copyWith(
      delivererOnline: online,
    );

    _users[uid] = updatedUser;

    _usersController.add(
      Map<String, AppUser>.of(_users),
    );

    if (currentUser?.uid == uid) {
      currentUser = updatedUser;
      _authController.add(updatedUser);
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    await _api?.signOut();
    currentUser = null;
    _authController.add(null);
  }

  NodeApiClient get _liveApi {
    final api = _api;
    if (api == null || !api.isAuthenticated) {
      throw StateError('Sign in to use live location services.');
    }
    return api;
  }

  Future<List<AddressSuggestion>> searchAddresses(String query) async {
    if (query.trim().length < 3) return [];
    return _liveApi.addressSuggestions(query.trim());
  }

  Future<AddressSuggestion> currentAddress() async {
    final owner = currentUser?.uid;
    if (owner == null) {
      throw StateError('Sign in to use your current location.');
    }
    final point = await const LocationService().getCurrentPosition();
    if (currentUser?.uid != owner) throw StateError('Your account changed.');
    String? syncWarning;
    try {
      await updateCurrentUserLocation(point.latitude, point.longitude);
    } catch (_) {
      syncWarning =
          'GPS found. Your location could not be saved. Please retry.';
    }
    if (currentUser?.uid != owner) throw StateError('Your account changed.');
    try {
      final result =
          await reverseAddress(LatLng(point.latitude, point.longitude));
      if (currentUser?.uid != owner) throw StateError('Your account changed.');
      return AddressSuggestion(
          id: result.id,
          name: result.name,
          address: result.address,
          latitude: point.latitude,
          longitude: point.longitude,
          placeId: result.placeId,
          syncWarning: syncWarning);
    } catch (_) {
      if (currentUser?.uid != owner) throw StateError('Your account changed.');
      return AddressSuggestion(
          id: 'device-gps',
          name: 'Current GPS location',
          address:
              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
          latitude: point.latitude,
          longitude: point.longitude,
          syncWarning: syncWarning);
    }
  }

  Future<AddressSuggestion> reverseAddress(LatLng point) =>
      _liveApi.reverseAddress(point);
  Future<Map<String, dynamic>> route(LatLng pickup, LatLng destination) =>
      _liveApi.route(pickup, destination);

  Future<LatLng?> resolveAddressLocation(String address) async {
    if (address.trim().isEmpty) return null;
    final result = await _liveApi.geocodeAddress(address.trim());
    if (result.latitude == null || result.longitude == null) {
      throw StateError('No coordinates were returned for this address.');
    }
    return LatLng(result.latitude!, result.longitude!);
  }

  // ===========================================================================
  // ORDERS
  // ===========================================================================

  /// Creates a new order.
  Future<String> createOrder(
    ParcelOrder draft,
  ) async {
    final api = _api;
    if (api != null) {
      final order = await api.createOrder(draft);
      _storeOrder(order);
      return order.id;
    }

    final id = _genOrderId();

    final order = ParcelOrder(
      id: id,
      code: _genOrderCode(),
      senderId: draft.senderId,
      senderName: draft.senderName,
      delivererId: draft.delivererId,
      delivererName: draft.delivererName,
      title: draft.title,
      category: draft.category,
      pickupAddress: draft.pickupAddress,
      dropoffAddress: draft.dropoffAddress,
      recipientPhone: draft.recipientPhone,
      pickupLocation: draft.pickupLocation,
      dropoffLocation: draft.dropoffLocation,
      price: draft.price,
      payout: draft.payout,
      isExpress: draft.isExpress,
      isP2P: draft.isP2P,
      matchingMode: draft.matchingMode,
      speedIndex: draft.speedIndex,
      speedLabel: draft.speedLabel,
      targetDelivererId: draft.targetDelivererId,
      targetDelivererName: draft.targetDelivererName,
      status: draft.status,
      createdAt: DateTime.now(),
    );

    _orders[id] = order;

    _ordersController.add(
      Map<String, ParcelOrder>.of(_orders),
    );

    return id;
  }

  /// Watches a single order.
  Future<ParcelOrder> trackingOrder(String orderId) async {
    final owner = currentUser?.uid;
    final order = await _liveApi.trackedOrder(orderId);
    if (owner == null || currentUser?.uid != owner) {
      throw StateError('Your account changed.');
    }
    _storeOrder(order);
    return order;
  }

  Stream<ParcelOrder?> watchOrder(String orderId) {
    final owner = currentUser?.uid;
    late StreamController<ParcelOrder?> controller;
    Timer? timer;
    bool fetching = false;
    Future<void> refresh() async {
      if (fetching || controller.isClosed) return;
      fetching = true;
      try {
        if (owner == null || currentUser?.uid != owner) {
          throw StateError('Sign in again to track this delivery.');
        }
        final order = await _liveApi.trackedOrder(orderId);
        if (!controller.isClosed && currentUser?.uid == owner) {
          controller.add(order);
        }
      } catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      } finally {
        fetching = false;
      }
    }

    controller = StreamController<ParcelOrder?>(onListen: () {
      refresh();
      timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    }, onCancel: () {
      timer?.cancel();
    });
    return controller.stream;
  }

  /// Gets an order immediately.
  ParcelOrder? getOrder(
    String orderId,
  ) {
    return _orders[orderId];
  }

  /// Sorts orders from newest to oldest.
  List<ParcelOrder> _sortedDesc(
    Iterable<ParcelOrder> orders,
  ) {
    final list = orders.toList();

    list.sort(
      (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    return list;
  }

  /// Watches all orders created by a sender.
  Stream<List<ParcelOrder>> watchSenderOrders(
    String senderId,
  ) {
    _api?.orders().then(_storeOrders).ignore();

    List<ParcelOrder> select(
      Map<String, ParcelOrder> orders,
    ) {
      return _sortedDesc(
        orders.values.where(
          (order) => order.senderId == senderId,
        ),
      );
    }

    return _withLocalTracking(
      () => select(_orders),
      _ordersController.stream.map(select),
    );
  }

  /// Watches the sender's currently active order.
  Stream<ParcelOrder?> watchActiveSenderOrder(
    String senderId,
  ) {
    _api?.orders().then(_storeOrders).ignore();

    ParcelOrder? select(
      Map<String, ParcelOrder> orders,
    ) {
      final activeOrders = _sortedDesc(
        orders.values.where(
          (order) =>
              order.senderId == senderId &&
              [
                OrderStatus.accepted,
                OrderStatus.pickedUp,
                OrderStatus.delivered,
              ].contains(order.status),
        ),
      );

      if (activeOrders.isEmpty) {
        return null;
      }

      return activeOrders.first;
    }

    return _withLocalTracking(
      () => select(_orders),
      _ordersController.stream.map(select),
    );
  }

  /// Watches all jobs currently available to deliverers.
  Stream<List<ParcelOrder>> watchOpenJobs() {
    _api?.orders().then(_storeOrders).ignore();

    List<ParcelOrder> select(
      Map<String, ParcelOrder> orders,
    ) {
      return _sortedDesc(
        orders.values.where(
          (order) => order.status == OrderStatus.pendingOffer,
        ),
      );
    }

    return _withLocalTracking(
      () => select(_orders),
      _ordersController.stream.map(select),
    );
  }

  /// Watches all orders assigned to a deliverer.
  Stream<List<ParcelOrder>> watchDelivererOrders(
    String delivererId,
  ) {
    _api?.orders().then(_storeOrders).ignore();

    List<ParcelOrder> select(
      Map<String, ParcelOrder> orders,
    ) {
      return _sortedDesc(
        orders.values.where(
          (order) => order.delivererId == delivererId,
        ),
      );
    }

    return _withLocalTracking(
      () => select(_orders),
      _ordersController.stream.map(select),
    );
  }

  /// Internal order updater.
  void _updateOrder(
    String orderId,
    ParcelOrder Function(ParcelOrder) update,
  ) {
    final currentOrder = _orders[orderId];

    if (currentOrder == null) {
      return;
    }

    final updatedOrder = update(currentOrder);

    _orders[orderId] = updatedOrder;

    _ordersController.add(
      Map<String, ParcelOrder>.of(_orders),
    );
  }

  /// Accepts an available delivery job.
  Future<void> acceptJob(
    String orderId, {
    required String delivererId,
    required String delivererName,
  }) async {
    final api = _api;
    if (api != null) {
      _storeOrder(
        await api.acceptJob(
          orderId: orderId,
          delivererId: delivererId,
          delivererName: delivererName,
        ),
      );
      return;
    }

    _updateOrder(
      orderId,
      (order) => order.copyWith(
        delivererId: delivererId,
        delivererName: delivererName,
        status: OrderStatus.accepted,
        dStage: 0,
        courierLocation: order.courierLocation,
        courierLocationIsSimulated: false,
      ),
    );
  }

  /// Moves the deliverer through the delivery stages.
  ///
  /// 0 = accepted
  /// 1 = picked up
  /// 2 = delivered
  Future<void> advanceDelivererStage(
    String orderId,
    int newStage,
  ) async {
    final api = _api;
    if (api != null) {
      _storeOrder(await api.advanceDelivererStage(orderId, newStage));
      return;
    }

    const statusForStage = [
      OrderStatus.accepted,
      OrderStatus.pickedUp,
      OrderStatus.delivered,
    ];

    if (newStage < 0 || newStage >= statusForStage.length) {
      throw ArgumentError(
        'Invalid delivery stage: $newStage',
      );
    }

    _updateOrder(
      orderId,
      (order) => order.copyWith(
        dStage: newStage,
        status: statusForStage[newStage],
        courierLocationIsSimulated: order.courierLocationIsSimulated,
        deliveredAt: newStage == 2 ? DateTime.now() : order.deliveredAt,
      ),
    );
  }

  /// Updates the courier's current location.
  Future<void> updateCourierLocation(
    String orderId,
    double lat,
    double lng, {
    required double accuracy,
    required DateTime capturedAt,
  }) async {
    final api = _api;
    if (api != null) {
      _storeOrder(await api.updateCourierLocation(orderId, lat, lng,
          accuracy: accuracy, capturedAt: capturedAt));
      return;
    }

    _updateOrder(
      orderId,
      (order) {
        final trail = [
          ...order.courierLocationTrail,
          LatLng(lat, lng),
        ];
        return order.copyWith(
          courierLocation: LatLng(lat, lng),
          courierLocationUpdatedAt: DateTime.now(),
          courierLocationTrail:
              trail.length > 120 ? trail.sublist(trail.length - 120) : trail,
          courierLocationIsSimulated: false,
        );
      },
    );
  }

  /// Updates the signed-in user's latest device location.
  Future<void> updateCurrentUserLocation(
    double lat,
    double lng,
  ) async {
    final api = _api;
    final owner = currentUser?.uid;
    if (api != null && api.isAuthenticated) {
      final user = await api.updateCurrentLocation(lat, lng);
      if (owner == null || currentUser?.uid != owner || user.uid != owner) {
        throw StateError('Your account changed.');
      }
      _storeUser(user, makeCurrent: true);
    }
  }

  /// Negotiates a new order price.
  Future<void> negotiatePrice(
    String orderId,
    double newPrice,
  ) async {
    final api = _api;
    if (api != null) {
      _storeOrder(await api.negotiatePrice(orderId, newPrice));
      return;
    }

    if (newPrice < 0) {
      throw ArgumentError(
        'Price cannot be negative.',
      );
    }

    _updateOrder(
      orderId,
      (order) => order.copyWith(
        price: newPrice,
        status: OrderStatus.negotiating,
      ),
    );
  }

  /// Confirms the agreed order price.
  Future<void> confirmOrderPrice(
    String orderId,
    double agreedPrice,
  ) async {
    final api = _api;
    if (api != null) {
      _storeOrder(await api.confirmOrderPrice(orderId, agreedPrice));
      return;
    }

    if (agreedPrice < 0) {
      throw ArgumentError(
        'Price cannot be negative.',
      );
    }

    _updateOrder(
      orderId,
      (order) => order.copyWith(
        price: agreedPrice,
        status: OrderStatus.pendingOffer,
      ),
    );
  }

  /// Releases the escrow/payment for an order.
  Future<void> releaseEscrow(
    String orderId,
  ) async {
    final api = _api;
    if (api != null) {
      _storeOrder(await api.releaseEscrow(orderId));
      return;
    }

    _updateOrder(
      orderId,
      (order) => order.copyWith(
        status: OrderStatus.released,
        releasedAt: DateTime.now(),
      ),
    );
  }

  /// Cancels an order.
  Future<void> cancelOrder(
    String orderId,
  ) async {
    final api = _api;
    if (api != null) {
      _storeOrder(await api.cancelOrder(orderId));
      return;
    }

    _updateOrder(
      orderId,
      (order) => order.copyWith(
        status: OrderStatus.cancelled,
      ),
    );
  }

  // ===========================================================================
  // DELIVERER DISCOVERY
  // ===========================================================================

  /// Watches all online deliverers.
  Stream<List<AppUser>> watchAvailableDeliverers() {
    _api?.availableDeliverers().then(_storeUsers).ignore();

    List<AppUser> select(
      Map<String, AppUser> users,
    ) {
      return users.values
          .where(
            (user) =>
                user.activeRole == UserRole.deliverer && user.delivererOnline,
          )
          .toList();
    }

    return _withInitial(
      () => select(_users),
      _usersController.stream.map(select),
    );
  }

  // ===========================================================================
  // CHAT
  // ===========================================================================

  /// Watches messages for an order.
  Stream<List<ChatMessage>> watchMessages(
    String orderId,
  ) {
    final api = _api;

    List<ChatMessage> select(
      Map<String, List<ChatMessage>> messages,
    ) {
      return List<ChatMessage>.of(
        messages[orderId] ?? const <ChatMessage>[],
      );
    }

    if (api != null) {
      late StreamController<List<ChatMessage>> controller;
      Timer? timer;
      StreamSubscription<Map<String, List<ChatMessage>>>? subscription;

      Future<void> refresh() async {
        try {
          _messages[orderId] = await api.messages(orderId);
          _messagesController.add(
            Map<String, List<ChatMessage>>.of(_messages),
          );
        } catch (error) {
          if (!controller.isClosed && select(_messages).isEmpty) {
            controller.addError(error);
            return;
          }
          // Keep the last known messages visible while the next poll retries.
        }

        if (!controller.isClosed) {
          controller.add(select(_messages));
        }
      }

      controller = StreamController<List<ChatMessage>>(
        onListen: () {
          controller.add(select(_messages));
          subscription = _messagesController.stream.listen(
            (messages) => controller.add(select(messages)),
          );
          refresh();
          timer = Timer.periodic(
            const Duration(seconds: 2),
            (_) => refresh(),
          );
        },
        onCancel: () async {
          timer?.cancel();
          await subscription?.cancel();
        },
      );

      return controller.stream;
    }

    return _withInitial(
      () => select(_messages),
      _messagesController.stream.map(select),
    );
  }

  /// Sends a chat message.
  Future<void> sendMessage(
    String orderId,
    String senderId,
    String text,
  ) async {
    final messageText = text.trim();

    if (messageText.isEmpty) {
      return;
    }

    final api = _api;
    if (api != null) {
      final message = await api.sendMessage(orderId, senderId, messageText);
      final list = _messages.putIfAbsent(
        orderId,
        () => <ChatMessage>[],
      );
      list.add(message);
      _messagesController.add(
        Map<String, List<ChatMessage>>.of(_messages),
      );
      return;
    }

    final list = _messages.putIfAbsent(
      orderId,
      () => <ChatMessage>[],
    );

    list.add(
      ChatMessage(
        id: _genMessageId(),
        senderId: senderId,
        text: messageText,
        createdAt: DateTime.now(),
      ),
    );

    _messagesController.add(
      Map<String, List<ChatMessage>>.of(_messages),
    );
  }

  Future<AppUser> orderContact(String orderId) async {
    final api = _api;
    if (api != null) {
      return api.orderContact(orderId);
    }

    final order = _orders[orderId];
    final uid = currentUser?.uid;
    if (order == null || uid == null) {
      throw StateError('Open a valid order before calling.');
    }

    final otherUserId =
        uid == order.senderId ? order.delivererId : order.senderId;
    final contact = otherUserId == null ? null : _users[otherUserId];
    if (contact == null) {
      throw StateError('The other participant is not available yet.');
    }
    return contact;
  }

  // ===========================================================================
  // WALLET
  // ===========================================================================

  /// Watches wallet transactions for a user.
  Stream<List<WalletTransaction>> watchWalletTransactions(
    String uid,
  ) {
    if (currentUser?.uid == uid) {
      _api?.walletTransactions().then((transactions) {
        _walletTx[uid] = transactions;
        _walletController.add(
          Map<String, List<WalletTransaction>>.of(_walletTx),
        );
      }).ignore();
    }

    List<WalletTransaction> select(
      Map<String, List<WalletTransaction>> transactions,
    ) {
      final list = List<WalletTransaction>.of(
        transactions[uid] ?? const <WalletTransaction>[],
      );

      list.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      return list;
    }

    return _withInitial(
      () => select(_walletTx),
      _walletController.stream.map(select),
    );
  }

  /// Adds a wallet transaction and updates the user's balance.
  Future<void> addWalletTransaction(
    String uid,
    WalletTransaction tx, {
    required double balanceDelta,
  }) async {
    final api = _api;
    if (api != null && api.isAuthenticated && currentUser?.uid == uid) {
      final user = await api.addWalletTransaction(
        tx: tx,
        balanceDelta: balanceDelta,
      );
      _storeUser(user, makeCurrent: true);
      _walletTx[uid] = await api.walletTransactions();
      _walletController.add(
        Map<String, List<WalletTransaction>>.of(_walletTx),
      );
      return;
    }

    final list = _walletTx.putIfAbsent(
      uid,
      () => <WalletTransaction>[],
    );

    list.add(
      WalletTransaction(
        id: _genTransactionId(),
        type: tx.type,
        title: tx.title,
        sub: tx.sub,
        amount: tx.amount,
        createdAt: DateTime.now(),
      ),
    );

    _walletController.add(
      Map<String, List<WalletTransaction>>.of(_walletTx),
    );

    final user = _users[uid];

    if (user == null) {
      return;
    }

    final updatedUser = user.copyWith(
      walletBalance: user.walletBalance + balanceDelta,
    );

    _users[uid] = updatedUser;

    _usersController.add(
      Map<String, AppUser>.of(_users),
    );

    if (currentUser?.uid == uid) {
      currentUser = updatedUser;
      _authController.add(updatedUser);
    }
  }

  // ===========================================================================
  // NOTIFICATIONS
  // ===========================================================================

  /// Watches notifications for a user.
  Stream<List<NotificationItem>> watchNotifications(
    String uid,
  ) {
    if (currentUser?.uid == uid) {
      _api?.notifications().then((notifications) {
        _notifs[uid] = notifications;
        _notifsController.add(
          Map<String, List<NotificationItem>>.of(_notifs),
        );
      }).ignore();
    }

    List<NotificationItem> select(
      Map<String, List<NotificationItem>> notifications,
    ) {
      final list = List<NotificationItem>.of(
        notifications[uid] ?? const <NotificationItem>[],
      );

      list.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      return list;
    }

    return _withInitial(
      () => select(_notifs),
      _notifsController.stream.map(select),
    );
  }

  /// Adds a notification.
  Future<void> addNotification(
    String uid,
    NotificationItem notification,
  ) async {
    final api = _api;
    if (api != null && currentUser?.uid == uid) {
      await api.addNotification(notification);
      _notifs[uid] = await api.notifications();
      _notifsController.add(
        Map<String, List<NotificationItem>>.of(_notifs),
      );
      return;
    }

    final list = _notifs.putIfAbsent(
      uid,
      () => <NotificationItem>[],
    );

    list.add(
      NotificationItem(
        id: _genNotificationId(),
        title: notification.title,
        body: notification.body,
        type: notification.type,
        read: notification.read,
        createdAt: DateTime.now(),
      ),
    );

    _notifsController.add(
      Map<String, List<NotificationItem>>.of(_notifs),
    );
  }

  /// Marks a notification as read.
  Future<void> markNotificationRead(
    String uid,
    String notifId,
  ) async {
    final api = _api;
    if (api != null && currentUser?.uid == uid) {
      await api.markNotificationRead(notifId);
      _notifs[uid] = await api.notifications();
      _notifsController.add(
        Map<String, List<NotificationItem>>.of(_notifs),
      );
      return;
    }

    final list = _notifs[uid];

    if (list == null) {
      return;
    }

    final index = list.indexWhere(
      (notification) => notification.id == notifId,
    );

    if (index == -1) {
      return;
    }

    list[index] = list[index].copyWith(
      read: true,
    );

    _notifsController.add(
      Map<String, List<NotificationItem>>.of(_notifs),
    );
  }

  // ===========================================================================
  // PROFILE SETTINGS
  // ===========================================================================

  Stream<List<SavedAddress>> watchSavedAddresses(String uid) {
    if (currentUser?.uid == uid) {
      _api?.savedAddresses().then((addresses) {
        _savedAddresses[uid] = addresses;
        _addressesController.add(
          Map<String, List<SavedAddress>>.of(_savedAddresses),
        );
      }).ignore();
    }

    List<SavedAddress> select(Map<String, List<SavedAddress>> addresses) {
      final list = List<SavedAddress>.of(
        addresses[uid] ?? const <SavedAddress>[],
      );
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    return _withInitial(
      () => select(_savedAddresses),
      _addressesController.stream.map(select),
    );
  }

  Future<void> saveAddress(
    String uid, {
    String? id,
    required String label,
    required String address,
  }) async {
    final trimmedLabel = label.trim();
    final trimmedAddress = address.trim();
    if (trimmedLabel.isEmpty || trimmedAddress.isEmpty) {
      throw StateError('Label and address are required.');
    }

    final api = _api;
    if (api != null && api.isAuthenticated && currentUser?.uid == uid) {
      await api.saveAddress(
        id: id,
        label: trimmedLabel,
        address: trimmedAddress,
      );
      _savedAddresses[uid] = await api.savedAddresses();
      _addressesController.add(
        Map<String, List<SavedAddress>>.of(_savedAddresses),
      );
      return;
    }

    final list = _savedAddresses.putIfAbsent(uid, () => <SavedAddress>[]);
    final item = SavedAddress(
      id: id ?? _genAddressId(),
      label: trimmedLabel,
      address: trimmedAddress,
      createdAt: DateTime.now(),
    );
    final index = list.indexWhere((address) => address.id == item.id);
    if (index == -1) {
      list.add(item);
    } else {
      list[index] = item;
    }
    _addressesController.add(
      Map<String, List<SavedAddress>>.of(_savedAddresses),
    );
  }

  Future<void> deleteAddress(String uid, String addressId) async {
    final api = _api;
    if (api != null && api.isAuthenticated && currentUser?.uid == uid) {
      await api.deleteAddress(addressId);
      _savedAddresses[uid] = await api.savedAddresses();
      _addressesController.add(
        Map<String, List<SavedAddress>>.of(_savedAddresses),
      );
      return;
    }

    final list = _savedAddresses[uid];
    if (list == null) return;
    list.removeWhere((address) => address.id == addressId);
    _addressesController.add(
      Map<String, List<SavedAddress>>.of(_savedAddresses),
    );
  }

  Stream<SecuritySettings> watchSecuritySettings(String uid) {
    if (currentUser?.uid == uid) {
      _api?.securitySettings().then((settings) {
        _securitySettings[uid] = settings;
        _securityController.add(
          Map<String, SecuritySettings>.of(_securitySettings),
        );
      }).ignore();
    }

    SecuritySettings select(Map<String, SecuritySettings> settings) {
      return settings[uid] ?? SecuritySettings();
    }

    return _withInitial(
      () => select(_securitySettings),
      _securityController.stream.map(select),
    );
  }

  Future<void> updateSecuritySettings(
    String uid, {
    required bool biometricsEnabled,
    required bool pinEnabled,
    String? pin,
  }) async {
    final current = _securitySettings[uid] ?? SecuritySettings();
    if (pinEnabled &&
        !current.pinEnabled &&
        (pin == null || pin.trim().isEmpty)) {
      throw StateError('Enter a PIN to enable PIN security.');
    }
    if (pinEnabled &&
        pin != null &&
        pin.trim().isNotEmpty &&
        pin.trim().length < 4) {
      throw StateError('PIN must be at least 4 digits.');
    }

    final api = _api;
    if (api != null && api.isAuthenticated && currentUser?.uid == uid) {
      _securitySettings[uid] = await api.updateSecuritySettings(
        biometricsEnabled: biometricsEnabled,
        pinEnabled: pinEnabled,
        pin: pin,
      );
      _securityController.add(
        Map<String, SecuritySettings>.of(_securitySettings),
      );
      return;
    }

    _securitySettings[uid] = SecuritySettings(
      biometricsEnabled: biometricsEnabled,
      pinEnabled: pinEnabled,
    );
    _securityController.add(
      Map<String, SecuritySettings>.of(_securitySettings),
    );
  }

  Stream<List<SupportTicket>> watchSupportTickets(String uid) {
    if (currentUser?.uid == uid) {
      _api?.supportTickets().then((tickets) {
        _supportTickets[uid] = tickets;
        _supportController.add(
          Map<String, List<SupportTicket>>.of(_supportTickets),
        );
      }).ignore();
    }

    List<SupportTicket> select(Map<String, List<SupportTicket>> tickets) {
      final list = List<SupportTicket>.of(
        tickets[uid] ?? const <SupportTicket>[],
      );
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    return _withInitial(
      () => select(_supportTickets),
      _supportController.stream.map(select),
    );
  }

  Future<void> createSupportTicket(
    String uid, {
    required String subject,
    required String message,
  }) async {
    final trimmedSubject = subject.trim();
    final trimmedMessage = message.trim();
    if (trimmedSubject.isEmpty || trimmedMessage.isEmpty) {
      throw StateError('Subject and message are required.');
    }

    final api = _api;
    if (api != null && api.isAuthenticated && currentUser?.uid == uid) {
      await api.createSupportTicket(
        subject: trimmedSubject,
        message: trimmedMessage,
      );
      _supportTickets[uid] = await api.supportTickets();
      _supportController.add(
        Map<String, List<SupportTicket>>.of(_supportTickets),
      );
      return;
    }

    final list = _supportTickets.putIfAbsent(uid, () => <SupportTicket>[]);
    list.add(
      SupportTicket(
        id: _genTicketId(),
        subject: trimmedSubject,
        message: trimmedMessage,
        createdAt: DateTime.now(),
      ),
    );
    _supportController.add(
      Map<String, List<SupportTicket>>.of(_supportTickets),
    );
  }

  // ===========================================================================
  // CLEANUP
  // ===========================================================================

  /// Closes all streams when the service is no longer needed.
  void dispose() {
    _usersController.close();
    _ordersController.close();
    _messagesController.close();
    _walletController.close();
    _notifsController.close();
    _addressesController.close();
    _securityController.close();
    _supportController.close();
    _authController.close();
  }
}
