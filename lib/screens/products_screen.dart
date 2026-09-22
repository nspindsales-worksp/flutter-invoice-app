import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/price_list_model.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _supabase = SupabaseService.instance;
  final _searchController = TextEditingController();

  List<ProductModel> _products = [];
  List<PriceListModel> _priceLists = [];
  String _selectedPriceListId = 'all';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final pls = await _supabase.getPriceLists();
      final prods = await _supabase.getProducts(
        priceListId: _selectedPriceListId,
        search: _searchController.text,
      );

      if (mounted) {
        setState(() {
          _priceLists = pls;
          _products = prods;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddOrEditProduct([ProductModel? existing]) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final unitController = TextEditingController(text: existing?.unit ?? 'Pcs');
    final rateController = TextEditingController(text: existing != null ? existing.standardRate.toStringAsFixed(2) : '');
    String? selectedPlId = existing?.priceListId ?? (_priceLists.isNotEmpty ? _priceLists.first.id : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Product' : 'Edit Product'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Product Name *'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: unitController,
                          decoration: const InputDecoration(labelText: 'Unit (Pcs, Box, Kg)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: rateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Standard Rate *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_priceLists.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedPlId,
                      decoration: const InputDecoration(labelText: 'Price List'),
                      items: _priceLists.map((pl) {
                        return DropdownMenuItem(value: pl.id, child: Text(pl.name));
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() => selectedPlId = val);
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
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  final rate = AppUtils.parseDouble(rateController.text);
                  final product = ProductModel(
                    id: existing?.id ?? const Uuid().v4(),
                    name: name,
                    unit: unitController.text.trim().isNotEmpty ? unitController.text.trim() : 'Pcs',
                    standardRate: rate,
                    priceListId: selectedPlId,
                  );

                  await _supabase.saveProduct(product);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                },
                child: const Text('Save Product'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteProduct(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
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
      await _supabase.deleteProduct(id);
      _loadData();
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
            // Filter & Search Controls
            Row(
              children: [
                // Price List Dropdown Filter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPriceListId,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Price Lists')),
                        ..._priceLists.map((pl) => DropdownMenuItem(value: pl.id, child: Text(pl.name))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPriceListId = val);
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Search field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadData();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _loadData(),
                  ),
                ),
                const SizedBox(width: 10),

                if (isAdmin)
                  ElevatedButton.icon(
                    onPressed: () => _showAddOrEditProduct(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Product'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_products.length} Products Found',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).hintColor),
              ),
            ),
            const SizedBox(height: 10),

            // Products List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _products.isEmpty
                      ? const Center(child: Text('No products found.'))
                      : ListView.separated(
                          itemCount: _products.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final p = _products[index];
                            return Card(
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppConstants.secondary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.inventory_2_outlined, color: AppConstants.secondary, size: 20),
                                ),
                                title: Text(p.name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Row(
                                  children: [
                                    Text('Unit: ${p.unit}', style: const TextStyle(fontSize: 12)),
                                    if (p.priceListName != null && p.priceListName!.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(p.priceListName!, style: const TextStyle(fontSize: 10)),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppUtils.formatAmount(p.standardRate),
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppConstants.primaryLight),
                                    ),
                                    if (isAdmin) ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        onPressed: () => _showAddOrEditProduct(p),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                        onPressed: () => _deleteProduct(p.id),
                                      ),
                                    ],
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
    );
  }
}
