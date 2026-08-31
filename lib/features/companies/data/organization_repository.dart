import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_get_helper.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/list_response.dart';
import 'models/organization.dart';

class OrganizationRepository with ApiGetHelper {
  OrganizationRepository(this.dio);

  @override
  final Dio dio;

  Future<OrganizationCreatorsPage> getCreators({String? orgCompanyId}) async {
    final raw = await getRawData(
      '/organization/creators',
      queryParameters: {'org_company_id': orgCompanyId},
      fallbackMessage: 'Failed to load creators',
    );
    return _parseCreators(raw);
  }

  Future<List<OrgCompany>> listChildCompanies({
    int page = 1,
    int limit = 100,
    String? search,
    String? parentCompanyId,
  }) {
    return getList(
      '/child-companies',
      queryParameters: {
        'page': page,
        'limit': limit,
        'search': search,
        'parent_company_id': parentCompanyId,
      },
      fromJson: (json) => OrgCompany.fromJson(json, companyType: 'child'),
      nestedKeys: const [
        'items',
        'results',
        'data',
        'companies',
        'child_companies',
      ],
      fallbackMessage: 'Failed to load child companies',
    );
  }

  Future<OrgCompany> getCurrentParentCompany() {
    return getObject(
      '/parent-companies/me',
      fromJson: (json) => OrgCompany.fromJson(json, companyType: 'parent'),
      fallbackMessage: 'Failed to load parent company',
    );
  }

  Future<CompanyTypographySettings> getCompanyTypography() {
    return getObject(
      '/company/me',
      fromJson: CompanyTypographySettings.fromJson,
      fallbackMessage: 'Failed to load company typography',
    );
  }

  OrganizationCreatorsPage _parseCreators(dynamic raw) {
    if (raw is List) {
      final items = raw
          .whereType<Map>()
          .map((item) => OrganizationCreator.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      return OrganizationCreatorsPage(items: items, total: items.length);
    }

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final items = ListResponse.extractItems(
        raw,
        OrganizationCreator.fromJson,
        nestedKeys: const ['items', 'results', 'data', 'creators'],
      );
      final total = map['total'];
      return OrganizationCreatorsPage(
        items: items,
        total: total is num ? total.toInt() : items.length,
      );
    }

    return const OrganizationCreatorsPage(items: [], total: 0);
  }
}

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository(ref.watch(dioProvider));
});
