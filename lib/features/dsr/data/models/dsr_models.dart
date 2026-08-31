import 'package:equatable/equatable.dart';

class DsrQueryParams {
  const DsrQueryParams({
    this.page = 1,
    this.limit = 10,
    this.search,
    this.companyId,
    this.orgCompanyId,
    this.createdBy,
    this.preparedBy,
    this.reportDateFrom,
    this.reportDateTo,
    this.periodFrom,
    this.periodTo,
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
  final String? periodFrom;
  final String? periodTo;
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
        'period_from': periodFrom,
        'period_to': periodTo,
        'status': status,
      };
}

class PaginatedDsrRecords extends Equatable {
  const PaginatedDsrRecords({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
  });

  final List<DiagnosticStudyRecord> items;
  final int total;
  final int page;
  final int limit;
  final int pages;

  @override
  List<Object?> get props => [items, total, page, limit, pages];
}

class ProductVolumeRow extends Equatable {
  const ProductVolumeRow({
    required this.productCategory,
    this.annualVolume = '',
    this.annualValue = '',
    this.volumePercent = 0,
    this.valuePercent = 0,
  });

  final String productCategory;
  final dynamic annualVolume;
  final dynamic annualValue;
  final double volumePercent;
  final double valuePercent;

  ProductVolumeRow copyWith({
    String? productCategory,
    dynamic annualVolume,
    dynamic annualValue,
    double? volumePercent,
    double? valuePercent,
  }) {
    return ProductVolumeRow(
      productCategory: productCategory ?? this.productCategory,
      annualVolume: annualVolume ?? this.annualVolume,
      annualValue: annualValue ?? this.annualValue,
      volumePercent: volumePercent ?? this.volumePercent,
      valuePercent: valuePercent ?? this.valuePercent,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_category': productCategory,
        'annual_volume': annualVolume,
        'annual_value': annualValue,
        'volume_percent': volumePercent,
        'value_percent': valuePercent,
      };

  factory ProductVolumeRow.fromJson(Map<String, dynamic> json) {
    return ProductVolumeRow(
      productCategory: json['product_category']?.toString() ?? '',
      annualVolume: json['annual_volume'],
      annualValue: json['annual_value'],
      volumePercent: _asDouble(json['volume_percent']),
      valuePercent: _asDouble(json['value_percent']),
    );
  }

  @override
  List<Object?> get props =>
      [productCategory, annualVolume, annualValue, volumePercent, valuePercent];
}

class CustomerBaseRow extends Equatable {
  const CustomerBaseRow({
    required this.customerName,
    this.annualVolume = '',
    this.volumePercent = 0,
  });

  final String customerName;
  final dynamic annualVolume;
  final double volumePercent;

  CustomerBaseRow copyWith({
    String? customerName,
    dynamic annualVolume,
    double? volumePercent,
  }) {
    return CustomerBaseRow(
      customerName: customerName ?? this.customerName,
      annualVolume: annualVolume ?? this.annualVolume,
      volumePercent: volumePercent ?? this.volumePercent,
    );
  }

  Map<String, dynamic> toJson() => {
        'customer_name': customerName,
        'annual_volume': annualVolume,
        'volume_percent': volumePercent,
      };

  factory CustomerBaseRow.fromJson(Map<String, dynamic> json) {
    return CustomerBaseRow(
      customerName: json['customer_name']?.toString() ?? '',
      annualVolume: json['annual_volume'],
      volumePercent: _asDouble(json['volume_percent']),
    );
  }

  @override
  List<Object?> get props => [customerName, annualVolume, volumePercent];
}

class MarketFocusRow extends Equatable {
  const MarketFocusRow({
    required this.marketFocus,
    this.volume = '',
    this.volumePercent = 0,
  });

  final String marketFocus;
  final dynamic volume;
  final double volumePercent;

  MarketFocusRow copyWith({
    String? marketFocus,
    dynamic volume,
    double? volumePercent,
  }) {
    return MarketFocusRow(
      marketFocus: marketFocus ?? this.marketFocus,
      volume: volume ?? this.volume,
      volumePercent: volumePercent ?? this.volumePercent,
    );
  }

  Map<String, dynamic> toJson() => {
        'market_focus': marketFocus,
        'volume': volume,
        'volume_percent': volumePercent,
      };

