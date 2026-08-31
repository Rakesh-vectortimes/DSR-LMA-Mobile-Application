import '../../../../core/network/list_response.dart';

class OrgCompany {
  const OrgCompany({
    required this.id,
    required this.companyName,
    this.address = '',
    this.currency,
    this.status = 'active',
    this.companyType,
    this.parentCompanyId,
  });

  final String id;
  final String companyName;
  final String address;
  final String? currency;
  final String status;
  final String? companyType;
  final String? parentCompanyId;

  factory OrgCompany.fromJson(
    Map<String, dynamic> json, {
    String companyType = 'child',
  }) {
    return OrgCompany(
      id: ListResponse.extractId(
        json,
        preferredKeys: const ['company_id', 'org_company_id'],
      ),
      companyName: (json['company_name'] as String?)?.trim() ?? '',
      address: (json['address'] as String?)?.trim() ?? '',
      currency: json['currency'] as String?,
      status: (json['status'] as String?)?.trim() ?? 'active',
      companyType: (json['company_type'] as String?) ?? companyType,
      parentCompanyId: normalizeEntityId(json['parent_company_id']),
    );
  }
}

class OrganizationCreator {
  const OrganizationCreator({
    required this.employeeId,
    required this.name,
    this.userId,
    this.role,
    this.orgCompanyId,
  });

  final String employeeId;
  final String name;
  final String? userId;
  final String? role;
  final String? orgCompanyId;

  factory OrganizationCreator.fromJson(Map<String, dynamic> json) {
    return OrganizationCreator(
      employeeId: normalizeEntityId(
            json['employee_id'] ?? json['user_id'] ?? json['id'],
          ) ??
          '',
      name: (json['name'] as String?)?.trim() ?? '',
      userId: normalizeEntityId(json['user_id']),
      role: json['role'] as String?,
      orgCompanyId: normalizeEntityId(json['org_company_id']),
    );
  }
}

class OrganizationCreatorsPage {
  const OrganizationCreatorsPage({
    required this.items,
    required this.total,
  });

  final List<OrganizationCreator> items;
  final int total;
}

class CompanyTypographySettings {
  const CompanyTypographySettings({
    this.fontFamily,
    this.fontSize,
    this.pdfFontFamily,
    this.pdfFontSize,
    this.wordFontFamily,
    this.wordFontSize,
  });

  static const defaultFontFamily = 'Calibri';
  static const defaultFontSize = '15px';

  final String? fontFamily;
  final String? fontSize;
  final String? pdfFontFamily;
  final String? pdfFontSize;
  final String? wordFontFamily;
  final String? wordFontSize;

  String get resolvedPdfFontFamily =>
      _normalizeFamily(pdfFontFamily ?? fontFamily) ?? defaultFontFamily;

  String get resolvedPdfFontSize =>
      _normalizeSize(pdfFontSize ?? fontSize) ?? defaultFontSize;

  String get resolvedWordFontFamily =>
      _normalizeFamily(wordFontFamily ?? fontFamily) ?? defaultFontFamily;

  String get resolvedWordFontSize =>
      _normalizeSize(wordFontSize ?? fontSize) ?? defaultFontSize;

  factory CompanyTypographySettings.fromJson(Map<String, dynamic> json) {
    return CompanyTypographySettings(
      fontFamily: json['font_family'] as String?,
      fontSize: json['font_size']?.toString(),
      pdfFontFamily: json['pdf_font_family'] as String?,
      pdfFontSize: json['pdf_font_size']?.toString(),
      wordFontFamily: json['word_font_family'] as String?,
      wordFontSize: json['word_font_size']?.toString(),
    );
  }

  static String? _normalizeFamily(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeSize(Object? value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    if (trimmed.isEmpty) return null;
    return trimmed.toLowerCase().endsWith('px') ? trimmed : '${trimmed}px';
  }
}
