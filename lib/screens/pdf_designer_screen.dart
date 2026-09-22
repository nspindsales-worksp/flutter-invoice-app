import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../models/settings_model.dart';
import '../services/pdf_service.dart';
import '../services/supabase_service.dart';

class PdfDesignerScreen extends StatefulWidget {
  const PdfDesignerScreen({super.key});

  @override
  State<PdfDesignerScreen> createState() => _PdfDesignerScreenState();
}

class _PdfDesignerScreenState extends State<PdfDesignerScreen> {
  final _supabase = SupabaseService.instance;
  SettingsModel _settings = SettingsModel();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final s = await _supabase.getSettings();
    if (mounted) {
      setState(() {
        _settings = s;
        _isLoading = false;
      });
    }
  }

  InvoiceModel _getSampleInvoice() {
    return InvoiceModel(
      invoiceNo: 'INV-DEMO8888',
      date: '2026-09-22',
      customerId: 'CUST-001',
      customerName: 'Sample Enterprise Ltd.',
      address: 'House 12, Road 4, Gulshan-2, Dhaka',
      mobile: '01712-345678',
      priceListName: 'Standard',
      createdBy: 'Dev.Raz',
      items: [
        InvoiceItemModel(id: '1', productName: 'Premium Office Paper 80gsm', description: 'A4 size 500 sheets ream', quantity: 10, unitPrice: 450, discountPercent: 5, deliveryChargePerUnit: 10),
        InvoiceItemModel(id: '2', productName: 'Laser Toner Cartridge Black', description: 'High yield replacement', quantity: 2, unitPrice: 2800, discountPercent: 0, deliveryChargePerUnit: 25),
        InvoiceItemModel(id: '3', productName: 'Executive Ballpoint Pen Box', description: 'Blue ink box of 50', quantity: 5, unitPrice: 320, discountPercent: 10, deliveryChargePerUnit: 0),
      ],
      notes: 'Thank you for your business! Payment is due within 15 days.',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: SingleChildScrollView(
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
                    Text('PDF Document Designer', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Customize PDF layout, typography, and test print preview', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final sample = _getSampleInvoice();
                    await PdfService.instance.printInvoice(sample, _settings);
                  },
                  icon: const Icon(Icons.preview),
                  label: const Text('Live PDF Preview'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Design Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Page Margins Configuration', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('Top Margin: ${_settings.marginTop.round()} pt'),
                    Slider(
                      value: _settings.marginTop,
                      min: 20,
                      max: 80,
                      divisions: 12,
                      activeColor: AppConstants.primary,
                      onChanged: (val) => setState(() => _settings = _settings.copyWith(marginTop: val)),
                    ),
                    Text('Bottom Margin: ${_settings.marginBottom.round()} pt'),
                    Slider(
                      value: _settings.marginBottom,
                      min: 20,
                      max: 80,
                      divisions: 12,
                      activeColor: AppConstants.primary,
                      onChanged: (val) => setState(() => _settings = _settings.copyWith(marginBottom: val)),
                    ),
                    Text('Left & Right Margins: ${_settings.marginLeft.round()} pt'),
                    Slider(
                      value: _settings.marginLeft,
                      min: 20,
                      max: 80,
                      divisions: 12,
                      activeColor: AppConstants.primary,
                      onChanged: (val) => setState(() => _settings = _settings.copyWith(marginLeft: val, marginRight: val)),
                    ),
                    const Divider(height: 24),

                    SwitchListTile(
                      title: const Text('Show "Prepared By" Signature Block'),
                      subtitle: const Text('Displays signature line and user ID at document bottom'),
                      value: _settings.showPreparedBy,
                      activeThumbColor: AppConstants.primary,
                      onChanged: (val) => setState(() => _settings = _settings.copyWith(showPreparedBy: val)),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await _supabase.saveSettings(_settings);
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Designer preferences saved!'), backgroundColor: AppConstants.primaryDark),
                          );
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('Save Designer Preferences'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppConstants.secondary),
                      ),
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
}
