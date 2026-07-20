class StoreModel {
  final int id;
  final String storeName;
  final String? storeCode;
  final String? location;

  StoreModel({
    required this.id,
    required this.storeName,
    this.storeCode,
    this.location,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: json['id'] as int,
      storeName: json['store_name'] as String,
      storeCode: json['store_code'] as String?,
      location: json['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'store_name': storeName,
      'store_code': storeCode,
      'location': location,
    };
  }
}
