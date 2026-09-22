class PriceListModel {
  final String id;
  final String name;
  final String sheetUrl;
  final bool isActive;
  final int sortOrder;
  final int productCount;
  final DateTime? createdAt;

  PriceListModel({
    required this.id,
    required this.name,
    this.sheetUrl = '',
    this.isActive = true,
    this.sortOrder = 0,
    this.productCount = 0,
    this.createdAt,
  });

  factory PriceListModel.fromMap(Map<String, dynamic> map, {int count = 0}) {
    DateTime? created;
    if (map['created_at'] != null) {
      created = DateTime.tryParse(map['created_at'].toString());
    }

    return PriceListModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      sheetUrl: map['sheet_url']?.toString() ?? map['sheetUrl']?.toString() ?? '',
      isActive: map['is_active'] == true || map['isActive'] == true,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? (map['sortOrder'] as num?)?.toInt() ?? 0,
      productCount: count,
      createdAt: created,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sheet_url': sheetUrl,
      'is_active': isActive,
      'sort_order': sortOrder,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  PriceListModel copyWith({
    String? id,
    String? name,
    String? sheetUrl,
    bool? isActive,
    int? sortOrder,
    int? productCount,
  }) {
    return PriceListModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sheetUrl: sheetUrl ?? this.sheetUrl,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      productCount: productCount ?? this.productCount,
      createdAt: createdAt,
    );
  }
}
