import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice_model.dart';
import '../services/supabase_service.dart';

enum AppPage {
  dashboard,
  customers,
  products,
  invoiceCreate,
  invoiceHistory,
  syncData,
  adminSettings,
  userControlLog,
  pdfDesigner,
}

class AppProvider extends ChangeNotifier {
  AppPage _currentPage = AppPage.dashboard;
  AppPage get currentPage => _currentPage;

  InvoiceModel? _editingInvoice;
  InvoiceModel? get editingInvoice => _editingInvoice;

  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  bool get isOnline => SupabaseService.instance.isOnline;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    notifyListeners();
  }

  void setPage(AppPage page) {
    if (_currentPage != page) {
      if (page != AppPage.invoiceCreate) {
        _editingInvoice = null; // Clear edit invoice when navigating away
      }
      _currentPage = page;
      notifyListeners();
    }
  }

  void startEditingInvoice(InvoiceModel invoice) {
    _editingInvoice = invoice;
    _currentPage = AppPage.invoiceCreate;
    notifyListeners();
  }

  void clearEditingInvoice() {
    _editingInvoice = null;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
    notifyListeners();
  }
}
