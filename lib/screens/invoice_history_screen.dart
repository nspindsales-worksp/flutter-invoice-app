import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/invoice_model.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../services/pdf_service.dart';
import '../services/supabase_service.dart';

class InvoiceHistoryScreen extends StatefulWidget {
  const InvoiceHistoryScreen({super.key});

  @override
  State<InvoiceHistoryScreen> createState() => _InvoiceHistoryScreenState();
}

class _InvoiceHistoryScreenState extends State<InvoiceHistoryScreen> {
  final _supabase = SupabaseService.instance;
  final _searchController = TextEditingController();

  List<InvoiceModel> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices({String? search}) async {
    setState(() => _isLoading = true);
    final user = context.read<AuthProvider>().user;

    try {
      final list = await _supabase.getInvoices(
        search: search,
        userId: user?.userId,
        role: user?.role,
        isSuperAdmin: user?.isSuperAdmin ?? false,
      );
      if (mounted) {
        setState(() {
          _invoices = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteInvoice(String invoiceNo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text('Are you sure you want to permanently delete $invoiceNo?'),
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
      await _supabase.deleteInvoice(invoiceNo);
      _loadInvoices(search: _searchController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invoice $invoiceNo deleted'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showInvoiceDetails(InvoiceModel invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(invoice.invoiceNo, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Date: ${invoice.date}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const Divider(height: 20),

                  // Customer info
                  Text('Customer: ${invoice.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (invoice.address.isNotEmpty) Text('Address: ${invoice.address}', style: const TextStyle(fontSize: 12)),
                  if (invoice.mobile.isNotEmpty) Text('Mobile: ${invoice.mobile}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 14),

                  // Line Items
                  Text('Items (${invoice.items.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  ...invoice.items.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text(
                                  'Qty: ${AppUtils.formatAmount(item.quantity, showDecimals: false)} × ${AppUtils.formatAmount(item.unitPrice)}'
                                  '${item.discountPercent > 0 ? " (Disc: ${item.discountPercent.toStringAsFixed(0)}%)" : ""}'
                                  '${item.totalDeliveryCharge > 0 ? " + Deliv: ${AppUtils.formatAmount(item.totalDeliveryCharge)}" : ""}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            AppUtils.formatAmount(item.total),
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppConstants.primaryLight),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 20),

                  // Summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        AppUtils.formatAmount(invoice.totalAmount),
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryLight),
                      ),
                    ],
                  ),
                  if (invoice.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Notes: ${invoice.notes}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 24),

                  // Action buttons inside sheet
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final settings = await _supabase.getSettings();
                            await PdfService.instance.printInvoice(invoice, settings);
                          },
                          icon: const Icon(Icons.picture_as_pdf, size: 16),
                          label: const Text('Invoice PDF'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final settings = await _supabase.getSettings();
                            await PdfService.instance.printChallan(invoice, settings);
                          },
                          icon: const Icon(Icons.local_shipping, size: 16),
                          label: const Text('Challan'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Invoice No, Customer, Phone...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _loadInvoices();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (val) => _loadInvoices(search: val),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload Invoices',
                  onPressed: () => _loadInvoices(search: _searchController.text),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Invoices count badge
            Text(
              '${_invoices.length} Invoices Found',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).hintColor),
            ),
            const SizedBox(height: 10),

            // Invoices List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _invoices.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text('No invoices found'),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => app.setPage(AppPage.invoiceCreate),
                                child: const Text('Create New Invoice'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _invoices.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final inv = _invoices[index];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.receipt, color: AppConstants.primary, size: 22),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      inv.invoiceNo,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    if (inv.sideDelivery)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Side Delivery',
                                          style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      inv.customerName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    Text(
                                      '${inv.date} • ${inv.items.length} items ${inv.mobile.isNotEmpty ? "• ${inv.mobile}" : ""}',
                                      style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          AppUtils.formatAmount(inv.totalAmount),
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppConstants.primaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),

                                    // Popup Menu for actions
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 20),
                                      onSelected: (val) async {
                                        final settings = await _supabase.getSettings();
                                        if (val == 'view') {
                                          _showInvoiceDetails(inv);
                                        } else if (val == 'edit') {
                                          app.startEditingInvoice(inv);
                                        } else if (val == 'pdf') {
                                          await PdfService.instance.printInvoice(inv, settings);
                                        } else if (val == 'challan') {
                                          await PdfService.instance.printChallan(inv, settings);
                                        } else if (val == 'share') {
                                          await PdfService.instance.shareInvoice(inv, settings);
                                        } else if (val == 'delete') {
                                          _deleteInvoice(inv.invoiceNo);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'view',
                                          child: Row(children: [Icon(Icons.visibility, size: 16), SizedBox(width: 8), Text('View Details')]),
                                        ),
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit Invoice')]),
                                        ),
                                        const PopupMenuItem(
                                          value: 'pdf',
                                          child: Row(children: [Icon(Icons.picture_as_pdf, size: 16), SizedBox(width: 8), Text('Print PDF')]),
                                        ),
                                        const PopupMenuItem(
                                          value: 'challan',
                                          child: Row(children: [Icon(Icons.local_shipping, size: 16), SizedBox(width: 8), Text('Print Challan')]),
                                        ),
                                        const PopupMenuItem(
                                          value: 'share',
                                          child: Row(children: [Icon(Icons.share, size: 16), SizedBox(width: 8), Text('Share')]),
                                        ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(children: [Icon(Icons.delete, size: 16, color: Colors.redAccent), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.redAccent))]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () => _showInvoiceDetails(inv),
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
