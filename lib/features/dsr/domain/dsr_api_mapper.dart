import 'package:intl/intl.dart';

import '../../../core/constants/report_status.dart';
import '../../../core/network/list_response.dart';
import '../../companies/data/models/company.dart';
import '../data/models/dsr_models.dart';
import 'dsr_calculations.dart';

Map<String, dynamic>? dsrSectionDetails(Object? section) {
  if (section is Map<String, dynamic>) {
    final details = section['details'];
    if (details is Map<String, dynamic>) return details;
    if (details is Map) return Map<String, dynamic>.from(details);
    return section;
  }
  if (section is Map) {
    final map = Map<String, dynamic>.from(section);
    final details = map['details'];
    if (details is Map<String, dynamic>) return details;
    if (details is Map) return Map<String, dynamic>.from(details);
    return map;
  }
  return null;
}

List<Map<String, dynamic>>? dsrSectionItems(Object? section) {
  if (section is List) {
    return section.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
  final details = dsrSectionDetails(section);
  final items = details?['items'];
  if (items is List) {
    return items.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
  return null;
}

String dsrStatusLabel(String? apiStatus) {
  final status = (apiStatus ?? '').trim().toLowerCase();
  switch (status) {
    case 'published':
      return 'Published';
    case 'archived':
      return 'Archived';
    default:
      return 'Draft';
  }
}

String dsrFormatDate(Object? value) {
  if (value == null || value == '') return '';
  if (value is DateTime) {
    return DateFormat('yyyy-MM-dd').format(value);
  }
  return value.toString().split('T').first;
}

String buildAnalysisPeriod(String? from, String? to) {
  final fromDate = dsrFormatDate(from);
  final toDate = dsrFormatDate(to);
  if (fromDate.isEmpty || toDate.isEmpty) return '';
  return '$fromDate to $toDate';
}

({String? from, String? to}) parseAnalysisPeriod(String? period) {
  if (period == null || period.trim().isEmpty) {
    return (from: null, to: null);
  }
  final parts = period.split(RegExp(r'\s+(?:to|-)\s+', caseSensitive: false));
  return (
    from: parts.isNotEmpty ? dsrFormatDate(parts.first) : null,
    to: parts.length > 1 ? dsrFormatDate(parts[1]) : null,
  );
}

int? dsrEnumNumber(Object? value, Map<String, int> labels) {
  if (value is int) return value;
  final numeric = num.tryParse(value?.toString() ?? '');
  if (numeric != null && numeric.isFinite) return numeric.toInt();
  return labels[value?.toString().trim().toLowerCase() ?? ''];
}

PerformanceRow normalizePerformanceRow(Map<String, dynamic> json) {
  return PerformanceRow.fromJson({
    ...json,
    'status': dsrEnumNumber(json['status'], {
          'measured': 1,
          'not_measured': 2,
        }) ??
        json['status'] ??
        1,
  });
}

ProcessExcellence normalizeProcessExcellence(Map<String, dynamic> json) {
  final projectsRaw = json['improvement_projects'];
  final projects = projectsRaw is List
      ? projectsRaw
          .whereType<Map>()
          .map((item) => ImprovementProject.fromJson(Map<String, dynamic>.from(item)))
          .where((project) => project.project.trim().toLowerCase() != 'total')
          .toList()
      : const <ImprovementProject>[];

  return ProcessExcellence(
    measureStandardTime: json['measure_standard_time']?.toString() ?? '',
    measurePcd: json['measure_pcd']?.toString() ?? '',
    interestedAutomation: json['interested_automation']?.toString() ?? '',
    ieDepartment: json['ie_department']?.toString() ?? '',
    leanBeltProfessionals: json['lean_belt_professionals']?.toString() ?? '',
    leanBeltLevel: dsrEnumNumber(json['lean_belt_level'], {
      'white': 1,
      'yellow': 2,
      'green': 3,
      'black': 4,
      'master_black': 5,
      'master black': 5,
    }),
    trackOperatorPerformance: json['track_operator_performance']?.toString() ?? '',
    trainingSchool: json['training_school']?.toString() ?? '',
    fiveSCertification: json['five_s_certification']?.toString() ?? '',
    fiveSLevel: dsrEnumNumber(json['five_s_level'], {
      'excellence': 1,
      'sustenance': 2,
      'model': 3,
    }),
    incentiveSystem: json['incentive_system']?.toString() ?? '',
    incentiveDetails: json['incentive_details']?.toString() ?? '',
    oneYearPlan: json['one_year_plan']?.toString() ?? '',
    improvementProjects: projects,
    leanToolsPracticed: json['lean_tools_practiced']?.toString() ?? '',
    leanPracticeDetails: dsrEnumNumber(json['lean_practice_details'], {
      'self_implementation': 1,
      'self implementation': 1,
      'hired_coach': 2,
      'hired coach': 2,
    }),
    painAreas: json['pain_areas']?.toString() ?? '',
    improvementsExpected: json['improvements_expected']?.toString() ?? '',
  );
}

DiagnosticStudyRecord normalizeDsrRecord(Map<String, dynamic> raw) {
  final companyBackground = dsrSectionDetails(raw['company_background']);
  final costPerformance = dsrSectionDetails(raw['cost_performance']);
  final processRaw = dsrSectionDetails(raw['process_excellence']);

  final createdByName = _normalizeDisplayUser(raw['created_by_name']);
  final preparedBy = createdByName ??
      _normalizeDisplayUser(raw['prepared_by']) ??
      _normalizeDisplayUser(companyBackground?['prepared_by']) ??
      _normalizeDisplayUser(raw['created_by']);
  final updatedBy = _normalizeDisplayUser(raw['updated_by_name']) ??
      _normalizeDisplayUser(raw['updated_by']) ??
      _normalizeDisplayUser(raw['updatedBy']);

  final productItems = dsrSectionItems(raw['product_volume_mix']);
  final customerItems = dsrSectionItems(raw['customer_base']);
  final marketItems = dsrSectionItems(raw['market_focus']);
  final qualityItems = dsrSectionItems(raw['quality_performance']);
  final deliveryItems = dsrSectionItems(raw['delivery_performance']);
  final headItems = (raw['head_count_data'] as List?) ??
      (costPerformance?['head_count_data'] as List?);
  final costDataRaw = raw['cost_data'] ?? costPerformance?['cost_data'];

  DsrCompanyBackground? background;
  if (companyBackground != null) {
    final period = parseAnalysisPeriod(
      companyBackground['analysis_period']?.toString() ?? raw['analysis_period']?.toString(),
    );
    background = DsrCompanyBackground(
      companyId: normalizeEntityId(companyBackground['company_id']),
      companyName: companyBackground['company_name']?.toString() ?? '',
      companyIntroduction: companyBackground['company_introduction']?.toString() ?? '',
      location: companyBackground['location']?.toString() ?? '',
      totalWorkforce: _asInt(companyBackground['total_workforce']),
      shiftOperation: companyBackground['shift_operation'],
      workingHours: companyBackground['working_hours']?.toString() ?? '',
      workingDays: companyBackground['working_days'],
      currency: companyBackground['currency']?.toString() ?? 'INR',
      currencySymbol: companyBackground['currency_symbol']?.toString(),
      preparedBy: companyBackground['prepared_by']?.toString(),
      reportDate: dsrFormatDate(
        companyBackground['report_date'] ?? raw['report_date'],
      ),
      analysisPeriod: companyBackground['analysis_period']?.toString() ??
          raw['analysis_period']?.toString() ??
          '',
      analysisPeriodFrom: dsrFormatDate(
        companyBackground['analysis_period_from'] ?? period.from,
      ),
      analysisPeriodTo: dsrFormatDate(
        companyBackground['analysis_period_to'] ?? period.to,
      ),
    );
  }

  return DiagnosticStudyRecord(
    id: normalizeEntityId(raw['id'] ?? raw['study_id'] ?? raw['_id']) ?? '',
    companyId: normalizeEntityId(
      raw['company_id'] ?? companyBackground?['company_id'],
    ),
    companyName: raw['company_name']?.toString() ??
        companyBackground?['company_name']?.toString() ??
        _titleToCompanyName(raw['title']?.toString()),
    title: raw['title']?.toString(),
    reportDate: dsrFormatDate(raw['report_date'] ?? companyBackground?['report_date']),
    analysisPeriod: raw['analysis_period']?.toString() ??
        companyBackground?['analysis_period']?.toString() ??
        '',
    preparedBy: preparedBy,
    createdByName: createdByName,
    updatedBy: updatedBy,
    updatedByName: updatedBy,
    createdByRole: raw['created_by_role']?.toString() ??
        raw['creator_role']?.toString() ??
        _extractRoleFromObject(raw['created_by']),
    status: raw['status']?.toString() ?? 'draft',
    companyBackground: background,
    productVolumeMix: productItems
            ?.map((item) => ProductVolumeRow.fromJson(item))
            .where((row) => row.productCategory.trim().toLowerCase() != 'total')
            .toList() ??
        const [],
    customerBase: customerItems
            ?.map((item) => CustomerBaseRow.fromJson(item))
            .where((row) => row.customerName.trim().toLowerCase() != 'total')
            .toList() ??
        const [],
    marketFocus: marketItems
            ?.map((item) => MarketFocusRow.fromJson(item))
            .where((row) => row.marketFocus.trim().toLowerCase() != 'total')
            .toList() ??
        const [],
    qualityPerformance: qualityItems
            ?.map(normalizePerformanceRow)
            .toList() ??
        const [],
    headCountData: headItems
            ?.whereType<Map>()
            .map((item) => HeadCountRow.fromJson(Map<String, dynamic>.from(item)))
            .where((row) => row.department.trim().toLowerCase() != 'total')
            .toList() ??
        const [],
    costData: costDataRaw is Map
        ? CostData.fromJson(Map<String, dynamic>.from(costDataRaw))
        : const CostData(),
    deliveryPerformance: deliveryItems
            ?.map(normalizePerformanceRow)
            .toList() ??
        const [],
    processExcellence: processRaw == null
        ? const ProcessExcellence()
        : normalizeProcessExcellence(processRaw),
    createdAt: raw['created_at']?.toString(),
    updatedAt: raw['updated_at']?.toString(),
    raw: raw,
  );
}

Map<String, dynamic> buildDsrApiPayload({
  required DsrCompanyBackground companyBackground,
  required List<ProductVolumeRow> productVolumeMix,
  required List<CustomerBaseRow> customerBase,
  required List<MarketFocusRow> marketFocus,
  required List<PerformanceRow> qualityPerformance,
  required List<HeadCountRow> headCountData,
  required CostData costData,
  required List<PerformanceRow> deliveryPerformance,
  required ProcessExcellence processExcellence,
  required String status,
}) {
  final companyName = companyBackground.companyName.trim().isEmpty
      ? 'Diagnostic Study'
      : companyBackground.companyName.trim();
  final analysisPeriod = buildAnalysisPeriod(
    companyBackground.analysisPeriodFrom,
    companyBackground.analysisPeriodTo,
  );

  final background = {
    ...companyBackground.toJson(),
    'company_name': companyName,
    'analysis_period': analysisPeriod.isNotEmpty
        ? analysisPeriod
        : companyBackground.analysisPeriod,
    'report_date': dsrFormatDate(companyBackground.reportDate),
    'analysis_period_from': dsrFormatDate(companyBackground.analysisPeriodFrom),
    'analysis_period_to': dsrFormatDate(companyBackground.analysisPeriodTo),
  };

  final processPayload = processExcellence.toJson()
    ..remove('improvement_areas');

  return {
    'company_id': companyBackground.companyId,
    'title': '$companyName Diagnostic Study',
    'status': ReportStatusMapper.toApi(status),
    'company_background': {'details': background},
    'product_volume_mix': {
      'details': {
        'items': sortRowsByVolumePercentDesc(
          productVolumeMix.map((row) => row.toJson()).toList(),
          section: 'product_volume_mix',
        ),
      },
    },
    'customer_base': {
      'details': {
        'items': sortRowsByVolumePercentDesc(
          customerBase.map((row) => row.toJson()).toList(),
          section: 'customer_base',
        ),
      },
    },
    'market_focus': {
      'details': {
        'items': sortRowsByVolumePercentDesc(
          marketFocus.map((row) => row.toJson()).toList(),
          section: 'market_focus',
        ),
      },
    },
    'quality_performance': {
      'details': {
        'items': qualityPerformance.map((row) => row.toJson()).toList(),
      },
    },
    'cost_performance': {
      'details': {
        'head_count_data': headCountData.map((row) => row.toJson()).toList(),
        'cost_data': costData.toJson(),
      },
    },
    'delivery_performance': {
      'details': {
        'items': deliveryPerformance.map((row) => row.toJson()).toList(),
      },
    },
    'process_excellence': {'details': processPayload},
  };
}

CompanyFormValues companyBackgroundToFormValues(DsrCompanyBackground bg) {
  return CompanyFormValues(
    companyId: bg.companyId,
    companyName: bg.companyName,
    location: bg.location,
    companyIntroduction: bg.companyIntroduction,
    totalWorkforce: bg.totalWorkforce,
    shiftOperation: bg.shiftOperation,
    workingHours: bg.workingHours,
    workingDays: bg.workingDays,
    currency: bg.currency,
    currencySymbol: bg.currencySymbol,
    status: 'active',
  );
}

DsrCompanyBackground formValuesToCompanyBackground({
  required CompanyFormValues values,
  required DsrCompanyBackground existing,
  required String? preparedBy,
}) {
  return existing.copyWith(
    companyId: values.companyId,
    companyName: values.companyName,
    companyIntroduction: values.companyIntroduction,
    location: values.location,
    totalWorkforce: values.totalWorkforce,
    shiftOperation: values.shiftOperation,
    workingHours: values.workingHours,
    workingDays: values.workingDays,
    currency: values.currency,
    currencySymbol: values.currencySymbol,
    preparedBy: preparedBy ?? existing.preparedBy,
  );
}

String? _normalizeDisplayUser(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(trimmed)) return null;
    return trimmed;
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    return _normalizeDisplayUser(
      map['name'] ?? map['full_name'] ?? map['email'],
    );
  }
  return null;
}

String? _extractRoleFromObject(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value)['role']?.toString();
  }
  return null;
}

String _titleToCompanyName(String? title) {
  final value = (title ?? '').trim();
  return value.replaceFirst(
    RegExp(r' Diagnostic Study$', caseSensitive: false),
    '',
  );
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
