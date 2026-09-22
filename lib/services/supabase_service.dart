import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/user_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/price_list_model.dart';
import '../models/invoice_model.dart';
import '../models/settings_model.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Box? _invoicesBox;
  Box? _customersBox;
  Box? _productsBox;
  Box? _priceListsBox;
  Box? _usersBox;
  Box? _settingsBox;

  Future<void> initialize() async {
    try {
      await Hive.initFlutter();
      _invoicesBox = await Hive.openBox(AppConstants.hiveBoxInvoices);
      _customersBox = await Hive.openBox(AppConstants.hiveBoxCustomers);
      _productsBox = await Hive.openBox(AppConstants.hiveBoxProducts);
      _priceListsBox = await Hive.openBox(AppConstants.hiveBoxPriceLists);
      _usersBox = await Hive.openBox(AppConstants.hiveBoxUsers);
      _settingsBox = await Hive.openBox(AppConstants.hiveBoxSettings);
    } catch (e) {
      debugPrint('Hive init error: $e');
    }

    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        publishableKey: AppConstants.supabaseAnonKey,
      );
      _isOnline = true;
    } catch (e) {
      debugPrint('Supabase initialize error: $e');
      _isOnline = false;
    }
  }

  // ==========================================
  // INVOICES CRUD
  // ==========================================

  Future<String> getNextInvoiceNumber() async {
    final existingNumbers = <String>{};

    // Load from local Hive
    if (_invoicesBox != null) {
      for (var key in _invoicesBox!.keys) {
        existingNumbers.add(key.toString());
      }
    }

    // Try reading existing invoice numbers from Supabase
    try {
      final res = await client.from('invoices').select('invoice_no');
      for (var row in res) {
        if (row['invoice_no'] != null) {
          existingNumbers.add(row['invoice_no'].toString());
        }
      }
    } catch (e) {
      debugPrint('Error checking online invoice numbers: $e');
    }

    return AppUtils.generateInvoiceNumber(existingNumbers: existingNumbers);
  }

  Future<void> saveInvoice(InvoiceModel invoice) async {
    // 1. Save locally in Hive
    if (_invoicesBox != null) {
      final jsonMap = invoice.toMap(includeItems: true);
      await _invoicesBox!.put(invoice.invoiceNo, jsonEncode(jsonMap));
    }

    // 2. Sync to Supabase
    try {
      // Upsert invoice header
      await client.from('invoices').upsert(invoice.toMap(includeItems: false));

      // Delete existing line items and insert new ones
      await client.from('invoice_items').delete().eq('invoice_no', invoice.invoiceNo);

      if (invoice.items.isNotEmpty) {
        final itemsPayload = invoice.items.map((item) {
          final m = item.toMap();
          m['invoice_no'] = invoice.invoiceNo;
          return m;
        }).toList();

        await client.from('invoice_items').insert(itemsPayload);
      }
      _isOnline = true;
    } catch (e) {
      debugPrint('Error syncing invoice to Supabase: $e');
      _isOnline = false;
      // Stored locally in Hive, will be accessible offline
    }
  }

  Future<List<InvoiceModel>> getInvoices({
    String? search,
    String? userId,
    String? role,
    bool isSuperAdmin = false,
  }) async {
    final isAdmin = role == 'Admin' || role == 'Super Admin';
    final List<InvoiceModel> list = [];

    // Try cloud fetch first
    try {
      final PostgrestTransformBuilder<PostgrestList> query;
      if (!isAdmin && userId != null && userId.isNotEmpty) {
        query = client.from('invoices').select('*, invoice_items(*)').eq('created_by', userId).order('created_at', ascending: false);
      } else if (!isSuperAdmin) {
        // Regular Admins and non-Super-Admins can NEVER see invoices created by Super Admin (0505)
        query = client.from('invoices').select('*, invoice_items(*)').neq('created_by', '0505').neq('created_by', 'sa-0505').order('created_at', ascending: false);
      } else {
        query = client.from('invoices').select('*, invoice_items(*)').order('created_at', ascending: false);
      }

      final data = await query;
      for (var row in data) {
        final inv = InvoiceModel.fromMap(row);
        // Ensure Super Admin invoices are never added if !isSuperAdmin
        if (!isSuperAdmin && (inv.createdBy == '0505' || inv.createdBy == 'sa-0505')) {
          continue;
        }
        list.add(inv);
        // Cache in Hive
        _invoicesBox?.put(inv.invoiceNo, jsonEncode(inv.toMap(includeItems: true)));
      }
      _isOnline = true;
    } catch (e) {
      debugPrint('Supabase getInvoices error (using offline cache): $e');
      _isOnline = false;

      // Fall back to Hive cache
      if (_invoicesBox != null) {
        for (var val in _invoicesBox!.values) {
          try {
            final decoded = jsonDecode(val.toString());
            final inv = InvoiceModel.fromMap(decoded);
            // Hide Super Admin invoices from anyone who is not Super Admin
            if (!isSuperAdmin && (inv.createdBy == '0505' || inv.createdBy == 'sa-0505')) {
              continue;
            }
            if (isAdmin || (userId == null || inv.createdBy == userId)) {
              list.add(inv);
            }
          } catch (_) {}
        }
        list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      }
    }

    // Filter by search if provided
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim().toLowerCase();
      return list.where((inv) {
        return inv.invoiceNo.toLowerCase().contains(term) ||
            inv.customerName.toLowerCase().contains(term) ||
            inv.mobile.toLowerCase().contains(term) ||
            inv.address.toLowerCase().contains(term);
      }).toList();
    }

    return list;
  }

  Future<InvoiceModel?> getInvoice(String invoiceNo, {bool isSuperAdmin = false}) async {
    // Check local Hive cache
    if (_invoicesBox != null && _invoicesBox!.containsKey(invoiceNo)) {
      try {
        final decoded = jsonDecode(_invoicesBox!.get(invoiceNo).toString());
        final inv = InvoiceModel.fromMap(decoded);
        if (!isSuperAdmin && (inv.createdBy == '0505' || inv.createdBy == 'sa-0505')) {
          return null; // Hidden from non-super-admins
        }
        return inv;
      } catch (_) {}
    }

    // Try Supabase
    try {
      final data = await client
          .from('invoices')
          .select('*, invoice_items(*)')
          .eq('invoice_no', invoiceNo)
          .maybeSingle();

      if (data != null) {
        final inv = InvoiceModel.fromMap(data);
        if (!isSuperAdmin && (inv.createdBy == '0505' || inv.createdBy == 'sa-0505')) {
          return null; // Hidden from non-super-admins
        }
        _invoicesBox?.put(invoiceNo, jsonEncode(inv.toMap(includeItems: true)));
        return inv;
      }
    } catch (e) {
      debugPrint('Error getInvoice from Supabase: $e');
    }
    return null;
  }

  Future<void> deleteInvoice(String invoiceNo) async {
    // Delete local
    await _invoicesBox?.delete(invoiceNo);

    // Delete Supabase
    try {
      await client.from('invoices').delete().eq('invoice_no', invoiceNo);
    } catch (e) {
      debugPrint('Error deleting invoice from Supabase: $e');
    }
  }

  // Lookups for autofilling invoice creator
  Future<double?> getLastProductPrice(String productName, {bool isSuperAdmin = false}) async {
    if (productName.isEmpty) return null;
    final invoices = await getInvoices(isSuperAdmin: isSuperAdmin);
    for (var inv in invoices) {
      for (var item in inv.items) {
        if (item.productName.toLowerCase() == productName.toLowerCase() && item.unitPrice > 0) {
          return item.unitPrice;
        }
      }
    }
    return null;
  }

  Future<Map<String, String>> getLastCustomerContact(String customerId, String customerName, {bool isSuperAdmin = false}) async {
    final invoices = await getInvoices(isSuperAdmin: isSuperAdmin);
    for (var inv in invoices) {
      final matchId = customerId.isNotEmpty && inv.customerId == customerId;
      final matchName = customerName.isNotEmpty && inv.customerName == customerName;
      if (matchId || matchName) {
        return {'address': inv.address, 'mobile': inv.mobile};
      }
    }
    return {'address': '', 'mobile': ''};
  }

  // ==========================================
  // CUSTOMERS CRUD
  // ==========================================

  Future<List<CustomerModel>> getCustomers({String? search}) async {
    final List<CustomerModel> list = [];

    try {
      final data = await client.from('customers').select().order('name', ascending: true);
      for (var row in data) {
        final c = CustomerModel.fromMap(row);
        list.add(c);
        _customersBox?.put(c.customerId, jsonEncode(c.toMap()));
      }
      _isOnline = true;
    } catch (e) {
      debugPrint('Error fetching customers from Supabase (using cache): $e');
      _isOnline = false;
      if (_customersBox != null) {
        for (var val in _customersBox!.values) {
          try {
            final decoded = jsonDecode(val.toString());
            list.add(CustomerModel.fromMap(decoded));
          } catch (_) {}
        }
      }
    }

    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim().toLowerCase();
      return list.where((c) {
        return c.name.toLowerCase().contains(term) ||
            c.customerId.toLowerCase().contains(term) ||
            c.mobile.toLowerCase().contains(term) ||
            c.address.toLowerCase().contains(term);
      }).toList();
    }

    return list;
  }

  Future<void> saveCustomer(CustomerModel customer) async {
    await _customersBox?.put(customer.customerId, jsonEncode(customer.toMap()));
    try {
      await client.from('customers').upsert(customer.toMap(), onConflict: 'customer_id');
    } catch (e) {
      debugPrint('Error saving customer to Supabase: $e');
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    await _customersBox?.delete(customerId);
    try {
      await client.from('customers').delete().eq('customer_id', customerId);
    } catch (e) {
      debugPrint('Error deleting customer from Supabase: $e');
    }
  }

  // ==========================================
  // PRICE LISTS & PRODUCTS CRUD
  // ==========================================

  Future<List<PriceListModel>> getPriceLists() async {
    final List<PriceListModel> list = [];
    try {
      final data = await client.from('price_lists').select('*, products(count)').order('sort_order', ascending: true);
      for (var row in data) {
        int count = 0;
        if (row['products'] is List && (row['products'] as List).isNotEmpty) {
          count = (row['products'][0]['count'] as num?)?.toInt() ?? 0;
        }
        final pl = PriceListModel.fromMap(row, count: count);
        list.add(pl);
        _priceListsBox?.put(pl.id, jsonEncode(pl.toMap()));
      }
    } catch (e) {
      debugPrint('Error getPriceLists: $e');
      if (_priceListsBox != null) {
        for (var val in _priceListsBox!.values) {
          try {
            list.add(PriceListModel.fromMap(jsonDecode(val.toString())));
          } catch (_) {}
        }
      }
    }
    return list;
  }

  Future<void> savePriceList(PriceListModel priceList) async {
    await _priceListsBox?.put(priceList.id, jsonEncode(priceList.toMap()));
    try {
      await client.from('price_lists').upsert(priceList.toMap(), onConflict: 'name');
    } catch (e) {
      debugPrint('Error savePriceList: $e');
    }
  }

  Future<void> deletePriceList(String id) async {
    await _priceListsBox?.delete(id);
    try {
      await client.from('price_lists').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deletePriceList: $e');
    }
  }

  Future<List<ProductModel>> getProducts({String? priceListId, String? search}) async {
    final List<ProductModel> list = [];
    try {
      final PostgrestTransformBuilder<PostgrestList> query;
      if (priceListId != null && priceListId.isNotEmpty && priceListId != 'all') {
        query = client.from('products').select('*, price_lists(name)').eq('price_list_id', priceListId).order('name', ascending: true);
      } else {
        query = client.from('products').select('*, price_lists(name)').order('name', ascending: true);
      }

      final data = await query;
      for (var row in data) {
        String? plName;
        if (row['price_lists'] != null) {
          plName = row['price_lists']['name']?.toString();
        }
        final p = ProductModel.fromMap(row, priceListName: plName);
        list.add(p);
        _productsBox?.put(p.id, jsonEncode(p.toMap()));
      }
    } catch (e) {
      debugPrint('Error getProducts: $e');
      if (_productsBox != null) {
        for (var val in _productsBox!.values) {
          try {
            final p = ProductModel.fromMap(jsonDecode(val.toString()));
            if (priceListId == null || priceListId == 'all' || p.priceListId == priceListId) {
              list.add(p);
            }
          } catch (_) {}
        }
      }
    }

    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim().toLowerCase();
      return list.where((p) => p.name.toLowerCase().contains(term)).toList();
    }
    return list;
  }

  Future<void> saveProduct(ProductModel product) async {
    await _productsBox?.put(product.id, jsonEncode(product.toMap()));
    try {
      await client.from('products').upsert(product.toMap());
    } catch (e) {
      debugPrint('Error saveProduct: $e');
    }
  }

  Future<void> deleteProduct(String id) async {
    await _productsBox?.delete(id);
    try {
      await client.from('products').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleteProduct: $e');
    }
  }

  // ==========================================
  // USERS CRUD & AUTH
  // ==========================================

  Future<List<UserModel>> getUsers({bool isSuperAdmin = false}) async {
    final List<UserModel> list = [];
    try {
      final data = await client.from('users').select().order('created_at', ascending: false);
      for (var row in data) {
        final u = UserModel.fromMap(row);
        // Completely shield Super Admin from non-super-admins
        if (!isSuperAdmin && (u.isSuperAdmin || u.userId == '0505' || u.userId == 'sa-0505' || u.role == 'Super Admin')) {
          continue;
        }
        list.add(u);
        _usersBox?.put(u.userId.toLowerCase(), jsonEncode(u.toMap()));
      }
    } catch (e) {
      debugPrint('Error getUsers: $e');
      if (_usersBox != null) {
        for (var val in _usersBox!.values) {
          try {
            final u = UserModel.fromMap(jsonDecode(val.toString()));
            if (!isSuperAdmin && (u.isSuperAdmin || u.userId == '0505' || u.userId == 'sa-0505' || u.role == 'Super Admin')) {
              continue;
            }
            list.add(u);
          } catch (_) {}
        }
      }
    }
    return list;
  }

  Future<void> saveUser(UserModel user, {bool isSuperAdmin = false}) async {
    // Shield Super Admin from being altered by non-super-admins
    if (!isSuperAdmin && (user.isSuperAdmin || user.userId == '0505' || user.userId == 'sa-0505' || user.role == 'Super Admin')) {
      throw Exception('Unauthorized: Cannot create or modify Super Admin data');
    }
    await _usersBox?.put(user.userId.toLowerCase(), jsonEncode(user.toMap()));
    try {
      await client.from('users').upsert(user.toMap(), onConflict: 'user_id');
    } catch (e) {
      debugPrint('Error saveUser: $e');
    }
  }

  Future<void> deleteUser(String userId, {bool isSuperAdmin = false}) async {
    // Prevent anyone from deleting Super Admin
    if (userId == '0505' || userId.toLowerCase() == 'sa-0505') {
      throw Exception('Unauthorized: Super Admin account cannot be deleted');
    }
    await _usersBox?.delete(userId.toLowerCase());
    try {
      await client.from('users').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint('Error deleteUser: $e');
    }
  }

  // ==========================================
  // SETTINGS
  // ==========================================

  Future<SettingsModel> getSettings() async {
    final Map<String, String> map = {};
    try {
      final data = await client.from('system_settings').select();
      for (var row in data) {
        if (row['key'] != null && row['value'] != null) {
          map[row['key'].toString()] = row['value'].toString();
        }
      }
      _settingsBox?.put('current_settings', jsonEncode(map));
      return SettingsModel.fromMap(map);
    } catch (e) {
      debugPrint('Error getSettings: $e');
      if (_settingsBox != null && _settingsBox!.containsKey('current_settings')) {
        try {
          final decoded = Map<String, dynamic>.from(jsonDecode(_settingsBox!.get('current_settings')));
          return SettingsModel.fromMap(decoded.map((k, v) => MapEntry(k, v.toString())));
        } catch (_) {}
      }
      return SettingsModel();
    }
  }

  Future<void> saveSettings(SettingsModel settings) async {
    final map = settings.toMap();
    await _settingsBox?.put('current_settings', jsonEncode(map));

    try {
      final rows = map.entries.map((e) => {'key': e.key, 'value': e.value}).toList();
      await client.from('system_settings').upsert(rows, onConflict: 'key');
    } catch (e) {
      debugPrint('Error saveSettings: $e');
    }
  }

  // ==========================================
  // ADMIN FEATURES & ACTIVITY LOG
  // ==========================================

  Future<Map<String, bool>> getAdminFeatures() async {
    final Map<String, bool> map = {'createInvoice': true, 'invoiceHistory': true};
    try {
      final data = await client.from('admin_features').select();
      for (var row in data) {
        if (row['key'] != null) {
          map[row['key'].toString()] = row['enabled'] == true;
        }
      }
    } catch (e) {
      debugPrint('Error getAdminFeatures: $e');
    }
    return map;
  }

  Future<void> updateAdminFeature(String key, bool enabled) async {
    try {
      await client.from('admin_features').update({'enabled': enabled}).eq('key', key);
    } catch (e) {
      debugPrint('Error updateAdminFeature: $e');
    }
  }

  Future<void> logActivity({
    required String userId,
    required String userName,
    required String action,
    String? deviceId,
    String? ipAddress,
  }) async {
    try {
      await client.from('user_activity_logs').insert({
        'user_id': userId,
        'user_name': userName,
        'action': action,
        'mac_address': deviceId ?? '',
        'ip_address': ipAddress ?? '',
      });
    } catch (_) {}
  }
}