  factory MarketFocusRow.fromJson(Map<String, dynamic> json) {
    return MarketFocusRow(
      marketFocus: json['market_focus']?.toString() ?? '',
      volume: json['volume'],
      volumePercent: _asDouble(json['volume_percent']),
    );
  }

  @override
  List<Object?> get props => [marketFocus, volume, volumePercent];
}

class PerformanceRow extends Equatable {
  const PerformanceRow({
    required this.description,
    this.status = 1,
    this.value = '',
    this.remark = '',
  });

  final String description;
  final int status;
  final String value;
  final String remark;

  bool get isMeasured => status == 1;

  PerformanceRow copyWith({
    String? description,
    int? status,
    String? value,
    String? remark,
  }) {
    return PerformanceRow(
      description: description ?? this.description,
      status: status ?? this.status,
      value: value ?? this.value,
      remark: remark ?? this.remark,
    );
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'status': status,
        'value': value,
        'remark': remark,
      };

  factory PerformanceRow.fromJson(Map<String, dynamic> json) {
    return PerformanceRow(
      description: json['description']?.toString() ?? '',
      status: _asInt(json['status']) ?? 1,
      value: json['value']?.toString() ?? '',
      remark: json['remark']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [description, status, value, remark];
}

class HeadCountRow extends Equatable {
  const HeadCountRow({
    required this.department,
    this.helpers = '',
    this.operators = '',
    this.supervisor = '',
    this.executive = '',
    this.checkers = '',
    this.manager = '',
  });

  final String department;
  final dynamic helpers;
  final dynamic operators;
  final dynamic supervisor;
  final dynamic executive;
  final dynamic checkers;
  final dynamic manager;

  HeadCountRow copyWith({
    String? department,
    dynamic helpers,
    dynamic operators,
    dynamic supervisor,
    dynamic executive,
    dynamic checkers,
    dynamic manager,
  }) {
    return HeadCountRow(
      department: department ?? this.department,
      helpers: helpers ?? this.helpers,
      operators: operators ?? this.operators,
      supervisor: supervisor ?? this.supervisor,
      executive: executive ?? this.executive,
      checkers: checkers ?? this.checkers,
      manager: manager ?? this.manager,
    );
  }

  Map<String, dynamic> toJson() => {
        'department': department,
        'helpers': helpers,
        'operators': operators,
        'supervisor': supervisor,
        'executive': executive,
        'checkers': checkers,
        'manager': manager,
      };

  factory HeadCountRow.fromJson(Map<String, dynamic> json) {
    return HeadCountRow(
      department: json['department']?.toString() ?? '',
      helpers: json['helpers'],
      operators: json['operators'] ?? json['workers'],
      supervisor: json['supervisor'],
      executive: json['executive'],
      checkers: json['checkers'],
      manager: json['manager'],
    );
  }

  @override
  List<Object?> get props =>
      [department, helpers, operators, supervisor, executive, checkers, manager];
}

class CostData extends Equatable {
  const CostData({
    this.avgOperatorSalary,
    this.totalDirectSalary,
    this.totalIndirectSalary,
    this.totalOverheads,
    this.operatingExpenses,
    this.avgMonthlyOutput,
    this.costPerPc,
    this.costPerMin,
    this.factoryEfficiency,
    this.productivityPerPerson,
  });

  final dynamic avgOperatorSalary;
  final dynamic totalDirectSalary;
  final dynamic totalIndirectSalary;
  final dynamic totalOverheads;
  final dynamic operatingExpenses;
  final dynamic avgMonthlyOutput;
  final dynamic costPerPc;
  final dynamic costPerMin;
  final dynamic factoryEfficiency;
  final dynamic productivityPerPerson;

  CostData copyWith({
    dynamic avgOperatorSalary,
    dynamic totalDirectSalary,
    dynamic totalIndirectSalary,
    dynamic totalOverheads,
    dynamic operatingExpenses,
    dynamic avgMonthlyOutput,
    dynamic costPerPc,
    dynamic costPerMin,
    dynamic factoryEfficiency,
    dynamic productivityPerPerson,
  }) {
    return CostData(
      avgOperatorSalary: avgOperatorSalary ?? this.avgOperatorSalary,
      totalDirectSalary: totalDirectSalary ?? this.totalDirectSalary,
      totalIndirectSalary: totalIndirectSalary ?? this.totalIndirectSalary,
      totalOverheads: totalOverheads ?? this.totalOverheads,
      operatingExpenses: operatingExpenses ?? this.operatingExpenses,
      avgMonthlyOutput: avgMonthlyOutput ?? this.avgMonthlyOutput,
      costPerPc: costPerPc ?? this.costPerPc,
      costPerMin: costPerMin ?? this.costPerMin,
      factoryEfficiency: factoryEfficiency ?? this.factoryEfficiency,
      productivityPerPerson:
          productivityPerPerson ?? this.productivityPerPerson,
    );
  }

  Map<String, dynamic> toJson() => {
        'avg_operator_salary': avgOperatorSalary,
        'total_direct_salary': totalDirectSalary,
        'total_indirect_salary': totalIndirectSalary,
        'total_overheads': totalOverheads,
        'operating_expenses': operatingExpenses,
        'avg_monthly_output': avgMonthlyOutput,
        'cost_per_pc': costPerPc,
        'cost_per_min': costPerMin,
        'factory_efficiency': factoryEfficiency,
        'productivity_per_person': productivityPerPerson,
      };

  factory CostData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CostData();
    return CostData(
      avgOperatorSalary: json['avg_operator_salary'],
      totalDirectSalary: json['total_direct_salary'],
      totalIndirectSalary: json['total_indirect_salary'],
      totalOverheads: json['total_overheads'],
      operatingExpenses: json['operating_expenses'],
      avgMonthlyOutput: json['avg_monthly_output'],
      costPerPc: json['cost_per_pc'],
      costPerMin: json['cost_per_min'],
      factoryEfficiency: json['factory_efficiency'],
      productivityPerPerson: json['productivity_per_person'],
    );
  }

  @override
  List<Object?> get props => [
        avgOperatorSalary,
        totalDirectSalary,
        totalIndirectSalary,
        totalOverheads,
        operatingExpenses,
        avgMonthlyOutput,
        costPerPc,
        costPerMin,
        factoryEfficiency,
        productivityPerPerson,
      ];
}

class ImprovementProject extends Equatable {
  const ImprovementProject({
    this.project = '',
    this.currentPerformance = '',
    this.goal = '',
    this.completionDate = '',
  });

