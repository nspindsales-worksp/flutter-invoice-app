import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/customer_model.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _supabase = SupabaseService.instance;
  final _searchController = TextEditingController();

  List<CustomerModel> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers({String? search}) async {
    setState(() => _isLoading = true);
    try {
      final list = await _supabase.getCustomers(search: search);
      if (mounted) {
        setState(() {
          _customers = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddOrEditDialog([CustomerModel? existing]) {
    final idController = TextEditingController(text: existing?.customerId ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final addressController = TextEditingController(text: existing?.address ?? '');
    final mobileController = TextEditingController(text: existing?.mobile ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Customer' : 'Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                readOnly: existing != null,
                decoration: const InputDecoration(labelText: 'Customer ID (e.g. C001)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Customer Name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mobileController,
                decoration: const InputDecoration(labelText: 'Mobile Number'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final custId = idController.text.trim().isNotEmpty
                  ? idController.text.trim()
                  : 'C-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

              final customer = CustomerModel(
                id: existing?.id ?? const Uuid().v4(),
                customerId: custId,
                name: name,
                mobile: mobileController.text.trim(),
                address: addressController.text.trim(),
              );

              await _supabase.saveCustomer(customer);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadCustomers(search: _searchController.text);
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCustomer(String customerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete customer $customerId?'),
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

    if (confirm == true) {
      await _supabase.deleteCustomer(customerId);
      _loadCustomers(search: _searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.user?.isAdmin ?? false;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search & Add Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Customer Name, ID, Mobile...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadCustomers();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (val) => _loadCustomers(search: val),
                  ),
                ),
                const SizedBox(width: 10),
                if (isAdmin)
                  ElevatedButton.icon(
                    onPressed: () => _showAddOrEditDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Customer'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Count badge
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_customers.length} Customers Available',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).hintColor),
              ),
            ),
            const SizedBox(height: 10),

            // Customer List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _customers.isEmpty
                      ? const Center(child: Text('No customers found.'))
                      : ListView.separated(
                          itemCount: _customers.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final c = _customers[index];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppConstants.secondary.withValues(alpha: 0.15),
                                  child: Text(
                                    c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                    style: const TextStyle(color: AppConstants.secondary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(c.customerId, style: const TextStyle(fontSize: 10)),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (c.mobile.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(c.mobile, style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    if (c.address.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(c.address, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                trailing: isAdmin
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18),
                                            onPressed: () => _showAddOrEditDialog(c),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                            onPressed: () => _deleteCustomer(c.customerId),
                                          ),
                                        ],
                                      )
                                    : null,
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
