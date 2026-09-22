class CustomerModel {
  final String id;
  final String customerId;
  final String name;
  final String address;
  final String mobile;
  final DateTime? createdAt;

  CustomerModel({
    required this.id,
    required this.customerId,
    required this.name,
    this.address = '',
    this.mobile = '',
    this.createdAt,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    DateTime? created;
    if (map['created_at'] != null) {
      created = DateTime.tryParse(map['created_at'].toString());
    }

    return CustomerModel(
      id: map['id']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? map['customerId']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      mobile: map['mobile']?.toString() ?? '',
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'name': name,
      'address': address,
      'mobile': mobile,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  CustomerModel copyWith({
    String? id,
    String? customerId,
    String? name,
    String? address,
    String? mobile,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      name: name ?? this.name,
      address: address ?? this.address,
      mobile: mobile ?? this.mobile,
      createdAt: createdAt,
    );
  }
}
