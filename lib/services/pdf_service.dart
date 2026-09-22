import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/utils.dart';
import '../models/invoice_model.dart';
import '../models/pdf_template_model.dart';
import '../models/settings_model.dart';
import 'supabase_service.dart';

class PdfService {
  static final PdfService instance = PdfService._internal();
  PdfService._internal();

  /// Generates the complete professional Invoice PDF with dynamic template customization
  Future<Uint8List> generateInvoicePdf(
    InvoiceModel invoice,
    SettingsModel settings, {
    PdfTemplateConfig? template,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final tpl = template ?? await SupabaseService.instance.getPdfTemplate(isChallan: false);
    final visibleElements = tpl.elements.where((e) => e.visible).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(
          settings.marginLeft,
          settings.marginTop,
          settings.marginRight,
          settings.marginBottom,
        ),
        build: (context) {
          final List<pw.Widget> widgets = [];
          int i = 0;

          while (i < visibleElements.length) {
            final el = visibleElements[i];

            // 1. Company Header
            if (el.id == 'company-header') {
              final textColor = _parsePdfColor(el.color);
              final fontSize = el.fontSize > 0 ? el.fontSize : 16.0;
              final headerWidget = pw.Column(
                crossAxisAlignment: _parseCrossAlign(el.align),
                children: [
                  pw.Text(
                    settings.companyName.toUpperCase(),
                    textAlign: _parsePdfAlign(el.align),
                    style: pw.TextStyle(
                      font: el.bold ? fontBold : fontRegular,
                      fontSize: fontSize,
                      color: textColor,
                    ),
                  ),
                  if (settings.companyAddress.isNotEmpty)
                    pw.Text(
                      settings.companyAddress,
                      textAlign: _parsePdfAlign(el.align),
                      style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700),
                    ),
                  if (settings.companyMobile.isNotEmpty)
                    pw.Text(
                      'Mobile: ${settings.companyMobile}',
                      textAlign: _parsePdfAlign(el.align),
                      style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700),
                    ),
                ],
              );
              widgets.add(_wrapWithBoxOutline(headerWidget, el));
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            // 2. Title
            if (el.id == 'title') {
              final titleText = el.customText?.isNotEmpty == true ? el.customText! : settings.invoiceTitle;
              final textColor = _parsePdfColor(el.color);
              final fontSize = el.fontSize > 0 ? el.fontSize : 13.0;

              final titleWidget = pw.Container(
                alignment: _parseAlignment(el.align),
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: pw.Text(
                  titleText,
                  textAlign: _parsePdfAlign(el.align),
                  style: pw.TextStyle(
                    font: el.bold ? fontBold : fontRegular,
                    fontSize: fontSize,
                    color: textColor,
                    letterSpacing: 1,
                  ),
                ),
              );
              widgets.add(_wrapWithBoxOutline(titleWidget, el));
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            // 3. Customer Info & Date Info (side-by-side if adjacent)
            if (el.id == 'customer-info' &&
                i + 1 < visibleElements.length &&
                visibleElements[i + 1].id == 'date-info') {
              final custEl = el;
              final dateEl = visibleElements[i + 1];
              widgets.add(
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 6, child: _buildCustomerInfo(invoice, custEl, fontRegular, fontBold)),
                    pw.SizedBox(width: 14),
                    pw.Expanded(flex: 4, child: _buildDateInfo(invoice, dateEl, fontRegular, fontBold)),
                  ],
                ),
              );
              widgets.add(pw.SizedBox(height: 10));
              i += 2;
              continue;
            }

            if (el.id == 'date-info' &&
                i + 1 < visibleElements.length &&
                visibleElements[i + 1].id == 'customer-info') {
              final dateEl = el;
              final custEl = visibleElements[i + 1];
              widgets.add(
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 4, child: _buildDateInfo(invoice, dateEl, fontRegular, fontBold)),
                    pw.SizedBox(width: 14),
                    pw.Expanded(flex: 6, child: _buildCustomerInfo(invoice, custEl, fontRegular, fontBold)),
                  ],
                ),
              );
              widgets.add(pw.SizedBox(height: 10));
              i += 2;
              continue;
            }

            if (el.id == 'customer-info') {
              widgets.add(_buildCustomerInfo(invoice, el, fontRegular, fontBold));
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            if (el.id == 'date-info') {
              widgets.add(_buildDateInfo(invoice, el, fontRegular, fontBold));
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            // 4. Product Table
            if (el.id == 'product-table') {
              widgets.add(_buildProductTable(invoice, el, fontRegular, fontBold));
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            // 5. Notes & Totals (side-by-side if adjacent)
            if (el.id == 'notes' &&
                i + 1 < visibleElements.length &&
                visibleElements[i + 1].id == 'totals') {
              final notesEl = el;
              final totalsEl = visibleElements[i + 1];
              widgets.add(
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 5, child: _buildNotes(invoice, notesEl, fontRegular, fontBold)),
                    pw.SizedBox(width: 14),
                    pw.Expanded(flex: 5, child: _buildTotals(invoice, totalsEl, fontRegular, fontBold)),
                  ],
                ),
              );
              widgets.add(pw.SizedBox(height: 10));
              i += 2;
              continue;
            }

            if (el.id == 'notes') {
              widgets.add(_buildNotes(invoice, el, fontRegular, fontBold));
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            if (el.id == 'totals') {
              widgets.add(
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 250,
                    child: _buildTotals(invoice, el, fontRegular, fontBold),
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            // 6. Standalone Grand Total Highlight
            if (el.id == 'grand-total') {
              final textColor = _parsePdfColor(el.color, PdfColors.teal800);
              final fontSize = el.fontSize > 0 ? el.fontSize : 12.0;
              final gtWidget = pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('GRAND TOTAL:', style: pw.TextStyle(font: fontBold, fontSize: fontSize, color: textColor)),
                    pw.Text(AppUtils.formatAmount(invoice.totalAmount), style: pw.TextStyle(font: fontBold, fontSize: fontSize + 1, color: textColor)),
                  ],
                ),
              );
              widgets.add(
                pw.Align(
                  alignment: _parseAlignment(el.align),
                  child: pw.Container(
                    width: 260,
                    child: _wrapWithBoxOutline(gtWidget, el),
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 12));
              i++;
              continue;
            }

            // 7. Prepared By / Signatures
            if (el.id == 'prepared-by') {
              widgets.add(_buildPreparedBy(invoice, settings, el, fontRegular, fontBold));
              widgets.add(pw.SizedBox(height: 14));
              i++;
              continue;
            }

            // 8. Footer
            if (el.id == 'footer') {
              widgets.add(_buildFooter(settings, el, fontRegular, fontBold, isChallan: false));
              widgets.add(pw.SizedBox(height: 8));
              i++;
              continue;
            }

            i++;
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  /// Generates the Delivery Order Challan PDF with dynamic template customization
  Future<Uint8List> generateChallanPdf(
    InvoiceModel invoice,
    SettingsModel settings, {
    PdfTemplateConfig? template,
  }) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    final tpl = template ?? await SupabaseService.instance.getPdfTemplate(isChallan: true);
    final visibleElements = tpl.elements.where((e) => e.visible).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(
          settings.marginLeft,
          settings.marginTop,
          settings.marginRight,
          settings.marginBottom,
        ),
        build: (context) {
          final List<pw.Widget> widgets = [];
          int i = 0;

          while (i < visibleElements.length) {
            final el = visibleElements[i];

            // Company Header
            if (el.id == 'company-header') {
              final textColor = _parsePdfColor(el.color);
              final fontSize = el.fontSize > 0 ? el.fontSize : 16.0;
              final headerWidget = pw.Column(
                crossAxisAlignment: _parseCrossAlign(el.align),
                children: [
                  pw.Text(
                    settings.companyName.toUpperCase(),
                    textAlign: _parsePdfAlign(el.align),
                    style: pw.TextStyle(
                      font: el.bold ? fontBold : fontRegular,
                      fontSize: fontSize,
                      color: textColor,
                    ),
                  ),
                  if (settings.companyAddress.isNotEmpty)
                    pw.Text(
                      settings.companyAddress,
                      textAlign: _parsePdfAlign(el.align),
                      style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700),
                    ),
                  if (settings.companyMobile.isNotEmpty)
                    pw.Text(
                      'Mobile: ${settings.companyMobile}',
                      textAlign: _parsePdfAlign(el.align),
                      style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700),
                    ),
                ],
              );
              widgets.add(_wrapWithBoxOutline(headerWidget, el));
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            // Challan Title
            if (el.id == 'title') {
              final titleText = el.customText?.isNotEmpty == true ? el.customText! : settings.challanTitle;
              final textColor = _parsePdfColor(el.color);
              final fontSize = el.fontSize > 0 ? el.fontSize : 13.0;

              final titleWidget = pw.Container(
                alignment: _parseAlignment(el.align),
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: pw.Text(
                  titleText,
                  textAlign: _parsePdfAlign(el.align),
                  style: pw.TextStyle(
                    font: el.bold ? fontBold : fontRegular,
                    fontSize: fontSize,
                    color: textColor,
                    letterSpacing: 1,
                  ),
                ),
              );
              widgets.add(_wrapWithBoxOutline(titleWidget, el));
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            // Customer Info & Date Info
            if (el.id == 'customer-info' &&
                i + 1 < visibleElements.length &&
                visibleElements[i + 1].id == 'date-info') {
              final custEl = el;
              final dateEl = visibleElements[i + 1];
              widgets.add(
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(flex: 6, child: _buildChallanCustomerInfo(invoice, custEl, fontRegular, fontBold)),
                    pw.SizedBox(width: 14),
                    pw.Expanded(flex: 4, child: _buildChallanDateInfo(invoice, dateEl, fontRegular, fontBold)),
                  ],
                ),
              );
              widgets.add(pw.SizedBox(height: 10));
              i += 2;
              continue;
            }

            if (el.id == 'customer-info') {
              widgets.add(_buildChallanCustomerInfo(invoice, el, fontRegular, fontBold));
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            if (el.id == 'date-info') {
              widgets.add(_buildChallanDateInfo(invoice, el, fontRegular, fontBold));
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            // Challan Delivered Items Table (Qty only, no pricing)
            if (el.id == 'product-table') {
              widgets.add(_buildChallanProductTable(invoice, el, fontRegular, fontBold));
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            // Challan Notes
            if (el.id == 'notes') {
              widgets.add(_buildChallanNotes(invoice, el, fontRegular, fontBold));
              widgets.add(pw.SizedBox(height: 10));
              i++;
              continue;
            }

            // Signatures (Received by & Delivered by)
            if (el.id == 'prepared-by') {
              widgets.add(_buildChallanSignatures(invoice, el, fontRegular, fontBold));
              widgets.add(pw.SizedBox(height: 14));
              i++;
              continue;
            }

            // Footer
            if (el.id == 'footer') {
              widgets.add(_buildFooter(settings, el, fontRegular, fontBold, isChallan: true));
              widgets.add(pw.SizedBox(height: 8));
              i++;
              continue;
            }

            i++;
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  // Element Builders for Invoice
  pw.Widget _buildCustomerInfo(InvoiceModel invoice, PdfElementConfig cfg, pw.Font fontRegular, pw.Font fontBold) {
    final textColor = _parsePdfColor(cfg.color);
    final fontSize = cfg.fontSize > 0 ? cfg.fontSize : 10.0;
    return _wrapWithBoxOutline(
      pw.Column(
        crossAxisAlignment: _parseCrossAlign(cfg.align),
        children: [
          pw.Text(
            'CUSTOMER DETAILS:',
            style: pw.TextStyle(font: fontBold, fontSize: (fontSize * 0.85).clamp(7.0, 14.0), color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            invoice.customerName.isNotEmpty ? invoice.customerName : 'N/A',
            style: pw.TextStyle(font: cfg.bold ? fontBold : fontRegular, fontSize: fontSize, color: textColor),
          ),
          if (invoice.customerId.isNotEmpty)
            pw.Text('ID: ${invoice.customerId}', style: pw.TextStyle(font: fontRegular, fontSize: (fontSize * 0.85).clamp(7.0, 14.0))),
          if (invoice.address.isNotEmpty)
            pw.Text('Address: ${invoice.address}', style: pw.TextStyle(font: fontRegular, fontSize: (fontSize * 0.85).clamp(7.0, 14.0))),
          if (invoice.mobile.isNotEmpty)
            pw.Text('Phone: ${invoice.mobile}', style: pw.TextStyle(font: fontRegular, fontSize: (fontSize * 0.85).clamp(7.0, 14.0))),
          if (invoice.sideDelivery)
            pw.Container(
              margin: const pw.EdgeInsets.only(top: 2),
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: const pw.BoxDecoration(color: PdfColors.amber100),
              child: pw.Text('Side Delivery', style: pw.TextStyle(font: fontBold, fontSize: 8)),
            ),
        ],
      ),
      cfg,
    );
  }

  pw.Widget _buildDateInfo(InvoiceModel invoice, PdfElementConfig cfg, pw.Font fontRegular, pw.Font fontBold) {
    final textColor = _parsePdfColor(cfg.color);
    final fontSize = cfg.fontSize > 0 ? cfg.fontSize : 9.0;
    return _wrapWithBoxOutline(
      pw.Column(
        crossAxisAlignment: _parseCrossAlign(cfg.align),
        children: [
          pw.Row(
            mainAxisAlignment: cfg.align == 'right'
                ? pw.MainAxisAlignment.end
                : (cfg.align == 'center' ? pw.MainAxisAlignment.center : pw.MainAxisAlignment.start),
            children: [
              pw.Text('Invoice No: ', style: pw.TextStyle(font: fontBold, fontSize: fontSize + 1)),
              pw.Text(invoice.invoiceNo, style: pw.TextStyle(font: fontBold, fontSize: fontSize + 1, color: PdfColors.teal700)),
            ],
          ),
          pw.Text('Date: ${invoice.date}', style: pw.TextStyle(font: cfg.bold ? fontBold : fontRegular, fontSize: fontSize, color: textColor)),
          if (invoice.priceListName.isNotEmpty)
            pw.Text('Price List: ${invoice.priceListName}', style: pw.TextStyle(font: fontRegular, fontSize: fontSize, color: textColor)),
          if (invoice.createdBy.isNotEmpty)
            pw.Text('User: ${invoice.createdBy}', style: pw.TextStyle(font: fontRegular, fontSize: fontSize, color: textColor)),
        ],
      ),
      cfg,
    );
  }

  pw.Widget _buildProductTable(InvoiceModel invoice, PdfElementConfig cfg, pw.Font fontRegular, pw.Font fontBold) {
    final borderColor = _parsePdfColor(cfg.outlineColor, PdfColors.grey300);
    final borderWidth = cfg.outlineWidth > 0 ? cfg.outlineWidth : 0.5;
    final tableFontSize = cfg.fontSize > 0 ? cfg.fontSize : 8.0;

    final table = pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: borderWidth),
      columnWidths: const {
        0: pw.FixedColumnWidth(24), // SL
        1: pw.FlexColumnWidth(4), // Product
        2: pw.FixedColumnWidth(36), // Qty
        3: pw.FixedColumnWidth(46), // Unit Price
        4: pw.FixedColumnWidth(46), // Gross
        5: pw.FixedColumnWidth(34), // Disc%
        6: pw.FixedColumnWidth(46), // Net
        7: pw.FixedColumnWidth(46), // Delivery
        8: pw.FixedColumnWidth(54), // Total
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _tableHeaderCell('#', fontBold, fontSize: tableFontSize),
            _tableHeaderCell('Product / Description', fontBold, fontSize: tableFontSize, align: pw.TextAlign.left),
            _tableHeaderCell('Qty', fontBold, fontSize: tableFontSize),
            _tableHeaderCell('Rate', fontBold, fontSize: tableFontSize),
            _tableHeaderCell('Gross', fontBold, fontSize: tableFontSize),
            _tableHeaderCell('Disc%', fontBold, fontSize: tableFontSize),
            _tableHeaderCell('Net', fontBold, fontSize: tableFontSize),
            _tableHeaderCell('Deliv.', fontBold, fontSize: tableFontSize),
            _tableHeaderCell('Total', fontBold, fontSize: tableFontSize),
          ],
        ),
        // Rows
        ...invoice.items.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final item = entry.value;
          return pw.TableRow(
            children: [
              _tableCell('$idx', fontRegular, fontSize: tableFontSize),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.productName, style: pw.TextStyle(font: fontBold, fontSize: tableFontSize)),
                    if (item.description.isNotEmpty)
                      pw.Text(item.description, style: pw.TextStyle(font: fontRegular, fontSize: (tableFontSize - 1).clamp(6.0, 14.0), color: PdfColors.grey600)),
                  ],
                ),
              ),
              _tableCell(AppUtils.formatAmount(item.quantity, showDecimals: false), fontRegular, fontSize: tableFontSize),
              _tableCell(AppUtils.formatAmount(item.unitPrice), fontRegular, fontSize: tableFontSize),
              _tableCell(AppUtils.formatAmount(item.grossAmount), fontRegular, fontSize: tableFontSize),
              _tableCell(item.discountPercent > 0 ? '${item.discountPercent.toStringAsFixed(0)}%' : '-', fontRegular, fontSize: tableFontSize),
              _tableCell(AppUtils.formatAmount(item.netAmount), fontRegular, fontSize: tableFontSize),
              _tableCell(item.totalDeliveryCharge > 0 ? AppUtils.formatAmount(item.totalDeliveryCharge) : '-', fontRegular, fontSize: tableFontSize),
              _tableCell(AppUtils.formatAmount(item.total), fontBold, fontSize: tableFontSize),
            ],
          );
        }),
      ],
    );

    return _wrapWithBoxOutline(table, cfg);
  }

  pw.Widget _buildNotes(InvoiceModel invoice, PdfElementConfig cfg, pw.Font fontRegular, pw.Font fontBold) {
    if (invoice.notes.isEmpty) return pw.SizedBox.shrink();
    final headerText = cfg.customText?.isNotEmpty == true ? cfg.customText! : 'NOTES:';
    final textColor = _parsePdfColor(cfg.color);
    final fontSize = cfg.fontSize > 0 ? cfg.fontSize : 8.0;

    final notesWidget = pw.Column(
      crossAxisAlignment: _parseCrossAlign(cfg.align),
      children: [
        pw.Text(headerText, style: pw.TextStyle(font: fontBold, fontSize: fontSize, color: textColor)),
        pw.SizedBox(height: 2),
        pw.Text(invoice.notes, style: pw.TextStyle(font: cfg.bold ? fontBold : fontRegular, fontSize: fontSize, color: textColor)),
      ],
    );

    return _wrapWithBoxOutline(notesWidget, cfg);
  }

  pw.Widget _buildTotals(InvoiceModel invoice, PdfElementConfig cfg, pw.Font fontRegular, pw.Font fontBold) {
    final totalsWidget = pw.Column(
      children: [
        _summaryRow('Subtotal Gross:', AppUtils.formatAmount(invoice.subtotalGross), fontRegular),
        if (invoice.totalDiscount > 0)
          _summaryRow('Total Discount:', '- ${AppUtils.formatAmount(invoice.totalDiscount)}', fontRegular, color: PdfColors.red700),
        _summaryRow('Subtotal Net:', AppUtils.formatAmount(invoice.subtotalNet), fontRegular),
        if (invoice.totalDeliveryCharge > 0)
          _summaryRow('Delivery Charges:', AppUtils.formatAmount(invoice.totalDeliveryCharge), fontRegular),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
        _summaryRow('GRAND TOTAL:', AppUtils.formatAmount(invoice.totalAmount), fontBold, isTotal: true),
      ],
    );

    return _wrapWithBoxOutline(totalsWidget, cfg);
  }

  pw.Widget _buildPreparedBy(InvoiceModel invoice, SettingsModel settings, PdfElementConfig cfg, pw.Font fontRegular, pw.Font fontBold) {
    if (!settings.showPreparedBy) return pw.SizedBox.shrink();
    final textColor = _parsePdfColor(cfg.color);
    final fontSize = cfg.fontSize > 0 ? cfg.fontSize : 8.0;
    final customName = cfg.customText?.isNotEmpty == true
        ? cfg.customText!
        : (invoice.createdBy.isNotEmpty ? 'Prepared By: ${invoice.createdBy}' : 'Authorized Signature');

    final signWidget = pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Container(width: 120, height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Text('Customer Signature', style: pw.TextStyle(font: fontRegular, fontSize: fontSize, color: textColor)),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 120, height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Text(
              customName,
              style: pw.TextStyle(font: cfg.bold ? fontBold : fontRegular, fontSize: fontSize, color: textColor),
            ),
          ],
        ),
      ],
    );

    return _wrapWithBoxOutline(signWidget, cfg);
  }

  pw.Widget _buildFooter(SettingsModel settings, PdfElementConfig cfg, pw.Font fontRegular, pw.Font fontBold, {required bool isChallan}) {
    final fallback = isChallan ? settings.challanFooterText : settings.invoiceFooterText;
    final footerText = cfg.customText?.isNotEmpty == true ? cfg.customText! : fallback;
    if (footerText.isEmpty) return pw.SizedBox.shrink();

    final textColor = _parsePdfColor(cfg.color, PdfColors.grey500);
    final fontSize = cfg.fontSize > 0 ? cfg.fontSize : 7.0;

    final footerWidget = pw.Container(
      alignment: _parseAlignment(cfg.align),
      child: pw.Text(
        footerText,
        textAlign: _parsePdfAlign(cfg.align),
        style: pw.TextStyle(font: cfg.bold ? fontBold : fontRegular, fontSize: fontSize, color: textColor),
      ),
    );

    return _wrapWithBoxOutline(footerWidget, cfg);
  }

  // Element Builders for Delivery Challan
  pw.Widget _buildChallanCustomerInfo(InvoiceModel invoice, PdfElementConfig cfg, pw.Font fontRegular, pw.Font fontBold) {
    final textColor = _parsePdfColor(cfg.color);
    final fontSize = cfg.fontSize > 0 ? cfg.fontSize : 10.0;
    return _wrapWithBoxOutline(
      pw.Column(
        crossAxisAlignment: _parseCrossAlign(cfg.align),
        children: [
          pw.Text('DELIVERY TO:', style: pw.TextStyle(font: fontBold, fontSize: (fontSize * 0.85).clamp(7.0, 14.0), color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(invoice.customerName.isNotEmpty ? invoice.customerName : 'N/A', style: pw.TextStyle(font: cfg.bold ? fontBold : fontRegular, fontSize: fontSize, color: textColor)),
          if (invoice.address.isNotEmpty)
            pw.Text('Delivery Address: ${invoice.address}', style: pw.TextStyle(font: fontRegular, fontSize: (fontSize * 0.85).clamp(7.0, 14.0))),
          if (invoice.mobile.isNotEmpty)
            pw.Text('Phone: ${invoice.mobile}', style: pw.TextStyle(font: fontRegular, fontSize: (fontSize * 0.85).clamp(7.0, 14.0))),
        ],
      ),
      cfg,
    );
  }

  pw.Widget _buildChallanDateInfo(InvoiceModel invoice, PdfElementConfig cfg, pw.Font fontRegular, pw.Font fontBold) {
    final textColor = _parsePdfColor(cfg.color);
    final fontSize = cfg.fontSize > 0 ? cfg.fontSize : 9.0;
    return _wrapWithBoxOutline(
      pw.Column(
        crossAxisAlignment: _parseCrossAlign(cfg.align),
        children: [
          pw.Row(
            mainAxisAlignment: cfg.align == 'right'
                ? pw.MainAxisAlignment.end
                : (cfg.align == 'center' ? pw.MainAxisAlignment.center : pw.MainAxisAlignment.start),
            children: [
              pw.Text('Challan / Inv No: ', style: pw.TextStyle(font: fontBold, fontSize: fontSize + 1)),
              pw.Text(invoice.invoiceNo, style: pw.TextStyle(font: fontBold, fontSize: fontSize + 1, color: PdfColors.teal700)),
            ],
          ),
          pw.Text('Date: ${invoice.date}', style: pw.TextStyle(font: cfg.bold ? fontBold : fontRegular, fontSize: fontSize, color: textColor)),
          if (invoice.createdBy.isNotEmpty)
            pw.Text('Prepared By: ${invoice.createdBy}', style: pw.TextStyle(font: fontRegular, fontSize: fontSize, color: textColor)),
        ],
      ),
      cfg,
    );
  }

  pw.Widget _buildChallanProductTable(InvoiceModel invoice, PdfElementConfig cfg, pw.Font fontRegular, pw.Font fontBold) {
    final borderColor = _parsePdfColor(cfg.outlineColor, PdfColors.grey300);
    final borderWidth = cfg.outlineWidth > 0 ? cfg.outlineWidth : 0.5;
    final tableFontSize = cfg.fontSize > 0 ? cfg.fontSize : 8.0;

    final table = pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: borderWidth),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(6),
        2: pw.FixedColumnWidth(60),
        3: pw.FixedColumnWidth(100),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _tableHeaderCell('#', fontBold, fontSize: tableFontSize),
            _tableHeaderCell('Product Name / Description', fontBold, fontSize: tableFontSize, align: pw.TextAlign.left),
            _tableHeaderCell('Quantity', fontBold, fontSize: tableFontSize),
            _tableHeaderCell('Remarks', fontBold, fontSize: tableFontSize, align: pw.TextAlign.left),
          ],
        ),
        ...invoice.items.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final item = entry.value;
          return pw.TableRow(
            children: [
              _tableCell('$idx', fontRegular, fontSize: tableFontSize),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item.productName, style: pw.TextStyle(font: fontBold, fontSize: tableFontSize + 1)),
                    if (item.description.isNotEmpty)
                      pw.Text(item.description, style: pw.TextStyle(font: fontRegular, fontSize: tableFontSize, color: PdfColors.grey600)),
                  ],
                ),
              ),
              _tableCell(AppUtils.formatAmount(item.quantity, showDecimals: false), fontBold, fontSize: tableFontSize),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  item.deliveryChargePerUnit > 0 ? 'Deliv. Charge applies' : '',
                  style: pw.TextStyle(font: fontRegular, fontSize: tableFontSize),
                ),
              ),
            ],
          );
        }),
      ],
    );

    return _wrapWithBoxOutline(table, cfg);
  }

  pw.Widget _buildChallanNotes(InvoiceModel invoice, PdfElementConfig cfg, pw.Font fontRegular, pw.Font fontBold) {
    if (invoice.notes.isEmpty) return pw.SizedBox.shrink();
    final headerText = cfg.customText?.isNotEmpty == true ? cfg.customText! : 'DELIVERY INSTRUCTIONS:';
    final textColor = _parsePdfColor(cfg.color);
    final fontSize = cfg.fontSize > 0 ? cfg.fontSize : 9.0;

    final notesWidget = pw.Column(
      crossAxisAlignment: _parseCrossAlign(cfg.align),
      children: [
        pw.Text(headerText, style: pw.TextStyle(font: fontBold, fontSize: fontSize, color: textColor)),
        pw.SizedBox(height: 2),
        pw.Text(invoice.notes, style: pw.TextStyle(font: cfg.bold ? fontBold : fontRegular, fontSize: fontSize - 1, color: textColor)),
      ],
    );

    return _wrapWithBoxOutline(notesWidget, cfg);
  }

  pw.Widget _buildChallanSignatures(InvoiceModel invoice, PdfElementConfig cfg, pw.Font fontRegular, pw.Font fontBold) {
    final textColor = _parsePdfColor(cfg.color);
    final fontSize = cfg.fontSize > 0 ? cfg.fontSize : 8.0;

    final signWidget = pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          children: [
            pw.Container(width: 140, height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Text('Received by (Customer Signature)', style: pw.TextStyle(font: fontRegular, fontSize: fontSize, color: textColor)),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 140, height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 4),
            pw.Text('Delivered by (Carrier Signature)', style: pw.TextStyle(font: fontRegular, fontSize: fontSize, color: textColor)),
          ],
        ),
      ],
    );

    return _wrapWithBoxOutline(signWidget, cfg);
  }

  // Styling & Outline Helpers
  pw.Widget _wrapWithBoxOutline(pw.Widget child, PdfElementConfig config) {
    final borderColor = _parsePdfColor(config.outlineColor, PdfColors.grey400);
    final borderWidth = config.outlineWidth > 0 ? config.outlineWidth : 1.0;

    PdfColor? bgColor;
    if (config.bgTint == 'subtle_gray') {
      bgColor = PdfColors.grey100;
    } else if (config.bgTint == 'subtle_teal') {
      bgColor = const PdfColor(0.88, 0.95, 0.95);
    } else if (config.bgTint == 'subtle_amber') {
      bgColor = const PdfColor(1.0, 0.98, 0.92);
    }

    pw.BoxDecoration? decoration;
    pw.EdgeInsets padding = const pw.EdgeInsets.all(0);

    if (config.outlineStyle == 'box') {
      decoration = pw.BoxDecoration(
        color: bgColor,
        border: pw.Border.all(color: borderColor, width: borderWidth),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      );
      padding = const pw.EdgeInsets.all(6);
    } else if (config.outlineStyle == 'top_bottom') {
      decoration = pw.BoxDecoration(
        color: bgColor,
        border: pw.Border(
          top: pw.BorderSide(color: borderColor, width: borderWidth),
          bottom: pw.BorderSide(color: borderColor, width: borderWidth),
        ),
      );
      padding = const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4);
    } else if (config.outlineStyle == 'left_bar') {
      decoration = pw.BoxDecoration(
        color: bgColor,
        border: pw.Border(
          left: pw.BorderSide(color: borderColor, width: borderWidth * 3),
        ),
      );
      padding = const pw.EdgeInsets.only(left: 8, top: 4, bottom: 4, right: 4);
    } else if (bgColor != null) {
      decoration = pw.BoxDecoration(
        color: bgColor,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      );
      padding = const pw.EdgeInsets.all(6);
    }

    if (decoration != null) {
      return pw.Container(
        width: double.infinity,
        decoration: decoration,
        padding: padding,
        child: child,
      );
    }
    return child;
  }

  PdfColor _parsePdfColor(String hex, [PdfColor fallback = PdfColors.black]) {
    try {
      var c = hex.replaceAll('#', '').trim();
      if (c.length == 6) {
        c = 'FF$c';
      }
      final val = int.parse(c, radix: 16);
      return PdfColor.fromInt(val);
    } catch (_) {
      return fallback;
    }
  }

  pw.TextAlign _parsePdfAlign(String align) {
    switch (align) {
      case 'center':
        return pw.TextAlign.center;
      case 'right':
        return pw.TextAlign.right;
      default:
        return pw.TextAlign.left;
    }
  }

  pw.CrossAxisAlignment _parseCrossAlign(String align) {
    switch (align) {
      case 'center':
        return pw.CrossAxisAlignment.center;
      case 'right':
        return pw.CrossAxisAlignment.end;
      default:
        return pw.CrossAxisAlignment.start;
    }
  }

  pw.Alignment _parseAlignment(String align) {
    switch (align) {
      case 'center':
        return pw.Alignment.center;
      case 'right':
        return pw.Alignment.centerRight;
      default:
        return pw.Alignment.centerLeft;
    }
  }

  // Common Table Helpers
  pw.Widget _tableHeaderCell(String text, pw.Font font, {double fontSize = 8.0, pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: fontSize, color: PdfColors.grey800),
      ),
    );
  }

  pw.Widget _tableCell(String text, pw.Font font, {double fontSize = 8.0}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: fontSize),
      ),
    );
  }

  pw.Widget _summaryRow(String label, String value, pw.Font font, {bool isTotal = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: isTotal ? 10 : 8,
              color: isTotal ? PdfColors.black : PdfColors.grey700,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: isTotal ? 11 : 8,
              color: color ?? (isTotal ? PdfColors.teal800 : PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  /// Direct printing action with dynamic template support
  Future<void> printInvoice(InvoiceModel invoice, SettingsModel settings, {PdfTemplateConfig? template}) async {
    final bytes = await generateInvoicePdf(invoice, settings, template: template);
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: '${invoice.invoiceNo}.pdf',
    );
  }

  /// Direct sharing action with dynamic template support
  Future<void> shareInvoice(InvoiceModel invoice, SettingsModel settings, {PdfTemplateConfig? template}) async {
    final bytes = await generateInvoicePdf(invoice, settings, template: template);
    await Printing.sharePdf(bytes: bytes, filename: '${invoice.invoiceNo}.pdf');
  }

  /// Direct printing for delivery order challan with dynamic template support
  Future<void> printChallan(InvoiceModel invoice, SettingsModel settings, {PdfTemplateConfig? template}) async {
    final bytes = await generateChallanPdf(invoice, settings, template: template);
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Challan_${invoice.invoiceNo}.pdf',
    );
  }

  /// Direct sharing for delivery order challan with dynamic template support
  Future<void> shareChallan(InvoiceModel invoice, SettingsModel settings, {PdfTemplateConfig? template}) async {
    final bytes = await generateChallanPdf(invoice, settings, template: template);
    await Printing.sharePdf(bytes: bytes, filename: 'Challan_${invoice.invoiceNo}.pdf');
  }
}
