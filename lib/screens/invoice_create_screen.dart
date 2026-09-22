import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/customer_model.dart';
import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../models/price_list_model.dart';
import '../models/product_model.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../services/pdf_service.dart';
import '../services/supabase_service.dart';

enum CustomerMode { normal, sideDelivery, newCustomer }

class InvoiceCreateScreen extends StatefulWidget {
  const InvoiceCreateScreen({super.key});

  @override
  State<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends State<InvoiceCreateScreen> {
  final _supabase = SupabaseService.instance;

  // Form Controllers
  final _invoiceNoController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerMobileController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isManualInvoiceNo = false;
  DateTime _selectedDate = DateTime.now();
  CustomerMode _customerMode = CustomerMode.normal;

  List<CustomerModel> _customers = [];
  CustomerModel? _selectedCustomer;

  List<PriceListModel> _priceLists = [];
  PriceListModel? _selectedPriceList;

  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];

  List<_FormItemRow> _itemRows = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _customerNameController.dispose();
    _customerAddressController.dispose();
    _customerMobileController.dispose();
    _notesController.dispose();
    for (var row in _itemRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);

    try {
      final customers = await _supabase.getCustomers();
      final priceLists = await _supabase.getPriceLists();
      final products = await _supabase.getProducts();

      _customers = customers;
      _priceLists = priceLists.where((pl) => pl.isActive).toList();
      if (_priceLists.isNotEmpty) {
        _selectedPriceList = _priceLists.first;
      }
      _allProducts = products;
      _filterProductsByPriceList();

      if (!mounted) return;
      final app = context.read<AppProvider>();
      final editing = app.editingInvoice;

      if (editing != null) {
        // Edit mode
        _invoiceNoController.text = editing.invoiceNo;
        _isManualInvoiceNo = true;
        _selectedDate = DateTime.tryParse(editing.date) ?? DateTime.now();

        if (editing.sideDelivery) {
          _customerMode = CustomerMode.sideDelivery;
        } else if (editing.customerId.isEmpty && editing.customerName.isNotEmpty) {
          _customerMode = CustomerMode.newCustomer;
        } else {
          _customerMode = CustomerMode.normal;
          _selectedCustomer = _customers.firstWhere(
            (c) => c.customerId == editing.customerId,
            orElse: () => CustomerModel(id: '', customerId: editing.customerId, name: editing.customerName),
          );
        }

        _customerNameController.text = editing.customerName;
        _customerAddressController.text = editing.address;
        _customerMobileController.text = editing.mobile;
        _notesController.text = editing.notes;

        _itemRows = editing.items.map((i) => _FormItemRow.fromModel(i)).toList();
      } else {
        // Create mode
        final nextNo = await _supabase.getNextInvoiceNumber();
        _invoiceNoController.text = nextNo;
        _itemRows = [_FormItemRow()];
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error init invoice screen: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterProductsByPriceList() {
    if (_selectedPriceList == null) {
      _filteredProducts = _allProducts;
    } else {
      _filteredProducts = _allProducts.where((p) => p.priceListId == _selectedPriceList!.id).toList();
      if (_filteredProducts.isEmpty) {
        _filteredProducts = _allProducts;
      }
    }
  }

  void _addItemRow() {
    setState(() {
      _itemRows.add(_FormItemRow());
    });
  }

  void _removeItemRow(int index) {
    if (_itemRows.length > 1) {
      setState(() {
        _itemRows[index].dispose();
        _itemRows.removeAt(index);
      });
    }
  }

  // Calculations
  double get _subtotalGross => _itemRows.fold(0.0, (sum, row) => sum + row.grossAmount);
  double get _totalDiscount => _itemRows.fold(0.0, (sum, row) => sum + (row.grossAmount - row.netAmount));
  double get _subtotalNet => _itemRows.fold(0.0, (sum, row) => sum + row.netAmount);
  double get _totalDeliveryCharge => _itemRows.fold(0.0, (sum, row) => sum + row.totalDeliveryCharge);
  double get _grandTotal => _itemRows.fold(0.0, (sum, row) => sum + row.total);

  InvoiceModel _buildInvoiceModel() {
    final auth = context.read<AuthProvider>();
    final items = _itemRows.where((r) => r.productName.trim().isNotEmpty).map((r) => r.toModel()).toList();

    String custId = '';
    String custName = _customerNameController.text.trim();
    if (_customerMode == CustomerMode.normal && _selectedCustomer != null) {
      custId = _selectedCustomer!.customerId;
      custName = _selectedCustomer!.name;
    }

    return InvoiceModel(
      invoiceNo: _invoiceNoController.text.trim(),
      date: AppUtils.formatDateStandard(_selectedDate),
      customerId: custId,
      customerName: custName,
      address: _customerAddressController.text.trim(),
      mobile: _customerMobileController.text.trim(),
      totalAmount: _grandTotal,
      notes: _notesController.text.trim(),
      priceListName: _selectedPriceList?.name ?? '',
      createdBy: auth.user?.userId ?? '',
      deviceId: auth.deviceId,
      sideDelivery: _customerMode == CustomerMode.sideDelivery,
      items: items,
      createdAt: DateTime.now(),
    );
  }

  Future<bool> _saveInvoice() async {
    final custName = _customerNameController.text.trim();
    if (_customerMode == CustomerMode.normal && _selectedCustomer == null && custName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter customer details')),
      );
      return false;
    }

    final validItems = _itemRows.where((r) => r.productName.trim().isNotEmpty).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product item')),
      );
      return false;
    }

