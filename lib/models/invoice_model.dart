import '../core/utils.dart';
import 'invoice_item_model.dart';

class InvoiceModel {
  final String invoiceNo;
  final String date;
  final String customerId;
  final String customerName;
  final String address;
  final String mobile;
  final double totalAmount;
  final String notes;
  final String priceListName;
  final String createdBy;
  final String deviceId;
  final bool sideDelivery;
  final List<InvoiceItemModel> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  InvoiceModel({
    required this.invoiceNo,
    required this.date,
    this.customerId = '',
    required this.customerName,
    this.address = '',
    this.mobile = '',
    double? totalAmount,
    this.notes = '',
    this.priceListName = '',
    this.createdBy = '',
    this.deviceId = '',
    this.sideDelivery = false,
    this.items = const [],
    this.createdAt,
    this.updatedAt,
  }) : totalAmount = totalAmount ?? items.fold(0.0, (sum, i) => sum + i.total);

  double get subtotalGross => items.fold(0.0, (sum, i) => sum + i.grossAmount);
  double get totalDiscount => items.fold(0.0, (sum, i) => sum + (i.grossAmount - i.netAmount));
  double get subtotalNet => items.fold(0.0, (sum, i) => sum + i.netAmount);
  double get totalDeliveryCharge => items.fold(0.0, (sum, i) => sum + i.totalDeliveryCharge);
  double get calculatedTotal => items.fold(0.0, (sum, i) => sum + i.total);

  factory InvoiceModel.fromMap(Map<String, dynamic> map, {List<InvoiceItemModel>? itemsList}) {
    final rawItems = itemsList ??
        (map['items'] as List?)?.map((x) => InvoiceItemModel.fromMap(Map<String, dynamic>.from(x))).toList() ??
        (map['invoice_items'] as List?)?.map((x) => InvoiceItemModel.fromMap(Map<String, dynamic>.from(x))).toList() ??
        [];

    DateTime? created;
    if (map['created_at'] != null) {
      created = DateTime.tryParse(map['created_at'].toString());
    }
    DateTime? updated;
    if (map['updated_at'] != null) {
      updated = DateTime.tryParse(map['updated_at'].toString());
    }

    return InvoiceModel(
      invoiceNo: map['invoice_no']?.toString() ?? map['invoiceNo']?.toString() ?? '',
      date: map['date']?.toString() ?? '',
      customerId: map['customer_id']?.toString() ?? map['customerId']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? map['customerName']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      mobile: map['mobile']?.toString() ?? '',
      totalAmount: AppUtils.parseDouble(map['total_amount'] ?? map['totalAmount']),
      notes: map['notes']?.toString() ?? '',
      priceListName: map['price_list_name']?.toString() ?? map['priceListName']?.toString() ?? '',
      createdBy: map['created_by']?.toString() ?? map['createdBy']?.toString() ?? '',
      deviceId: map['device_id']?.toString() ?? map['deviceId']?.toString() ?? '',
      sideDelivery: map['side_delivery'] == true || map['sideDelivery'] == true,
      items: rawItems,
      createdAt: created,
      updatedAt: updated,
    );
  }

  Map<String, dynamic> toMap({bool includeItems = false}) {
    final map = <String, dynamic>{
      'invoice_no': invoiceNo,
      'date': date,
      'customer_id': customerId,
      'customer_name': customerName,
      'address': address,
      'mobile': mobile,
      'total_amount': totalAmount,
      'notes': notes,
      'price_list_name': priceListName,
      'created_by': createdBy,
      'device_id': deviceId,
      'side_delivery': sideDelivery,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };

    if (includeItems) {
      map['items'] = items.map((i) => i.toMap()).toList();
    }

    return map;
  }

  InvoiceModel copyWith({
    String? invoiceNo,
    String? date,
    String? customerId,
    String? customerName,
    String? address,
    String? mobile,
    double? totalAmount,
    String? notes,
    String? priceListName,
    String? createdBy,
    String? deviceId,
    bool? sideDelivery,
    List<InvoiceItemModel>? items,
  }) {
    return InvoiceModel(
      invoiceNo: invoiceNo ?? this.invoiceNo,
      date: date ?? this.date,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      address: address ?? this.address,
      mobile: mobile ?? this.mobile,
      totalAmount: totalAmount ?? this.totalAmount,
      notes: notes ?? this.notes,
      priceListName: priceListName ?? this.priceListName,
      createdBy: createdBy ?? this.createdBy,
      deviceId: deviceId ?? this.deviceId,
      sideDelivery: sideDelivery ?? this.sideDelivery,
      items: items ?? this.items,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
