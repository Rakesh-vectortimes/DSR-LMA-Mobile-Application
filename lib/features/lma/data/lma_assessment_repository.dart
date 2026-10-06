import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/report_status.dart';
import '../../../core/export/export_filename.dart';
import '../../../core/export/export_share.dart';
import '../../../core/network/api_get_helper.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/list_response.dart';
import '../../companies/data/models/organization.dart';
import '../domain/lma_api_mapper.dart';
import 'models/lma_assessment_models.dart';

class LmaAssessmentRepository with ApiGetHelper {
  LmaAssessmentRepository(this.dio);

  @override
  final Dio dio;

  Future<PaginatedLmaRecords> listPage(LmaQueryParams query) async {
    try {
      final response = await dio.get<dynamic>(
        '/lean-maturity-assessments',
        queryParameters: _query({
          ...query.toQueryParameters(),
          'status': ReportStatus.toApiFilter(query.status),
        }),
      );
      final envelope = _require(
        response,
        fallbackMessage: 'Failed to load assessments',
      );
      return _toPaginatedRecords(envelope.data, query);
    } on DioException catch (e) {
      throw _mapError(e, fallback: 'Failed to load assessments');
    }
  }

  Future<LeanMaturityAssessmentRecord> getById(String id) async {
    try {
      final response = await dio.get<dynamic>('/lean-maturity-assessments/$id');
      final envelope = _require(
        response,
        fallbackMessage: 'Failed to load assessment',
      );
      final data = envelope.data;
      if (data is Map<String, dynamic>) return normalizeLmaRecord(data);
      if (data is Map) return normalizeLmaRecord(Map<String, dynamic>.from(data));
      throw ApiException('Failed to load assessment', statusCode: response.statusCode);
    } on DioException catch (e) {
      throw _mapError(e, fallback: 'Failed to load assessment');
    }
  }

  Future<LeanMaturityAssessmentRecord> create(Map<String, dynamic> payload) async {
    return _save(
      request: () => dio.post<dynamic>('/lean-maturity-assessments', data: payload),
      fallbackMessage: 'Failed to create assessment',
    );
  }

  Future<LeanMaturityAssessmentRecord> update(
    String id,
    Map<String, dynamic> payload,
  ) async {
    return _save(
      request: () =>
          dio.put<dynamic>('/lean-maturity-assessments/$id', data: payload),
      fallbackMessage: 'Failed to update assessment',
    );
  }

  Future<void> delete(String id) async {
    try {
      final response = await dio.delete<dynamic>('/lean-maturity-assessments/$id');
      _require(response, fallbackMessage: 'Failed to delete assessment');
    } on DioException catch (e) {
      throw _mapError(e, fallback: 'Failed to delete assessment');
    }
  }

  Future<ExportFile> exportPdf(
    String id, {
    required LeanMaturityAssessmentRecord record,
    required CompanyTypographySettings typography,
  }) {
    return _export(
      kind: ExportKind.pdf,
      path: '/lean-maturity-assessments/$id/export/pdf',
      fallbackMessage: 'Failed to export PDF',
      lastResort: 'lma-$id.pdf',
      constructedFilename: buildLmaExportFilename(
        companyName: record.companyName ?? record.displayCompanyName,
        title: record.title,
        reportDate: record.reportDate,
        kind: ExportKind.pdf,
      ),
      fontFamily: typography.resolvedPdfFontFamily,
      fontSize: typography.resolvedPdfFontSize,
    );
  }

  Future<ExportFile> exportWord(
    String id, {
    required LeanMaturityAssessmentRecord record,
    required CompanyTypographySettings typography,
  }) {
    return _export(
      kind: ExportKind.word,
      path: '/lean-maturity-assessments/$id/export/word',
      fallbackMessage: 'Failed to export Word',
      lastResort: 'lma-$id.docx',
      constructedFilename: buildLmaExportFilename(
        companyName: record.companyName ?? record.displayCompanyName,
        title: record.title,
        reportDate: record.reportDate,
        kind: ExportKind.word,
      ),
      fontFamily: typography.resolvedWordFontFamily,
      fontSize: typography.resolvedWordFontSize,
    );
  }

  Future<ExportFile> _export({
    required ExportKind kind,
    required String path,
    required String fallbackMessage,
    required String lastResort,
    required String constructedFilename,
    required String fontFamily,
    required String fontSize,
  }) async {
    try {
      final response = await dio.get<List<int>>(
        path,
        queryParameters: {
          'font_family': fontFamily,
          'font_size': fontSize,
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 400) {
        throw ApiException(fallbackMessage, statusCode: status);
      }
      final bytes = Uint8List.fromList(response.data ?? const <int>[]);
      final filename = resolveExportFilename(
        contentDisposition: response.headers.value('content-disposition'),
        fallback: constructedFilename,
        lastResort: lastResort,
      );
      return ExportFile(bytes: bytes, filename: filename, kind: kind);
    } on DioException catch (e) {
      throw mapExportError(e, fallback: fallbackMessage);
    }
  }

  Future<LeanMaturityAssessmentRecord> _save({
    required Future<Response<dynamic>> Function() request,
    required String fallbackMessage,
  }) async {
    try {
      final response = await request();
      final envelope = _require(response, fallbackMessage: fallbackMessage);
      final data = envelope.data;
      if (data is Map<String, dynamic>) return normalizeLmaRecord(data);
      if (data is Map) return normalizeLmaRecord(Map<String, dynamic>.from(data));
      throw ApiException(fallbackMessage, statusCode: response.statusCode);
    } on DioException catch (e) {
      throw _mapError(e, fallback: fallbackMessage);
    }
  }

  PaginatedLmaRecords _toPaginatedRecords(dynamic data, LmaQueryParams query) {
    final items = ListResponse.extractItems(
      data,
      normalizeLmaRecord,
      nestedKeys: const [
        'items',
        'results',
        'data',
        'assessments',
        'lean_maturity_assessments',
      ],
    );

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final page = _asInt(map['page']) ?? query.page;
      final limit = _asInt(map['limit']) ?? query.limit;
      final total = _asInt(map['total']) ?? items.length;
      final pages = _asInt(map['pages']) ??
          (limit > 0 ? (total / limit).ceil().clamp(1, 999999) : 1);
      return PaginatedLmaRecords(
        items: items,
        total: total,
        page: page,
        limit: limit,
        pages: pages,
      );
    }

    return PaginatedLmaRecords(
      items: items,
      total: items.length,
      page: query.page,
      limit: query.limit,
      pages: 1,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic>? _query(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is String && value.isEmpty) return;
      cleaned[key] = value;
    });
    return cleaned.isEmpty ? null : cleaned;
  }

  ApiResponse<dynamic> _require(
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

  ApiException _mapError(DioException e, {required String fallback}) {
    return ApiException(
      ApiException.messageFromBody(e.response?.data, fallback: fallback),
      statusCode: e.response?.statusCode,
    );
  }
}

final lmaAssessmentRepositoryProvider = Provider<LmaAssessmentRepository>((ref) {
  return LmaAssessmentRepository(ref.watch(dioProvider));
});
