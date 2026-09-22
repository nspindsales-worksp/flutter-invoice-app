import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/price_list_model.dart';
import '../models/settings_model.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _supabase = SupabaseService.instance;
  final _syncService = SyncService.instance;

  SettingsModel _settings = SettingsModel();
  List<PriceListModel> _priceLists = [];
  String? _lastSyncTime;
  bool _isLoading = true;

  bool _syncingUsers = false;
  bool _syncingCustomers = false;
  bool _syncingProducts = false;
  String _syncLog = '';

  @override
  void initState() {
    super.initState();
    _loadSyncData();
  }

  Future<void> _loadSyncData() async {
    setState(() => _isLoading = true);
    try {
      final s = await _supabase.getSettings();
      final pls = await _supabase.getPriceLists();
      final last = await _syncService.getLastSyncTime();

      if (mounted) {
        setState(() {
          _settings = s;
          _priceLists = pls;
          _lastSyncTime = last;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _appendLog(String text) {
    setState(() {
      _syncLog = '[${DateTime.now().toLocal().toString().substring(11, 19)}] $text\n$_syncLog';
    });
  }

  Future<void> _syncUsers() async {
    setState(() => _syncingUsers = true);
    _appendLog('Starting Users sync from Google Sheets...');
    try {
      final res = await _syncService.syncUsers(_settings.sheetUrlAuth);
      _appendLog(res.message);
      _lastSyncTime = await _syncService.getLastSyncTime();
    } catch (e) {
      _appendLog('Error syncing users: $e');
    } finally {
      if (mounted) setState(() => _syncingUsers = false);
    }
  }

  Future<void> _syncCustomers() async {
    setState(() => _syncingCustomers = true);
    _appendLog('Starting Customers sync from Google Sheets...');
    try {
      final res = await _syncService.syncCustomers(_settings.sheetUrlCustomer);
      _appendLog(res.message);
      _lastSyncTime = await _syncService.getLastSyncTime();
    } catch (e) {
      _appendLog('Error syncing customers: $e');
    } finally {
      if (mounted) setState(() => _syncingCustomers = false);
    }
  }

  Future<void> _syncPriceListProducts(PriceListModel pl) async {
    if (pl.sheetUrl.isEmpty) {
      _appendLog('No sheet URL configured for price list ${pl.name}');
      return;
    }
    setState(() => _syncingProducts = true);
    _appendLog('Syncing products for "${pl.name}"...');
    try {
      final res = await _syncService.syncProducts(
        sheetUrl: pl.sheetUrl,
        priceListId: pl.id,
        priceListName: pl.name,
      );
      _appendLog(res.message);
      _lastSyncTime = await _syncService.getLastSyncTime();
    } catch (e) {
      _appendLog('Error syncing products for ${pl.name}: $e');
    } finally {
      if (mounted) setState(() => _syncingProducts = false);
    }
  }

  Future<void> _syncAll() async {
    _appendLog('=== FULL SYNC STARTED ===');
    await _syncUsers();
    await _syncCustomers();
    for (var pl in _priceLists) {
      if (pl.isActive && pl.sheetUrl.isNotEmpty) {
        await _syncPriceListProducts(pl);
      }
    }
    _appendLog('=== FULL SYNC COMPLETED ===');
    _loadSyncData();
  }

  void _showAddPriceListDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Price List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Price List Name (e.g. New)')),
            const SizedBox(height: 12),
            TextField(controller: urlController, decoration: const InputDecoration(labelText: 'Google Sheet URL')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final pl = PriceListModel(
                id: const Uuid().v4(),
                name: name,
                sheetUrl: urlController.text.trim(),
                isActive: true,
                sortOrder: _priceLists.length + 1,
              );
              await _supabase.savePriceList(pl);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadSyncData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Sync Summary Bar
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Google Sheets Data Sync', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          _lastSyncTime != null
                              ? 'Last sync: ${_lastSyncTime!.substring(0, 19).replaceAll("T", " ")}'
                              : 'No sync recorded yet',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: (_syncingUsers || _syncingCustomers || _syncingProducts) ? null : _syncAll,
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync All Sheets'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Sync Modules Grid
            Row(
              children: [
                // 1. Users Sync Card
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Users / Auth Sheet', style: TextStyle(fontWeight: FontWeight.bold)),
                              _syncingUsers
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _syncUsers),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text('Syncs employees, roles, and passwords from central sheet.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _syncingUsers ? null : _syncUsers,
                            icon: const Icon(Icons.cloud_download_outlined, size: 16),
                            label: const Text('Sync Users'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Customers Sync Card
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Customer Sheet', style: TextStyle(fontWeight: FontWeight.bold)),
                              _syncingCustomers
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _syncCustomers),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text('Syncs customer names, addresses, and contacts.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _syncingCustomers ? null : _syncCustomers,
                            icon: const Icon(Icons.cloud_download_outlined, size: 16),
                            label: const Text('Sync Customers'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Price Lists Management Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Price Lists (${_priceLists.length})', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          onPressed: _showAddPriceListDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Price List'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_priceLists.isEmpty)
                      const Text('No price lists configured.')
                    else
                      ..._priceLists.map((pl) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.list_alt, color: pl.isActive ? AppConstants.primary : Colors.grey, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pl.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(
                                      pl.sheetUrl.isNotEmpty ? pl.sheetUrl : 'No Sheet URL attached',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _syncingProducts ? null : () => _syncPriceListProducts(pl),
                                icon: const Icon(Icons.sync, size: 14),
                                label: const Text('Sync'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Live Sync Console Log Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sync Console Output', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => setState(() => _syncLog = ''),
                          child: const Text('Clear Log'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _syncLog.isEmpty ? 'Ready for synchronization...' : _syncLog,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF34D399)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
