import 'package:flutter_test/flutter_test.dart';

import 'package:dsr_lma/core/constants/crm_conversion_type.dart';
import 'package:dsr_lma/features/companies/data/models/converted_company.dart';

void main() {
  test('CrmConversionType matches backend enum', () {
    expect(CrmConversionType.lma, 4);
    expect(CrmConversionType.dsr, 5);
  });

  test('ConvertedCompany.fromJson uses company_id not deal_id', () {
    final company = ConvertedCompany.fromJson({
      'deal_id': '6ab214904229d5e7c3bef458',
      'lead_id': '6ab214904229d5e7c3bef457',
      'company_name': 'KEN Global Designs Pvt Ltd',
      'email': 'ops@example.com',
      'phone': '999',
      'converted_to': 4,
      'converted_to_label': 'Lma',
    });

    expect(company.companyName, 'KEN Global Designs Pvt Ltd');
    expect(company.dealId, '6ab214904229d5e7c3bef458');
    expect(company.companyId, isNull);
    expect(company.toCompanyOption().id, isEmpty);
    expect(company.toCompanyOption().companyName, 'KEN Global Designs Pvt Ltd');
  });

  test('ConvertedCompany.fromJson keeps explicit company_id', () {
    final company = ConvertedCompany.fromJson({
      'deal_id': '6ab214904229d5e7c3bef458',
      'company_id': '507f1f77bcf86cd799439011',
      'company_name': 'Acme',
      'converted_to': 5,
    });

    expect(company.resolvedCompanyId, '507f1f77bcf86cd799439011');
    expect(company.toCompanyOption().id, '507f1f77bcf86cd799439011');
  });
}
