class AddressInput {
  const AddressInput(
      {required this.label,
      required this.address,
      required this.latitude,
      required this.longitude,
      this.placeId,
      this.city,
      this.state,
      this.country = 'NG',
      this.isDefault = false});
  final String label;
  final String address;
  final double latitude;
  final double longitude;
  final String? placeId;
  final String? city;
  final String? state;
  final String country;
  final bool isDefault;
  Map<String, dynamic> toJson() => {
        'label': label,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'placeId': placeId,
        'city': city,
        'state': state,
        'country': country,
        'isDefault': isDefault
      };
}

class ProductionAddress {
  ProductionAddress.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        ownerId = json['user_id'] as String,
        label = json['label'] as String,
        address = json['address'] as String,
        latitude = (json['latitude'] as num?)?.toDouble(),
        longitude = (json['longitude'] as num?)?.toDouble(),
        placeId = json['place_id'] as String?,
        city = json['city'] as String?,
        state = json['state'] as String?,
        country = json['country'] as String,
        isDefault = json['is_default'] as bool,
        createdAt = DateTime.parse(json['created_at'] as String),
        updatedAt = DateTime.parse(json['updated_at'] as String);
  final String id;
  final String ownerId;
  final String label;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? placeId;
  final String? city;
  final String? state;
  final String country;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
}
