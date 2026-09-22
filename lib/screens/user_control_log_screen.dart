import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';

class UserControlLogScreen extends StatefulWidget {
  const UserControlLogScreen({super.key});

  @override
  State<UserControlLogScreen> createState() => _UserControlLogScreenState();
}

class _UserControlLogScreenState extends State<UserControlLogScreen> with SingleTickerProviderStateMixin {
  final _supabase = SupabaseService.instance;
  late TabController _tabController;

  // Tab 1: Activity Logs
  List<Map<String, dynamic>> _logs = [];
  bool _logsLoading = true;
  final _filterUserIdCtrl = TextEditingController();
  final _filterIpCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  int _logPage = 1;
  static const int _pageSize = 25;

  // Tab 2: Blocked Entities
  List<Map<String, dynamic>> _blockedEntities = [];
  bool _blockedLoading = true;
  final _blockedSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLogs();
    _loadBlockedEntities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _filterUserIdCtrl.dispose();
    _filterIpCtrl.dispose();
    _blockedSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _logsLoading = true);
    final user = context.read<AuthProvider>().user;
    final isSuperAdmin = user?.isSuperAdmin ?? false;

    try {
      var query = _supabase.client.from('user_activity_logs').select();

      if (!isSuperAdmin) {
        query = query.neq('user_id', '0505').neq('user_id', 'sa-0505');
      }

      if (_filterUserIdCtrl.text.trim().isNotEmpty) {
        query = query.ilike('user_id', '%${_filterUserIdCtrl.text.trim()}%');
      }
      if (_filterIpCtrl.text.trim().isNotEmpty) {
        query = query.ilike('ip_address', '%${_filterIpCtrl.text.trim()}%');
      }
      if (_startDate != null) {
        query = query.gte('created_at', _startDate!.toIso8601String());
      }
      if (_endDate != null) {
        query = query.lte('created_at', _endDate!.add(const Duration(days: 1)).toIso8601String());
      }

      final data = await query.order('created_at', ascending: false).limit(200);

      var list = List<Map<String, dynamic>>.from(data);
      if (!isSuperAdmin) {
        list = list.where((l) {
          final uid = l['user_id']?.toString() ?? '';
          final uname = l['user_name']?.toString().toLowerCase() ?? '';
          return uid != '0505' && uid != 'sa-0505' && !uname.contains('super admin');
        }).toList();
      }

      if (mounted) {
        setState(() {
          _logs = list;
          _logsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _logsLoading = false);
    }
  }

  Future<void> _loadBlockedEntities() async {
    setState(() => _blockedLoading = true);
    try {
      final data = await _supabase.client.from('blocked_entities').select().order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _blockedEntities = List<Map<String, dynamic>>.from(data);
          _blockedLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _blockedLoading = false);
    }
  }

  Future<void> _clearLogs() async {
    final authUser = context.read<AuthProvider>().user;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Activity Logs'),
        content: const Text('Are you sure you want to clear the activity logs? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final isSuperAdmin = authUser?.isSuperAdmin ?? false;

        if (isSuperAdmin) {
          await _supabase.client.from('user_activity_logs').delete().neq('id', '');
        } else {
          await _supabase.client.from('user_activity_logs').delete().neq('user_id', '0505').neq('user_id', 'sa-0505');
        }
        _loadLogs();
      } catch (_) {}
    }
  }

  void _showAddBlockDialog() {
    String entityType = 'user_id';
    final valCtrl = TextEditingController();
    String status = 'blocked';
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text('Block Entity', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Entity Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: entityType,
                    isDense: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'user_id', child: Text('User ID')),
                      DropdownMenuItem(value: 'ip_address', child: Text('IP Address')),
                      DropdownMenuItem(value: 'mac_address', child: Text('MAC Address / Device ID')),
                    ],
                    onChanged: (v) => setDlgState(() => entityType = v ?? 'user_id'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Entity Value (e.g. user ID, IP address, MAC)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    isDense: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'blocked', child: Text('Blocked (Full Deny)')),
                      DropdownMenuItem(value: 'suspended', child: Text('Suspended (Temporary)')),
                      DropdownMenuItem(value: 'allowed', child: Text('Allowed (Whitelist)')),
                    ],
                    onChanged: (v) => setDlgState(() => status = v ?? 'blocked'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Reason for blocking/restriction',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                if (valCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                final id = const Uuid().v4();
                await _supabase.client.from('blocked_entities').insert({
                  'id': id,
                  'entity_type': entityType,
                  'entity_value': valCtrl.text.trim(),
                  'status': status,
                  'reason': reasonCtrl.text.trim(),
                  'blocked_by': auth.user?.userId ?? 'Admin',
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                });
                _loadBlockedEntities();
              },
              child: const Text('Block Entity', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeStatusDialog(Map<String, dynamic> item) {
    String status = item['status']?.toString() ?? 'blocked';
    final reasonCtrl = TextEditingController(text: item['reason']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Change Status: ${item["entity_value"]}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                initialValue: status,
                isDense: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                  DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                  DropdownMenuItem(value: 'allowed', child: Text('Allowed')),
                ],
                onChanged: (v) => setDlgState(() => status = v ?? 'blocked'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Reason', isDense: true, border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              onPressed: () async {
                Navigator.pop(ctx);
                await _supabase.client.from('blocked_entities').update({
                  'status': status,
                  'reason': reasonCtrl.text.trim(),
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', item['id']);
                _loadBlockedEntities();
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBlockedEntity(String id) async {
    await _supabase.client.from('blocked_entities').delete().eq('id', id);
    _loadBlockedEntities();
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
            Text('Activity Log Details: ${log["action"] ?? "Action"}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('User ID', log['user_id']?.toString() ?? 'N/A'),
              _detailRow('User Name', log['user_name']?.toString() ?? 'N/A'),
              _detailRow('Action', log['action']?.toString() ?? 'N/A'),
              _detailRow('Timestamp', log['created_at'] != null ? _formatDate(log['created_at']) : 'N/A'),
              _detailRow('IP Address', log['ip_address']?.toString() ?? 'N/A'),
              _detailRow('MAC / Device ID', log['mac_address']?.toString() ?? 'N/A'),
              _detailRow('User Agent', log['user_agent']?.toString() ?? 'Flutter Application'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Color _getActionColor(String action) {
    final a = action.toUpperCase();
    if (a.contains('LOGIN')) return const Color(0xFF059669);
    if (a.contains('LOGOUT')) return Colors.grey;
    if (a.contains('CREATE')) return Colors.blueAccent;
    if (a.contains('DELETE')) return Colors.redAccent;
    if (a.contains('SYNC')) return Colors.amber.shade800;
    return Colors.teal;
  }

  Color _getStatusBadgeColor(String status) {
    switch (status.toLowerCase()) {
      case 'blocked':
        return Colors.redAccent;
      case 'suspended':
        return Colors.orange;
      case 'allowed':
        return const Color(0xFF059669);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Theme.of(context).cardColor,
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF059669),
            labelColor: const Color(0xFF059669),
            tabs: const [
              Tab(icon: Icon(Icons.history, size: 18), text: 'Activity Logs'),
              Tab(icon: Icon(Icons.block, size: 18), text: 'Blocked List'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActivityLogsTab(),
          _buildBlockedListTab(),
        ],
      ),
    );
  }

  Widget _buildActivityLogsTab() {
    if (_logsLoading) return const Center(child: CircularProgressIndicator());

    final totalPages = (_logs.length / _pageSize).ceil().clamp(1, 9999);
    final startIndex = (_logPage - 1) * _pageSize;
    final currentLogs = _logs.skip(startIndex).take(_pageSize).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Bar
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _filterUserIdCtrl,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(labelText: 'Filter by User ID', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _filterIpCtrl,
                          style: const TextStyle(fontSize: 12),
                          decoration: const InputDecoration(labelText: 'Filter by IP', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _logPage = 1);
                          _loadLogs();
                        },
                        icon: const Icon(Icons.search, size: 14, color: Colors.white),
                        label: const Text('Search', style: TextStyle(color: Colors.white, fontSize: 11)),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () {
                          _filterUserIdCtrl.clear();
                          _filterIpCtrl.clear();
                          _startDate = null;
                          _endDate = null;
                          setState(() => _logPage = 1);
                          _loadLogs();
                        },
                        child: const Text('Reset', style: TextStyle(fontSize: 11)),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18),
                        tooltip: 'Refresh',
                        onPressed: _loadLogs,
                      ),
                      OutlinedButton.icon(
                        onPressed: _clearLogs,
                        icon: const Icon(Icons.delete_sweep, size: 14, color: Colors.redAccent),
                        label: const Text('Clear Logs', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Logs Table
          if (_logs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('No activity logs found matching the filter criteria.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                constraints: const BoxConstraints(minWidth: 800),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
                ),
                child: DataTable(
                  columnSpacing: 16,
                  headingRowHeight: 38,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 52,
                  columns: const [
                    DataColumn(label: Text('Timestamp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('IP Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Device / MAC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: currentLogs.map((l) {
                    final action = l['action']?.toString() ?? '';
                    final actionColor = _getActionColor(action);

                    return DataRow(
                      cells: [
                        DataCell(Text(l['created_at'] != null ? _formatDate(l['created_at']) : '—', style: const TextStyle(fontSize: 11))),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(l['user_name']?.toString() ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text('ID: ${l["user_id"] ?? "—"}', style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                            ],
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: actionColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              action,
                              style: TextStyle(color: actionColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        DataCell(Text(l['ip_address']?.toString().isNotEmpty == true ? l['ip_address'] : '127.0.0.1', style: const TextStyle(fontSize: 11))),
                        DataCell(Text(l['mac_address']?.toString().isNotEmpty == true ? l['mac_address'] : 'Mobile Device', style: const TextStyle(fontSize: 11))),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.info_outline, size: 16, color: Colors.blueAccent),
                            tooltip: 'View Details',
                            onPressed: () => _showLogDetails(l),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Pagination
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: ${_logs.length} logs (Page $_logPage of $totalPages)', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _logPage > 1 ? () => setState(() => _logPage--) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _logPage < totalPages ? () => setState(() => _logPage++) : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockedListTab() {
    if (_blockedLoading) return const Center(child: CircularProgressIndicator());

    final term = _blockedSearchCtrl.text.toLowerCase().trim();
    final filtered = term.isEmpty
        ? _blockedEntities
        : _blockedEntities.where((b) {
            final val = b['entity_value']?.toString().toLowerCase() ?? '';
            final reason = b['reason']?.toString().toLowerCase() ?? '';
            return val.contains(term) || reason.contains(term);
          }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Text('Blocked & Restricted Entities', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddBlockDialog,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text('Block Entity', style: TextStyle(color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search
          TextField(
            controller: _blockedSearchCtrl,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Search blocked entities by value or reason...',
              prefixIcon: Icon(Icons.search, size: 16),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),

          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('No blocked entities found. Click "Block Entity" to add restrictions.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = filtered[i];
                final status = item['status']?.toString() ?? 'blocked';
                final statusColor = _getStatusBadgeColor(status);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Icon(Icons.block, color: statusColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(item['entity_value']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    (item['entity_type']?.toString() ?? 'user_id').replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(fontSize: 9, color: Colors.blueAccent),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('Reason: ${item["reason"]?.toString().isNotEmpty == true ? item["reason"] : "No reason provided"} • By: ${item["blocked_by"] ?? "Admin"}',
                                style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (val) {
                          if (val == 'status') _showChangeStatusDialog(item);
                          if (val == 'delete') _deleteBlockedEntity(item['id']?.toString() ?? '');
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'status', child: Text('Change Status')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete / Unblock', style: TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
