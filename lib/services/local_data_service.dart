import 'dart:async';
import 'dart:math';

import '../models/app_user.dart';
import '../models/misc_models.dart';
import '../models/parcel_order.dart';
import 'node_api_client.dart';

/// Everything the app needs to run locally — auth, orders, chat, wallet,
/// notifications, and deliverer discovery.
///
/// This is a frontend-only implementation.
/// All data is stored in memory and will be reset when the app restarts.
///
/// Later, this class can be replaced with a real backend implementation
/// without requiring major changes to the UI, provided the same public
/// methods and streams are maintained.
class LocalDataService {
  LocalDataService({
    NodeApiClient? api,
    bool useRemote = true,
  }) : _api = useRemote ? api ?? NodeApiClient() : null;

  final NodeApiClient? _api;

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
      final uid =
          'user_${DateTime.now().microsecondsSinceEpoch}';

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
      throw StateError('No MoveTraq account was found for that email or phone.');
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
      pickupLocation: draft.pickupLocation,
      dropoffLocation: draft.dropoffLocation,
      price: draft.price,
      payout: draft.payout,
      isExpress: draft.isExpress,
      isP2P: draft.isP2P,
      status: draft.delivererId == null
          ? draft.status
          : OrderStatus.accepted,
      createdAt: DateTime.now(),
    );

    _orders[id] = order;

    _ordersController.add(
      Map<String, ParcelOrder>.of(_orders),
    );

    return id;
  }

  /// Watches a single order.
  Stream<ParcelOrder?> watchOrder(
    String orderId,
  ) {
    final api = _api;

    if (api != null) {
      late StreamController<ParcelOrder?> controller;
      Timer? timer;
      StreamSubscription<Map<String, ParcelOrder>>? subscription;

      Future<void> refresh() async {
        try {
          _storeOrders(await api.orders());
          if (!controller.isClosed) {
            controller.add(_orders[orderId]);
          }
        } catch (_) {
          if (!controller.isClosed) {
            controller.add(_orders[orderId]);
          }
        }
      }

      controller = StreamController<ParcelOrder?>(
        onListen: () {
          controller.add(_orders[orderId]);
          subscription = _ordersController.stream.listen(
            (orders) => controller.add(orders[orderId]),
          );
          refresh();
          timer = Timer.periodic(
            const Duration(seconds: 3),
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
      () => _orders[orderId],
      _ordersController.stream.map(
        (orders) => orders[orderId],
      ),
    );
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

    return _withInitial(
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

    return _withInitial(
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
          (order) =>
              order.status == OrderStatus.pendingOffer,
        ),
      );
    }

    return _withInitial(
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
          (order) =>
              order.delivererId == delivererId,
        ),
      );
    }

    return _withInitial(
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

    if (newStage < 0 ||
        newStage >= statusForStage.length) {
      throw ArgumentError(
        'Invalid delivery stage: $newStage',
      );
    }

    _updateOrder(
      orderId,
      (order) => order.copyWith(
        dStage: newStage,
        status: statusForStage[newStage],
        deliveredAt: newStage == 2
            ? DateTime.now()
            : order.deliveredAt,
      ),
    );
  }

  /// Updates the courier's current location.
  Future<void> updateCourierLocation(
    String orderId,
    double lat,
    double lng,
  ) async {
    final api = _api;
    if (api != null) {
      _storeOrder(await api.updateCourierLocation(orderId, lat, lng));
      return;
    }

    _updateOrder(
      orderId,
      (order) => order.copyWith(
        courierLocation: LatLng(lat, lng),
      ),
    );
  }

  /// Updates the signed-in user's latest device location.
  Future<void> updateCurrentUserLocation(
    double lat,
    double lng,
  ) async {
    final api = _api;
    if (api != null && api.isAuthenticated) {
      _storeUser(await api.updateCurrentLocation(lat, lng), makeCurrent: true);
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
                user.activeRole == UserRole.deliverer &&
                user.delivererOnline,
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
        } catch (_) {
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
      walletBalance:
          user.walletBalance + balanceDelta,
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
        notifications[uid] ??
            const <NotificationItem>[],
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
  // CLEANUP
  // ===========================================================================

  /// Closes all streams when the service is no longer needed.
  void dispose() {
    _usersController.close();
    _ordersController.close();
    _messagesController.close();
    _walletController.close();
    _notifsController.close();
    _authController.close();
  }
}
