class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });
}

enum WalletTxType { escrowHold, topup, released, refund, cashback, withdrawal }

class WalletTransaction {
  final String id;
  final WalletTxType type;
  final String title;
  final String sub;
  final double amount; // positive = credit, negative = debit
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.title,
    required this.sub,
    required this.amount,
    required this.createdAt,
  });
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type; // e.g. 'delivery', 'promo', 'wallet'
  final bool read;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.read = false,
    required this.createdAt,
  });

  NotificationItem copyWith({bool? read}) {
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      type: type,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }
}
