import 'package:equatable/equatable.dart';

import '../../../../core/network/list_response.dart';
import 'lma_config_models.dart';

class LmaQueryParams {
  const LmaQueryParams({
    this.page = 1,
    this.limit = 10,
    this.search,
    this.companyId,
    this.orgCompanyId,
    this.createdBy,
    this.preparedBy,
    this.reportDateFrom,
    this.reportDateTo,
    this.status,
  });

  final int page;
  final int limit;
  final String? search;
  final String? companyId;
  final String? orgCompanyId;
  final String? createdBy;
  final String? preparedBy;
  final String? reportDateFrom;
  final String? reportDateTo;
  final String? status;

  Map<String, dynamic> toQueryParameters() => {
        'page': page,
        'limit': limit,
        'search': search,
        'company_id': companyId,
        'org_company_id': orgCompanyId,
        'created_by': createdBy,
        'prepared_by': preparedBy,
        'report_date_from': reportDateFrom,
        'report_date_to': reportDateTo,
        'status': status,
      };
}

class PaginatedLmaRecords extends Equatable {
  const PaginatedLmaRecords({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
  });

  final List<LeanMaturityAssessmentRecord> items;
  final int total;
  final int page;
  final int limit;
  final int pages;

  @override
  List<Object?> get props => [items, total, page, limit, pages];
}

class LmaCompanyBackground extends Equatable {
  const LmaCompanyBackground({
    this.companyId,
    this.companyName,
    this.companyIntroduction,
    this.location,
    this.totalWorkforce,
    this.shiftOperation,
    this.workingHours,
    this.workingDays,
    this.currency,
    this.currencySymbol,
  });

  final String? companyId;
  final String? companyName;
  final String? companyIntroduction;
  final String? location;
  final int? totalWorkforce;
  final dynamic shiftOperation;
  final dynamic workingDays;
  final String? workingHours;
  final String? currency;
  final String? currencySymbol;

  factory LmaCompanyBackground.fromJson(Map<String, dynamic> json) {
    return LmaCompanyBackground(
      companyId: normalizeEntityId(json['company_id']),
      companyName: json['company_name']?.toString(),
      companyIntroduction: json['company_introduction']?.toString(),
      location: json['location']?.toString(),
      totalWorkforce: _asInt(json['total_workforce']),
      shiftOperation: json['shift_operation'],
      workingHours: json['working_hours']?.toString(),
      workingDays: json['working_days'],
      currency: json['currency']?.toString(),
      currencySymbol: json['currency_symbol']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'company_name': companyName,
        'company_introduction': companyIntroduction,
        'location': location,
        'total_workforce': totalWorkforce,
        'shift_operation': shiftOperation,
        'working_hours': workingHours,
        'working_days': workingDays,
        'currency': currency,
        'currency_symbol': currencySymbol,
      };

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  List<Object?> get props => [
        companyId,
        companyName,
        companyIntroduction,
        location,
        totalWorkforce,
        shiftOperation,
        workingHours,
        workingDays,
        currency,
        currencySymbol,
      ];
}

class LeanMaturityAssessmentRecord extends Equatable {
  const LeanMaturityAssessmentRecord({
    required this.id,
    required this.companyId,
    required this.status,
    this.companyName,
    this.title,
    this.reportDate,
    this.preparedBy,
    this.createdByName,
    this.updatedBy,
    this.updatedByName,
    this.createdByRole,
    this.companyBackground,
    this.responses = const [],
    this.scores,
    this.createdAt,
    this.updatedAt,
    this.raw,
  });

  final String id;
  final String? companyId;
  final String status;
  final String? companyName;
  final String? title;
  final String? reportDate;
  final String? preparedBy;
  final String? createdByName;
  final String? updatedBy;
  final String? updatedByName;
  final String? createdByRole;
  final LmaCompanyBackground? companyBackground;
  final List<LeanMaturityResponse> responses;
  final LeanMaturityScores? scores;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic>? raw;

  String get displayCompanyName {
    final name = (companyName ?? companyBackground?.companyName ?? '').trim();
    return name.isEmpty ? 'Untitled assessment' : name;
  }

  @override
  List<Object?> get props => [
        id,
        companyId,
        status,
        companyName,
        title,
        reportDate,
        preparedBy,
        updatedBy,
        createdByRole,
        companyBackground,
        responses,
        scores,
      ];
}
