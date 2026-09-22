import '../core/constants.dart';
import '../core/utils.dart';

class SettingsModel {
  final String companyName;
  final String companyAddress;
  final String companyMobile;
  final String invoiceTitle;
  final String challanTitle;
  final String invoiceFooterText;
  final String challanFooterText;
  final bool showPreparedBy;
  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;
  final String companyLogo; // Base64 or URL
  final String sheetUrlAuth;
  final String sheetUrlCustomer;
  final String sheetUrlProduct;

  SettingsModel({
    this.companyName = 'INVOICE MANAGER',
    this.companyAddress = 'Dhaka, Bangladesh',
    this.companyMobile = '01913-539860',
    this.invoiceTitle = 'INVOICE',
    this.challanTitle = 'DELIVERY ORDER',
    this.invoiceFooterText = 'Developed By Invoice Management System',
    this.challanFooterText = 'This is a computer-generated Delivery Order. No signature is required.',
    this.showPreparedBy = true,
    this.marginTop = 40.0,
    this.marginBottom = 40.0,
    this.marginLeft = 40.0,
    this.marginRight = 40.0,
    this.companyLogo = '',
    this.sheetUrlAuth = AppConstants.defaultAuthSheet,
    this.sheetUrlCustomer = AppConstants.defaultCustomerSheet,
    this.sheetUrlProduct = AppConstants.defaultProductSheetOld,
  });

  factory SettingsModel.fromMap(Map<String, String> map) {
    return SettingsModel(
      companyName: map['pdf_company_name'] ?? 'INVOICE MANAGER',
      companyAddress: map['pdf_company_address'] ?? 'Dhaka, Bangladesh',
      companyMobile: map['pdf_company_mobile'] ?? '01913-539860',
      invoiceTitle: map['pdf_invoice_title'] ?? 'INVOICE',
      challanTitle: map['pdf_challan_title'] ?? 'DELIVERY ORDER',
      invoiceFooterText: map['pdf_footer_text'] ?? 'Developed By Invoice Management System',
      challanFooterText: map['pdf_challan_footer_text'] ?? 'This is a computer-generated Delivery Order. No signature is required.',
      showPreparedBy: map['pdf_show_prepared_by'] != 'false',
      marginTop: AppUtils.parseDouble(map['pdf_margin_top'], 40.0),
      marginBottom: AppUtils.parseDouble(map['pdf_margin_bottom'], 40.0),
      marginLeft: AppUtils.parseDouble(map['pdf_margin_left'], 40.0),
      marginRight: AppUtils.parseDouble(map['pdf_margin_right'], 40.0),
      companyLogo: map['pdf_company_logo'] ?? '',
      sheetUrlAuth: map['sheet_url_auth'] ?? AppConstants.defaultAuthSheet,
      sheetUrlCustomer: map['sheet_url_customer'] ?? AppConstants.defaultCustomerSheet,
      sheetUrlProduct: map['sheet_url_product'] ?? AppConstants.defaultProductSheetOld,
    );
  }

  Map<String, String> toMap() {
    return {
      'pdf_company_name': companyName,
      'pdf_company_address': companyAddress,
      'pdf_company_mobile': companyMobile,
      'pdf_invoice_title': invoiceTitle,
      'pdf_challan_title': challanTitle,
      'pdf_footer_text': invoiceFooterText,
      'pdf_challan_footer_text': challanFooterText,
      'pdf_show_prepared_by': showPreparedBy.toString(),
      'pdf_margin_top': marginTop.toString(),
      'pdf_margin_bottom': marginBottom.toString(),
      'pdf_margin_left': marginLeft.toString(),
      'pdf_margin_right': marginRight.toString(),
      'pdf_company_logo': companyLogo,
      'sheet_url_auth': sheetUrlAuth,
      'sheet_url_customer': sheetUrlCustomer,
      'sheet_url_product': sheetUrlProduct,
    };
  }

  SettingsModel copyWith({
    String? companyName,
    String? companyAddress,
    String? companyMobile,
    String? invoiceTitle,
    String? challanTitle,
    String? invoiceFooterText,
    String? challanFooterText,
    bool? showPreparedBy,
    double? marginTop,
    double? marginBottom,
    double? marginLeft,
    double? marginRight,
    String? companyLogo,
    String? sheetUrlAuth,
    String? sheetUrlCustomer,
    String? sheetUrlProduct,
  }) {
    return SettingsModel(
      companyName: companyName ?? this.companyName,
      companyAddress: companyAddress ?? this.companyAddress,
      companyMobile: companyMobile ?? this.companyMobile,
      invoiceTitle: invoiceTitle ?? this.invoiceTitle,
      challanTitle: challanTitle ?? this.challanTitle,
      invoiceFooterText: invoiceFooterText ?? this.invoiceFooterText,
      challanFooterText: challanFooterText ?? this.challanFooterText,
      showPreparedBy: showPreparedBy ?? this.showPreparedBy,
      marginTop: marginTop ?? this.marginTop,
      marginBottom: marginBottom ?? this.marginBottom,
      marginLeft: marginLeft ?? this.marginLeft,
      marginRight: marginRight ?? this.marginRight,
      companyLogo: companyLogo ?? this.companyLogo,
      sheetUrlAuth: sheetUrlAuth ?? this.sheetUrlAuth,
      sheetUrlCustomer: sheetUrlCustomer ?? this.sheetUrlCustomer,
      sheetUrlProduct: sheetUrlProduct ?? this.sheetUrlProduct,
    );
  }
}
