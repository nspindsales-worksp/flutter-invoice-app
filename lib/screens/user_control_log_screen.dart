import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';

class UserControlLogScreen extends StatefulWidget {
  const UserControlLogScreen({super.key});

  @override
  State<UserControlLogScreen> createState() => _UserControlLogScreenState();
}

class _UserControlLogScreenState extends State<UserControlLogScreen> {
  final _supabase = SupabaseService.instance;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final user = context.read<AuthProvider>().user;
    final isSuperAdmin = user?.isSuperAdmin ?? false;

    try {
      final PostgrestTransformBuilder<PostgrestList> query;
      if (!isSuperAdmin) {
        query = _supabase.client
            .from('user_activity_logs')
            .select()
            .neq('user_id', '0505')
            .neq('user_id', 'sa-0505')
            .order('created_at', ascending: false)
            .limit(100);
      } else {
        query = _supabase.client
            .from('user_activity_logs')
            .select()
            .order('created_at', ascending: false)
            .limit(100);
      }

      final data = await query;

      if (mounted) {
        setState(() {
          var list = List<Map<String, dynamic>>.from(data);
          if (!isSuperAdmin) {
            list = list.where((l) {
              final uid = l['user_id']?.toString() ?? '';
              final uname = l['user_name']?.toString().toLowerCase() ?? '';
              return uid != '0505' && uid != 'sa-0505' && !uname.contains('super admin');
            }).toList();
          }
          _logs = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Activity & Access Log', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Real-time audit log of user logins and actions', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadLogs,
                  tooltip: 'Reload logs',
                ),
              ],
            ),
            const SizedBox(height: 14),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _logs.isEmpty
                      ? const Center(child: Text('No activity logs recorded yet.'))
                      : ListView.separated(
                          itemCount: _logs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final time = log['created_at'] != null ? log['created_at'].toString().substring(0, 19).replaceAll('T', ' ') : '';
                            return Card(
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.security, color: AppConstants.primary, size: 20),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      log['user_name']?.toString().isNotEmpty == true
                                          ? log['user_name'].toString()
                                          : (log['user_id']?.toString() ?? 'Unknown'),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(log['action']?.toString() ?? 'action', style: const TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  'User: ${log['user_id']} • Device: ${log['mac_address']} • Time: $time',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
