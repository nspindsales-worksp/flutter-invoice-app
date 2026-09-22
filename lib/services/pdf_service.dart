import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/utils.dart';
import '../models/invoice_model.dart';
import '../models/settings_model.dart';

class PdfService {
  static final PdfService instance = PdfService._internal();
  PdfService._internal();

  /// Generates the complete professional Invoice PDF
  Future<Uint8List> generateInvoicePdf(InvoiceModel invoice, SettingsModel settings) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

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
          return [
            // 1. Company Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    settings.companyName.toUpperCase(),
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 16,
                      color: PdfColors.black,
                    ),
                  ),
                  if (settings.companyAddress.isNotEmpty)
                    pw.Text(
                      settings.companyAddress,
                      style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700),
                    ),
                  if (settings.companyMobile.isNotEmpty)
                    pw.Text(
                      'Mobile: ${settings.companyMobile}',
                      style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700),
                    ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      settings.invoiceTitle,
                      style: pw.TextStyle(font: fontBold, fontSize: 13, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 2. Metadata: Customer Info & Invoice Meta
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Customer details
                pw.Expanded(
                  flex: 6,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CUSTOMER DETAILS:',
                        style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey600),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        invoice.customerName.isNotEmpty ? invoice.customerName : 'N/A',
                        style: pw.TextStyle(font: fontBold, fontSize: 11),
                      ),
                      if (invoice.customerId.isNotEmpty)
                        pw.Text('ID: ${invoice.customerId}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                      if (invoice.address.isNotEmpty)
                        pw.Text('Address: ${invoice.address}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                      if (invoice.mobile.isNotEmpty)
                        pw.Text('Phone: ${invoice.mobile}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                      if (invoice.sideDelivery)
                        pw.Container(
                          margin: const pw.EdgeInsets.only(top: 2),
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: const pw.BoxDecoration(color: PdfColors.amber100),
                          child: pw.Text('Side Delivery', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                        ),
                    ],
                  ),
                ),
                // Invoice details
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text('Invoice No: ', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                          pw.Text(invoice.invoiceNo, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.teal700)),
                        ],
                      ),
                      pw.Text('Date: ${invoice.date}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                      if (invoice.priceListName.isNotEmpty)
                        pw.Text('Price List: ${invoice.priceListName}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                      if (invoice.createdBy.isNotEmpty)
                        pw.Text('User: ${invoice.createdBy}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // 3. Line Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
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
                    _tableHeaderCell('#', fontBold),
                    _tableHeaderCell('Product / Description', fontBold, align: pw.TextAlign.left),
                    _tableHeaderCell('Qty', fontBold),
                    _tableHeaderCell('Rate', fontBold),
                    _tableHeaderCell('Gross', fontBold),
                    _tableHeaderCell('Disc%', fontBold),
                    _tableHeaderCell('Net', fontBold),
                    _tableHeaderCell('Deliv.', fontBold),
                    _tableHeaderCell('Total', fontBold),
                  ],
                ),
                // Rows
                ...invoice.items.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  return pw.TableRow(
                    children: [
                      _tableCell('$idx', fontRegular),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.productName, style: pw.TextStyle(font: fontBold, fontSize: 8)),
                            if (item.description.isNotEmpty)
                              pw.Text(item.description, style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                      _tableCell(AppUtils.formatAmount(item.quantity, showDecimals: false), fontRegular),
                      _tableCell(AppUtils.formatAmount(item.unitPrice), fontRegular),
                      _tableCell(AppUtils.formatAmount(item.grossAmount), fontRegular),
                      _tableCell(item.discountPercent > 0 ? '${item.discountPercent.toStringAsFixed(0)}%' : '-', fontRegular),
                      _tableCell(AppUtils.formatAmount(item.netAmount), fontRegular),
                      _tableCell(item.totalDeliveryCharge > 0 ? AppUtils.formatAmount(item.totalDeliveryCharge) : '-', fontRegular),
                      _tableCell(AppUtils.formatAmount(item.total), fontBold),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 10),

            // 4. Summary & Notes
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Left: Notes
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (invoice.notes.isNotEmpty) ...[
                        pw.Text('NOTES:', style: pw.TextStyle(font: fontBold, fontSize: 8)),
                        pw.SizedBox(height: 2),
                        pw.Text(invoice.notes, style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                      ],
                    ],
                  ),
                ),
                // Right: Financial Totals
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
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
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // 5. Signatures & Prepared By
            if (settings.showPreparedBy)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      pw.Text('Customer Signature', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: PdfColors.grey400),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        invoice.createdBy.isNotEmpty ? 'Prepared By: ${invoice.createdBy}' : 'Authorized Signature',
                        style: pw.TextStyle(font: fontRegular, fontSize: 8),
                      ),
                    ],
                  ),
                ],
              ),
            pw.SizedBox(height: 16),

            // 6. Footer Note
            if (settings.invoiceFooterText.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  settings.invoiceFooterText,
                  style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey500),
                ),
              ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Generates the Delivery Order Challan PDF (without pricing)
  Future<Uint8List> generateChallanPdf(InvoiceModel invoice, SettingsModel settings) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

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
          return [
            // Company Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    settings.companyName.toUpperCase(),
                    style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.black),
                  ),
                  if (settings.companyAddress.isNotEmpty)
                    pw.Text(settings.companyAddress, style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700)),
                  if (settings.companyMobile.isNotEmpty)
                    pw.Text('Mobile: ${settings.companyMobile}', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text(
                      settings.challanTitle,
                      style: pw.TextStyle(font: fontBold, fontSize: 13, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Customer & Delivery Info
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  flex: 6,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DELIVERY TO:', style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey600)),
                      pw.SizedBox(height: 2),
                      pw.Text(invoice.customerName.isNotEmpty ? invoice.customerName : 'N/A', style: pw.TextStyle(font: fontBold, fontSize: 11)),
                      if (invoice.address.isNotEmpty)
                        pw.Text('Delivery Address: ${invoice.address}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                      if (invoice.mobile.isNotEmpty)
                        pw.Text('Phone: ${invoice.mobile}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                    ],
                  ),
                ),
                pw.Expanded(
                  flex: 4,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Text('Challan / Inv No: ', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                          pw.Text(invoice.invoiceNo, style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.teal700)),
                        ],
                      ),
                      pw.Text('Date: ${invoice.date}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                      if (invoice.createdBy.isNotEmpty)
                        pw.Text('Prepared By: ${invoice.createdBy}', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Delivery Items Table (NO financial prices)
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
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
                    _tableHeaderCell('#', fontBold),
                    _tableHeaderCell('Product Name / Description', fontBold, align: pw.TextAlign.left),
                    _tableHeaderCell('Quantity', fontBold),
                    _tableHeaderCell('Remarks', fontBold, align: pw.TextAlign.left),
                  ],
                ),
                ...invoice.items.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  return pw.TableRow(
                    children: [
                      _tableCell('$idx', fontRegular),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.productName, style: pw.TextStyle(font: fontBold, fontSize: 9)),
                            if (item.description.isNotEmpty)
                              pw.Text(item.description, style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600)),
                          ],
                        ),
                      ),
                      _tableCell(AppUtils.formatAmount(item.quantity, showDecimals: false), fontBold),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          item.deliveryChargePerUnit > 0 ? 'Deliv. Charge applies' : '',
                          style: pw.TextStyle(font: fontRegular, fontSize: 8),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),

            if (invoice.notes.isNotEmpty) ...[
              pw.Text('DELIVERY INSTRUCTIONS:', style: pw.TextStyle(font: fontBold, fontSize: 9)),
              pw.SizedBox(height: 2),
              pw.Text(invoice.notes, style: pw.TextStyle(font: fontRegular, fontSize: 8)),
              pw.SizedBox(height: 16),
            ],

            // Signatures
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    pw.Text('Received by (Customer Signature)', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(width: 140, height: 1, color: PdfColors.grey400),
                    pw.SizedBox(height: 4),
                    pw.Text('Delivered by (Carrier Signature)', style: pw.TextStyle(font: fontRegular, fontSize: 8)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            pw.Center(
              child: pw.Text(
                settings.challanFooterText,
                style: pw.TextStyle(font: fontRegular, fontSize: 7, color: PdfColors.grey500),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Helpers
  pw.Widget _tableHeaderCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey800),
      ),
    );
  }

  pw.Widget _tableCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 8),
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

  /// Direct printing action
  Future<void> printInvoice(InvoiceModel invoice, SettingsModel settings) async {
    final bytes = await generateInvoicePdf(invoice, settings);
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: '${invoice.invoiceNo}.pdf',
    );
  }

  /// Direct sharing action
  Future<void> shareInvoice(InvoiceModel invoice, SettingsModel settings) async {
    final bytes = await generateInvoicePdf(invoice, settings);
    await Printing.sharePdf(bytes: bytes, filename: '${invoice.invoiceNo}.pdf');
  }

  /// Direct printing for delivery order challan
  Future<void> printChallan(InvoiceModel invoice, SettingsModel settings) async {
    final bytes = await generateChallanPdf(invoice, settings);
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Challan_${invoice.invoiceNo}.pdf',
    );
  }

  /// Direct sharing for delivery order challan
  Future<void> shareChallan(InvoiceModel invoice, SettingsModel settings) async {
    final bytes = await generateChallanPdf(invoice, settings);
    await Printing.sharePdf(bytes: bytes, filename: 'Challan_${invoice.invoiceNo}.pdf');
  }
}
