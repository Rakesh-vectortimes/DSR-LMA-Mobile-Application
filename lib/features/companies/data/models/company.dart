import 'package:equatable/equatable.dart';

import '../../../../core/network/list_response.dart';
import '../../../../core/permissions/record_permissions.dart';

/// Report-target company used by DSR and LMA forms.
class Company extends Equatable {
  const Company({
    required this.id,
    required this.companyName,
    this.location = '',
    this.address,
    this.companyIntroduction = '',
    this.contactPerson,
    this.mailId,
    this.contactPhoneNumber,
    this.whatsappNumber,
    this.currency = 'INR',
    this.currencySymbol,
    this.totalWorkforce,
    this.shiftOperation,
    this.workingHours,
    this.workingDays,
    this.sewingLines,
    this.productionSystem,
    this.inventoryType,
    this.workstationType,
    this.lineConfiguration,
    this.status = 'active',
    this.orgCompanyId,
    this.createdByRole,
    this.createdBy,
  });

  final String id;
  final String companyName;
  final String location;
  final String? address;
  final String companyIntroduction;
  final String? contactPerson;
  final String? mailId;
  final String? contactPhoneNumber;
  final String? whatsappNumber;
  final String currency;
  final String? currencySymbol;
  final int? totalWorkforce;
  final dynamic shiftOperation;
  final String? workingHours;
  final dynamic workingDays;
  final int? sewingLines;
  final dynamic productionSystem;
  final dynamic inventoryType;
  final dynamic workstationType;
  final dynamic lineConfiguration;
  final String status;
  final String? orgCompanyId;
  final String? createdByRole;
  final dynamic createdBy;

  String get displayName => companyName.isEmpty ? id : companyName;

  factory Company.fromJson(Map<String, dynamic> json) {
    final record = json;
    final intro = record['company_introduction'] ?? record['company_intro'];
    return Company(
      id: ListResponse.extractId(json, preferredKeys: const ['company_id']),
      companyName: (json['company_name'] as String?)?.trim() ??
          (json['name'] as String?)?.trim() ??
          '',
      location: (json['location'] as String?)?.trim() ??
          (json['address'] as String?)?.trim() ??
          '',
      address: json['address'] as String?,
      companyIntroduction: (intro as String?)?.trim() ?? '',
      contactPerson: json['contact_person'] as String?,
      mailId: json['mail_id'] as String?,
      contactPhoneNumber: json['contact_phone_number'] as String?,
      whatsappNumber: json['whatsapp_number'] as String?,
      currency: (json['currency'] as String?)?.trim().isNotEmpty == true
          ? (json['currency'] as String).trim()
          : 'INR',
      currencySymbol: json['currency_symbol'] as String?,
      totalWorkforce: _asInt(json['total_workforce']),
      shiftOperation: json['shift_operation'],
      workingHours: json['working_hours']?.toString(),
      workingDays: json['working_days'],
      sewingLines: _asInt(json['sewing_lines']),
      productionSystem: json['production_system'],
      inventoryType: json['inventory_type'],
      workstationType: json['workstation_type'],
      lineConfiguration: json['line_configuration'],
      status: (json['status'] as String?)?.trim().isNotEmpty == true
          ? (json['status'] as String).trim()
          : 'active',
      orgCompanyId: normalizeEntityId(json['org_company_id']),
      createdByRole: RecordPermissions.extractCreatorRole(
        createdByRole: json['created_by_role'] as String?,
        creatorRole: json['creator_role'] as String?,
        createdBy: json['created_by'] ?? json['createdBy'],
      ),
      createdBy: json['created_by'] ?? json['createdBy'],
    );
  }

  Map<String, dynamic> toCreatePayload() => {
        'company_name': companyName,
        'location': location,
        'company_introduction': companyIntroduction,
        'total_workforce': totalWorkforce ?? 0,
        'shift_operation': _shiftAsNumber(shiftOperation),
        'working_hours': workingHours ?? '',
        'working_days': workingDays ?? 0,
        'currency': currency.isNotEmpty ? currency : 'INR',
        'status': status.isNotEmpty ? status : 'active',
      };

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static num _shiftAsNumber(dynamic value) {
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }

  @override
  List<Object?> get props => [id, companyName, location, currency];
}

class PaginatedCompanies {
  const PaginatedCompanies({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
  });

  final List<Company> items;
  final int total;
  final int page;
  final int limit;
  final int pages;
}

/// Values edited by the company autocomplete / background form.
class CompanyFormValues {
  CompanyFormValues({
    this.companyId,
    this.companyName = '',
    this.location = '',
    this.companyIntroduction = '',
    this.totalWorkforce,
    this.shiftOperation,
    this.workingHours = '',
    this.workingDays,
    this.currency = 'INR',
    this.currencySymbol,
    this.status = 'active',
  });

  String? companyId;
  String companyName;
  String location;
  String companyIntroduction;
  int? totalWorkforce;
  dynamic shiftOperation;
  String workingHours;
  dynamic workingDays;
  String currency;
  String? currencySymbol;
  String status;

  bool get hasExistingCompany =>
      companyId != null && companyId!.trim().isNotEmpty;

  void applyCompany(Company company) {
    companyId = company.id.isEmpty ? null : company.id;
    companyName = company.companyName;
    location = company.location;
    companyIntroduction = company.companyIntroduction;
    totalWorkforce = company.totalWorkforce;
    shiftOperation = company.shiftOperation;
    workingHours = company.workingHours ?? '';
    workingDays = company.workingDays;
    currency = company.currency.isNotEmpty ? company.currency : 'INR';
    currencySymbol = company.currencySymbol;
    status = company.status;
  }

  void clearCompanyLink() {
    companyId = null;
  }

  Map<String, dynamic> toCreatePayload() => {
        'company_name': companyName.trim(),
        'location': location.trim(),
        'company_introduction': companyIntroduction,
        'total_workforce': totalWorkforce ?? 0,
        'shift_operation': Company._shiftAsNumber(shiftOperation),
        'working_hours': workingHours,
        'working_days': workingDays ?? 0,
        'currency': currency.isNotEmpty ? currency : 'INR',
        'status': status.isNotEmpty ? status : 'active',
      };

  factory CompanyFormValues.fromCompany(Company company) {
    final values = CompanyFormValues();
    values.applyCompany(company);
    return values;
  }
}
