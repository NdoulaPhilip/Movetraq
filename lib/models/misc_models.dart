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

class SavedAddress {
  final String id;
  final String label;
  final String address;
  final DateTime createdAt;
  final bool isDefault;

  SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.createdAt,
    this.isDefault = false,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      address: json['address'] as String? ?? '',
      isDefault: json['is_default'] == true || json['isDefault'] == true,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'address': address,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class SecuritySettings {
  final bool biometricsEnabled;
  final bool pinEnabled;

  SecuritySettings({
    this.biometricsEnabled = false,
    this.pinEnabled = false,
  });

  factory SecuritySettings.fromJson(Map<String, dynamic> json) {
    return SecuritySettings(
      biometricsEnabled: json['biometricsEnabled'] as bool? ?? false,
      pinEnabled: json['pinEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'biometricsEnabled': biometricsEnabled,
      'pinEnabled': pinEnabled,
    };
  }

  SecuritySettings copyWith({
    bool? biometricsEnabled,
    bool? pinEnabled,
  }) {
    return SecuritySettings(
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      pinEnabled: pinEnabled ?? this.pinEnabled,
    );
  }
}

class SupportTicket {
  final String id;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;

  SupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    this.status = 'open',
    required this.createdAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'message': message,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
