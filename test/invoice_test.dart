import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/core/utils.dart';
import 'package:invoice_app/models/invoice_item_model.dart';
import 'package:invoice_app/models/invoice_model.dart';

void main() {
  group('Invoice Number Generator Tests', () {
    test('generates format INV-XXXXXXXX with length 12', () {
      final invNo = AppUtils.generateInvoiceNumber();
      expect(invNo.startsWith('INV-'), isTrue);
      expect(invNo.length, equals(12));
    });

    test('excludes ambiguous characters 0, O, 1, I', () {
      for (int i = 0; i < 50; i++) {
        final invNo = AppUtils.generateInvoiceNumber();
        final code = invNo.substring(4);
        expect(code.contains('0'), isFalse);
        expect(code.contains('O'), isFalse);
        expect(code.contains('1'), isFalse);
        expect(code.contains('I'), isFalse);
      }
    });

    test('guarantees uniqueness against existing set', () {
      final existing = {'INV-A7YB85LN', 'INV-CMX3Z3Y5'};
      final newNo = AppUtils.generateInvoiceNumber(existingNumbers: existing);
      expect(existing.contains(newNo), isFalse);
    });
  });

  group('Invoice Calculations Tests', () {
    test('calculates line item gross, discount, delivery, and total correctly', () {
      final item = InvoiceItemModel(
        id: 'item-1',
        productName: 'Toner Cartridge',
        quantity: 5,
        unitPrice: 200,
        discountPercent: 10,
        deliveryChargePerUnit: 15,
      );

      // Gross = 5 * 200 = 1000
      expect(item.grossAmount, equals(1000.0));
      // Net = 1000 * 0.9 = 900
      expect(item.netAmount, equals(900.0));
      // Delivery = 15 * 5 = 75
      expect(item.totalDeliveryCharge, equals(75.0));
      // Total = 900 + 75 = 975
      expect(item.total, equals(975.0));
    });

    test('calculates invoice model grand total accurately', () {
      final item1 = InvoiceItemModel(
        id: '1',
        productName: 'Item A',
        quantity: 2,
        unitPrice: 500,
        discountPercent: 0,
        deliveryChargePerUnit: 0,
      ); // Total = 1000

      final item2 = InvoiceItemModel(
        id: '2',
        productName: 'Item B',
        quantity: 1,
        unitPrice: 300,
        discountPercent: 10, // Net = 270
        deliveryChargePerUnit: 30, // Total = 300
      );

      final invoice = InvoiceModel(
        invoiceNo: 'INV-TEST1234',
        date: '2026-09-22',
        customerName: 'Test Corp',
        items: [item1, item2],
      );

      expect(invoice.subtotalGross, equals(1300.0));
      expect(invoice.totalDiscount, equals(30.0));
      expect(invoice.subtotalNet, equals(1270.0));
      expect(invoice.totalDeliveryCharge, equals(30.0));
      expect(invoice.totalAmount, equals(1300.0));
    });
  });

  group('Authentication & Security Tests', () {
    test('hashes password to SHA-256 hex correctly', () {
      final hash = AppUtils.hashPassword('Manha@0505');
      expect(hash, equals('88d0d01e3f0403234511f566f9039cc7e34c3a5e169163ec4bc9a3bc40fa273a'));
    });
  });
}
