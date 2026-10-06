import '../../../../core/network/list_response.dart';
import 'company.dart';

/// Company name from a CRM deal converted to DSR or LMA.
class ConvertedCompany {
  const ConvertedCompany({
    required this.companyName,
    this.dealId,
    this.leadId,
    this.companyId,
    this.firstName,
    this.email,
    this.countryCode,
    this.phone,
    this.convertedTo,
    this.convertedToLabel,
  });

  final String companyName;
  final String? dealId;
  final String? leadId;
  final String? companyId;
  final String? firstName;
  final String? email;
  final String? countryCode;
  final String? phone;
  final int? convertedTo;
  final String? convertedToLabel;

  String get resolvedCompanyId => (companyId ?? '').trim();

  String get dropdownValue =>
      resolvedCompanyId.isNotEmpty ? resolvedCompanyId : companyName;

  ConvertedCompany copyWith({String? companyId}) {
    return ConvertedCompany(
      companyName: companyName,
      dealId: dealId,
      leadId: leadId,
      companyId: companyId ?? this.companyId,
      firstName: firstName,
      email: email,
      countryCode: countryCode,
      phone: phone,
      convertedTo: convertedTo,
      convertedToLabel: convertedToLabel,
    );
  }

  factory ConvertedCompany.fromJson(Map<String, dynamic> json) {
    return ConvertedCompany(
      companyName: (json['company_name'] as String?)?.trim() ??
          (json['name'] as String?)?.trim() ??
          '',
      dealId: normalizeEntityId(json['deal_id']),
      leadId: normalizeEntityId(json['lead_id']),
      companyId: normalizeEntityId(json['company_id'] ?? json['fk_company_id']),
      firstName: (json['first_name'] as String?)?.trim(),
      email: (json['email'] as String?)?.trim(),
      countryCode: (json['country_code'] as String?)?.trim(),
      phone: (json['phone'] as String?)?.trim(),
      convertedTo: _asInt(json['converted_to']),
      convertedToLabel: (json['converted_to_label'] as String?)?.trim(),
    );
  }

  Company toCompanyOption() {
    return Company(
      id: resolvedCompanyId,
      companyName: companyName,
      mailId: email,
      contactPhoneNumber: phone,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
