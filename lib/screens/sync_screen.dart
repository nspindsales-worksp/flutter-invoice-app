import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/price_list_model.dart';
import '../models/settings_model.dart';
import '../providers/auth_provider.dart';
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

  // Sheet links
  final _authSheetController = TextEditingController();
  final _customerSheetController = TextEditingController();

  SettingsModel _settings = SettingsModel();
  List<PriceListModel> _priceLists = [];
  bool _isLoading = true;
  bool _isSavingSettings = false;

  // Auto-sync timer state (runs every 5 mins)
  String? _lastAutoSync;
  int _nextAutoSyncIn = 5;
  Timer? _countdownTimer;

  // Active sync state
  String? _syncingType;
  String _syncProgress = '';
  List<SyncResultItem> _syncResults = [];


  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoSyncCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _authSheetController.dispose();
    _customerSheetController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final s = await _supabase.getSettings();
      final pls = await _supabase.getPriceLists();
      final lastSync = await _syncService.getLastSyncTime();

      if (mounted) {
        setState(() {
          _settings = s;
          _authSheetController.text = s.sheetUrlAuth;
          _customerSheetController.text = s.sheetUrlCustomer;
          _priceLists = pls;
          _lastAutoSync = lastSync;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startAutoSyncCountdown() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateCountdown());
  }

  void _updateCountdown() {
    if (_lastAutoSync != null) {
      final last = DateTime.tryParse(_lastAutoSync!);
      if (last != null) {
        final elapsed = DateTime.now().difference(last).inMinutes;
        final rem = (5 - elapsed).clamp(0, 5);
        if (mounted) setState(() => _nextAutoSyncIn = rem);
        return;
      }
    }
    if (mounted) setState(() => _nextAutoSyncIn = 5);
  }

  Future<void> _saveSettings() async {
    setState(() => _isSavingSettings = true);
    try {
      final updated = _settings.copyWith(
        sheetUrlAuth: _authSheetController.text.trim(),
        sheetUrlCustomer: _customerSheetController.text.trim(),
      );
      await _supabase.saveSettings(updated);
      setState(() => _settings = updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sheet settings saved successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingSettings = false);
    }
  }

  Future<void> _handleTestSheet(String sheetUrl, String title) async {
    if (sheetUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid Google Sheet URL first.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF059669))),
    );

    final preview = await _syncService.previewSheet(sheetUrl);

    if (mounted) {
      Navigator.pop(context); // close loader
      _showPreviewDialog(title, preview);
    }
  }

  void _showPreviewDialog(String title, SheetPreviewData preview) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.table_chart_outlined, color: Color(0xFF059669), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sheet Preview: $title',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: preview.error != null
              ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          preview.error!,
                          style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sheet meta info
                      Row(
                        children: [
                          Chip(
                            label: Text('Rows: ${preview.totalRows}', style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text('Columns: ${preview.headers.length}', style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Detected Columns
                      const Text('Detected Column Mapping:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: preview.columnDetection.entries.map((e) {
                          final found = e.value != '(not found)';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: found ? const Color(0xFF059669).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: found ? const Color(0xFF059669) : Colors.redAccent, width: 0.5),
                            ),
                            child: Text(
                              '${e.key}: ${e.value}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: found ? const Color(0xFF059669) : Colors.redAccent,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Headers list
                      const Text('Headers Found:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        preview.headers.map((h) => '"$h"').join(', '),
                        style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                      ),
                      const SizedBox(height: 14),

                      // Preview Table (first 5 rows)
                      if (preview.previewRows.isNotEmpty) ...[
                        const Text('First 5 Rows Preview:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 32,
                            dataRowMinHeight: 28,
                            dataRowMaxHeight: 36,
                            columns: [
                              const DataColumn(label: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                              ...preview.headers.take(5).map((h) => DataColumn(
                                    label: Text(h, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  )),
                            ],
                            rows: preview.previewRows.map((r) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(r['_row'] ?? '', style: const TextStyle(fontSize: 10))),
                                  ...preview.headers.take(5).map((h) => DataCell(
                                        Text(r[h] ?? '', style: const TextStyle(fontSize: 10)),
                                      )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPriceList() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Price List', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Price List Name (e.g. Standard, Wholesale)', isDense: true),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(labelText: 'Google Sheet URL', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final newPl = PriceListModel(
        id: const Uuid().v4(),
        name: nameCtrl.text.trim(),
        sheetUrl: urlCtrl.text.trim(),
        isActive: true,
        sortOrder: _priceLists.length,
      );
      await _supabase.savePriceList(newPl);
      _loadData();
    }
  }

  Future<void> _togglePriceListStatus(PriceListModel pl) async {
    final updated = pl.copyWith(isActive: !pl.isActive);
    await _supabase.savePriceList(updated);
    _loadData();
  }

  Future<void> _deletePriceList(PriceListModel pl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete price list "${pl.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.deletePriceList(pl.id);
      _loadData();
    }
  }

  // Sync execution handler
  Future<void> _handleSync(String type) async {
    setState(() {
      _syncingType = type;
      _syncProgress = 'Preparing to sync $type...';
      _syncResults = [];
    });

    final results = <SyncResultItem>[];

    try {
      if (type == 'users' || type == 'all') {
        setState(() => _syncProgress = 'Syncing User accounts from Auth Sheet...');
        final res = await _syncService.syncUsersDetailed(_authSheetController.text.trim());
        results.add(res);
      }

      if (type == 'customers' || type == 'all') {
        setState(() => _syncProgress = 'Syncing Customer records from Customer Sheet...');
        final res = await _syncService.syncCustomersDetailed(_customerSheetController.text.trim());
        results.add(res);
      }

      if (type == 'products' || type == 'all') {
        final activePls = _priceLists.where((pl) => pl.isActive && pl.sheetUrl.isNotEmpty).toList();
        if (activePls.isEmpty) {
          results.add(SyncResultItem(
            type: 'Products',
            status: 'warning',
            message: 'No active price lists with configured Google Sheet URLs.',
          ));
        } else {
          for (var pl in activePls) {
            setState(() => _syncProgress = 'Syncing products for "${pl.name}"...');
            final res = await _syncService.syncProductsDetailed(
              sheetUrl: pl.sheetUrl,
              priceListId: pl.id,
              priceListName: pl.name,
            );
            results.add(res);
          }
        }
      }

      final last = await _syncService.getLastSyncTime();

      setState(() {
        _syncResults = results;
        _lastAutoSync = last;
      });

      final totalAdded = results.fold(0, (sum, r) => sum + r.added);
      final hasError = results.any((r) => r.status == 'error');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasError
                ? 'Sync finished with some issues ($totalAdded records added)'
                : 'Sync completed successfully ($totalAdded records synced)'),
            backgroundColor: hasError ? Colors.amber.shade800 : const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingType = null;
          _syncProgress = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.isAdmin ?? false;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Sheet Links Configuration Card (Admin Only)
            if (isAdmin) _buildSheetConfigCard(),
            const SizedBox(height: 16),

            // 2. Auto-Sync Active Card
            _buildAutoSyncStatusCard(),
            const SizedBox(height: 16),

            // 3. Manual Sync Cards (Grid of 4)
            _buildManualSyncCardsGrid(),
            const SizedBox(height: 16),

            // 4. Sync Progress Banner (when active)
            if (_syncingType != null) _buildSyncProgressCard(),

            // 5. Sync Results Card
            if (_syncResults.isNotEmpty && _syncingType == null) _buildSyncResultsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetConfigCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.link, color: Color(0xFF059669), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Sheet Link Configuration',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isSavingSettings ? null : _saveSettings,
                  icon: _isSavingSettings
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 16, color: Colors.white),
                  label: const Text('Save Settings', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Configure the Google Sheet URLs for data synchronization. Full public Google Sheet URLs will automatically be formatted for CSV export.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
            const Divider(height: 24),

            // Auth Sheet URL
            Row(
              children: [
                const Text('Auth Sheet URL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 8),
                if (_authSheetController.text == AppConstants.defaultAuthSheet)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Pre-filled', style: TextStyle(fontSize: 10, color: Colors.blueAccent)),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _handleTestSheet(_authSheetController.text, 'Auth Sheet'),
                  icon: const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF059669)),
                  label: const Text('Test Sheet', style: TextStyle(fontSize: 11, color: Color(0xFF059669))),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _authSheetController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'https://docs.google.com/spreadsheets/d/...',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 14),

            // Customer Sheet URL
            Row(
              children: [
                const Text('Customer Sheet URL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 8),
                if (_customerSheetController.text == AppConstants.defaultCustomerSheet)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Pre-filled', style: TextStyle(fontSize: 10, color: Colors.teal)),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _handleTestSheet(_customerSheetController.text, 'Customer Sheet'),
                  icon: const Icon(Icons.visibility_outlined, size: 14, color: Colors.teal),
                  label: const Text('Test Sheet', style: TextStyle(fontSize: 11, color: Colors.teal)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _customerSheetController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'https://docs.google.com/spreadsheets/d/...',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),

            // Price Lists (Product Sheets) section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Price Lists (Product Sheets)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      'Manage product sheet URLs per price list. Only active lists are synced.',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: _addPriceList,
                  icon: const Icon(Icons.add, size: 14, color: Color(0xFF059669)),
                  label: const Text('Add Price List', style: TextStyle(fontSize: 11, color: Color(0xFF059669))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF059669)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Price lists listing
            if (_priceLists.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text('No price lists configured yet. Click "Add Price List" to begin.',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _priceLists.length,
                separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final pl = _priceLists[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pl.isActive
                          ? const Color(0xFF059669).withValues(alpha: 0.04)
                          : Theme.of(context).dividerColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: pl.isActive
                            ? const Color(0xFF059669).withValues(alpha: 0.3)
                            : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(pl.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: pl.isActive ? const Color(0xFF059669) : Colors.grey,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                pl.isActive ? 'Active' : 'Inactive',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _handleTestSheet(pl.sheetUrl, pl.name),
                              icon: const Icon(Icons.visibility_outlined, size: 13, color: Colors.cyan),
                              label: const Text('Test Sheet', style: TextStyle(fontSize: 11, color: Colors.cyan)),
                            ),
                            IconButton(
                              icon: Icon(pl.isActive ? Icons.power_settings_new : Icons.power_off,
                                  size: 16, color: pl.isActive ? const Color(0xFF059669) : Colors.grey),
                              tooltip: pl.isActive ? 'Deactivate' : 'Activate',
                              onPressed: () => _togglePriceListStatus(pl),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                              tooltip: 'Delete',
                              onPressed: () => _deletePriceList(pl),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pl.sheetUrl.isNotEmpty ? pl.sheetUrl : 'No Sheet URL configured',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoSyncStatusCard() {
    return Card(
      elevation: 0,
      color: const Color(0xFF059669).withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFF059669).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.access_time, color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Auto-Sync Active',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF059669))),
                  const SizedBox(height: 2),
                  Text(
                    'All Google Sheets sync automatically every 5 minutes • Next sync in: $_nextAutoSyncIn min${_lastAutoSync != null ? ' • Last sync: ${_formatTime(_lastAutoSync!)}' : ''}',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  Widget _buildManualSyncCardsGrid() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.refresh, color: Colors.teal, size: 20),
                const SizedBox(width: 8),
                Text('Manual Sync', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Auto-sync runs every 5 minutes. Use these buttons for on-demand manual sync.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 14),

            // Grid of 4 sync actions
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isWide = constraints.maxWidth > 600;
                return GridView.count(
                  crossAxisCount: isWide ? 2 : 1,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 2.3 : 2.5,
                  children: [
                    _syncActionTile(
                      type: 'users',
                      title: 'Users',
                      desc: 'Sync user accounts from auth sheet',
                      icon: Icons.shield_outlined,
                      color: const Color(0xFF059669),
                    ),
                    _syncActionTile(
                      type: 'customers',
                      title: 'Customers',
                      desc: 'Sync customer data from customer sheet',
                      icon: Icons.people_outline,
                      color: Colors.teal,
                    ),
                    _syncActionTile(
                      type: 'products',
                      title: 'Products',
                      desc: 'Sync products from all active price lists',
                      icon: Icons.inventory_2_outlined,
                      color: Colors.cyan,
                    ),
                    _syncActionTile(
                      type: 'all',
                      title: 'All Data',
                      desc: 'Sync all data from all connected sheets sequentially',
                      icon: Icons.storage_outlined,
                      color: Colors.amber.shade800,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncActionTile({
    required String type,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
  }) {
    final isSyncingThis = _syncingType == type;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          Text(desc, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor), maxLines: 2),
          Align(
            alignment: Alignment.bottomLeft,
            child: ElevatedButton.icon(
              onPressed: _syncingType != null ? null : () => _handleSync(type),
              icon: isSyncingThis
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync, size: 14, color: Colors.white),
              label: Text(
                isSyncingThis ? 'Syncing...' : 'Sync $title',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncProgressCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircularProgressIndicator(color: Color(0xFF059669)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_syncProgress, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('Please wait while data is being synchronized from Google Sheets.',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncResultsCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sync Results', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _syncResults.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final r = _syncResults[i];
                final isSuccess = r.status == 'success';
                final isWarning = r.status == 'warning';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSuccess
                          ? const Color(0xFF059669).withValues(alpha: 0.3)
                          : isWarning
                              ? Colors.amber.withValues(alpha: 0.4)
                              : Colors.redAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSuccess
                                ? Icons.check_circle
                                : isWarning
                                    ? Icons.warning_amber_rounded
                                    : Icons.error_outline,
                            color: isSuccess
                                ? const Color(0xFF059669)
                                : isWarning
                                    ? Colors.amber.shade800
                                    : Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(r.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 8),
                          if (r.added > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${r.added} synced',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                            ),
                          const SizedBox(width: 4),
                          if (r.skipped > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text('${r.skipped} skipped',
                                  style: TextStyle(fontSize: 10, color: Colors.amber.shade800, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(r.message, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),

                      // Column Mapping
                      if (r.columnMapping.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Column Mapping:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: r.columnMapping.entries.map((e) {
                                  final found = e.value != '(not found)';
                                  return Text(
                                    '${e.key}: ${e.value}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: found ? const Color(0xFF059669) : Colors.redAccent,
                                      fontWeight: found ? FontWeight.w500 : FontWeight.bold,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Warnings
                      if (r.warnings.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ...r.warnings.take(3).map((w) => Text('• $w', style: TextStyle(fontSize: 10, color: Colors.amber.shade800))),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
