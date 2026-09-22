import 'dart:convert';

class PdfElementConfig {
  final String id;
  final String label;
  final bool visible;
  final String color;
  final double fontSize;
  final bool bold;
  final String align; // 'left' | 'center' | 'right'
  final String? customText;
  final String outlineStyle; // 'none' | 'box' | 'top_bottom' | 'left_bar'
  final String outlineColor;
  final double outlineWidth;
  final String bgTint; // 'none' | 'subtle_gray' | 'subtle_teal' | 'subtle_amber'

  PdfElementConfig({
    required this.id,
    required this.label,
    this.visible = true,
    this.color = '#000000',
    this.fontSize = 10,
    this.bold = false,
    this.align = 'left',
    this.customText,
    this.outlineStyle = 'none',
    this.outlineColor = '#CCCCCC',
    this.outlineWidth = 1.0,
    this.bgTint = 'none',
  });

  factory PdfElementConfig.fromMap(Map<String, dynamic> map) {
    return PdfElementConfig(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      visible: map['visible'] != false,
      color: map['color']?.toString() ?? '#000000',
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 10.0,
      bold: map['bold'] == true,
      align: map['align']?.toString() ?? 'left',
      customText: map['customText']?.toString(),
      outlineStyle: map['outlineStyle']?.toString() ?? 'none',
      outlineColor: map['outlineColor']?.toString() ?? '#CCCCCC',
      outlineWidth: (map['outlineWidth'] as num?)?.toDouble() ?? 1.0,
      bgTint: map['bgTint']?.toString() ?? 'none',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'visible': visible,
      'color': color,
      'fontSize': fontSize,
      'bold': bold,
      'align': align,
      if (customText != null) 'customText': customText,
      'outlineStyle': outlineStyle,
      'outlineColor': outlineColor,
      'outlineWidth': outlineWidth,
      'bgTint': bgTint,
    };
  }

  PdfElementConfig copyWith({
    String? id,
    String? label,
    bool? visible,
    String? color,
    double? fontSize,
    bool? bold,
    String? align,
    String? customText,
    String? outlineStyle,
    String? outlineColor,
    double? outlineWidth,
    String? bgTint,
  }) {
    return PdfElementConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      visible: visible ?? this.visible,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      bold: bold ?? this.bold,
      align: align ?? this.align,
      customText: customText ?? this.customText,
      outlineStyle: outlineStyle ?? this.outlineStyle,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      bgTint: bgTint ?? this.bgTint,
    );
  }
}

class PdfTemplateConfig {
  final List<PdfElementConfig> elements;
  final String notesPosition; // 'left' | 'right' | 'bottom'

  PdfTemplateConfig({
    required this.elements,
    this.notesPosition = 'left',
  });

  factory PdfTemplateConfig.fromMap(Map<String, dynamic> map) {
    final rawElements = map['elements'];
    final List<PdfElementConfig> list = [];
    if (rawElements is List) {
      for (var e in rawElements) {
        if (e is Map<String, dynamic>) {
          list.add(PdfElementConfig.fromMap(e));
        } else if (e is Map) {
          list.add(PdfElementConfig.fromMap(Map<String, dynamic>.from(e)));
        }
      }
    }

    return PdfTemplateConfig(
      elements: list.isNotEmpty ? list : defaultInvoiceTemplate().elements,
      notesPosition: map['notesPosition']?.toString() ?? 'left',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'elements': elements.map((e) => e.toMap()).toList(),
      'notesPosition': notesPosition,
    };
  }

  String toJson() => jsonEncode(toMap());

  factory PdfTemplateConfig.fromJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return PdfTemplateConfig.fromMap(decoded);
      } else if (decoded is Map) {
        return PdfTemplateConfig.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return defaultInvoiceTemplate();
  }

  static PdfTemplateConfig defaultInvoiceTemplate() {
    return PdfTemplateConfig(
      notesPosition: 'left',
      elements: [
        PdfElementConfig(id: 'company-header', label: 'Company Header', visible: true, color: '#000000', fontSize: 16, bold: true, align: 'center'),
        PdfElementConfig(id: 'title', label: 'Invoice Title', visible: true, color: '#000000', fontSize: 13, bold: true, align: 'center', customText: 'INVOICE', outlineStyle: 'box', outlineColor: '#9E9E9E'),
        PdfElementConfig(id: 'customer-info', label: 'Customer Details', visible: true, color: '#000000', fontSize: 10, bold: false, align: 'left'),
        PdfElementConfig(id: 'date-info', label: 'Invoice No & Date', visible: true, color: '#000000', fontSize: 9, bold: false, align: 'right'),
        PdfElementConfig(id: 'product-table', label: 'Product Table & Outlines', visible: true, color: '#000000', fontSize: 8, bold: false, align: 'left', outlineStyle: 'box', outlineColor: '#757575'),
        PdfElementConfig(id: 'notes', label: 'Notes Section', visible: true, color: '#000000', fontSize: 9, bold: false, align: 'left'),
        PdfElementConfig(id: 'totals', label: 'Totals Summary', visible: true, color: '#000000', fontSize: 9, bold: false, align: 'right'),
        PdfElementConfig(id: 'grand-total', label: 'Grand Total Highlight', visible: true, color: '#000000', fontSize: 12, bold: true, align: 'right', outlineStyle: 'box', outlineColor: '#059669', bgTint: 'subtle_teal'),
        PdfElementConfig(id: 'prepared-by', label: 'Prepared By Block', visible: true, color: '#000000', fontSize: 9, bold: true, align: 'left'),
        PdfElementConfig(id: 'footer', label: 'Footer Notice', visible: true, color: '#757575', fontSize: 8, bold: false, align: 'center', customText: 'Developed By Invoice Management System'),
      ],
    );
  }

  static PdfTemplateConfig defaultChallanTemplate() {
    return PdfTemplateConfig(
      notesPosition: 'left',
      elements: [
        PdfElementConfig(id: 'company-header', label: 'Company Header', visible: true, color: '#000000', fontSize: 16, bold: true, align: 'center'),
        PdfElementConfig(id: 'title', label: 'Challan Title', visible: true, color: '#000000', fontSize: 13, bold: true, align: 'center', customText: 'DELIVERY ORDER', outlineStyle: 'box', outlineColor: '#0284C7'),
        PdfElementConfig(id: 'customer-info', label: 'Delivery Contact Information', visible: true, color: '#000000', fontSize: 10, bold: false, align: 'left'),
        PdfElementConfig(id: 'date-info', label: 'Challan Date & No', visible: true, color: '#000000', fontSize: 9, bold: false, align: 'right'),
        PdfElementConfig(id: 'product-table', label: 'Delivered Items Table (Qty)', visible: true, color: '#000000', fontSize: 8, bold: false, align: 'left', outlineStyle: 'box', outlineColor: '#0284C7'),
        PdfElementConfig(id: 'notes', label: 'Delivery Notes', visible: true, color: '#000000', fontSize: 9, bold: false, align: 'left'),
        PdfElementConfig(id: 'prepared-by', label: 'Receiver & Signature Lines', visible: true, color: '#000000', fontSize: 9, bold: true, align: 'left'),
        PdfElementConfig(id: 'footer', label: 'Challan Disclaimer', visible: true, color: '#757575', fontSize: 7, bold: false, align: 'center', customText: 'This is a computer-generated Delivery Order. No signature is required.'),
      ],
    );
  }
}
