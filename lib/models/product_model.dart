import '../core/utils.dart';

class ProductModel {
  final String id;
  final String name;
  final String unit;
  final double standardRate;
  final String? priceListId;
  final String? priceListName;
  final DateTime? createdAt;

  ProductModel({
    required this.id,
    required this.name,
    this.unit = 'Pcs',
    this.standardRate = 0.0,
    this.priceListId,
    this.priceListName,
    this.createdAt,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map, {String? priceListName}) {
    DateTime? created;
    if (map['created_at'] != null) {
      created = DateTime.tryParse(map['created_at'].toString());
    }

    return ProductModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      unit: map['unit']?.toString() ?? 'Pcs',
      standardRate: AppUtils.parseDouble(map['standard_rate'] ?? map['standardRate']),
      priceListId: map['price_list_id']?.toString() ?? map['priceListId']?.toString(),
      priceListName: priceListName ?? map['price_list_name']?.toString(),
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'standard_rate': standardRate,
      'price_list_id': priceListId,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? unit,
    double? standardRate,
    String? priceListId,
    String? priceListName,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      unit: unit ?? this.unit,
      standardRate: standardRate ?? this.standardRate,
      priceListId: priceListId ?? this.priceListId,
      priceListName: priceListName ?? this.priceListName,
      createdAt: createdAt,
    );
  }
}
