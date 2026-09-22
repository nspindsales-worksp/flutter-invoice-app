import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/invoice_model.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  int _totalCustomers = 0;
  int _totalProducts = 0;
  int _totalInvoices = 0;
  double _totalRevenue = 0.0;
  List<InvoiceModel> _recentInvoices = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final supabase = SupabaseService.instance;
    final user = context.read<AuthProvider>().user;

    try {
      final customers = await supabase.getCustomers();
      final products = await supabase.getProducts();
      final invoices = await supabase.getInvoices(
        userId: user?.userId,
        role: user?.role,
      );

      double revenue = 0.0;
      for (var inv in invoices) {
        revenue += inv.totalAmount;
      }

      if (mounted) {
        setState(() {
          _totalCustomers = customers.length;
          _totalProducts = products.length;
          _totalInvoices = invoices.length;
          _totalRevenue = revenue;
          _recentInvoices = invoices.take(8).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${user?.name.isNotEmpty == true ? user!.name : user?.userId}!',
                      style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Here is your business overview today.',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload stats',
                  onPressed: _loadDashboardData,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4 Stat Cards Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 600;
                final crossAxisCount = isCompact ? 2 : 4;
                final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStatCard(
                      width: cardWidth,
                      title: 'Total Customers',
                      value: '$_totalCustomers',
                      icon: Icons.people_outline,
                      color: AppConstants.primary,
                    ),
                    _buildStatCard(
                      width: cardWidth,
                      title: 'Total Products',
                      value: '$_totalProducts',
                      icon: Icons.inventory_2_outlined,
                      color: AppConstants.secondary,
                    ),
                    _buildStatCard(
                      width: cardWidth,
                      title: 'Total Invoices',
                      value: '$_totalInvoices',
                      icon: Icons.receipt_long_outlined,
                      color: Colors.cyan,
                    ),
                    _buildStatCard(
                      width: cardWidth,
                      title: 'Total Revenue',
                      value: AppUtils.formatAmount(_totalRevenue),
                      icon: Icons.monetization_on_outlined,
                      color: Colors.amber,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Quick Actions Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Actions',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => app.setPage(AppPage.invoiceCreate),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create Invoice'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => app.setPage(AppPage.customers),
                          icon: const Icon(Icons.person_add_outlined, size: 18),
                          label: const Text('Customers'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => app.setPage(AppPage.products),
                          icon: const Icon(Icons.post_add, size: 18),
                          label: const Text('Products'),
                        ),
                        if (user?.isAdmin == true)
                          OutlinedButton.icon(
                            onPressed: () => app.setPage(AppPage.syncData),
                            icon: const Icon(Icons.cloud_sync_outlined, size: 18),
                            label: const Text('Sync Sheets'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Recent Invoices Table
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Invoices',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () => app.setPage(AppPage.invoiceHistory),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const Divider(),
                    if (_recentInvoices.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No invoices recorded yet. Tap "Create Invoice" to begin!'),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _recentInvoices.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final inv = _recentInvoices[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppConstants.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.receipt, color: AppConstants.primary, size: 20),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  inv.invoiceNo,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
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
                                      style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              '${inv.customerName} • ${inv.date} • ${inv.items.length} items',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppUtils.formatAmount(inv.totalAmount),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppConstants.primaryLight,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.print_outlined, size: 18),
                                  tooltip: 'Print PDF',
                                  onPressed: () async {
                                    final settings = await SupabaseService.instance.getSettings();
                                    await PdfService.instance.printInvoice(inv, settings);
                                  },
                                ),
                              ],
                            ),
                            onTap: () => app.startEditingInvoice(inv),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Theme.of(context).hintColor),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
