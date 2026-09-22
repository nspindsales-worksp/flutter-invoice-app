import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/utils.dart';
import '../models/user_model.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import 'supabase_service.dart';

class SyncResult {
  final int added;
  final int updated;
  final int deleted;
  final String message;
  final bool success;

  SyncResult({
    this.added = 0,
    this.updated = 0,
    this.deleted = 0,
    required this.message,
    this.success = true,
  });
}

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  /// Converts standard Google Sheets URL into direct CSV export URL
  String _toCsvUrl(String url) {
    if (url.isEmpty) return '';
    if (url.contains('/export?format=csv')) return url;

    // Pattern: https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit...gid={GID}
    final regExp = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regExp.firstMatch(url);
    if (match == null) return url;

    final sheetId = match.group(1);
    String gid = '0';
    final gidMatch = RegExp(r'[#&?]gid=([0-9]+)').firstMatch(url);
    if (gidMatch != null) {
      gid = gidMatch.group(1)!;
    }

    return 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=$gid';
  }

  Future<List<List<dynamic>>> _fetchCsv(String sheetUrl) async {
    final csvUrl = _toCsvUrl(sheetUrl);
    final response = await http.get(
      Uri.parse(csvUrl),
      headers: {'User-Agent': 'Mozilla/5.0 (compatible; InvoiceApp/1.0)'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch sheet: HTTP ${response.statusCode}');
    }

    final rows = csv.decode(response.body);
    return rows.map((r) => r.toList()).toList();
  }

  int _findColumn(List<dynamic> headers, List<String> patterns) {
    final lowerHeaders = headers.map((h) => h.toString().toLowerCase().trim()).toList();
    for (var pattern in patterns) {
      final p = pattern.toLowerCase();
      final idx = lowerHeaders.indexWhere((h) => h.contains(p));
      if (idx != -1) return idx;
    }
    return -1;
  }

  /// Synchronizes Users from Auth Sheet
  Future<SyncResult> syncUsers(String sheetUrl) async {
    final rows = await _fetchCsv(sheetUrl);
    if (rows.isEmpty) return SyncResult(message: 'Sheet is empty', success: false);

    final headers = rows.first;
    final userIdIdx = _findColumn(headers, ['user id', 'userid', 'id', 'username']);
    final passIdx = _findColumn(headers, ['password', 'pass']);
    final nameIdx = _findColumn(headers, ['name', 'full name', 'employee']);
    final roleIdx = _findColumn(headers, ['role', 'type', 'designation']);
    final mobileIdx = _findColumn(headers, ['mobile', 'phone', 'contact']);

    if (userIdIdx == -1 || passIdx == -1) {
      return SyncResult(message: 'Missing required columns (User ID, Password)', success: false);
    }

    final supabase = SupabaseService.instance;
    final existingUsers = await supabase.getUsers();
    final protectedMap = <String, UserModel>{};

    for (var u in existingUsers) {
      if (u.isSystem || u.isLocal || u.role == 'Super Admin') {
        protectedMap[u.userId.toLowerCase()] = u;
      }
    }

    int added = 0;
    int updated = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= userIdIdx) continue;

      final uId = row[userIdIdx].toString().trim();
      if (uId.isEmpty) continue;

      // Skip protected users (Super Admin, admin-created local users)
      if (protectedMap.containsKey(uId.toLowerCase())) continue;

      final rawPass = row.length > passIdx ? row[passIdx].toString().trim() : '';
      final name = nameIdx != -1 && row.length > nameIdx ? row[nameIdx].toString().trim() : '';
      final role = roleIdx != -1 && row.length > roleIdx ? row[roleIdx].toString().trim() : 'User';
      final mobile = mobileIdx != -1 && row.length > mobileIdx ? row[mobileIdx].toString().trim() : '';

      final hashedPassword = AppUtils.hashPassword(rawPass);

      final user = UserModel(
        id: const Uuid().v4(),
        userId: uId,
        password: hashedPassword,
        name: name,
        role: role.isEmpty ? 'User' : role,
        mobile: mobile,
        isSystem: false,
        isLocal: false,
      );

      await supabase.saveUser(user);
      added++;
    }

    await _recordSyncTime();
    return SyncResult(added: added, updated: updated, message: 'Synced $added users successfully');
  }

  /// Synchronizes Customers from Customer Sheet
  Future<SyncResult> syncCustomers(String sheetUrl) async {
    final rows = await _fetchCsv(sheetUrl);
    if (rows.isEmpty) return SyncResult(message: 'Sheet is empty', success: false);

    final headers = rows.first;
    final custIdIdx = _findColumn(headers, ['customer id', 'customerid', 'id', 'cust id']);
    final nameIdx = _findColumn(headers, ['customer name', 'name', 'company']);
    final addressIdx = _findColumn(headers, ['address', 'location']);
    final mobileIdx = _findColumn(headers, ['mobile', 'phone', 'contact']);

    if (custIdIdx == -1 && nameIdx == -1) {
      return SyncResult(message: 'Missing customer columns (Customer ID, Name)', success: false);
    }

    final supabase = SupabaseService.instance;
    int added = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final cId = custIdIdx != -1 && row.length > custIdIdx ? row[custIdIdx].toString().trim() : 'CUST-$i';
      final name = nameIdx != -1 && row.length > nameIdx ? row[nameIdx].toString().trim() : '';
      if (name.isEmpty && cId.isEmpty) continue;

      final address = addressIdx != -1 && row.length > addressIdx ? row[addressIdx].toString().trim() : '';
      final mobile = mobileIdx != -1 && row.length > mobileIdx ? row[mobileIdx].toString().trim() : '';

      final cust = CustomerModel(
        id: const Uuid().v4(),
        customerId: cId.isNotEmpty ? cId : 'CUST-$i',
        name: name.isNotEmpty ? name : cId,
        address: address,
        mobile: mobile,
      );

      await supabase.saveCustomer(cust);
      added++;
    }

    await _recordSyncTime();
    return SyncResult(added: added, message: 'Synced $added customers successfully');
  }

  /// Synchronizes Products for a specific Price List
  Future<SyncResult> syncProducts({
    required String sheetUrl,
    required String priceListId,
    required String priceListName,
  }) async {
    final rows = await _fetchCsv(sheetUrl);
    if (rows.isEmpty) return SyncResult(message: 'Sheet is empty', success: false);

    final headers = rows.first;
    final nameIdx = _findColumn(headers, ['product name', 'product', 'item name', 'item', 'description']);
    final unitIdx = _findColumn(headers, ['unit', 'uom', 'pack']);
    final rateIdx = _findColumn(headers, ['rate', 'price', 'mrp', 'standard rate', 'unit price']);

    if (nameIdx == -1) {
      return SyncResult(message: 'Missing Product Name column', success: false);
    }

    final supabase = SupabaseService.instance;
    int added = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= nameIdx) continue;

      final name = row[nameIdx].toString().trim();
      if (name.isEmpty) continue;

      final unit = unitIdx != -1 && row.length > unitIdx ? row[unitIdx].toString().trim() : 'Pcs';
      final rawRate = rateIdx != -1 && row.length > rateIdx ? row[rateIdx] : '0';
      final rate = AppUtils.parseDouble(rawRate, 0.0);

      final product = ProductModel(
        id: const Uuid().v4(),
        name: name,
        unit: unit.isEmpty ? 'Pcs' : unit,
        standardRate: rate,
        priceListId: priceListId,
        priceListName: priceListName,
      );

      await supabase.saveProduct(product);
      added++;
    }

    await _recordSyncTime();
    return SyncResult(added: added, message: 'Synced $added products for $priceListName');
  }

  Future<void> _recordSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_auto_sync', DateTime.now().toIso8601String());
  }

  Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_auto_sync');
  }
}
