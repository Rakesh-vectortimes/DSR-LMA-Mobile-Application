import '../../../core/constants/report_status.dart';
import '../data/models/dsr_models.dart';
import 'dsr_calculations.dart';
import 'dsr_defaults.dart';

class DsrFormState {
  DsrFormState({
    required this.companyBackground,
    required this.productVolumeMix,
    required this.customerBase,
    required this.marketFocus,
    required this.qualityPerformance,
    required this.headCountData,
    required this.costData,
    required this.deliveryPerformance,
    required this.processExcellence,
    this.status = ReportStatus.draft,
  });

  DsrCompanyBackground companyBackground;
  List<ProductVolumeRow> productVolumeMix;
  List<CustomerBaseRow> customerBase;
  List<MarketFocusRow> marketFocus;
  List<PerformanceRow> qualityPerformance;
  List<HeadCountRow> headCountData;
  CostData costData;
  List<PerformanceRow> deliveryPerformance;
  ProcessExcellence processExcellence;
  int status;

  factory DsrFormState.initial() {
    final now = DateTime.now();
    final today = DsrFormState._formatDate(now);
    return DsrFormState(
      companyBackground: DsrCompanyBackground(
        reportDate: today,
        analysisPeriodFrom: today,
        analysisPeriodTo: null,
      ),
      productVolumeMix: productVolumeDefaults
          .map((name) => ProductVolumeRow(productCategory: name))
          .toList(),
      customerBase: customerBaseDefaults
          .map((name) => CustomerBaseRow(customerName: name))
          .toList(),
      marketFocus:
          marketFocusDefaults.map((name) => MarketFocusRow(marketFocus: name)).toList(),
      qualityPerformance: qualityPerformanceDefaults
          .map((name) => PerformanceRow(description: name))
          .toList(),
      headCountData:
          headCountDefaults.map((name) => HeadCountRow(department: name)).toList(),
      costData: const CostData(),
      deliveryPerformance: deliveryPerformanceDefaults
          .map((name) => PerformanceRow(description: name))
          .toList(),
      processExcellence: const ProcessExcellence(),
      status: ReportStatus.draft,
    );
  }

  void patchFromRecord(DiagnosticStudyRecord record) {
    final bg = record.companyBackground;
    if (bg != null) {
      companyBackground = bg;
    } else {
      companyBackground = companyBackground.copyWith(
        companyId: record.companyId,
        companyName: record.companyName ?? '',
        reportDate: record.reportDate ?? companyBackground.reportDate,
        analysisPeriod: record.analysisPeriod ?? companyBackground.analysisPeriod,
      );
    }

    if (record.productVolumeMix.isNotEmpty) {
      productVolumeMix = record.productVolumeMix;
    }
    if (record.customerBase.isNotEmpty) {
      customerBase = record.customerBase;
    }
    if (record.marketFocus.isNotEmpty) {
      marketFocus = record.marketFocus;
    }
    if (record.qualityPerformance.isNotEmpty) {
      qualityPerformance = record.qualityPerformance;
    }
    if (record.headCountData.isNotEmpty) {
      headCountData = record.headCountData;
    }
    costData = record.costData;
    if (record.deliveryPerformance.isNotEmpty) {
      deliveryPerformance = record.deliveryPerformance;
    }
    processExcellence = record.processExcellence;
    status = ReportStatus.parse(record.status);
    recalculateAll();
  }

  void recalculateAll() {
    productVolumeMix = recalcProductVolumePercents(productVolumeMix);
    customerBase = recalcCustomerBasePercents(customerBase);
    marketFocus = recalcMarketFocusPercents(marketFocus);
    costData = recalcCostData(
      costData: costData,
      headCountData: headCountData,
      workingDays: companyBackground.workingDays,
    );
  }

  static String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
