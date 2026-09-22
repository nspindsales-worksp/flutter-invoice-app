import 'package:flutter_test/flutter_test.dart';
import 'package:invoice_app/core/constants.dart';

void main() {
  test('AppConstants smoke test', () {
    expect(AppConstants.invoicePrefix, equals('INV-'));
    expect(AppConstants.invoiceCodeLength, equals(8));
  });
}
