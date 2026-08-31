import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_get_helper.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/list_response.dart';
import 'models/company.dart';
import 'models/country.dart';

class CompanyRepository with ApiGetHelper {
  CompanyRepository(this.dio);

  @override
  final Dio dio;

  Future<PaginatedCompanies> listPage({
    int page = 1,
    int limit = 100,
    String? search,
    String? status,
    String? location,
    String? orgCompanyId,
    String? createdBy,
  }) async {
    try {
      final response = await dio.get<dynamic>(
        '/companies',
        queryParameters: _cleanQuery({
          'page': page,
          'limit': limit,
          'search': search,
          'status': status,
          'location': location,
          'org_company_id': orgCompanyId,
          'created_by': createdBy,
        }),
      );
      final envelope = _requireSuccess(response, fallbackMessage: 'Failed to load companies');
      return _toPaginatedCompanies(envelope.data, page: page, limit: limit);
    } on DioException catch (e) {
      throw _mapDio(e, fallback: 'Failed to load companies');
    }
  }

  Future<List<Company>> list({
    int page = 1,
    int limit = 100,
    String? search,
    String? status,
  }) async {
    final pageResult = await listPage(
      page: page,
      limit: limit,
      search: search,
      status: status,
    );
    return pageResult.items;
  }

  Future<Company> getById(String id) {
    return getObject(
      '/companies/$id',
      fromJson: Company.fromJson,
      fallbackMessage: 'Failed to load company',
    );
  }

  Future<Company> create(Map<String, dynamic> payload) async {
    try {
      final response = await dio.post<dynamic>('/companies', data: payload);
      final envelope = _requireSuccess(response, fallbackMessage: 'Failed to create company');
      final data = envelope.data;
      if (data is Map<String, dynamic>) return Company.fromJson(data);
      if (data is Map) return Company.fromJson(Map<String, dynamic>.from(data));
      throw ApiException('Failed to create company', statusCode: response.statusCode);
    } on DioException catch (e) {
      throw _mapDio(e, fallback: 'Failed to create company');
    }
  }

  /// Creates a company when the user typed a new name (company_id null).
  Future<Company> resolveOrCreate(CompanyFormValues values) async {
    if (values.hasExistingCompany) {
      return getById(values.companyId!);
    }

    final name = values.companyName.trim();
    if (name.isEmpty) {
      throw ApiException('Company name is required');
    }

    return create(values.toCreatePayload());
  }

  Future<List<Country>> listCountries({String? search}) {
    return getList(
      '/countries',
      queryParameters: {'search': search},
      fromJson: Country.fromJson,
      nestedKeys: const ['items', 'results', 'data', 'countries'],
      fallbackMessage: 'Failed to load countries',
    );
  }

  PaginatedCompanies _toPaginatedCompanies(
    dynamic data, {
    required int page,
    required int limit,
  }) {
    final companies = ListResponse.extractItems(
      data,
      Company.fromJson,
      nestedKeys: const ['items', 'results', 'data', 'companies'],
    );

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final resolvedPage = _asInt(map['page']) ?? page;
      final resolvedLimit = _asInt(map['limit']) ?? limit;
      final total = _asInt(map['total']) ?? companies.length;
      final pages = _asInt(map['pages']) ??
          (resolvedLimit > 0 ? (total / resolvedLimit).ceil().clamp(1, 999999) : 1);
      return PaginatedCompanies(
        items: companies,
        total: total,
        page: resolvedPage,
        limit: resolvedLimit,
        pages: pages,
      );
    }

    return PaginatedCompanies(
      items: companies,
      total: companies.length,
      page: page,
      limit: limit,
      pages: 1,
    );
  }

  Map<String, dynamic>? _cleanQuery(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      cleaned[key] = value;
    });
    return cleaned.isEmpty ? null : cleaned;
  }

  ApiResponse<dynamic> _requireSuccess(
    Response<dynamic> response, {
    required String fallbackMessage,
  }) {
    final envelope = ApiResponse.fromDioData<dynamic>(response.data, null);
    final status = response.statusCode ?? 0;
    if (status >= 400 || !envelope.success) {
      throw ApiException(
        envelope.message.isNotEmpty ? envelope.message : fallbackMessage,
        statusCode: status,
        success: envelope.success,
      );
    }
    return envelope;
  }

  ApiException _mapDio(DioException e, {required String fallback}) {
    return ApiException(
      ApiException.messageFromBody(e.response?.data, fallback: fallback),
      statusCode: e.response?.statusCode,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository(ref.watch(dioProvider));
});
