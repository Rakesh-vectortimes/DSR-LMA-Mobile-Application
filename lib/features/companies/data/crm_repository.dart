import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_get_helper.dart';
import '../../../core/network/dio_client.dart';
import 'company_repository.dart';
import 'models/converted_company.dart';

class CrmRepository with ApiGetHelper {
  CrmRepository(this.dio);

  @override
  final Dio dio;

  /// Companies from deals converted to [convertedTo] (4 = LMA, 5 = DSR).
  Future<List<ConvertedCompany>> listConvertedCompanies({
    required int convertedTo,
    String? search,
  }) async {
    final items = await getList(
      '/crm/deals/dependency',
      queryParameters: {
        'converted_to': convertedTo,
        'search': search,
      },
      fromJson: ConvertedCompany.fromJson,
      nestedKeys: const ['items', 'results', 'data', 'companies'],
      fallbackMessage: 'Failed to load companies',
    );
    return items.where((item) => item.companyName.trim().isNotEmpty).toList();
  }

  /// Same as [listConvertedCompanies], filling `company_id` from `/companies` when missing.
  Future<List<ConvertedCompany>> listConvertedCompaniesResolved({
    required int convertedTo,
    String? search,
    required CompanyRepository companyRepository,
  }) async {
    final converted = await listConvertedCompanies(
      convertedTo: convertedTo,
      search: search,
    );
    if (converted.isEmpty) return converted;

    final missingIds = converted.any((item) => item.resolvedCompanyId.isEmpty);
    if (!missingIds) return converted;

    try {
      final page = await companyRepository.listPage(
        page: 1,
        limit: 100,
        search: search,
      );
      final byName = <String, String>{};
      for (final company in page.items) {
        final key = company.companyName.trim().toLowerCase();
        if (key.isEmpty || company.id.isEmpty) continue;
        byName.putIfAbsent(key, () => company.id);
      }
      return converted
          .map((item) {
            if (item.resolvedCompanyId.isNotEmpty) return item;
            final id = byName[item.companyName.trim().toLowerCase()];
            return id == null ? item : item.copyWith(companyId: id);
          })
          .toList();
    } catch (_) {
      return converted;
    }
  }
}

final crmRepositoryProvider = Provider<CrmRepository>((ref) {
  return CrmRepository(ref.watch(dioProvider));
});
