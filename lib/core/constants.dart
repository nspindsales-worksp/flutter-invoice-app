import 'package:flutter/material.dart';

class AppConstants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://gnpewobtibmadnfgxzvb.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImducGV3b2J0aWJtYWRuZmd4enZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAwNTE1NjcsImV4cCI6MjEwNTYyNzU2N30.riSBzlgNfF__ngadqAQ24ewORhE41UHY6f6Ilt_-K6g';

  // Google Sheets Default URLs
  static const String defaultAuthSheet =
      'https://docs.google.com/spreadsheets/d/1J7BXizJ4rg4n8DweH_5KWaQRhNJ66C9B2mF0K1G7EUI/edit?gid=0#gid=0';
  static const String defaultCustomerSheet =
      'https://docs.google.com/spreadsheets/d/1CobUG7Et8D06WBWmPs9NnCD3zQ1jb_yRBHDIf_Reijs/edit?gid=370372328#gid=370372328';
  static const String defaultProductSheetOld =
      'https://docs.google.com/spreadsheets/d/1tMGE35u1fylvD7bNKTvZt9P7btzqU9Mfn4YfohbXIgU/edit?gid=1185562692#gid=1185562692';

  // Invoice Number Generation
  // Exclude ambiguous characters: 0/O and 1/I
  static const String invoiceAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const String invoicePrefix = 'INV-';
  static const int invoiceCodeLength = 8;

  // Design Tokens (Emerald & Slate Aesthetic)
  static const Color primary = Color(0xFF10B981); // Emerald 500
  static const Color primaryDark = Color(0xFF059669); // Emerald 600
  static const Color primaryLight = Color(0xFF34D399); // Emerald 400
  static const Color secondary = Color(0xFF0D9488); // Teal 600
  static const Color accent = Color(0xFF06B6D4); // Cyan 500

  static const Color darkBg = Color(0xFF0B1120); // Slate 950
  static const Color darkCard = Color(0xFF1E293B); // Slate 800
  static const Color darkSurface = Color(0xFF131D31);
  static const Color darkBorder = Color(0xFF334155); // Slate 700

  static const Color lightBg = Color(0xFFF8FAFC); // Slate 50
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0); // Slate 200

  // SharedPreferences & Hive Box Names
  static const String hiveBoxInvoices = 'box_invoices';
  static const String hiveBoxCustomers = 'box_customers';
  static const String hiveBoxProducts = 'box_products';
  static const String hiveBoxPriceLists = 'box_price_lists';
  static const String hiveBoxUsers = 'box_users';
  static const String hiveBoxSettings = 'box_settings';
  static const String hiveBoxMeta = 'box_meta';
}
