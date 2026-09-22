import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../core/utils.dart';
import '../models/customer_model.dart';
import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../models/price_list_model.dart';
import '../models/product_model.dart';
import '../models/settings_model.dart';
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
  static const int maxItemsPerInvoice = 80;

  final _supabase = SupabaseService.instance;
  final _pdfService = PdfService.instance;

  // Controllers
  final _invoiceNoController = TextEditingController();
  final _customerSearchController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerMobileController = TextEditingController();

  // Side Delivery / New Customer manual fields
  final _sideNameController = TextEditingController();
  final _sideAddressController = TextEditingController();
  final _sideMobileController = TextEditingController();

  // Notes
  final _notesController = TextEditingController();
  bool _noteEditorOpen = false;

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
  bool _isGeneratingPdf = false;
  String? _savedInvoiceNo;

  SettingsModel _settings = SettingsModel();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _customerSearchController.dispose();
    _customerAddressController.dispose();
    _customerMobileController.dispose();
    _sideNameController.dispose();
    _sideAddressController.dispose();
    _sideMobileController.dispose();
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
      final settings = await _supabase.getSettings();

      _customers = customers;
      _priceLists = priceLists.where((pl) => pl.isActive).toList();
      if (_priceLists.isNotEmpty) {
        _selectedPriceList = _priceLists.first;
      }
      _allProducts = products;
      _settings = settings;
      _filterProductsByPriceList();

      if (!mounted) return;
      final app = context.read<AppProvider>();
      final editing = app.editingInvoice;

      if (editing != null) {
        // Edit mode
        _invoiceNoController.text = editing.invoiceNo;
        _isManualInvoiceNo = true;
        _savedInvoiceNo = editing.invoiceNo;
        _selectedDate = DateTime.tryParse(editing.date) ?? DateTime.now();

        if (editing.sideDelivery) {
          _customerMode = CustomerMode.sideDelivery;
          _sideNameController.text = editing.customerName;
          _sideAddressController.text = editing.address;
          _sideMobileController.text = editing.mobile;
          if (editing.customerId.isNotEmpty) {
            _selectedCustomer = _customers.firstWhere(
              (c) => c.customerId == editing.customerId,
              orElse: () => CustomerModel(id: '', customerId: editing.customerId, name: editing.customerName),
            );
            _customerSearchController.text = '${editing.customerName} - ${editing.customerId}';
          }
        } else if (editing.customerId.isEmpty && editing.customerName.isNotEmpty) {
          _customerMode = CustomerMode.newCustomer;
          _sideNameController.text = editing.customerName;
          _sideAddressController.text = editing.address;
          _sideMobileController.text = editing.mobile;
        } else {
          _customerMode = CustomerMode.normal;
          _selectedCustomer = _customers.firstWhere(
            (c) => c.customerId == editing.customerId,
            orElse: () => CustomerModel(id: '', customerId: editing.customerId, name: editing.customerName),
          );
          _customerSearchController.text = '${editing.customerName} - ${editing.customerId}';
          _customerAddressController.text = editing.address;
          _customerMobileController.text = editing.mobile;
        }

        _notesController.text = editing.notes;
        _noteEditorOpen = editing.notes.trim().isNotEmpty;

        if (editing.priceListName.isNotEmpty) {
          final matched = _priceLists.where((pl) => pl.name == editing.priceListName);
          if (matched.isNotEmpty) {
            _selectedPriceList = matched.first;
            _filterProductsByPriceList();
          }
        }

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
    if (_itemRows.length >= maxItemsPerInvoice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 80 items are allowed in one invoice')),
      );
      return;
    }
    setState(() {
      _itemRows.add(_FormItemRow());
    });
  }

  void _removeItemRow(int index) {
    if (_itemRows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one item is required')),
      );
      return;
    }
    setState(() {
      _itemRows[index].dispose();
      _itemRows.removeAt(index);
    });
  }

  // Calculations
  double get _subtotalGross => _itemRows.fold(0.0, (sum, row) => sum + row.grossAmount);
  double get _totalDiscount => _itemRows.fold(0.0, (sum, row) => sum + (row.grossAmount - row.netAmount));
  double get _totalDeliveryCharge => _itemRows.fold(0.0, (sum, row) => sum + row.totalDeliveryCharge);
  double get _grandTotal => _itemRows.fold(0.0, (sum, row) => sum + row.total);

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }

  _DeliveryContactInfo _getDeliveryContactInfo() {
    if (_customerMode == CustomerMode.newCustomer) {
      return _DeliveryContactInfo(
        customerId: '',
        customerName: _sideNameController.text.trim(),
        address: _sideAddressController.text.trim(),
        mobile: _sideMobileController.text.trim(),
        isSideDelivery: false,
      );
    }
    if (_customerMode == CustomerMode.sideDelivery) {
      return _DeliveryContactInfo(
        customerId: _selectedCustomer?.customerId ?? '',
        customerName: _sideNameController.text.trim(),
        address: _sideAddressController.text.trim(),
        mobile: _sideMobileController.text.trim(),
        isSideDelivery: true,
      );
    }
    final custName = _customerSearchController.text.contains(' - ')
        ? _customerSearchController.text.split(' - ')[0].trim()
        : _customerSearchController.text.trim();
    return _DeliveryContactInfo(
      customerId: _selectedCustomer?.customerId ?? '',
      customerName: _selectedCustomer?.name ?? custName,
      address: _customerAddressController.text.trim(),
      mobile: _customerMobileController.text.trim(),
      isSideDelivery: false,
    );
  }

  InvoiceModel _buildInvoiceModel() {
    final auth = context.read<AuthProvider>();
    final contact = _getDeliveryContactInfo();
    final items = _itemRows.where((r) => r.productName.trim().isNotEmpty).map((r) => r.toModel()).toList();

    return InvoiceModel(
      invoiceNo: _invoiceNoController.text.trim(),
      date: DateFormat('yyyy-MM-dd').format(_selectedDate),
      customerId: contact.customerId,
      customerName: contact.customerName,
      address: contact.address,
      mobile: contact.mobile,
      totalAmount: _grandTotal,
      notes: _notesController.text.trim(),
      priceListName: _selectedPriceList?.name ?? '',
      createdBy: auth.user?.userId ?? '',
      deviceId: auth.deviceId,
      sideDelivery: contact.isSideDelivery,
      items: items,
      createdAt: DateTime.now(),
    );
  }

  bool _validateForm() {
    final invNo = _invoiceNoController.text.trim();
    if (invNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice number is required')),
      );
      return false;
    }

    final contact = _getDeliveryContactInfo();

    if (_customerMode == CustomerMode.newCustomer) {
      if (contact.customerName.isEmpty || contact.address.isEmpty || contact.mobile.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('In New Customer mode, Name, Address, and Mobile are required.')),
        );
        return false;
      }
    } else if (_customerMode == CustomerMode.sideDelivery) {
      if (_selectedCustomer == null && contact.customerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('For Side Delivery, please select a customer first.')),
        );
        return false;
      }
      if (contact.customerName.isEmpty || contact.address.isEmpty || contact.mobile.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('In Side Delivery mode, Name, Address, and Mobile are required.')),
        );
        return false;
      }
    } else {
      if (_selectedCustomer == null && _customerSearchController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a customer!')),
        );
        return false;
      }
    }

    final hasEmptyProduct = _itemRows.any((r) => r.productName.trim().isEmpty);
    if (hasEmptyProduct) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all product names')),
      );
      return false;
    }

    final hasZeroQty = _itemRows.any((r) => r.quantity <= 0);
    if (hasZeroQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than 0 for all items')),
      );
      return false;
    }

    if (_priceLists.length > 1 && _selectedPriceList == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Price List')),
      );
      return false;
    }

    return true;
  }

  Future<bool> _saveInvoice() async {
    if (!_validateForm()) return false;

    setState(() => _isSaving = true);
    try {
      final invoice = _buildInvoiceModel();
      await _supabase.saveInvoice(invoice);

      _savedInvoiceNo = invoice.invoiceNo;

      if (mounted) {
        final isEdit = context.read<AppProvider>().editingInvoice != null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Invoice ${invoice.invoiceNo} updated successfully!' : 'Invoice ${invoice.invoiceNo} saved successfully!'),
            backgroundColor: const Color(0xFF059669),
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

  Future<void> _handleGeneratePdfAndChallan() async {
    if (!_validateForm()) return;

    setState(() => _isGeneratingPdf = true);
    try {
      final invoice = _buildInvoiceModel();

      // Save first
      await _supabase.saveInvoice(invoice);
      _savedInvoiceNo = invoice.invoiceNo;

      // Generate and share/print Invoice PDF
      await _pdfService.shareInvoice(invoice, _settings);

      // Brief delay for system share/download pipeline
      await Future.delayed(const Duration(milliseconds: 600));

      // Generate and share/print Challan PDF
      await _pdfService.shareChallan(invoice, _settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice saved & PDF + Challan generated successfully!'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }

      if (!mounted) return;
      final isEdit = context.read<AppProvider>().editingInvoice != null;
      if (!isEdit) {
        await _clearForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF & Challan: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _handleInvoicePdfOnly() async {
    if (!_validateForm()) return;

    setState(() => _isGeneratingPdf = true);
    try {
      final invoice = _buildInvoiceModel();
      await _supabase.saveInvoice(invoice);
      _savedInvoiceNo = invoice.invoiceNo;
      await _pdfService.shareInvoice(invoice, _settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating Invoice PDF: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _handleChallanPdfOnly() async {
    if (!_validateForm()) return;

    setState(() => _isGeneratingPdf = true);
    try {
      final invoice = _buildInvoiceModel();
      await _supabase.saveInvoice(invoice);
      _savedInvoiceNo = invoice.invoiceNo;
      await _pdfService.shareChallan(invoice, _settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating Challan PDF: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<void> _clearForm() async {
    for (var row in _itemRows) {
      row.dispose();
    }
    _customerSearchController.clear();
    _customerAddressController.clear();
    _customerMobileController.clear();
    _sideNameController.clear();
    _sideAddressController.clear();
    _sideMobileController.clear();
    _notesController.clear();
    _noteEditorOpen = false;
    _selectedCustomer = null;
    _customerMode = CustomerMode.normal;
    _selectedDate = DateTime.now();
    _savedInvoiceNo = null;

    final app = context.read<AppProvider>();
    app.clearEditingInvoice();

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

    final auth = context.watch<AuthProvider>();
    final app = context.watch<AppProvider>();
    final isEditing = app.editingInvoice != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. INVOICE INFORMATION CARD (matches invoice-create-page.tsx)
          _buildInvoiceInfoCard(isEditing),
          const SizedBox(height: 16),

          // 2. INVOICE ITEMS CARD WITH TABLE (matches invoice-create-page.tsx)
          _buildInvoiceItemsCard(),
          const SizedBox(height: 16),

          // 3. INVOICE SUMMARY CARD (matches invoice-create-page.tsx totals)
          _buildInvoiceSummaryCard(auth),
          const SizedBox(height: 20),

          // 4. ACTION BUTTONS BAR (matches invoice-create-page.tsx buttons)
          _buildActionButtonsBar(isEditing, app),
        ],
      ),
    );
  }

  Widget _buildInvoiceInfoCard(bool isEditing) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title
            Text(
              isEditing ? 'Re-Open Invoice - ${_invoiceNoController.text}' : 'Invoice Information',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),

            // Two-column or responsive layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final showManualSideFields = _customerMode == CustomerMode.sideDelivery || _customerMode == CustomerMode.newCustomer;

                if (isWide && showManualSideFields) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildLeftInfoColumn()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildRightSideDeliveryColumn()),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLeftInfoColumn(),
                    if (showManualSideFields) ...[
                      const SizedBox(height: 16),
                      _buildRightSideDeliveryColumn(),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 14),

            // Note Section (like n1.py's Note Editor)
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _noteEditorOpen = !_noteEditorOpen),
                  icon: const Icon(Icons.sticky_note_2_outlined, size: 16),
                  label: Text(_notesController.text.trim().isNotEmpty ? 'Edit Note' : 'Add Note'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _notesController.text.trim().isNotEmpty
                        ? 'Note added: ${_notesController.text.replaceAll('\n', ' ').trim()}'
                        : 'No note added',
                    style: TextStyle(
                      fontSize: 12,
                      color: _notesController.text.trim().isNotEmpty ? const Color(0xFF059669) : Theme.of(context).hintColor,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_noteEditorOpen) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Additional notes for this invoice...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeftInfoColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Invoice No & Date
        Row(
          children: [
            // Invoice No
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invoice No:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _invoiceNoController,
                    readOnly: !_isManualInvoiceNo,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF059669),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: IconButton(
                        icon: Icon(_isManualInvoiceNo ? Icons.lock_open : Icons.edit, size: 16),
                        tooltip: _isManualInvoiceNo ? 'Manual entry enabled' : 'Click to edit manually',
                        onPressed: () => setState(() => _isManualInvoiceNo = !_isManualInvoiceNo),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 14),
                    label: Text(
                      DateFormat('yyyy-MM-dd').format(_selectedDate),
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Mode Toggles: Side Delivery (Manual) + New Customer (Checkboxes like invoice-create-page.tsx)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // Checkbox 1: Side Delivery (Manual)
              InkWell(
                onTap: _customerMode == CustomerMode.newCustomer
                    ? null
                    : () {
                        setState(() {
                          if (_customerMode == CustomerMode.sideDelivery) {
                            _customerMode = CustomerMode.normal;
                            _sideNameController.clear();
                            _sideAddressController.clear();
                            _sideMobileController.clear();
                          } else {
                            _customerMode = CustomerMode.sideDelivery;
                            _sideNameController.clear();
                            _sideAddressController.clear();
                            _sideMobileController.clear();
                          }
                        });
                      },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _customerMode == CustomerMode.sideDelivery,
                      onChanged: _customerMode == CustomerMode.newCustomer
                          ? null
                          : (val) {
                              setState(() {
                                _customerMode = val == true ? CustomerMode.sideDelivery : CustomerMode.normal;
                                if (val != true) {
                                  _sideNameController.clear();
                                  _sideAddressController.clear();
                                  _sideMobileController.clear();
                                }
                              });
                            },
                    ),
                    const Icon(Icons.local_shipping, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(
                      'Side Delivery (Manual)',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Checkbox 2: New Customer
              InkWell(
                onTap: () {
                  setState(() {
                    if (_customerMode == CustomerMode.newCustomer) {
                      _customerMode = CustomerMode.normal;
                      _sideNameController.clear();
                      _sideAddressController.clear();
                      _sideMobileController.clear();
                    } else {
                      _customerMode = CustomerMode.newCustomer;
                      _selectedCustomer = null;
                      _customerSearchController.clear();
                      _customerAddressController.clear();
                      _customerMobileController.clear();
                      _sideNameController.clear();
                      _sideAddressController.clear();
                      _sideMobileController.clear();
                    }
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _customerMode == CustomerMode.newCustomer,
                      onChanged: (val) {
                        setState(() {
                          _customerMode = val == true ? CustomerMode.newCustomer : CustomerMode.normal;
                          if (val == true) {
                            _selectedCustomer = null;
                            _customerSearchController.clear();
                            _customerAddressController.clear();
                            _customerMobileController.clear();
                          }
                          _sideNameController.clear();
                          _sideAddressController.clear();
                          _sideMobileController.clear();
                        });
                      },
                    ),
                    const Icon(Icons.person_add, size: 16, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                    Text(
                      'New',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Select Customer Dropdown / Autocomplete (disabled in New Customer mode)
        Text('Select Customer:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Autocomplete<CustomerModel>(
          displayStringForOption: (c) => '${c.name} - ${c.customerId}',
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) return const Iterable<CustomerModel>.empty();
            final q = textEditingValue.text.toLowerCase();
            return _customers.where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.customerId.toLowerCase().contains(q) ||
                c.mobile.toLowerCase().contains(q) ||
                c.address.toLowerCase().contains(q));
          },
          onSelected: (customer) async {
            setState(() {
              _selectedCustomer = customer;
              _customerSearchController.text = '${customer.name} - ${customer.customerId}';
              _customerAddressController.text = customer.address;
              _customerMobileController.text = customer.mobile;
            });

            // Fallback contact info if address or mobile is empty
            if (customer.address.isEmpty || customer.mobile.isEmpty) {
              final isSuperAdmin = context.read<AuthProvider>().user?.isSuperAdmin ?? false;
              final lastContact = await _supabase.getLastCustomerContact(
                customer.customerId,
                customer.name,
                isSuperAdmin: isSuperAdmin,
              );
              if (_customerAddressController.text.isEmpty && lastContact['address']?.isNotEmpty == true) {
                _customerAddressController.text = lastContact['address']!;
              }
              if (_customerMobileController.text.isEmpty && lastContact['mobile']?.isNotEmpty == true) {
                _customerMobileController.text = lastContact['mobile']!;
              }
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            if (controller.text.isEmpty && _customerSearchController.text.isNotEmpty) {
              controller.text = _customerSearchController.text;
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: _customerMode != CustomerMode.newCustomer,
              decoration: InputDecoration(
                hintText: _customerMode == CustomerMode.newCustomer
                    ? 'Disabled in New Customer Mode'
                    : 'Type customer name, area, or ID',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: const Icon(Icons.keyboard_arrow_down, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (val) {
                _customerSearchController.text = val;
              },
            );
          },
        ),

        // Customer Details preview (normal mode)
        if (_customerMode == CustomerMode.normal && _selectedCustomer != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Address:', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                const SizedBox(height: 2),
                TextField(
                  controller: _customerAddressController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                ),
                const SizedBox(height: 6),
                Text('Mobile:', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                const SizedBox(height: 2),
                TextField(
                  controller: _customerMobileController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRightSideDeliveryColumn() {
    final isSide = _customerMode == CustomerMode.sideDelivery;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSide ? Colors.red.withValues(alpha: 0.04) : Colors.blue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSide ? Colors.redAccent.withValues(alpha: 0.4) : Colors.blueAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Center(
            child: Text(
              isSide ? 'SIDE DELIVERY (Manual)' : 'NEW CUSTOMER (No ID Required)',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSide ? Colors.redAccent : Colors.blueAccent,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Name
          Text('Name: *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          TextField(
            controller: _sideNameController,
            decoration: InputDecoration(
              hintText: isSide ? 'Type side delivery customer name' : 'Type new customer name',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(height: 8),

          // Address
          Text('Address: *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          TextField(
            controller: _sideAddressController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: isSide ? 'Type side delivery address' : 'Type customer address',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          const SizedBox(height: 8),

          // Mobile
          Text('Mobile: *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          TextField(
            controller: _sideMobileController,
            decoration: InputDecoration(
              hintText: isSide ? 'Type side delivery mobile' : 'Type customer mobile',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceItemsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title, Price List dropdown, Count Badge, Add Product button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Invoice Items', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),

                    // Price List Selector
                    if (_priceLists.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        height: 32,
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PriceListModel>(
                            value: _selectedPriceList,
                            hint: const Text('Select Price List', style: TextStyle(fontSize: 11)),
                            items: _priceLists.map((pl) {
                              return DropdownMenuItem<PriceListModel>(
                                value: pl,
                                child: Text(pl.name, style: const TextStyle(fontSize: 11)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedPriceList = val;
                                _filterProductsByPriceList();
                              });
                            },
                          ),
                        ),
                      )
                    else if (_priceLists.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(_priceLists[0].name, style: const TextStyle(fontSize: 11)),
                      ),
                  ],
                ),

                Row(
                  children: [
                    // Badge: rows / 80
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_itemRows.length}/$maxItemsPerInvoice',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Add Product Button
                    ElevatedButton.icon(
                      onPressed: _itemRows.length >= maxItemsPerInvoice ? null : _addItemRow,
                      icon: const Icon(Icons.add, size: 16, color: Colors.white),
                      label: const Text('Add Product', style: TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // SPREADSHEET-STYLE TABLE (horizontally scrollable)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                constraints: const BoxConstraints(minWidth: 950),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DataTable(
                  columnSpacing: 12,
                  horizontalMargin: 12,
                  headingRowHeight: 40,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  headingRowColor: WidgetStateProperty.all(Theme.of(context).dividerColor.withValues(alpha: 0.06)),
                  columns: const [
                    DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Unit Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Gross', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Disc%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Net', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('D/C', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: List.generate(_itemRows.length, (index) {
                    final row = _itemRows[index];
                    return DataRow(
                      cells: [
                        // 1. Product Autocomplete (220px)
                        DataCell(
                          SizedBox(
                            width: 220,
                            child: Autocomplete<ProductModel>(
                              displayStringForOption: (p) => p.name,
                              optionsBuilder: (textEditingValue) {
                                if (textEditingValue.text.isEmpty) return const Iterable<ProductModel>.empty();
                                final q = textEditingValue.text.toLowerCase();
                                return _filteredProducts.where((p) => p.name.toLowerCase().contains(q));
                              },
                              onSelected: (product) async {
                                row.productName = product.name;
                                double price = product.standardRate;
                                if (price <= 0) {
                                  final isSuperAdmin = context.read<AuthProvider>().user?.isSuperAdmin ?? false;
                                  final lastPrice = await _supabase.getLastProductPrice(product.name, isSuperAdmin: isSuperAdmin);
                                  if (lastPrice != null && lastPrice > 0) {
                                    price = lastPrice;
                                  }
                                }
                                row.rateController.text = price > 0 ? price.toStringAsFixed(2) : '';
                                setState(() {});
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                if (controller.text.isEmpty && row.productName.isNotEmpty) {
                                  controller.text = row.productName;
                                }
                                return TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: 'Select product...',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  onChanged: (val) => row.productName = val,
                                );
                              },
                            ),
                          ),
                        ),

                        // 2. Description (140px)
                        DataCell(
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: row.descController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Description',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                          ),
                        ),

                        // 3. Qty (70px)
                        DataCell(
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: row.qtyController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),

                        // 4. Unit Price (85px)
                        DataCell(
                          SizedBox(
                            width: 85,
                            child: TextField(
                              controller: row.rateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),

                        // 5. Gross (80px - Computed)
                        DataCell(
                          SizedBox(
                            width: 80,
                            child: Text(
                              _formatCurrency(row.grossAmount),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),

                        // 6. Disc% (65px)
                        DataCell(
                          SizedBox(
                            width: 65,
                            child: TextField(
                              controller: row.discController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),

                        // 7. Net (80px - Computed)
                        DataCell(
                          SizedBox(
                            width: 80,
                            child: Text(
                              _formatCurrency(row.netAmount),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),

                        // 8. D/C (70px)
                        DataCell(
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: row.delivController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),

                        // 9. Line Total (90px - Computed)
                        DataCell(
                          SizedBox(
                            width: 90,
                            child: Text(
                              _formatCurrency(row.total),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),

                        // 10. Delete Action Button
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            onPressed: _itemRows.length <= 1 ? null : () => _removeItemRow(index),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSummaryCard(AuthProvider auth) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice Summary', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // 4 summary blocks (matches invoice-create-page.tsx totals)
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                return GridView.count(
                  crossAxisCount: isWide ? 4 : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 12,
                  childAspectRatio: isWide ? 2.5 : 2.2,
                  children: [
                    _summaryMetricBox('Subtotal', '${_formatCurrency(_subtotalGross)} BDT'),
                    _summaryMetricBox('Total Discount', '${_formatCurrency(_totalDiscount)} BDT'),
                    _summaryMetricBox('Total Design Charge', '${_formatCurrency(_totalDeliveryCharge)} BDT'),
                    _summaryMetricBox(
                      'Grand Total',
                      '${_formatCurrency(_grandTotal)} BDT',
                      isHighlight: true,
                    ),
                  ],
                );
              },
            ),

            const Divider(height: 24),

            // Prepared By info (matches invoice-create-page.tsx)
            Row(
              children: [
                Text(
                  'Prepared By: ${auth.user?.name.isNotEmpty == true ? auth.user!.name : (auth.user?.userId ?? "System User")}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
                if (auth.user?.name.isNotEmpty == true && auth.user?.userId.isNotEmpty == true)
                  Text(
                    ' (${auth.user!.userId})',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                  ),
                if (auth.user?.role.isNotEmpty == true) ...[
                  const SizedBox(width: 12),
                  Text(
                    '• Role: ${auth.user!.role}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetricBox(String title, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: isHighlight ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: isHighlight ? const Color(0xFF059669) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtonsBar(bool isEditing, AppProvider app) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        // 1. Save Invoice Button
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveInvoice,
          icon: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save, size: 18, color: Colors.white),
          label: Text(
            isEditing ? 'Update Invoice' : 'Save Invoice',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),

        // 2. Generate PDF & Challan Button (Blue Outline)
        OutlinedButton.icon(
          onPressed: (_isSaving || _isGeneratingPdf) ? null : _handleGeneratePdfAndChallan,
          icon: _isGeneratingPdf
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download, size: 18, color: Colors.blueAccent),
          label: const Text('Generate PDF & Challan', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.blueAccent),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),

        // 3. Invoice PDF Button
        OutlinedButton.icon(
          onPressed: (_isSaving || _isGeneratingPdf || _savedInvoiceNo == null) ? null : _handleInvoicePdfOnly,
          icon: const Icon(Icons.picture_as_pdf, size: 16),
          label: const Text('Invoice PDF'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),

        // 4. Challan PDF Button
        OutlinedButton.icon(
          onPressed: (_isSaving || _isGeneratingPdf || _savedInvoiceNo == null) ? null : _handleChallanPdfOnly,
          icon: const Icon(Icons.local_shipping_outlined, size: 16),
          label: const Text('Challan PDF'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),

        // 5. Clear Form Button
        OutlinedButton.icon(
          onPressed: _clearForm,
          icon: const Icon(Icons.rotate_left, size: 16),
          label: const Text('Clear Form'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),

        // 6. Back to History Button (when editing)
        if (isEditing)
          OutlinedButton(
            onPressed: () {
              app.clearEditingInvoice();
              app.setPage(AppPage.invoiceHistory);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Back to History'),
          ),
      ],
    );
  }
}

class _DeliveryContactInfo {
  final String customerId;
  final String customerName;
  final String address;
  final String mobile;
  final bool isSideDelivery;

  _DeliveryContactInfo({
    required this.customerId,
    required this.customerName,
    required this.address,
    required this.mobile,
    required this.isSideDelivery,
  });
}

class _FormItemRow {
  String id = const Uuid().v4();
  String productName = '';
  final TextEditingController qtyController;
  final TextEditingController rateController;
  final TextEditingController discController;
  final TextEditingController delivController;
  final TextEditingController descController;

  _FormItemRow({
    this.productName = '',
    String description = '',
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
