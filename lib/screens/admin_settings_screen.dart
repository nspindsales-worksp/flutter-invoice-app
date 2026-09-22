import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/settings_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> with SingleTickerProviderStateMixin {
  final _supabase = SupabaseService.instance;
  late TabController _tabController;

  List<UserModel> _users = [];
  Map<String, bool> _features = {'createInvoice': true, 'invoiceHistory': true};
  SettingsModel _settings = SettingsModel();

  // Settings Controllers
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyMobileController = TextEditingController();
  final _invoiceTitleController = TextEditingController();
  final _challanTitleController = TextEditingController();
  final _invoiceFooterController = TextEditingController();
  final _challanFooterController = TextEditingController();
  final _marginTopController = TextEditingController();
  final _marginBottomController = TextEditingController();
  final _marginLeftController = TextEditingController();
  final _marginRightController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _companyMobileController.dispose();
    _invoiceTitleController.dispose();
    _challanTitleController.dispose();
    _invoiceFooterController.dispose();
    _challanFooterController.dispose();
    _marginTopController.dispose();
    _marginBottomController.dispose();
    _marginLeftController.dispose();
    _marginRightController.dispose();
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

      _companyNameController.text = s.companyName;
      _companyAddressController.text = s.companyAddress;
      _companyMobileController.text = s.companyMobile;
      _invoiceTitleController.text = s.invoiceTitle;
      _challanTitleController.text = s.challanTitle;
      _invoiceFooterController.text = s.invoiceFooterText;
      _challanFooterController.text = s.challanFooterText;
      _marginTopController.text = s.marginTop.toStringAsFixed(0);
      _marginBottomController.text = s.marginBottom.toStringAsFixed(0);
      _marginLeftController.text = s.marginLeft.toStringAsFixed(0);
      _marginRightController.text = s.marginRight.toStringAsFixed(0);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddUserDialog([UserModel? existing]) {
    final userIdController = TextEditingController(text: existing?.userId ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final passwordController = TextEditingController();
    final mobileController = TextEditingController(text: existing?.mobile ?? '');
    String role = existing?.role ?? 'User';
    int? tempDurationHours;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text(existing == null ? 'Add User Account' : 'Edit User Account'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: userIdController,
                    readOnly: existing != null,
                    decoration: const InputDecoration(labelText: 'User ID *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: existing == null ? 'Password *' : 'New Password (leave empty to keep current)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: mobileController,
                    decoration: const InputDecoration(labelText: 'Mobile'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'User', child: Text('User')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => role = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: tempDurationHours,
                    decoration: const InputDecoration(labelText: 'Account Expiry'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Permanent (No Expiry)')),
                      DropdownMenuItem(value: 24, child: Text('24 Hours')),
                      DropdownMenuItem(value: 72, child: Text('3 Days (72h)')),
                      DropdownMenuItem(value: 168, child: Text('7 Days (168h)')),
                    ],
                    onChanged: (val) {
                      setModalState(() => tempDurationHours = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                onPressed: () async {
                  final uId = userIdController.text.trim();
                  if (uId.isEmpty) return;

                  if (uId == '0505' || uId.toLowerCase() == 'sa-0505') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot create or edit reserved system user ID')),
                    );
                    return;
                  }

                  String passwordHash = existing?.password ?? '';
                  if (passwordController.text.trim().isNotEmpty) {
                    passwordHash = AppUtils.hashPassword(passwordController.text.trim());
                  } else if (existing == null) {
                    return; // Password required for new user
                  }

                  DateTime? exp;
                  if (tempDurationHours != null) {
                    exp = DateTime.now().add(Duration(hours: tempDurationHours!));
                  }

                  final user = UserModel(
                    id: existing?.id ?? const Uuid().v4(),
                    userId: uId,
                    name: nameController.text.trim(),
                    password: passwordHash,
                    role: role,
                    mobile: mobileController.text.trim(),
                    isLocal: true,
                    isSystem: existing?.isSystem ?? false,
                    expiresAt: exp,
                  );

                  final authUser = context.read<AuthProvider>().user;
                  await _supabase.saveUser(user, isSuperAdmin: authUser?.isSuperAdmin ?? false);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAll();
                },
                child: const Text('Save User'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteUser(UserModel u) async {
    if (u.isSuperAdmin || u.userId == '0505' || u.userId == 'sa-0505') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete Super Admin account!')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete user ${u.userId}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final authUser = context.read<AuthProvider>().user;
      await _supabase.deleteUser(u.userId, isSuperAdmin: authUser?.isSuperAdmin ?? false);
      _loadAll();
    }
  }

  Future<void> _savePdfSettings() async {
    final updated = _settings.copyWith(
      companyName: _companyNameController.text.trim(),
      companyAddress: _companyAddressController.text.trim(),
      companyMobile: _companyMobileController.text.trim(),
      invoiceTitle: _invoiceTitleController.text.trim(),
      challanTitle: _challanTitleController.text.trim(),
      invoiceFooterText: _invoiceFooterController.text.trim(),
      challanFooterText: _challanFooterController.text.trim(),
      marginTop: AppUtils.parseDouble(_marginTopController.text, 40.0),
      marginBottom: AppUtils.parseDouble(_marginBottomController.text, 40.0),
      marginLeft: AppUtils.parseDouble(_marginLeftController.text, 40.0),
      marginRight: AppUtils.parseDouble(_marginRightController.text, 40.0),
    );

    await _supabase.saveSettings(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: AppConstants.primaryDark),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabController,
          labelColor: AppConstants.primary,
          indicatorColor: AppConstants.primary,
          tabs: const [
            Tab(icon: Icon(Icons.people, size: 18), text: 'Users'),
            Tab(icon: Icon(Icons.toggle_on, size: 18), text: 'Feature Toggles'),
            Tab(icon: Icon(Icons.branding_watermark, size: 18), text: 'PDF & Company'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Users Tab
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('User Accounts (${_users.length})', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: () => _showAddUserDialog(),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: const Text('Add User'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final u = _users[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: u.isSuperAdmin ? Colors.purple : (u.isAdmin ? Colors.blue : Colors.grey),
                            child: Text(
                              u.name.isNotEmpty ? u.name[0].toUpperCase() : u.userId[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(u.name.isNotEmpty ? u.name : u.userId, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: u.isSuperAdmin ? Colors.purple.withValues(alpha: 0.15) : (u.isAdmin ? Colors.blue.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(u.role, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: u.isSuperAdmin ? Colors.purple : (u.isAdmin ? Colors.blue : Colors.grey))),
                              ),
                              if (u.isLocal) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Local', style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            'User ID: ${u.userId} • Mobile: ${u.mobile}'
                            '${u.expiresAt != null ? " • Expires: ${u.expiresAt.toString().substring(0, 16)}" : ""}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _showAddUserDialog(u),
                              ),
                              if (!u.isSuperAdmin)
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                  onPressed: () => _deleteUser(u),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 2. Feature Toggles Tab
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text('User Permissions Control', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Enable or disable features for regular Users. Admins always have full access.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Create Invoice Feature'),
                        subtitle: const Text('Allow regular users to create and generate invoices'),
                        value: _features['createInvoice'] ?? true,
                        activeThumbColor: AppConstants.primary,
                        onChanged: (val) async {
                          setState(() => _features['createInvoice'] = val);
                          await _supabase.updateAdminFeature('createInvoice', val);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Invoice History Feature'),
                        subtitle: const Text('Allow regular users to view their past invoice history'),
                        value: _features['invoiceHistory'] ?? true,
                        activeThumbColor: AppConstants.primary,
                        onChanged: (val) async {
                          setState(() => _features['invoiceHistory'] = val);
                          await _supabase.updateAdminFeature('invoiceHistory', val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. PDF & Company Branding Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PDF & Branding Settings', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: _savePdfSettings,
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save Settings'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(controller: _companyNameController, decoration: const InputDecoration(labelText: 'Company / Business Name')),
                        const SizedBox(height: 12),
                        TextField(controller: _companyAddressController, decoration: const InputDecoration(labelText: 'Company Address')),
                        const SizedBox(height: 12),
                        TextField(controller: _companyMobileController, decoration: const InputDecoration(labelText: 'Company Phone / Mobile')),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _invoiceTitleController, decoration: const InputDecoration(labelText: 'Invoice Title (e.g. INVOICE)'))),
                            const SizedBox(width: 12),
                            Expanded(child: TextField(controller: _challanTitleController, decoration: const InputDecoration(labelText: 'Challan Title (e.g. DELIVERY ORDER)'))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(controller: _invoiceFooterController, decoration: const InputDecoration(labelText: 'Invoice Footer Note')),
                        const SizedBox(height: 12),
                        TextField(controller: _challanFooterController, decoration: const InputDecoration(labelText: 'Challan Footer Note')),
                        const SizedBox(height: 16),
                        const Align(alignment: Alignment.centerLeft, child: Text('PDF Page Margins (Points)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: _marginTopController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Top'))),
                            const SizedBox(width: 8),
                            Expanded(child: TextField(controller: _marginBottomController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bottom'))),
                            const SizedBox(width: 8),
                            Expanded(child: TextField(controller: _marginLeftController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Left'))),
                            const SizedBox(width: 8),
                            Expanded(child: TextField(controller: _marginRightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Right'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
