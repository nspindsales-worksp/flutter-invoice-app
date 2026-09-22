import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'constants.dart';

class AppUtils {
  static final NumberFormat _currencyFormat = NumberFormat('#,##,##0.00', 'en_IN');
  static final NumberFormat _integerFormat = NumberFormat('#,##,##0', 'en_IN');
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');
  static final Random _secureRandom = Random.secure();

  /// Formats amount into Indian/South-Asian grouping e.g. 1,50,000.00
  static String formatAmount(double amount, {bool showDecimals = true}) {
    if (!showDecimals || amount == amount.roundToDouble()) {
      return _integerFormat.format(amount);
    }
    return _currencyFormat.format(amount);
  }

  /// Formats date to standard YYYY-MM-DD
  static String formatDateStandard(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Formats date for display e.g. 22 Sep 2026
  static String formatDateDisplay(DateTime date) {
    return _displayDateFormat.format(date);
  }

  /// Hashes a password with SHA-256 hex
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generates a random alphanumeric code of specified length from unambiguous alphabet
  static String generateRandomCode([int length = AppConstants.invoiceCodeLength]) {
    final buffer = StringBuffer();
    final alphabet = AppConstants.invoiceAlphabet;
    for (int i = 0; i < length; i++) {
      final index = _secureRandom.nextInt(alphabet.length);
      buffer.write(alphabet[index]);
    }
    return buffer.toString();
  }

  /// Generates a unique invoice number in the format INV-XXXXXXXX
  /// Guarantees uniqueness against a set of known invoice numbers.
  static String generateInvoiceNumber({Set<String>? existingNumbers}) {
    for (int attempt = 0; attempt < 100; attempt++) {
      final code = generateRandomCode(AppConstants.invoiceCodeLength);
      final candidate = '${AppConstants.invoicePrefix}$code';
      if (existingNumbers == null || !existingNumbers.contains(candidate)) {
        return candidate;
      }
    }
    // Fallback if 100 attempts collide (virtually impossible with 32^8 possibilities)
    final extra = generateRandomCode(2);
    return '${AppConstants.invoicePrefix}${generateRandomCode(AppConstants.invoiceCodeLength)}$extra';
  }

  /// Parse double safely
  static double parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(',', '').trim();
      return double.tryParse(cleaned) ?? defaultValue;
    }
    return defaultValue;
  }
}
