import 'package:flutter_test/flutter_test.dart';

import 'package:dsr_lma/features/dsr/data/models/dsr_models.dart';
import 'package:dsr_lma/features/dsr/domain/dsr_api_mapper.dart';
import 'package:dsr_lma/features/dsr/domain/dsr_calculations.dart';

void main() {
  test('dsrPercentOf matches web rounding', () {
    expect(dsrPercentOf(25, 100), 25);
    expect(dsrPercentOf(1, 3), 33.33);
  });

  test('recalcCostData computes operating expenses and cost per pc', () {
    final cost = recalcCostData(
      costData: const CostData(
        totalDirectSalary: 100,
        totalIndirectSalary: 50,
        totalOverheads: 25,
        avgMonthlyOutput: 200,
      ),
      headCountData: const [
        HeadCountRow(department: 'Sewing', operators: 10),
      ],
      workingDays: 20,
    );

    expect(cost.operatingExpenses, 175);
    expect(cost.costPerPc, 0.88);
    expect(cost.productivityPerPerson, 1);
  });

  test('buildDsrApiPayload wraps sections and maps submitted to published', () {
    final payload = buildDsrApiPayload(
      companyBackground: const DsrCompanyBackground(
        companyId: 'cmp-1',
        companyName: 'Acme',
        analysisPeriodFrom: '2026-01-01',
        analysisPeriodTo: '2026-08-17',
        reportDate: '2026-01-01',
        preparedBy: 'Jane Doe',
      ),
      productVolumeMix: const [
        ProductVolumeRow(productCategory: 'A', annualVolume: 60, volumePercent: 60),
        ProductVolumeRow(productCategory: 'B', annualVolume: 40, volumePercent: 40),
      ],
      customerBase: const [],
      marketFocus: const [],
      qualityPerformance: const [],
      headCountData: const [],
      costData: const CostData(),
      deliveryPerformance: const [],
      processExcellence: const ProcessExcellence(),
      status: 'submitted',
    );

    expect(payload['status'], 'published');
    expect(payload['title'], 'Acme Diagnostic Study');

    final background = payload['company_background'] as Map<String, dynamic>;
    final details = background['details'] as Map<String, dynamic>;
    expect(details['prepared_by'], 'Jane Doe');
    expect(details['analysis_period'], '2026-01-01 to 2026-08-17');

    final volume = payload['product_volume_mix'] as Map<String, dynamic>;
    final volumeDetails = volume['details'] as Map<String, dynamic>;
    final items = volumeDetails['items'] as List<dynamic>;
    expect((items.first as Map)['product_category'], 'A');
  });

  test('normalizeDsrRecord unwraps sections and coerces performance status', () {
    final record = normalizeDsrRecord({
      '_id': '507f1f77bcf86cd799439011',
      'status': 'published',
      'created_by_name': 'Jane Doe',
      'updated_by': '507f1f77bcf86cd799439012',
      'company_background': {
        'details': {
          'company_name': 'Acme',
          'analysis_period_from': '2026-01-01',
          'analysis_period_to': '2026-08-17',
          'analysis_period': '2026-01-01 to 2026-08-17',
        },
      },
      'quality_performance': {
        'details': {
          'items': [
            {
              'description': 'Rework %',
              'status': 'not_measured',
              'value': '',
            },
          ],
        },
      },
      'cost_performance': {
        'details': {
          'head_count_data': [
            {'department': 'Sewing', 'workers': 5},
          ],
          'cost_data': {'operating_expenses': 100},
        },
      },
      'process_excellence': {
        'details': {
          'lean_belt_level': 'master_black',
          'five_s_level': 'excellence',
          'lean_practice_details': 'hired_coach',
          'improvement_areas': 'hidden',
        },
      },
    });

    expect(record.preparedBy, 'Jane Doe');
    expect(record.updatedBy, isNull);
    expect(record.qualityPerformance.single.status, 2);
    expect(record.headCountData.single.operators, 5);
    expect(record.processExcellence.leanBeltLevel, 5);
    expect(record.processExcellence.fiveSLevel, 1);
    expect(record.processExcellence.leanPracticeDetails, 2);
  });
}
