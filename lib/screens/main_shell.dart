import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';
import 'customers_screen.dart';
import 'products_screen.dart';
import 'invoice_create_screen.dart';
import 'invoice_history_screen.dart';
import 'sync_screen.dart';
import 'admin_settings_screen.dart';
import 'user_control_log_screen.dart';
import 'pdf_designer_screen.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final app = context.watch<AppProvider>();
    final user = auth.user;

    final isAdmin = user?.isAdmin ?? false;
    final isSuperAdmin = user?.isSuperAdmin ?? false;

    // Build accessible navigation items based on role & permissions
    final navItems = <_NavItem>[
      _NavItem(page: AppPage.dashboard, title: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
      _NavItem(page: AppPage.customers, title: 'Customers', icon: Icons.people_outline, activeIcon: Icons.people),
      _NavItem(page: AppPage.products, title: 'Products', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2),
      if (isAdmin || (user?.hasPermission('createInvoice') ?? true))
        _NavItem(page: AppPage.invoiceCreate, title: 'Create Invoice', icon: Icons.post_add_outlined, activeIcon: Icons.post_add),
      if (isAdmin || (user?.hasPermission('invoiceHistory') ?? true))
        _NavItem(page: AppPage.invoiceHistory, title: 'Invoice History', icon: Icons.history_outlined, activeIcon: Icons.history),
      if (isAdmin)
        _NavItem(page: AppPage.syncData, title: 'Sync Data', icon: Icons.sync_outlined, activeIcon: Icons.sync, adminOnly: true),
      if (isAdmin)
        _NavItem(page: AppPage.adminSettings, title: 'Admin Settings', icon: Icons.settings_outlined, activeIcon: Icons.settings, adminOnly: true),
      if (isSuperAdmin)
        _NavItem(page: AppPage.userControlLog, title: 'User Control Log', icon: Icons.shield_outlined, activeIcon: Icons.shield, adminOnly: true),
      if (isSuperAdmin)
        _NavItem(page: AppPage.pdfDesigner, title: 'PDF Designer', icon: Icons.palette_outlined, activeIcon: Icons.palette, adminOnly: true),
    ];

    Widget currentWidget;
    switch (app.currentPage) {
      case AppPage.dashboard:
        currentWidget = const DashboardScreen();
        break;
      case AppPage.customers:
        currentWidget = const CustomersScreen();
        break;
      case AppPage.products:
        currentWidget = const ProductsScreen();
        break;
      case AppPage.invoiceCreate:
        currentWidget = const InvoiceCreateScreen();
        break;
      case AppPage.invoiceHistory:
        currentWidget = const InvoiceHistoryScreen();
        break;
      case AppPage.syncData:
        currentWidget = const SyncScreen();
        break;
      case AppPage.adminSettings:
        currentWidget = const AdminSettingsScreen();
        break;
      case AppPage.userControlLog:
        currentWidget = const UserControlLogScreen();
        break;
      case AppPage.pdfDesigner:
        currentWidget = const PdfDesignerScreen();
        break;
    }

    final isWide = MediaQuery.of(context).size.width > 840;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppConstants.primary, AppConstants.secondary]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Invoice Manager',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  navItems.firstWhere((n) => n.page == app.currentPage, orElse: () => navItems.first).title,
                  style: GoogleFonts.inter(fontSize: 11, color: AppConstants.primaryLight),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Online / Offline Status Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: app.isOnline
                  ? AppConstants.primaryDark.withValues(alpha: 0.15)
                  : Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: app.isOnline ? AppConstants.primary.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  app.isOnline ? Icons.cloud_done : Icons.cloud_off,
                  size: 14,
                  color: app.isOnline ? AppConstants.primaryLight : Colors.amber,
                ),
                const SizedBox(width: 5),
                Text(
                  app.isOnline ? 'Cloud' : 'Local',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: app.isOnline ? AppConstants.primaryLight : Colors.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Dark/Light Theme Toggle
          IconButton(
            icon: Icon(app.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined, size: 20),
            tooltip: 'Toggle Theme',
            onPressed: () => app.toggleTheme(),
          ),

          // Logout Action
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: Colors.redAccent),
            tooltip: 'Logout',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                auth.logout();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isWide ? null : Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // User header in drawer
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppConstants.primary,
                      radius: 22,
                      child: Text(
                        (user?.name.isNotEmpty == true ? user!.name[0] : (user?.userId.isNotEmpty == true ? user!.userId[0] : 'U')).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name.isNotEmpty == true ? user!.name : 'User',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'ID: ${user?.userId} (${user?.role})',
                            style: TextStyle(fontSize: 12, color: AppConstants.primaryLight),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Navigation list
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  children: navItems.map((item) {
                    final isSelected = app.currentPage == item.page;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? AppConstants.primary.withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        leading: Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected ? AppConstants.primary : (item.adminOnly ? Colors.amber : null),
                          size: 20,
                        ),
                        title: Text(
                          item.title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppConstants.primary : null,
                          ),
                        ),
                        trailing: item.adminOnly
                            ? const Icon(Icons.shield, size: 14, color: AppConstants.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          app.setPage(item.page);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Drawer footer
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Invoice App v1.0 • Supabase Cloud',
                  style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Row(
        children: [
          // Sidebar on desktop / tablet
          if (isWide)
            Container(
              width: 240,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppConstants.primary,
                          radius: 18,
                          child: Text(
                            (user?.name.isNotEmpty == true ? user!.name[0] : (user?.userId.isNotEmpty == true ? user!.userId[0] : 'U')).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name.isNotEmpty == true ? user!.name : 'User',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${user?.role}',
                                style: TextStyle(fontSize: 11, color: AppConstants.primaryLight),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: navItems.map((item) {
                        final isSelected = app.currentPage == item.page;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? AppConstants.primary.withValues(alpha: 0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            leading: Icon(
                              isSelected ? item.activeIcon : item.icon,
                              color: isSelected ? AppConstants.primary : (item.adminOnly ? Colors.amber : null),
                              size: 18,
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? AppConstants.primary : null,
                              ),
                            ),
                            trailing: item.adminOnly
                                ? const Icon(Icons.shield, size: 14, color: AppConstants.primary)
                                : null,
                            onTap: () => app.setPage(item.page),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

          // Main Screen View
          Expanded(child: currentWidget),
        ],
      ),
    );
  }
}

class _NavItem {
  final AppPage page;
  final String title;
  final IconData icon;
  final IconData activeIcon;
  final bool adminOnly;

  _NavItem({
    required this.page,
    required this.title,
    required this.icon,
    required this.activeIcon,
    this.adminOnly = false,
  });
}
