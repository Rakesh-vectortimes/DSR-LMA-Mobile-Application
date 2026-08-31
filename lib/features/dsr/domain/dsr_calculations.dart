import '../data/models/dsr_models.dart';

double dsrNumericValue(Object? value) {
  if (value == null || value == '') return 0;
  final parsed = double.tryParse(value.toString().replaceAll(',', ''));
  return parsed != null && parsed.isFinite ? parsed : 0;
}

double dsrPercentOf(num value, num total) {
  if (total <= 0) return 0;
  return (value / total * 10000).round() / 100;
}

double dsrRound2(num value) => (value * 100).round() / 100;

List<ProductVolumeRow> recalcProductVolumePercents(List<ProductVolumeRow> rows) {
  final filtered = rows.where((row) => !_isTotalRow(row.productCategory)).toList();
  final volumeTotal =
      filtered.fold<double>(0, (sum, row) => sum + dsrNumericValue(row.annualVolume));
  final valueTotal =
      filtered.fold<double>(0, (sum, row) => sum + dsrNumericValue(row.annualValue));

  return rows.map((row) {
    if (_isTotalRow(row.productCategory)) return row;
    return row.copyWith(
      volumePercent: dsrPercentOf(dsrNumericValue(row.annualVolume), volumeTotal),
      valuePercent: dsrPercentOf(dsrNumericValue(row.annualValue), valueTotal),
    );
  }).toList();
}

List<CustomerBaseRow> recalcCustomerBasePercents(List<CustomerBaseRow> rows) {
  final filtered = rows.where((row) => !_isTotalRow(row.customerName)).toList();
  final total =
      filtered.fold<double>(0, (sum, row) => sum + dsrNumericValue(row.annualVolume));

  return rows.map((row) {
    if (_isTotalRow(row.customerName)) return row;
    return row.copyWith(
      volumePercent: dsrPercentOf(dsrNumericValue(row.annualVolume), total),
    );
  }).toList();
}

List<MarketFocusRow> recalcMarketFocusPercents(List<MarketFocusRow> rows) {
  final filtered = rows.where((row) => !_isTotalRow(row.marketFocus)).toList();
  final total = filtered.fold<double>(0, (sum, row) => sum + dsrNumericValue(row.volume));

  return rows.map((row) {
    if (_isTotalRow(row.marketFocus)) return row;
    return row.copyWith(
      volumePercent: dsrPercentOf(dsrNumericValue(row.volume), total),
    );
  }).toList();
}

CostData recalcCostData({
  required CostData costData,
  required List<HeadCountRow> headCountData,
  required dynamic workingDays,
}) {
  final directSalary = dsrNumericValue(costData.totalDirectSalary);
  final indirectSalary = dsrNumericValue(costData.totalIndirectSalary);
  final overheads = dsrNumericValue(costData.totalOverheads);
  final monthlyOutput = dsrNumericValue(costData.avgMonthlyOutput);
  final days = dsrNumericValue(workingDays);
  final sewingOperators = _sewingOperators(headCountData);

  final operatingExpenses = directSalary + indirectSalary + overheads;

  return costData.copyWith(
    operatingExpenses: dsrRound2(operatingExpenses),
    costPerPc: monthlyOutput > 0 ? dsrRound2(operatingExpenses / monthlyOutput) : 0,
    productivityPerPerson: days > 0 && sewingOperators > 0
        ? dsrRound2(monthlyOutput / days / sewingOperators)
        : 0,
  );
}

double _sewingOperators(List<HeadCountRow> rows) {
  for (final row in rows) {
    if (row.department.trim().toLowerCase() == 'sewing') {
      return dsrNumericValue(row.operators);
    }
  }
  return 0;
}

bool _isTotalRow(String label) => label.trim().toLowerCase() == 'total';

List<Map<String, dynamic>> sortRowsByVolumePercentDesc(
  List<Map<String, dynamic>> rows, {
  required String section,
}) {
  final filtered = rows.where((row) {
    final label = row['product_category'] ??
        row['customer_name'] ??
        row['market_focus'];
    return label.toString().trim().toLowerCase() != 'total';
  }).toList();

  double percentFor(Map<String, dynamic> row) {
    if (section == 'product_volume_mix') {
      final total = filtered.fold<double>(
        0,
        (sum, item) => sum + dsrNumericValue(item['annual_volume']),
      );
      return dsrPercentOf(dsrNumericValue(row['annual_volume']), total);
    }
    return dsrNumericValue(row['volume_percent']);
  }

  final sorted = [...filtered]..sort((a, b) => percentFor(b).compareTo(percentFor(a)));
  return sorted;
}

List<T> withoutTotalRows<T>(
  List<T> rows,
  String Function(T row) labelFor,
) {
  return rows
      .where((row) => labelFor(row).trim().toLowerCase() != 'total')
      .toList();
}