  final String project;
  final String currentPerformance;
  final String goal;
  final String completionDate;

  ImprovementProject copyWith({
    String? project,
    String? currentPerformance,
    String? goal,
    String? completionDate,
  }) {
    return ImprovementProject(
      project: project ?? this.project,
      currentPerformance: currentPerformance ?? this.currentPerformance,
      goal: goal ?? this.goal,
      completionDate: completionDate ?? this.completionDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'project': project,
        'current_performance': currentPerformance,
        'goal': goal,
        'completion_date': completionDate,
      };

  factory ImprovementProject.fromJson(Map<String, dynamic> json) {
    return ImprovementProject(
      project: json['project']?.toString() ?? '',
      currentPerformance: json['current_performance']?.toString() ?? '',
      goal: json['goal']?.toString() ?? '',
      completionDate: json['completion_date']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [project, currentPerformance, goal, completionDate];
}

class ProcessExcellence extends Equatable {
  const ProcessExcellence({
    this.measureStandardTime = '',
    this.measurePcd = '',
    this.interestedAutomation = '',
    this.ieDepartment = '',
    this.leanBeltProfessionals = '',
    this.leanBeltLevel,
    this.trackOperatorPerformance = '',
    this.trainingSchool = '',
    this.fiveSCertification = '',
    this.fiveSLevel,
    this.incentiveSystem = '',
    this.incentiveDetails = '',
    this.oneYearPlan = '',
    this.improvementProjects = const [],
    this.leanToolsPracticed = '',
    this.leanPracticeDetails,
    this.painAreas = '',
    this.improvementsExpected = '',
  });

  final String measureStandardTime;
  final String measurePcd;
  final String interestedAutomation;
  final String ieDepartment;
  final String leanBeltProfessionals;
  final int? leanBeltLevel;
  final String trackOperatorPerformance;
  final String trainingSchool;
  final String fiveSCertification;
  final int? fiveSLevel;
  final String incentiveSystem;
  final String incentiveDetails;
  final String oneYearPlan;
  final List<ImprovementProject> improvementProjects;
  final String leanToolsPracticed;
  final int? leanPracticeDetails;
  final String painAreas;
  final String improvementsExpected;

  bool isYes(String field) {
    switch (field) {
      case 'lean_belt_professionals':
        return leanBeltProfessionals == 'yes';
      case 'five_s_certification':
        return fiveSCertification == 'yes';
      case 'incentive_system':
        return incentiveSystem == 'yes';
      case 'one_year_plan':
        return oneYearPlan == 'yes';
      case 'lean_tools_practiced':
        return leanToolsPracticed == 'yes';
      default:
        return false;
    }
  }

  ProcessExcellence copyWith({
    String? measureStandardTime,
    String? measurePcd,
    String? interestedAutomation,
    String? ieDepartment,
    String? leanBeltProfessionals,
    int? leanBeltLevel,
    String? trackOperatorPerformance,
    String? trainingSchool,
    String? fiveSCertification,
    int? fiveSLevel,
    String? incentiveSystem,
    String? incentiveDetails,
    String? oneYearPlan,
    List<ImprovementProject>? improvementProjects,
    String? leanToolsPracticed,
    int? leanPracticeDetails,
    String? painAreas,
    String? improvementsExpected,
  }) {
    return ProcessExcellence(
      measureStandardTime: measureStandardTime ?? this.measureStandardTime,
      measurePcd: measurePcd ?? this.measurePcd,
      interestedAutomation: interestedAutomation ?? this.interestedAutomation,
      ieDepartment: ieDepartment ?? this.ieDepartment,
      leanBeltProfessionals:
          leanBeltProfessionals ?? this.leanBeltProfessionals,
      leanBeltLevel: leanBeltLevel ?? this.leanBeltLevel,
      trackOperatorPerformance:
          trackOperatorPerformance ?? this.trackOperatorPerformance,
      trainingSchool: trainingSchool ?? this.trainingSchool,
      fiveSCertification: fiveSCertification ?? this.fiveSCertification,
      fiveSLevel: fiveSLevel ?? this.fiveSLevel,
      incentiveSystem: incentiveSystem ?? this.incentiveSystem,
      incentiveDetails: incentiveDetails ?? this.incentiveDetails,
      oneYearPlan: oneYearPlan ?? this.oneYearPlan,
      improvementProjects: improvementProjects ?? this.improvementProjects,
      leanToolsPracticed: leanToolsPracticed ?? this.leanToolsPracticed,
      leanPracticeDetails: leanPracticeDetails ?? this.leanPracticeDetails,
      painAreas: painAreas ?? this.painAreas,
      improvementsExpected: improvementsExpected ?? this.improvementsExpected,
    );
  }

  Map<String, dynamic> toJson() => {
        'measure_standard_time': measureStandardTime,
        'measure_pcd': measurePcd,
        'interested_automation': interestedAutomation,
        'ie_department': ieDepartment,
        'lean_belt_professionals': leanBeltProfessionals,
        'lean_belt_level': leanBeltLevel,
        'track_operator_performance': trackOperatorPerformance,
        'training_school': trainingSchool,
        'five_s_certification': fiveSCertification,
        'five_s_level': fiveSLevel,
        'incentive_system': incentiveSystem,
        'incentive_details': incentiveDetails,
        'one_year_plan': oneYearPlan,
        'improvement_projects':
            improvementProjects.map((project) => project.toJson()).toList(),
        'lean_tools_practiced': leanToolsPracticed,
        'lean_practice_details': leanPracticeDetails,
        'pain_areas': painAreas,
        'improvements_expected': improvementsExpected,
      };

  @override
  List<Object?> get props => [
        measureStandardTime,
        measurePcd,
        interestedAutomation,
        ieDepartment,
        leanBeltProfessionals,
        leanBeltLevel,
        trackOperatorPerformance,
        trainingSchool,
        fiveSCertification,
        fiveSLevel,
        incentiveSystem,
        incentiveDetails,
        oneYearPlan,
        improvementProjects,
        leanToolsPracticed,
        leanPracticeDetails,
        painAreas,
        improvementsExpected,
      ];
}

class DsrCompanyBackground extends Equatable {
  const DsrCompanyBackground({
    this.companyId,
    this.companyName = '',
    this.companyIntroduction = '',
    this.location = '',
    this.totalWorkforce,
    this.shiftOperation,
    this.workingHours = '',
    this.workingDays,
    this.currency = 'INR',
    this.currencySymbol,
    this.preparedBy,
    this.reportDate,
    this.analysisPeriod = '',
    this.analysisPeriodFrom,
    this.analysisPeriodTo,
  });

  final String? companyId;
  final String companyName;
  final String companyIntroduction;
  final String location;
  final int? totalWorkforce;
  final dynamic shiftOperation;
  final String workingHours;
  final dynamic workingDays;
  final String currency;
  final String? currencySymbol;
  final String? preparedBy;
  final String? reportDate;
  final String analysisPeriod;
  final String? analysisPeriodFrom;
  final String? analysisPeriodTo;

  DsrCompanyBackground copyWith({
    String? companyId,
    String? companyName,
    String? companyIntroduction,
    String? location,
    int? totalWorkforce,
    dynamic shiftOperation,
    String? workingHours,
    dynamic workingDays,
    String? currency,
    String? currencySymbol,
    String? preparedBy,
    String? reportDate,
    String? analysisPeriod,
    String? analysisPeriodFrom,
    String? analysisPeriodTo,
  }) {
    return DsrCompanyBackground(
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyIntroduction: companyIntroduction ?? this.companyIntroduction,
      location: location ?? this.location,
      totalWorkforce: totalWorkforce ?? this.totalWorkforce,
      shiftOperation: shiftOperation ?? this.shiftOperation,
      workingHours: workingHours ?? this.workingHours,
      workingDays: workingDays ?? this.workingDays,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      preparedBy: preparedBy ?? this.preparedBy,
      reportDate: reportDate ?? this.reportDate,
      analysisPeriod: analysisPeriod ?? this.analysisPeriod,
      analysisPeriodFrom: analysisPeriodFrom ?? this.analysisPeriodFrom,
      analysisPeriodTo: analysisPeriodTo ?? this.analysisPeriodTo,
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
        'prepared_by': preparedBy,
        'report_date': reportDate,
        'analysis_period': analysisPeriod,
        'analysis_period_from': analysisPeriodFrom,
        'analysis_period_to': analysisPeriodTo,
      };

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
        preparedBy,
        reportDate,
        analysisPeriod,
        analysisPeriodFrom,
        analysisPeriodTo,
      ];
}

class DiagnosticStudyRecord extends Equatable {
  const DiagnosticStudyRecord({
    required this.id,
    required this.status,
    this.companyId,
    this.companyName,
    this.title,
    this.reportDate,
    this.analysisPeriod,
    this.preparedBy,
    this.createdByName,
    this.updatedBy,
    this.updatedByName,
    this.createdByRole,
    this.companyBackground,
    this.productVolumeMix = const [],
    this.customerBase = const [],
    this.marketFocus = const [],
    this.qualityPerformance = const [],
    this.headCountData = const [],
    this.costData = const CostData(),
    this.deliveryPerformance = const [],
    this.processExcellence = const ProcessExcellence(),
    this.createdAt,
    this.updatedAt,
    this.raw,
  });

  final String id;
  final String status;
  final String? companyId;
  final String? companyName;
  final String? title;
  final String? reportDate;
  final String? analysisPeriod;
  final String? preparedBy;
  final String? createdByName;
  final String? updatedBy;
  final String? updatedByName;
  final String? createdByRole;
  final DsrCompanyBackground? companyBackground;
  final List<ProductVolumeRow> productVolumeMix;
  final List<CustomerBaseRow> customerBase;
  final List<MarketFocusRow> marketFocus;
  final List<PerformanceRow> qualityPerformance;
  final List<HeadCountRow> headCountData;
  final CostData costData;
  final List<PerformanceRow> deliveryPerformance;
  final ProcessExcellence processExcellence;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic>? raw;

  String get displayCompanyName {
    final name = (companyName ?? companyBackground?.companyName ?? '').trim();
    return name.isEmpty ? 'Untitled study' : name;
  }

  @override
  List<Object?> get props => [
        id,
        status,
        companyId,
        companyName,
        title,
        reportDate,
        analysisPeriod,
        preparedBy,
        updatedBy,
        createdByRole,
        companyBackground,
        productVolumeMix,
        customerBase,
        marketFocus,
        qualityPerformance,
        headCountData,
        costData,
        deliveryPerformance,
        processExcellence,
      ];
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    if (value == 'measured') return 1;
    if (value == 'not_measured') return 2;
    return int.tryParse(value);
  }
  return null;
}
