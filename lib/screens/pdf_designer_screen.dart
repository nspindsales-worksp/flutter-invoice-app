import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/invoice_item_model.dart';
import '../models/invoice_model.dart';
import '../models/pdf_template_model.dart';
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

  bool _isChallan = false; // false = Invoice, true = Delivery Challan
  PdfTemplateConfig _invoiceConfig = PdfTemplateConfig.defaultInvoiceTemplate();
  PdfTemplateConfig _challanConfig = PdfTemplateConfig.defaultChallanTemplate();
  SettingsModel _settings = SettingsModel();

  int _selectedElementIndex = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  final _customTextCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _customTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final s = await _supabase.getSettings();
      final invTpl = await _supabase.getPdfTemplate(isChallan: false);
      final chnTpl = await _supabase.getPdfTemplate(isChallan: true);

      if (mounted) {
        setState(() {
          _settings = s;
          _invoiceConfig = invTpl;
          _challanConfig = chnTpl;
          _isLoading = false;
          _syncEditorControllers();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  PdfTemplateConfig get _currentConfig => _isChallan ? _challanConfig : _invoiceConfig;

  void _syncEditorControllers() {
    final elements = _currentConfig.elements;
    if (_selectedElementIndex >= 0 && _selectedElementIndex < elements.length) {
      final el = elements[_selectedElementIndex];
      _customTextCtrl.text = el.customText ?? '';
    }
  }

  void _updateCurrentConfig(PdfTemplateConfig updated) {
    setState(() {
      if (_isChallan) {
        _challanConfig = updated;
      } else {
        _invoiceConfig = updated;
      }
    });
  }

  Future<void> _saveCurrentTemplate() async {
    setState(() => _isSaving = true);
    try {
      await _supabase.savePdfTemplate(_currentConfig, isChallan: _isChallan);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_isChallan ? "Delivery Challan" : "Invoice"} PDF template saved successfully!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving template: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetToDefault() {
    setState(() {
      if (_isChallan) {
        _challanConfig = PdfTemplateConfig.defaultChallanTemplate();
      } else {
        _invoiceConfig = PdfTemplateConfig.defaultInvoiceTemplate();
      }
      _selectedElementIndex = 0;
      _syncEditorControllers();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset to default layout')),
    );
  }

  Future<void> _previewRealPdf() async {
    try {
      final sampleInvoice = InvoiceModel(
        invoiceNo: 'INV-DEMO9999',
        date: '2026-09-22',
        customerId: 'CUST-001',
        customerName: 'Sample Corporation Ltd.',
        address: 'House 12, Road 4, Banani, Dhaka',
        mobile: '01712-345678',
        priceListName: 'Retail Standard',
        items: [
          InvoiceItemModel(
            id: 'P1',
            productName: 'Sample Premium Product A',
            description: 'High durability specification',
            quantity: 5,
            unitPrice: 500,
            discountPercent: 10,
            deliveryChargePerUnit: 20,
          ),
          InvoiceItemModel(
            id: 'P2',
            productName: 'Sample Standard Product B',
            quantity: 2,
            unitPrice: 1000,
            discountPercent: 0,
            deliveryChargePerUnit: 0,
          ),
        ],
        notes: 'Sample invoice generated from PDF Designer live test.',
        createdBy: 'Admin',
      );

      if (_isChallan) {
        await PdfService.instance.printChallan(sampleInvoice, _settings, template: _currentConfig);
      } else {
        await PdfService.instance.printInvoice(sampleInvoice, _settings, template: _currentConfig);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF preview: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _moveElement(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _currentConfig.elements.length) return;
    final list = List<PdfElementConfig>.from(_currentConfig.elements);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _updateCurrentConfig(PdfTemplateConfig(elements: list, notesPosition: _currentConfig.notesPosition));
    setState(() => _selectedElementIndex = newIndex);
  }

  void _toggleElementVisibility(int index) {
    final list = List<PdfElementConfig>.from(_currentConfig.elements);
    final el = list[index];
    list[index] = el.copyWith(visible: !el.visible);
    _updateCurrentConfig(PdfTemplateConfig(elements: list, notesPosition: _currentConfig.notesPosition));
  }

  void _updateSelectedElement({
    double? fontSize,
    bool? bold,
    String? align,
    String? color,
    String? customText,
    String? outlineStyle,
    String? outlineColor,
    double? outlineWidth,
    String? bgTint,
  }) {
    if (_selectedElementIndex < 0 || _selectedElementIndex >= _currentConfig.elements.length) return;
    final list = List<PdfElementConfig>.from(_currentConfig.elements);
    final el = list[_selectedElementIndex];
    list[_selectedElementIndex] = el.copyWith(
      fontSize: fontSize,
      bold: bold,
      align: align,
      color: color,
      customText: customText,
      outlineStyle: outlineStyle,
      outlineColor: outlineColor,
      outlineWidth: outlineWidth,
      bgTint: bgTint,
    );
    _updateCurrentConfig(PdfTemplateConfig(elements: list, notesPosition: _currentConfig.notesPosition));
  }

  Color _parseHex(String hex, [Color fallback = Colors.black]) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('0xFF$clean'));
      } else if (clean.length == 8) {
        return Color(int.parse('0x$clean'));
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Title & Template Switcher
            _buildTopBar(),
            const SizedBox(height: 16),

            // Responsive 2-column or 1-column layout
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildLeftControls()),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: _buildRightLivePreview()),
                ],
              )
            else
              Column(
                children: [
                  _buildLeftControls(),
                  const SizedBox(height: 20),
                  _buildRightLivePreview(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.palette_outlined, color: Color(0xFF059669), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PDF Template Designer', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    'Reorder, customize lines, fonts, colors, and outlines for Invoice and Delivery Challan documents.',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),

            // Template Switcher (Invoice vs Challan)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: false, label: Text('Invoice PDF', style: TextStyle(fontSize: 11))),
                ButtonSegment<bool>(value: true, label: Text('Challan PDF', style: TextStyle(fontSize: 11))),
              ],
              selected: {_isChallan},
              onSelectionChanged: (set) {
                setState(() {
                  _isChallan = set.first;
                  _selectedElementIndex = 0;
                  _syncEditorControllers();
                });
              },
            ),
            const SizedBox(width: 12),

            // Reset button
            OutlinedButton(
              onPressed: _resetToDefault,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Reset', style: TextStyle(fontSize: 11)),
            ),
            const SizedBox(width: 8),

            // Preview / Test PDF button
            OutlinedButton.icon(
              onPressed: _previewRealPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 14, color: Color(0xFF0284C7)),
              label: const Text('Test PDF', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0284C7)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(width: 8),

            // Save button
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveCurrentTemplate,
              icon: _isSaving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 14, color: Colors.white),
              label: const Text('Save Template', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftControls() {
    final elements = _currentConfig.elements;
    final selected = (_selectedElementIndex >= 0 && _selectedElementIndex < elements.length)
        ? elements[_selectedElementIndex]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Elements Order & Visibility List
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Document Elements & Order (Move / Toggle)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${elements.where((e) => e.visible).length}/${elements.length} visible',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                  ],
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: elements.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 6),
                  itemBuilder: (ctx, i) {
                    final el = elements[i];
                    final isSel = i == _selectedElementIndex;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedElementIndex = i;
                          _syncEditorControllers();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFF059669).withValues(alpha: 0.1)
                              : el.visible
                                  ? Theme.of(context).dividerColor.withValues(alpha: 0.04)
                                  : Theme.of(context).dividerColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel
                                ? const Color(0xFF059669)
                                : Theme.of(context).dividerColor.withValues(alpha: 0.25),
                            width: isSel ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Up / Down reorder controls
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: i > 0 ? () => _moveElement(i, i - 1) : null,
                                  child: Icon(Icons.arrow_drop_up, size: 18, color: i > 0 ? const Color(0xFF059669) : Colors.grey.shade400),
                                ),
                                InkWell(
                                  onTap: i < elements.length - 1 ? () => _moveElement(i, i + 1) : null,
                                  child: Icon(Icons.arrow_drop_down, size: 18, color: i < elements.length - 1 ? const Color(0xFF059669) : Colors.grey.shade400),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),

                            // Color chip & label
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _parseHex(el.color),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade400, width: 0.5),
                              ),
                            ),
                            const SizedBox(width: 8),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    el.label,
                                    style: TextStyle(
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 12,
                                      color: el.visible ? null : Theme.of(context).hintColor,
                                    ),
                                  ),
                                  Text(
                                    '${el.fontSize.toStringAsFixed(0)}pt ${el.bold ? "bold" : "regular"} • ${el.align} • outline: ${el.outlineStyle}',
                                    style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor),
                                  ),
                                ],
                              ),
                            ),

                            // Visibility toggle
                            Switch(
                              value: el.visible,
                              activeThumbColor: const Color(0xFF059669),
                              onChanged: (_) => _toggleElementVisibility(i),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Selected Element Granular Part Customizer
        if (selected != null)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFF059669), size: 18),
                      const SizedBox(width: 8),
                      Text('Customize: ${selected.label}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 20),

                  // A. Custom Text Override (if applicable)
                  if (selected.id == 'title' || selected.id == 'footer' || selected.id == 'notes') ...[
                    const Text('Custom Text Override', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _customTextCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: 'Enter custom text...'),
                      onChanged: (val) => _updateSelectedElement(customText: val),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // B. Font Settings (Size, Bold, Align)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Font Size: ${selected.fontSize.toStringAsFixed(0)}pt',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Slider(
                              value: selected.fontSize.clamp(6.0, 32.0),
                              min: 6,
                              max: 32,
                              divisions: 26,
                              activeColor: const Color(0xFF059669),
                              onChanged: (v) => _updateSelectedElement(fontSize: v),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bold Weight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          ChoiceChip(
                            label: const Text('Bold', style: TextStyle(fontSize: 11)),
                            selected: selected.bold,
                            selectedColor: const Color(0xFF059669).withValues(alpha: 0.2),
                            onSelected: (b) => _updateSelectedElement(bold: b),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Alignment
                  const Text('Text Alignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left, size: 16), label: Text('Left', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: 'center', icon: Icon(Icons.format_align_center, size: 16), label: Text('Center', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: 'right', icon: Icon(Icons.format_align_right, size: 16), label: Text('Right', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {selected.align},
                    onSelectionChanged: (set) => _updateSelectedElement(align: set.first),
                  ),
                  const SizedBox(height: 14),

                  // C. Color Customization
                  const Text('Element Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      '#000000',
                      '#059669',
                      '#0284C7',
                      '#7C3AED',
                      '#DC2626',
                      '#D97706',
                      '#4B5563',
                    ].map((hex) {
                      final isCurrent = selected.color.toLowerCase() == hex.toLowerCase();
                      return InkWell(
                        onTap: () => _updateSelectedElement(color: hex),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _parseHex(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCurrent ? Colors.black : Colors.grey.shade400,
                              width: isCurrent ? 2.5 : 1.0,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // D. Outline & Line Design
                  const Text('Outline / Border & Lines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: selected.outlineStyle,
                    isDense: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None (Clean Layout)')),
                      DropdownMenuItem(value: 'box', child: Text('Box Outline Border')),
                      DropdownMenuItem(value: 'top_bottom', child: Text('Top & Bottom Divider Lines')),
                      DropdownMenuItem(value: 'left_bar', child: Text('Left Accent Line')),
                    ],
                    onChanged: (val) => _updateSelectedElement(outlineStyle: val ?? 'none'),
                  ),
                  const SizedBox(height: 10),

                  // Line thickness & tint
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Line Thickness: ${selected.outlineWidth.toStringAsFixed(1)}pt',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            Slider(
                              value: selected.outlineWidth.clamp(0.5, 3.0),
                              min: 0.5,
                              max: 3.0,
                              divisions: 5,
                              activeColor: const Color(0xFF059669),
                              onChanged: (w) => _updateSelectedElement(outlineWidth: w),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Background Tint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              initialValue: selected.bgTint,
                              isDense: true,
                              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                              items: const [
                                DropdownMenuItem(value: 'none', child: Text('None', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'subtle_gray', child: Text('Soft Gray', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'subtle_teal', child: Text('Soft Teal', style: TextStyle(fontSize: 11))),
                                DropdownMenuItem(value: 'subtle_amber', child: Text('Soft Amber', style: TextStyle(fontSize: 11))),
                              ],
                              onChanged: (tint) => _updateSelectedElement(bgTint: tint ?? 'none'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRightLivePreview() {
    final elements = _currentConfig.elements;

    return Card(
      elevation: 3,
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
                    const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 8),
                    Text('Live A4 Canvas Preview', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_isChallan ? 'Challan Format' : 'Invoice Format',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Scaled Mockup Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
                ],
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: elements.where((e) => e.visible).map((el) {
                  return _renderPreviewElement(el);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderPreviewElement(PdfElementConfig el) {
    final textColor = _parseHex(el.color);
    final borderColor = _parseHex(el.outlineColor, Colors.grey.shade400);

    BoxDecoration boxDeco = const BoxDecoration();
    if (el.outlineStyle == 'box') {
      boxDeco = BoxDecoration(
        border: Border.all(color: borderColor, width: el.outlineWidth),
        color: _getBgTintColor(el.bgTint),
        borderRadius: BorderRadius.circular(4),
      );
    } else if (el.outlineStyle == 'top_bottom') {
      boxDeco = BoxDecoration(
        border: Border(
          top: BorderSide(color: borderColor, width: el.outlineWidth),
          bottom: BorderSide(color: borderColor, width: el.outlineWidth),
        ),
        color: _getBgTintColor(el.bgTint),
      );
    } else if (el.outlineStyle == 'left_bar') {
      boxDeco = BoxDecoration(
        border: Border(left: BorderSide(color: borderColor, width: el.outlineWidth * 3)),
        color: _getBgTintColor(el.bgTint),
      );
    } else if (el.bgTint != 'none') {
      boxDeco = BoxDecoration(color: _getBgTintColor(el.bgTint), borderRadius: BorderRadius.circular(4));
    }

    TextAlign textAlign = TextAlign.left;
    if (el.align == 'center') textAlign = TextAlign.center;
    if (el.align == 'right') textAlign = TextAlign.right;

    Widget child;

    switch (el.id) {
      case 'company-header':
        child = Column(
          crossAxisAlignment: el.align == 'center'
              ? CrossAxisAlignment.center
              : el.align == 'right'
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
          children: [
            Text(
              _settings.companyName.toUpperCase(),
              textAlign: textAlign,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: (el.fontSize * 0.75).clamp(10.0, 20.0)),
            ),
            if (_settings.companyAddress.isNotEmpty)
              Text(_settings.companyAddress, textAlign: textAlign, style: const TextStyle(fontSize: 8.5, color: Colors.black54)),
            if (_settings.companyMobile.isNotEmpty)
              Text('Mobile: ${_settings.companyMobile}', textAlign: textAlign, style: const TextStyle(fontSize: 8.5, color: Colors.black54)),
          ],
        );
        break;

      case 'title':
        final titleText = el.customText?.isNotEmpty == true ? el.customText! : (_isChallan ? 'DELIVERY ORDER' : 'INVOICE');
        child = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: boxDeco,
          alignment: el.align == 'center'
              ? Alignment.center
              : el.align == 'right'
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
          child: Text(
            titleText,
            style: TextStyle(color: textColor, fontWeight: el.bold ? FontWeight.bold : FontWeight.normal, fontSize: (el.fontSize * 0.75).clamp(9.0, 18.0)),
          ),
        );
        break;

      case 'customer-info':
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isChallan ? 'DELIVERY TO:' : 'CUSTOMER DETAILS:',
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black45)),
            const SizedBox(height: 2),
            Text('Demo Corporation Ltd.', style: TextStyle(fontWeight: el.bold ? FontWeight.bold : FontWeight.w600, fontSize: 10, color: textColor)),
            const Text('House 12, Road 4, Banani, Dhaka • Phone: 01712-345678', style: TextStyle(fontSize: 8, color: Colors.black87)),
          ],
        );
        break;

      case 'date-info':
        child = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Date: 2026-09-22', style: TextStyle(fontSize: 8.5, color: Colors.black87)),
            Text('${_isChallan ? "Challan" : "Invoice"} No: INV-DEMO8888',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: textColor)),
          ],
        );
        break;

      case 'product-table':
        child = Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
          child: Table(
            columnWidths: const {
              0: FixedColumnWidth(24),
              1: FlexColumnWidth(4),
              2: FixedColumnWidth(36),
              3: FixedColumnWidth(48),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: [
                  const Padding(padding: EdgeInsets.all(4), child: Text('#', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black))),
                  const Padding(padding: EdgeInsets.all(4), child: Text('Product / Description', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black))),
                  const Padding(padding: EdgeInsets.all(4), child: Text('Qty', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black))),
                  Padding(padding: const EdgeInsets.all(4), child: Text(_isChallan ? 'Remarks' : 'Total', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black))),
                ],
              ),
              const TableRow(
                children: [
                  Padding(padding: EdgeInsets.all(4), child: Text('1', style: TextStyle(fontSize: 8, color: Colors.black))),
                  Padding(padding: EdgeInsets.all(4), child: Text('Premium Office Paper A4', style: TextStyle(fontSize: 8, color: Colors.black))),
                  Padding(padding: EdgeInsets.all(4), child: Text('10', style: TextStyle(fontSize: 8, color: Colors.black))),
                  Padding(padding: EdgeInsets.all(4), child: Text('4,500.00', style: TextStyle(fontSize: 8, color: Colors.black))),
                ],
              ),
            ],
          ),
        );
        break;

      case 'notes':
        final noteTitle = el.customText?.isNotEmpty == true ? el.customText! : 'Special Instructions:';
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(noteTitle, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 2),
            const Text('Payment due within 15 days. Please inspect goods upon delivery.', style: TextStyle(fontSize: 8, color: Colors.black87)),
          ],
        );
        break;

      case 'totals':
        child = const Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Subtotal: 4,500.00 BDT', style: TextStyle(fontSize: 8, color: Colors.black87)),
              Text('Discount: 225.00 BDT', style: TextStyle(fontSize: 8, color: Colors.black54)),
            ],
          ),
        );
        break;

      case 'grand-total':
        child = Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: boxDeco,
            child: Text(
              'Grand Total: 4,275.00 BDT',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: (el.fontSize * 0.75).clamp(9.0, 16.0)),
            ),
          ),
        );
        break;

      case 'prepared-by':
        child = Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 90, height: 0.5, color: Colors.grey.shade400),
                const SizedBox(height: 2),
                const Text('Prepared By: Admin', style: TextStyle(fontSize: 7.5, color: Colors.black54)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(width: 90, height: 0.5, color: Colors.grey.shade400),
                const SizedBox(height: 2),
                const Text('Authorized Signature', style: TextStyle(fontSize: 7.5, color: Colors.black54)),
              ],
            ),
          ],
        );
        break;

      case 'footer':
        final footerText = el.customText?.isNotEmpty == true
            ? el.customText!
            : (_isChallan ? _settings.challanFooterText : _settings.invoiceFooterText);
        child = Center(
          child: Text(footerText, style: TextStyle(fontSize: 7, color: textColor)),
        );
        break;

      default:
        child = Text(el.label, style: TextStyle(fontSize: 9, color: textColor));
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: el.outlineStyle != 'none' ? const EdgeInsets.all(6) : EdgeInsets.zero,
      decoration: el.id != 'title' && el.id != 'grand-total' ? boxDeco : null,
      child: child,
    );
  }

  Color _getBgTintColor(String tint) {
    switch (tint) {
      case 'subtle_gray':
        return Colors.grey.shade100;
      case 'subtle_teal':
        return const Color(0xFF059669).withValues(alpha: 0.08);
      case 'subtle_amber':
        return Colors.amber.withValues(alpha: 0.08);
      default:
        return Colors.transparent;
    }
  }
}
