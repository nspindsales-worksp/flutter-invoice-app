import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../core/utils.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _supabase = SupabaseService.instance;

  List<UserModel> _users = [];
  Map<String, bool> _features = {'createInvoice': true, 'invoiceHistory': true};
  SettingsModel _settings = SettingsModel();

  // Settings Controllers
  final _companyNameCtrl = TextEditingController();
  final _companyAddressCtrl = TextEditingController();
  final _companyMobileCtrl = TextEditingController();
  final _invoicePrefixCtrl = TextEditingController(text: 'INV');
  final _invoiceTitleCtrl = TextEditingController();
  final _challanTitleCtrl = TextEditingController();
  final _invoiceFooterCtrl = TextEditingController();
  final _challanFooterCtrl = TextEditingController();
  final _challanFooterLine2Ctrl = TextEditingController();
  final _marginTopCtrl = TextEditingController();
  final _marginBottomCtrl = TextEditingController();
  final _marginLeftCtrl = TextEditingController();
  final _marginRightCtrl = TextEditingController();
  final _retentionDaysCtrl = TextEditingController(text: '30');

  // Super Admin: Footer Customization
  bool _footerCustomEnabled = true;
  final _footerTextCtrl = TextEditingController(text: 'Developed By R@Z - 01913539860');

  bool _showPreparedBy = true;
  bool _isLoading = true;
  bool _isSavingPdfSettings = false;
  bool _isSavingRetention = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _companyNameCtrl.dispose();
    _companyAddressCtrl.dispose();
    _companyMobileCtrl.dispose();
    _invoicePrefixCtrl.dispose();
    _invoiceTitleCtrl.dispose();
    _challanTitleCtrl.dispose();
    _invoiceFooterCtrl.dispose();
    _challanFooterCtrl.dispose();
    _challanFooterLine2Ctrl.dispose();
    _marginTopCtrl.dispose();
    _marginBottomCtrl.dispose();
    _marginLeftCtrl.dispose();
    _marginRightCtrl.dispose();
    _retentionDaysCtrl.dispose();
    _footerTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    final authUser = context.read<AuthProvider>().user;
    final isSuperAdmin = authUser?.isSuperAdmin ?? false;

    try {
      final u = await _supabase.getUsers(isSuperAdmin: isSuperAdmin);
      final f = await _supabase.getAdminFeatures();
      final s = await _supabase.getSettings();

      _users = u;
      _features = f;
      _settings = s;

      _companyNameCtrl.text = s.companyName;
      _companyAddressCtrl.text = s.companyAddress;
      _companyMobileCtrl.text = s.companyMobile;
      _invoiceTitleCtrl.text = s.invoiceTitle;
      _challanTitleCtrl.text = s.challanTitle;
      _invoiceFooterCtrl.text = s.invoiceFooterText;
      _challanFooterCtrl.text = s.challanFooterText;
      _showPreparedBy = s.showPreparedBy;
      _marginTopCtrl.text = s.marginTop.toStringAsFixed(0);
      _marginBottomCtrl.text = s.marginBottom.toStringAsFixed(0);
      _marginLeftCtrl.text = s.marginLeft.toStringAsFixed(0);
      _marginRightCtrl.text = s.marginRight.toStringAsFixed(0);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFeature(String key) async {
    final current = _features[key] ?? true;
    final updated = !current;
    setState(() => _features[key] = updated);
    await _supabase.updateAdminFeature(key, updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${key == "createInvoice" ? "Create Invoice" : "Invoice History"} ${updated ? "enabled" : "disabled"} for Users'),
          backgroundColor: updated ? const Color(0xFF059669) : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _savePdfSettings() async {
    setState(() => _isSavingPdfSettings = true);
    try {
      final updated = _settings.copyWith(
        companyName: _companyNameCtrl.text.trim(),
        companyAddress: _companyAddressCtrl.text.trim(),
        companyMobile: _companyMobileCtrl.text.trim(),
        invoiceTitle: _invoiceTitleCtrl.text.trim(),
        challanTitle: _challanTitleCtrl.text.trim(),
        invoiceFooterText: _invoiceFooterCtrl.text.trim(),
        challanFooterText: _challanFooterCtrl.text.trim(),
        showPreparedBy: _showPreparedBy,
        marginTop: AppUtils.parseDouble(_marginTopCtrl.text, 40.0),
        marginBottom: AppUtils.parseDouble(_marginBottomCtrl.text, 40.0),
        marginLeft: AppUtils.parseDouble(_marginLeftCtrl.text, 40.0),
        marginRight: AppUtils.parseDouble(_marginRightCtrl.text, 40.0),
      );

      await _supabase.saveSettings(updated);
      setState(() => _settings = updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF & Invoice settings saved successfully!'),
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
      if (mounted) setState(() => _isSavingPdfSettings = false);
    }
  }

  Future<void> _saveRetentionDays() async {
    setState(() => _isSavingRetention = true);
    try {
      final days = int.tryParse(_retentionDaysCtrl.text) ?? 30;
      await _supabase.client.from('system_settings').upsert({
        'key': 'invoice_retention_days',
        'value': days.toString(),
      }, onConflict: 'key');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retention set to $days days!'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingRetention = false);
    }
  }

  void _showAddUserDialog() {
    final userIdCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    String role = 'User';
    String durationHours = '0'; // 0 = permanent

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add_outlined, color: Color(0xFF059669), size: 20),
              SizedBox(width: 8),
              Text('Add New User', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: userIdCtrl,
                    decoration: const InputDecoration(labelText: 'User ID (Login Username) *', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password *', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: mobileCtrl,
                    decoration: const InputDecoration(labelText: 'Mobile Phone', isDense: true),
                  ),
                  const SizedBox(height: 14),

                  // Role selector
                  const Text('Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    isDense: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'User', child: Text('User')),
                      DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                    ],
                    onChanged: (v) => setDlgState(() => role = v ?? 'User'),
                  ),
                  const SizedBox(height: 14),

                  // Temporary user expiry selector
                  const Text('Account Duration (Temporary Expiry)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: durationHours,
                    isDense: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: '0', child: Text('Permanent (No Expiry)')),
                      DropdownMenuItem(value: '1', child: Text('1 Hour')),
                      DropdownMenuItem(value: '6', child: Text('6 Hours')),
                      DropdownMenuItem(value: '12', child: Text('12 Hours')),
                      DropdownMenuItem(value: '24', child: Text('24 Hours (1 Day)')),
                      DropdownMenuItem(value: '48', child: Text('48 Hours (2 Days)')),
                      DropdownMenuItem(value: '72', child: Text('72 Hours (3 Days)')),
                    ],
                    onChanged: (v) => setDlgState(() => durationHours = v ?? '0'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              onPressed: () async {
                if (userIdCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ID and Password are required')));
                  return;
                }
                Navigator.pop(ctx);

                DateTime? expiresAt;
                final hrs = int.tryParse(durationHours) ?? 0;
                if (hrs > 0) {
                  expiresAt = DateTime.now().add(Duration(hours: hrs));
                }

                final newUser = UserModel(
                  id: const Uuid().v4(),
                  userId: userIdCtrl.text.trim(),
                  password: AppUtils.hashPassword(passCtrl.text.trim()),
                  name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : userIdCtrl.text.trim(),
                  role: role,
                  mobile: mobileCtrl.text.trim(),
                  isSystem: false,
                  isLocal: true,
                  expiresAt: expiresAt,
                );

                await _supabase.saveUser(newUser);
                _loadAll();
              },
              child: const Text('Add User', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final mobileCtrl = TextEditingController(text: user.mobile);
    final passCtrl = TextEditingController();
    String role = user.role;
    final isSuperAdmin = context.read<AuthProvider>().user?.isSuperAdmin ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Edit User: ${user.userId}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile', isDense: true)),
              const SizedBox(height: 10),
              TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New Password (leave empty to keep current)', isDense: true)),
              if (isSuperAdmin) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'User', child: Text('User')),
                    DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                  ],
                  onChanged: (v) => setDlgState(() => role = v ?? role),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              onPressed: () async {
                Navigator.pop(ctx);
                final updated = user.copyWith(
                  name: nameCtrl.text.trim(),
                  mobile: mobileCtrl.text.trim(),
                  role: role,
                  password: passCtrl.text.trim().isNotEmpty ? AppUtils.hashPassword(passCtrl.text.trim()) : user.password,
                );
                await _supabase.saveUser(updated);
                _loadAll();
              },
              child: const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUser(UserModel u) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete User'),
        content: Text('Are you sure you want to delete user "${u.userId}"?'),
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
      await _supabase.deleteUser(u.userId);
      _loadAll();
    }
  }

  String _formatExpiry(DateTime? expiresAt) {
    if (expiresAt == null) return 'Permanent';
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inHours > 24) return '${diff.inDays}d ${diff.inHours % 24}h';
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider>().user;
    final isSuperAdmin = authUser?.isSuperAdmin ?? false;
    final app = context.read<AppProvider>();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings, color: Colors.redAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin Settings', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Manage feature permissions, PDF layout, and user accounts',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                      ],
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => app.setPage(AppPage.pdfDesigner),
                  icon: const Icon(Icons.palette_outlined, size: 16),
                  label: const Text('PDF Designer'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Feature Permissions Card
            _buildFeaturePermissionsCard(),
            const SizedBox(height: 16),

            // PDF & Invoice Settings Card
            _buildPdfSettingsCard(),
            const SizedBox(height: 16),

            // Invoice Retention Card
            _buildRetentionCard(),
            const SizedBox(height: 16),

            // User Management Card
            _buildUserManagementCard(isSuperAdmin),

            // Super Admin Only: Footer Customization & System Info
            if (isSuperAdmin) ...[
              const SizedBox(height: 16),
              _buildFooterCustomizationCard(),
              const SizedBox(height: 16),
              _buildSystemInfoCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePermissionsCard() {
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
                const Icon(Icons.shield_outlined, color: Color(0xFF059669), size: 20),
                const SizedBox(width: 8),
                Text('Feature Permissions', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Control which features are available to regular Users. Admins and Super Admins always have all features enabled.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
            const Divider(height: 20),

            // Toggle 1: Create Invoice
            _featureTile(
              key: 'createInvoice',
              label: 'Create Invoice',
              icon: Icons.post_add,
              enabled: _features['createInvoice'] ?? true,
            ),
            const SizedBox(height: 10),

            // Toggle 2: Invoice History
            _featureTile(
              key: 'invoiceHistory',
              label: 'Invoice History',
              icon: Icons.history,
              enabled: _features['invoiceHistory'] ?? true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureTile({
    required String key,
    required String label,
    required IconData icon,
    required bool enabled,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: enabled ? const Color(0xFF059669).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: enabled ? const Color(0xFF059669) : Colors.redAccent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  enabled ? 'Enabled for all Users' : 'Disabled for Users (Admins still have access)',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: const Color(0xFF059669),
            onChanged: (_) => _toggleFeature(key),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfSettingsCard() {
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
                    const Icon(Icons.picture_as_pdf_outlined, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text('PDF & Invoice Settings', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isSavingPdfSettings ? null : _savePdfSettings,
                  icon: _isSavingPdfSettings
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 16, color: Colors.white),
                  label: const Text('Save Settings', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Customize company header, footer notices, invoice titles, and page margins.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            const Divider(height: 20),

            // Company Header
            const Text('Company Header (shown at top of PDFs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _companyNameCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(labelText: 'Company Name', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _companyMobileCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(labelText: 'Company Phone', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _companyAddressCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(labelText: 'Company Address', isDense: true, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // Invoice Title & Footer
            const Text('Invoice PDF Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _invoiceTitleCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(labelText: 'Invoice Title', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _invoiceFooterCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(labelText: 'Invoice Footer Text', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Challan Settings
            const Text('Challan / Delivery Order PDF Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _challanTitleCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(labelText: 'Challan Title', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _challanFooterLine2Ctrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(labelText: 'Challan Footer Line 2', isDense: true, border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _challanFooterCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(labelText: 'Challan Footer Notice', isDense: true, border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // Margins
            const Text('Page Margins (in points, 1 inch = 72pt)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _marginTopCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Top', isDense: true, border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _marginBottomCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bottom', isDense: true, border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _marginLeftCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Left', isDense: true, border: OutlineInputBorder()))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _marginRightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Right', isDense: true, border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 14),

            // Show prepared by
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Show "Prepared By" Section', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Display the preparer name and ID on printed documents', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Switch(
                  value: _showPreparedBy,
                  activeThumbColor: const Color(0xFF059669),
                  onChanged: (v) => setState(() => _showPreparedBy = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.timer_outlined, color: Colors.orange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invoice History Save Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Set how long (days) invoices are kept before cleanup (0 = keep forever)', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: TextField(
                controller: _retentionDaysCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(isDense: true, suffixText: 'd', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: _isSavingRetention ? null : _saveRetentionDays,
              child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagementCard(bool isSuperAdmin) {
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
                    const Icon(Icons.people_alt_outlined, color: Colors.teal, size: 20),
                    const SizedBox(width: 8),
                    Text('User Management', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddUserDialog,
                  icon: const Icon(Icons.person_add, size: 16, color: Colors.white),
                  label: const Text('Add User', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Create, edit, and manage user accounts. Temporary users will expire automatically.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            const Divider(height: 20),

            // Users list
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _users.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final u = _users[i];
                final isSA = u.isSuperAdmin || u.userId == '0505';
                final isExpired = u.expiresAt != null && u.expiresAt!.isBefore(DateTime.now());

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: isSA
                            ? Colors.purple.withValues(alpha: 0.2)
                            : u.role == 'Admin'
                                ? const Color(0xFF059669).withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.2),
                        child: Text(
                          (u.name.isNotEmpty ? u.name : u.userId).substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSA
                                ? Colors.purple
                                : u.role == 'Admin'
                                    ? const Color(0xFF059669)
                                    : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(u.name.isNotEmpty ? u.name : u.userId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isSA
                                        ? Colors.purple.withValues(alpha: 0.15)
                                        : u.role == 'Admin'
                                            ? const Color(0xFF059669).withValues(alpha: 0.15)
                                            : Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    u.role,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSA ? Colors.purple : u.role == 'Admin' ? const Color(0xFF059669) : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                if (u.isLocal) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                    child: const Text('Local', style: TextStyle(fontSize: 10, color: Colors.blueAccent)),
                                  ),
                                ],
                                if (u.expiresAt != null) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isExpired ? Colors.red.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.timer_outlined, size: 10, color: isExpired ? Colors.redAccent : Colors.orange.shade800),
                                        const SizedBox(width: 3),
                                        Text(
                                          _formatExpiry(u.expiresAt),
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isExpired ? Colors.redAccent : Colors.orange.shade800),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('ID: ${u.userId}${u.mobile.isNotEmpty ? " • ${u.mobile}" : ""}',
                                style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                          ],
                        ),
                      ),
                      if (!isSA || isSuperAdmin) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          tooltip: 'Edit User',
                          onPressed: () => _showEditUserDialog(u),
                        ),
                        if (!isSA)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                            tooltip: 'Delete User',
                            onPressed: () => _deleteUser(u),
                          ),
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

  Widget _buildFooterCustomizationCard() {
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
                const Icon(Icons.branding_watermark_outlined, color: Colors.pinkAccent, size: 20),
                const SizedBox(width: 8),
                Text('Footer Customization (Super Admin)', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Customize the public footer branding text and color scheme across light and dark modes.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
            const Divider(height: 20),
            Row(
              children: [
                const Text('Enable Custom Footer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                Switch(
                  value: _footerCustomEnabled,
                  activeThumbColor: Colors.pinkAccent,
                  onChanged: (v) => setState(() => _footerCustomEnabled = v),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _footerTextCtrl,
              decoration: const InputDecoration(labelText: 'Footer Text', isDense: true, border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            if (_footerCustomEnabled) ...[
              const SizedBox(height: 14),
              const Text('Theme Previews', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF1818F0)),
                      ),
                      child: Text(
                        _footerTextCtrl.text.isNotEmpty ? _footerTextCtrl.text : 'Footer Text',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF1818F0), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF33FFC9)),
                      ),
                      child: Text(
                        _footerTextCtrl.text.isNotEmpty ? _footerTextCtrl.text : 'Footer Text',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF33FFC9), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfoCard() {
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
                const Icon(Icons.storage_outlined, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                Text('System & Storage Info (Super Admin)', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Database Provider', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Chip(label: const Text('Supabase Cloud', style: TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Client Application', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                Chip(label: const Text('Flutter (Android + Web)', style: TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