    setState(() => _isSaving = true);
    try {
      final invoice = _buildInvoiceModel();
      await _supabase.saveInvoice(invoice);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invoice ${invoice.invoiceNo} saved successfully!'),
            backgroundColor: AppConstants.primaryDark,
          ),
        );
      }
      setState(() => _isSaving = false);
      return true;
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving invoice: $e'), backgroundColor: Colors.redAccent),
        );
      }
      return false;
    }
  }

  Future<void> _resetForm() async {
    for (var row in _itemRows) {
      row.dispose();
    }
    _customerNameController.clear();
    _customerAddressController.clear();
    _customerMobileController.clear();
    _notesController.clear();
    _selectedCustomer = null;
    _customerMode = CustomerMode.normal;
    _selectedDate = DateTime.now();

    final nextNo = await _supabase.getNextInvoiceNumber();
    setState(() {
      _invoiceNoController.text = nextNo;
      _isManualInvoiceNo = false;
      _itemRows = [_FormItemRow()];
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final isWide = MediaQuery.of(context).size.width > 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice Generator',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Unique alphanumeric format INV-XXXXXXXX',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Reset form',
                    onPressed: _resetForm,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Layout: Split into Left Form and Right Summary on Wide screens
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _buildFormSections()),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: _buildSummaryAndActionsCard()),
              ],
            )
          else
            Column(
              children: [
                _buildFormSections(),
                const SizedBox(height: 16),
                _buildSummaryAndActionsCard(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFormSections() {
    return Column(
      children: [
        // 1. Invoice Meta Card (Invoice No, Date, Price List)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice Details', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Invoice Number Field
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _invoiceNoController,
                        readOnly: !_isManualInvoiceNo,
                        decoration: InputDecoration(
                          labelText: 'Invoice Number',
                          prefixIcon: const Icon(Icons.tag, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(_isManualInvoiceNo ? Icons.lock_open : Icons.edit, size: 18),
                            tooltip: _isManualInvoiceNo ? 'Manual entry enabled' : 'Click to edit manually',
                            onPressed: () {
                              setState(() => _isManualInvoiceNo = !_isManualInvoiceNo);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Date Picker
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) setState(() => _selectedDate = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Invoice Date',
                            prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                          ),
                          child: Text(AppUtils.formatDateStandard(_selectedDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Price List Selector
                    if (_priceLists.isNotEmpty)
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<PriceListModel>(
                          initialValue: _selectedPriceList,
                          decoration: const InputDecoration(
                            labelText: 'Price List',
                            prefixIcon: Icon(Icons.list_alt, size: 18),
                          ),
                          items: _priceLists.map((pl) {
                            return DropdownMenuItem(value: pl, child: Text(pl.name));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedPriceList = val;
                                _filterProductsByPriceList();
                              });
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Customer Selection Card (Normal / Side Delivery / New Customer)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Customer Information', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                    // Mode Selector Chips
                    SegmentedButton<CustomerMode>(
                      segments: const [
                        ButtonSegment(value: CustomerMode.normal, label: Text('Saved')),
                        ButtonSegment(value: CustomerMode.sideDelivery, label: Text('Side Delivery')),
                        ButtonSegment(value: CustomerMode.newCustomer, label: Text('New')),
                      ],
                      selected: {_customerMode},
                      onSelectionChanged: (val) {
                        setState(() {
                          _customerMode = val.first;
                          if (_customerMode == CustomerMode.normal && _selectedCustomer != null) {
                            _customerNameController.text = _selectedCustomer!.name;
                            _customerAddressController.text = _selectedCustomer!.address;
                            _customerMobileController.text = _selectedCustomer!.mobile;
                          }
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_customerMode == CustomerMode.normal) ...[
                  // Autocomplete Search for Saved Customers
                  Autocomplete<CustomerModel>(
                    displayStringForOption: (c) => '${c.name} (${c.customerId})',
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const Iterable<CustomerModel>.empty();
                      final query = textEditingValue.text.toLowerCase();
                      return _customers.where((c) {
                        return c.name.toLowerCase().contains(query) ||
                            c.customerId.toLowerCase().contains(query) ||
                            c.mobile.toLowerCase().contains(query);
                      });
                    },
                    onSelected: (customer) async {
                      _selectedCustomer = customer;
                      _customerNameController.text = customer.name;
                      _customerAddressController.text = customer.address;
                      _customerMobileController.text = customer.mobile;

                      // Check last contact info from previous invoices if empty
                      if (customer.address.isEmpty || customer.mobile.isEmpty) {
                        final last = await _supabase.getLastCustomerContact(customer.customerId, customer.name);
                        if (last['address']?.isNotEmpty == true && _customerAddressController.text.isEmpty) {
                          _customerAddressController.text = last['address']!;
                        }
                        if (last['mobile']?.isNotEmpty == true && _customerMobileController.text.isEmpty) {
                          _customerMobileController.text = last['mobile']!;
                        }
                      }
                      setState(() {});
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Search Customer (Name, ID, Mobile)',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          hintText: _selectedCustomer != null ? _selectedCustomer!.name : 'Type to search...',
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_customerMode != CustomerMode.normal)
                      Expanded(
                        child: TextField(
                          controller: _customerNameController,
                          decoration: InputDecoration(
                            labelText: _customerMode == CustomerMode.sideDelivery ? 'Side Delivery Name' : 'Customer Name',
                            prefixIcon: const Icon(Icons.person_outline, size: 18),
                          ),
                        ),
                      ),
                    if (_customerMode != CustomerMode.normal) const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _customerMobileController,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone_outlined, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customerAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Address / Delivery Location',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Line Items Table Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Products & Items (${_itemRows.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: _addItemRow,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Row'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // List of Items
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _itemRows.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final row = _itemRows[index];
                    return _buildItemRowWidget(index, row);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Notes Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notes / Instructions', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Add special delivery or billing notes here...',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRowWidget(int index, _FormItemRow row) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppConstants.primary.withValues(alpha: 0.15),
                child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.primary)),
              ),
              const SizedBox(width: 8),

              // Product Selector Autocomplete
              Expanded(
                flex: 5,
                child: Autocomplete<ProductModel>(
                  displayStringForOption: (p) => p.name,
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return const Iterable<ProductModel>.empty();
                    final query = textEditingValue.text.toLowerCase();
                    return _filteredProducts.where((p) => p.name.toLowerCase().contains(query));
                  },
                  onSelected: (product) async {
                    row.productName = product.name;
                    row.rateController.text = product.standardRate.toStringAsFixed(2);

                    // Check last price used if available
                    final lastPrice = await _supabase.getLastProductPrice(product.name);
                    if (lastPrice != null && lastPrice > 0) {
                      row.rateController.text = lastPrice.toStringAsFixed(2);
                    }
                    setState(() {});
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    if (controller.text.isEmpty && row.productName.isNotEmpty) {
                      controller.text = row.productName;
                    }
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Select / Type Product',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      onChanged: (val) {
                        row.productName = val;
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Quantity Input
              SizedBox(
                width: 75,
                child: TextField(
                  controller: row.qtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Qty',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),

              // Rate Input
              SizedBox(
                width: 90,
                child: TextField(
                  controller: row.rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Rate',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),

              // Delete row button
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                onPressed: _itemRows.length > 1 ? () => _removeItemRow(index) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Secondary row: Description, Discount %, Delivery Charge, Line Total
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  controller: row.descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (val) => row.description = val,
                ),
              ),
              const SizedBox(width: 8),

              SizedBox(
                width: 75,
                child: TextField(
                  controller: row.discController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Disc %',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),

              SizedBox(
                width: 90,
                child: TextField(
                  controller: row.delivController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Deliv/Unit',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),

              // Computed Line Total
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Line Total', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(
                    AppUtils.formatAmount(row.total),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.primaryLight),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAndActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Invoice Summary', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            _summaryLine('Subtotal Gross', AppUtils.formatAmount(_subtotalGross)),
            if (_totalDiscount > 0)
              _summaryLine('Total Discount', '- ${AppUtils.formatAmount(_totalDiscount)}', color: Colors.redAccent),
            _summaryLine('Subtotal Net', AppUtils.formatAmount(_subtotalNet)),
            if (_totalDeliveryCharge > 0)
              _summaryLine('Delivery Charges', AppUtils.formatAmount(_totalDeliveryCharge)),
            const Divider(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('GRAND TOTAL:', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(
                  AppUtils.formatAmount(_grandTotal),
                  style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: AppConstants.primaryLight),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save Invoice Button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveInvoice,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Invoice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 10),

            // Print / Preview PDF
            OutlinedButton.icon(
              onPressed: () async {
                final invoice = _buildInvoiceModel();
                final settings = await _supabase.getSettings();
                await PdfService.instance.printInvoice(invoice, settings);
              },
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Print / Preview Invoice PDF'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
            const SizedBox(height: 10),

            // Delivery Order Challan Button
            OutlinedButton.icon(
              onPressed: () async {
                final invoice = _buildInvoiceModel();
                final settings = await _supabase.getSettings();
                await PdfService.instance.printChallan(invoice, settings);
              },
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Print Delivery Challan'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
            const SizedBox(height: 10),

            // Share PDF
            OutlinedButton.icon(
              onPressed: () async {
                final invoice = _buildInvoiceModel();
                final settings = await _supabase.getSettings();
                await PdfService.instance.shareInvoice(invoice, settings);
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share Invoice'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _FormItemRow {
  String id = const Uuid().v4();
  String productName = '';
  String description = '';
  final TextEditingController qtyController;
  final TextEditingController rateController;
  final TextEditingController discController;
  final TextEditingController delivController;
  final TextEditingController descController;

  _FormItemRow({
    this.productName = '',
    this.description = '',
    double quantity = 1.0,
    double unitPrice = 0.0,
    double discountPercent = 0.0,
    double deliveryCharge = 0.0,
  })  : qtyController = TextEditingController(text: quantity.toStringAsFixed(0)),
        rateController = TextEditingController(text: unitPrice > 0 ? unitPrice.toStringAsFixed(2) : ''),
        discController = TextEditingController(text: discountPercent > 0 ? discountPercent.toStringAsFixed(0) : ''),
        delivController = TextEditingController(text: deliveryCharge > 0 ? deliveryCharge.toStringAsFixed(2) : ''),
        descController = TextEditingController(text: description);

  factory _FormItemRow.fromModel(InvoiceItemModel m) {
    return _FormItemRow(
      productName: m.productName,
      description: m.description,
      quantity: m.quantity,
      unitPrice: m.unitPrice,
      discountPercent: m.discountPercent,
      deliveryCharge: m.deliveryChargePerUnit,
    );
  }

  double get quantity => AppUtils.parseDouble(qtyController.text, 1.0);
  double get unitPrice => AppUtils.parseDouble(rateController.text, 0.0);
  double get discountPercent => AppUtils.parseDouble(discController.text, 0.0);
  double get deliveryChargePerUnit => AppUtils.parseDouble(delivController.text, 0.0);

  double get grossAmount => quantity * unitPrice;
  double get netAmount => grossAmount * (1 - discountPercent / 100);
  double get totalDeliveryCharge => deliveryChargePerUnit * quantity;
  double get total => netAmount + totalDeliveryCharge;

  InvoiceItemModel toModel() {
    return InvoiceItemModel(
      id: id,
      productName: productName,
      description: descController.text.trim(),
      quantity: quantity,
      unitPrice: unitPrice,
      grossAmount: grossAmount,
      discountPercent: discountPercent,
      netAmount: netAmount,
      deliveryChargePerUnit: deliveryChargePerUnit,
      totalDeliveryCharge: totalDeliveryCharge,
      total: total,
    );
  }

  void dispose() {
    qtyController.dispose();
    rateController.dispose();
    discController.dispose();
    delivController.dispose();
    descController.dispose();
  }
}
