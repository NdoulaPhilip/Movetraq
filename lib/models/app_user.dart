enum UserRole { sender, deliverer }

UserRole userRoleFromJson(String? value) {
  return value == 'deliverer' ? UserRole.deliverer : UserRole.sender;
}

String userRoleToJson(UserRole role) {
  return role == UserRole.deliverer ? 'deliverer' : 'sender';
}

/// A user profile. In this frontend-only build, all instances live in
/// memory (see `LocalDataService`) rather than a remote database.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final UserRole activeRole;
  final double rating;
  final int totalDeliveries;
  final String memberTier; // e.g. "Gold"
  final double walletBalance;
  final bool delivererOnline;
  final DateTime? createdAt;

  // --- Route/trip-specific display fields (used when this user shows up
  // as an available deliverer for a particular send). These are mock
  // values seeded per-route in LocalDataService rather than permanent
  // account attributes, but live here to keep the UI simple. ---
  final bool verified;
  final String vehicleType; // 'bike' or 'car'
  final double distanceKm;
  final int etaMinutes;
  final double rate;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.activeRole = UserRole.sender,
    this.rating = 5.0,
    this.totalDeliveries = 0,
    this.memberTier = 'Bronze',
    this.walletBalance = 0,
    this.delivererOnline = false,
    this.createdAt,
    this.verified = false,
    this.vehicleType = 'bike',
    this.distanceKm = 0,
    this.etaMinutes = 0,
    this.rate = 0,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      activeRole: userRoleFromJson(json['activeRole'] as String?),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalDeliveries: (json['totalDeliveries'] as num?)?.toInt() ?? 0,
      memberTier: json['memberTier'] as String? ?? 'Bronze',
      walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0,
      delivererOnline: json['delivererOnline'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      verified: json['verified'] as bool? ?? false,
      vehicleType: json['vehicleType'] as String? ?? 'bike',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'activeRole': userRoleToJson(activeRole),
      'rating': rating,
      'totalDeliveries': totalDeliveries,
      'memberTier': memberTier,
      'walletBalance': walletBalance,
      'delivererOnline': delivererOnline,
      'createdAt': createdAt?.toIso8601String(),
      'verified': verified,
      'vehicleType': vehicleType,
      'distanceKm': distanceKm,
      'etaMinutes': etaMinutes,
      'rate': rate,
    };
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? activeRole,
    double? rating,
    int? totalDeliveries,
    String? memberTier,
    double? walletBalance,
    bool? delivererOnline,
    bool? verified,
    String? vehicleType,
    double? distanceKm,
    int? etaMinutes,
    double? rate,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      activeRole: activeRole ?? this.activeRole,
      rating: rating ?? this.rating,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      memberTier: memberTier ?? this.memberTier,
      walletBalance: walletBalance ?? this.walletBalance,
      delivererOnline: delivererOnline ?? this.delivererOnline,
      createdAt: createdAt,
      verified: verified ?? this.verified,
      vehicleType: vehicleType ?? this.vehicleType,
      distanceKm: distanceKm ?? this.distanceKm,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      rate: rate ?? this.rate,
    );
  }
}
