import '../core/utils.dart';

class InvoiceItemModel {
  final String id;
  final String invoiceNo;
  final String productName;
  final String description;
  final double quantity;
  final double unitPrice;
  final double grossAmount;
  final double discountPercent;
  final double netAmount;
  final double deliveryChargePerUnit;
  final double totalDeliveryCharge;
  final double total;

  InvoiceItemModel({
    required this.id,
    this.invoiceNo = '',
    required this.productName,
    this.description = '',
    this.quantity = 1.0,
    this.unitPrice = 0.0,
    double? grossAmount,
    this.discountPercent = 0.0,
    double? netAmount,
    this.deliveryChargePerUnit = 0.0,
    double? totalDeliveryCharge,
    double? total,
  })  : grossAmount = grossAmount ?? (quantity * unitPrice),
        netAmount = netAmount ?? ((quantity * unitPrice) * (1 - (discountPercent / 100))),
        totalDeliveryCharge = totalDeliveryCharge ?? (deliveryChargePerUnit * quantity),
        total = total ?? (((quantity * unitPrice) * (1 - (discountPercent / 100))) + (deliveryChargePerUnit * quantity));

  factory InvoiceItemModel.fromMap(Map<String, dynamic> map) {
    final qty = AppUtils.parseDouble(map['quantity'], 1.0);
    final price = AppUtils.parseDouble(map['unit_price'] ?? map['unitPrice'], 0.0);
    final disc = AppUtils.parseDouble(map['discount_percent'] ?? map['discountPercent'], 0.0);
    final delPerUnit = AppUtils.parseDouble(map['delivery_charge_per_unit'] ?? map['deliveryChargePerUnit'], 0.0);

    final gross = map['gross_amount'] != null || map['grossAmount'] != null
        ? AppUtils.parseDouble(map['gross_amount'] ?? map['grossAmount'])
        : (qty * price);
    final net = map['net_amount'] != null || map['netAmount'] != null
        ? AppUtils.parseDouble(map['net_amount'] ?? map['netAmount'])
        : (gross * (1 - disc / 100));
    final totDel = map['total_delivery_charge'] != null || map['totalDeliveryCharge'] != null
        ? AppUtils.parseDouble(map['total_delivery_charge'] ?? map['totalDeliveryCharge'])
        : (delPerUnit * qty);
    final tot = map['total'] != null
        ? AppUtils.parseDouble(map['total'])
        : (net + totDel);

    return InvoiceItemModel(
      id: map['id']?.toString() ?? '',
      invoiceNo: map['invoice_no']?.toString() ?? map['invoiceNo']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? map['productName']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      quantity: qty,
      unitPrice: price,
      grossAmount: gross,
      discountPercent: disc,
      netAmount: net,
      deliveryChargePerUnit: delPerUnit,
      totalDeliveryCharge: totDel,
      total: tot,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_no': invoiceNo,
      'product_name': productName,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'gross_amount': grossAmount,
      'discount_percent': discountPercent,
      'net_amount': netAmount,
      'delivery_charge_per_unit': deliveryChargePerUnit,
      'total_delivery_charge': totalDeliveryCharge,
      'total': total,
    };
  }

  InvoiceItemModel copyWith({
    String? id,
    String? invoiceNo,
    String? productName,
    String? description,
    double? quantity,
    double? unitPrice,
    double? discountPercent,
    double? deliveryChargePerUnit,
  }) {
    final q = quantity ?? this.quantity;
    final p = unitPrice ?? this.unitPrice;
    final d = discountPercent ?? this.discountPercent;
    final del = deliveryChargePerUnit ?? this.deliveryChargePerUnit;
    return InvoiceItemModel(
      id: id ?? this.id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      productName: productName ?? this.productName,
      description: description ?? this.description,
      quantity: q,
      unitPrice: p,
      discountPercent: d,
      deliveryChargePerUnit: del,
    );
  }
}
