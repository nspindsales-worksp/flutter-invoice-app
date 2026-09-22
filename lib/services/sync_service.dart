import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/utils.dart';
import '../models/customer_model.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
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

class SyncResultItem {
  final String type;
  final int added;
  final int deleted;
  final int skipped;
  final int totalRows;
  final String status; // 'success' | 'warning' | 'error'
  final String message;
  final Map<String, String> columnMapping;
  final List<String> headersFound;
  final List<String> warnings;

  SyncResultItem({
    required this.type,
    this.added = 0,
    this.deleted = 0,
    this.skipped = 0,
    this.totalRows = 0,
    required this.status,
    required this.message,
    this.columnMapping = const {},
    this.headersFound = const [],
    this.warnings = const [],
  });
}

class SheetPreviewData {
  final String sheetId;
  final String gid;
  final int totalRows;
  final List<String> headers;
  final Map<String, String> columnDetection;
  final List<Map<String, String>> previewRows;
  final String? error;

  SheetPreviewData({
    this.sheetId = '',
    this.gid = '0',
    this.totalRows = 0,
    this.headers = const [],
    this.columnDetection = const {},
    this.previewRows = const [],
    this.error,
  });
}

class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  /// Converts standard Google Sheets URL into direct CSV export URL
  String toCsvUrl(String url) {
    if (url.isEmpty) return '';
    if (url.contains('/export?format=csv')) return url;

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
    final csvUrl = toCsvUrl(sheetUrl);
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
      final idx = lowerHeaders.indexWhere((h) => h == p || h.contains(p));
      if (idx != -1) return idx;
    }
    return -1;
  }

  /// Preview a Google Sheet (Test Sheet feature)
  Future<SheetPreviewData> previewSheet(String sheetUrl) async {
    try {
      final regExp = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
      final match = regExp.firstMatch(sheetUrl);
      final sheetId = match?.group(1) ?? 'unknown';

      String gid = '0';
      final gidMatch = RegExp(r'[#&?]gid=([0-9]+)').firstMatch(sheetUrl);
      if (gidMatch != null) {
        gid = gidMatch.group(1)!;
      }

      final rows = await _fetchCsv(sheetUrl);
      if (rows.isEmpty) {
        return SheetPreviewData(
          sheetId: sheetId,
          gid: gid,
          totalRows: 0,
          error: 'Sheet is empty or has no accessible rows.',
        );
      }

      final headerList = rows.first.map((h) => h.toString().trim()).toList();

      final nameIdx = _findColumn(headerList, ['product name', 'product', 'item name', 'item', 'description']);
      final rateIdx = _findColumn(headerList, ['rate', 'price', 'mrp', 'standard rate', 'unit price']);
      final unitIdx = _findColumn(headerList, ['unit', 'uom', 'pack']);

      final columnDetection = <String, String>{
        'Product Name': nameIdx != -1 ? headerList[nameIdx] : '(not found)',
        'Unit Price': rateIdx != -1 ? headerList[rateIdx] : '(not found)',
        'Unit': unitIdx != -1 ? headerList[unitIdx] : '(not found)',
      };

      final previewList = <Map<String, String>>[];
      for (int i = 1; i < rows.length && i <= 6; i++) {
        final row = rows[i];
        final rowMap = <String, String>{'_row': i.toString()};
        for (int j = 0; j < headerList.length; j++) {
          rowMap[headerList[j]] = j < row.length ? row[j].toString() : '';
        }
        previewList.add(rowMap);
      }

      return SheetPreviewData(
        sheetId: sheetId,
        gid: gid,
        totalRows: rows.length > 1 ? rows.length - 1 : 0,
        headers: headerList,
        columnDetection: columnDetection,
        previewRows: previewList,
      );
    } catch (e) {
      return SheetPreviewData(error: e.toString());
    }
  }

  /// Synchronizes Users with detailed metrics
  Future<SyncResultItem> syncUsersDetailed(String sheetUrl) async {
    try {
      final rows = await _fetchCsv(sheetUrl);
      if (rows.isEmpty) {
        return SyncResultItem(
          type: 'Users',
          status: 'error',
          message: 'Auth sheet is empty or inaccessible.',
        );
      }

      final headers = rows.first.map((h) => h.toString().trim()).toList();
      final userIdIdx = _findColumn(headers, ['user id', 'userid', 'id', 'username']);
      final passIdx = _findColumn(headers, ['password', 'pass']);
      final nameIdx = _findColumn(headers, ['name', 'full name', 'employee']);
      final roleIdx = _findColumn(headers, ['role', 'type', 'designation']);
      final mobileIdx = _findColumn(headers, ['mobile', 'phone', 'contact']);

      final mapping = <String, String>{
        'User ID': userIdIdx != -1 ? headers[userIdIdx] : '(not found)',
        'Password': passIdx != -1 ? headers[passIdx] : '(not found)',
        'Name': nameIdx != -1 ? headers[nameIdx] : '(not found)',
        'Role': roleIdx != -1 ? headers[roleIdx] : '(not found)',
        'Mobile': mobileIdx != -1 ? headers[mobileIdx] : '(not found)',
      };

      if (userIdIdx == -1 || passIdx == -1) {
        return SyncResultItem(
          type: 'Users',
          status: 'error',
          message: 'Missing required columns: User ID or Password.',
          columnMapping: mapping,
          headersFound: headers,
        );
      }

      final supabase = SupabaseService.instance;
      final existingUsers = await supabase.getUsers();
      final protectedMap = <String, UserModel>{};
      for (var u in existingUsers) {
        if (u.isSystem || u.isLocal || u.role == 'Super Admin' || u.userId == '0505') {
          protectedMap[u.userId.toLowerCase()] = u;
        }
      }

      int added = 0;
      int skipped = 0;
      final warnings = <String>[];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= userIdIdx) {
          skipped++;
          continue;
        }

        final uId = row[userIdIdx].toString().trim();
        if (uId.isEmpty) {
          skipped++;
          continue;
        }

        if (protectedMap.containsKey(uId.toLowerCase())) {
          skipped++;
          warnings.add('Skipped protected account: $uId');
          continue;
        }

        final rawPass = row.length > passIdx ? row[passIdx].toString().trim() : '';
        final name = nameIdx != -1 && row.length > nameIdx ? row[nameIdx].toString().trim() : '';
        final role = roleIdx != -1 && row.length > roleIdx ? row[roleIdx].toString().trim() : 'User';
        final mobile = mobileIdx != -1 && row.length > mobileIdx ? row[mobileIdx].toString().trim() : '';

        final hashedPassword = AppUtils.hashPassword(rawPass);

        final user = UserModel(
          id: const Uuid().v4(),
          userId: uId,
          password: hashedPassword,
          name: name.isNotEmpty ? name : uId,
          role: role.isEmpty ? 'User' : role,
          mobile: mobile,
          isSystem: false,
          isLocal: false,
        );

        await supabase.saveUser(user);
        added++;
      }

      await _recordSyncTime();
      return SyncResultItem(
        type: 'Users',
        added: added,
        skipped: skipped,
        totalRows: rows.length - 1,
        status: added > 0 ? 'success' : 'warning',
        message: 'Successfully synchronized $added user account(s) from auth sheet.',
        columnMapping: mapping,
        headersFound: headers,
        warnings: warnings,
      );
    } catch (e) {
      return SyncResultItem(
        type: 'Users',
        status: 'error',
        message: 'User sync failed: $e',
      );
    }
  }

  /// Synchronizes Customers with detailed metrics
  Future<SyncResultItem> syncCustomersDetailed(String sheetUrl) async {
    try {
      final rows = await _fetchCsv(sheetUrl);
      if (rows.isEmpty) {
        return SyncResultItem(
          type: 'Customers',
          status: 'error',
          message: 'Customer sheet is empty or inaccessible.',
        );
      }

      final headers = rows.first.map((h) => h.toString().trim()).toList();
      final custIdIdx = _findColumn(headers, ['customer id', 'customerid', 'id', 'cust id']);
      final nameIdx = _findColumn(headers, ['customer name', 'name', 'company']);
      final addressIdx = _findColumn(headers, ['address', 'location']);
      final mobileIdx = _findColumn(headers, ['mobile', 'phone', 'contact']);

      final mapping = <String, String>{
        'Customer ID': custIdIdx != -1 ? headers[custIdIdx] : '(not found)',
        'Name': nameIdx != -1 ? headers[nameIdx] : '(not found)',
        'Address': addressIdx != -1 ? headers[addressIdx] : '(not found)',
        'Mobile': mobileIdx != -1 ? headers[mobileIdx] : '(not found)',
      };

      if (custIdIdx == -1 && nameIdx == -1) {
        return SyncResultItem(
          type: 'Customers',
          status: 'error',
          message: 'Missing customer columns: Customer ID or Customer Name.',
          columnMapping: mapping,
          headersFound: headers,
        );
      }

      final supabase = SupabaseService.instance;
      int added = 0;
      int skipped = 0;
      final warnings = <String>[];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final cId = custIdIdx != -1 && row.length > custIdIdx ? row[custIdIdx].toString().trim() : 'CUST-$i';
        final name = nameIdx != -1 && row.length > nameIdx ? row[nameIdx].toString().trim() : '';

        if (name.isEmpty && cId.isEmpty) {
          skipped++;
          continue;
        }

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
      return SyncResultItem(
        type: 'Customers',
        added: added,
        skipped: skipped,
        totalRows: rows.length - 1,
        status: added > 0 ? 'success' : 'warning',
        message: 'Successfully synchronized $added customer record(s).',
        columnMapping: mapping,
        headersFound: headers,
        warnings: warnings,
      );
    } catch (e) {
      return SyncResultItem(
        type: 'Customers',
        status: 'error',
        message: 'Customer sync failed: $e',
      );
    }
  }

  /// Synchronizes Products for a specific price list with detailed metrics
  Future<SyncResultItem> syncProductsDetailed({
    required String sheetUrl,
    required String priceListId,
    required String priceListName,
  }) async {
    try {
      final rows = await _fetchCsv(sheetUrl);
      if (rows.isEmpty) {
        return SyncResultItem(
          type: 'Products ($priceListName)',
          status: 'error',
          message: 'Product sheet is empty or inaccessible.',
        );
      }

      final headers = rows.first.map((h) => h.toString().trim()).toList();
      final nameIdx = _findColumn(headers, ['product name', 'product', 'item name', 'item', 'description']);
      final unitIdx = _findColumn(headers, ['unit', 'uom', 'pack']);
      final rateIdx = _findColumn(headers, ['rate', 'price', 'mrp', 'standard rate', 'unit price']);

      final mapping = <String, String>{
        'Product Name': nameIdx != -1 ? headers[nameIdx] : '(not found)',
        'Unit Price': rateIdx != -1 ? headers[rateIdx] : '(not found)',
        'Unit': unitIdx != -1 ? headers[unitIdx] : '(not found)',
      };

      if (nameIdx == -1) {
        return SyncResultItem(
          type: 'Products ($priceListName)',
          status: 'error',
          message: 'Missing required "Product Name" column.',
          columnMapping: mapping,
          headersFound: headers,
        );
      }

      final supabase = SupabaseService.instance;
      int added = 0;
      int skipped = 0;
      final warnings = <String>[];

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= nameIdx) {
          skipped++;
          continue;
        }

        final name = row[nameIdx].toString().trim();
        if (name.isEmpty) {
          skipped++;
          continue;
        }

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
      return SyncResultItem(
        type: 'Products ($priceListName)',
        added: added,
        skipped: skipped,
        totalRows: rows.length - 1,
        status: added > 0 ? 'success' : 'warning',
        message: 'Synchronized $added products for price list "$priceListName".',
        columnMapping: mapping,
        headersFound: headers,
        warnings: warnings,
      );
    } catch (e) {
      return SyncResultItem(
        type: 'Products ($priceListName)',
        status: 'error',
        message: 'Product sync failed for $priceListName: $e',
      );
    }
  }

  /// Legacy methods for backward compatibility
  Future<SyncResult> syncUsers(String sheetUrl) async {
    final item = await syncUsersDetailed(sheetUrl);
    return SyncResult(added: item.added, message: item.message, success: item.status == 'success');
  }

  Future<SyncResult> syncCustomers(String sheetUrl) async {
    final item = await syncCustomersDetailed(sheetUrl);
    return SyncResult(added: item.added, message: item.message, success: item.status == 'success');
  }

  Future<SyncResult> syncProducts({
    required String sheetUrl,
    required String priceListId,
    required String priceListName,
  }) async {
    final item = await syncProductsDetailed(
      sheetUrl: sheetUrl,
      priceListId: priceListId,
      priceListName: priceListName,
    );
    return SyncResult(added: item.added, message: item.message, success: item.status == 'success');
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
