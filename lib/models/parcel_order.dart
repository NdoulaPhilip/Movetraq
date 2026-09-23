enum OrderStatus {
  pendingOffer, // sender created, waiting for deliverer match / negotiation
  negotiating,
  accepted, // deliverer accepted, heading to pickup
  pickedUp, // in transit
  delivered, // deliverer marked delivered, awaiting escrow release
  released, // sender released escrow, complete
  cancelled,
}

OrderStatus orderStatusFromJson(String? value) {
  return OrderStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => OrderStatus.pendingOffer,
  );
}

/// A simple lat/lng pair used for pickup/dropoff/courier locations.
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);

  factory LatLng.fromJson(Map<String, dynamic> json) {
    return LatLng(
      (json['latitude'] as num?)?.toDouble() ?? 0,
      (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class ParcelOrder {
  final String id;
  final String code; // e.g. MT-4821
  final String senderId;
  final String senderName;
  String? delivererId;
  String? delivererName;
  final String title; // parcel description e.g. "Wireless Headphones"
  final String category; // parcel type key
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng? pickupLocation;
  final LatLng? dropoffLocation;
  LatLng? courierLocation; // live location, updated by deliverer
  final double price;
  final double payout; // what the deliverer earns
  final bool isExpress;
  final bool isP2P; // peer negotiated vs instant match
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final DateTime? releasedAt;
  final int dStage; // 0 heading to pickup, 1 delivering, 2 delivered (deliverer view)

  ParcelOrder({
    required this.id,
    required this.code,
    required this.senderId,
    required this.senderName,
    this.delivererId,
    this.delivererName,
    required this.title,
    required this.category,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.pickupLocation,
    this.dropoffLocation,
    this.courierLocation,
    required this.price,
    required this.payout,
    this.isExpress = false,
    this.isP2P = false,
    this.status = OrderStatus.pendingOffer,
    required this.createdAt,
    this.deliveredAt,
    this.releasedAt,
    this.dStage = 0,
  });

  factory ParcelOrder.fromJson(Map<String, dynamic> json) {
    LatLng? readLatLng(String key) {
      final value = json[key];
      if (value is Map<String, dynamic>) {
        return LatLng.fromJson(value);
      }
      return null;
    }

    return ParcelOrder(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String? ?? '',
      delivererId: json['delivererId'] as String?,
      delivererName: json['delivererName'] as String?,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'parcel',
      pickupAddress: json['pickupAddress'] as String? ?? '',
      dropoffAddress: json['dropoffAddress'] as String? ?? '',
      pickupLocation: readLatLng('pickupLocation'),
      dropoffLocation: readLatLng('dropoffLocation'),
      courierLocation: readLatLng('courierLocation'),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      payout: (json['payout'] as num?)?.toDouble() ?? 0,
      isExpress: json['isExpress'] as bool? ?? false,
      isP2P: json['isP2P'] as bool? ?? false,
      status: orderStatusFromJson(json['status'] as String?),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      deliveredAt: json['deliveredAt'] == null
          ? null
          : DateTime.tryParse(json['deliveredAt'] as String),
      releasedAt: json['releasedAt'] == null
          ? null
          : DateTime.tryParse(json['releasedAt'] as String),
      dStage: (json['dStage'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'senderId': senderId,
      'senderName': senderName,
      'delivererId': delivererId,
      'delivererName': delivererName,
      'title': title,
      'category': category,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'pickupLocation': pickupLocation?.toJson(),
      'dropoffLocation': dropoffLocation?.toJson(),
      'courierLocation': courierLocation?.toJson(),
      'price': price,
      'payout': payout,
      'isExpress': isExpress,
      'isP2P': isP2P,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'releasedAt': releasedAt?.toIso8601String(),
      'dStage': dStage,
    };
  }

  ParcelOrder copyWith({
    String? delivererId,
    String? delivererName,
    LatLng? courierLocation,
    double? price,
    OrderStatus? status,
    DateTime? deliveredAt,
    DateTime? releasedAt,
    int? dStage,
  }) {
    return ParcelOrder(
      id: id,
      code: code,
      senderId: senderId,
      senderName: senderName,
      delivererId: delivererId ?? this.delivererId,
      delivererName: delivererName ?? this.delivererName,
      title: title,
      category: category,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      courierLocation: courierLocation ?? this.courierLocation,
      price: price ?? this.price,
      payout: payout,
      isExpress: isExpress,
      isP2P: isP2P,
      status: status ?? this.status,
      createdAt: createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      releasedAt: releasedAt ?? this.releasedAt,
      dStage: dStage ?? this.dStage,
    );
  }
}
