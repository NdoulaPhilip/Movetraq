class ProductionSession {
  const ProductionSession(
      {required this.accessToken,
      required this.refreshToken,
      required this.expiresAt});
  final String accessToken;
  final String refreshToken;
  final int expiresAt;
  factory ProductionSession.fromJson(Map<String, dynamic> json) {
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final expiry = json['expiresAt'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        expiry is! int ||
        expiry <= 0) {
      throw const FormatException('Invalid session credentials.');
    }
    return ProductionSession(
        accessToken: access, refreshToken: refresh, expiresAt: expiry);
  }
  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt
      };
}

class ProductionAccount {
  ProductionAccount.fromJson(Map<String, dynamic> json)
      : id = json['uid'] as String,
        name = json['name'] as String,
        email = json['email'] as String,
        activeRole = json['activeRole'] as String? ?? 'sender',
        verificationStatus =
            json['verificationStatus'] as String? ?? 'not_started',
        delivererVerificationStatus =
            json['delivererVerificationStatus'] as String? ?? 'not_started',
        roles =
            List<String>.unmodifiable((json['roles'] as List).cast<String>()),
        balanceMinor = (json['wallet'] as Map)['balanceMinor'] as int,
        currency = (json['wallet'] as Map)['currency'] as String;
  final String id;
  final String name;
  final String email;
  final String activeRole;
  final String verificationStatus;
  final String delivererVerificationStatus;
  final List<String> roles;
  bool get canSend => roles.contains('sender');
  bool get canDeliver => roles.contains('deliverer');
  final int balanceMinor;
  final String currency;
}
