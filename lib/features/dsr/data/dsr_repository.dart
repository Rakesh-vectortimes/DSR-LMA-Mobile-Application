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
import '../data/models/dsr_models.dart';
import '../domain/dsr_api_mapper.dart';

class DsrRepository with ApiGetHelper {
  DsrRepository(this.dio);

  @override
  final Dio dio;

  Future<PaginatedDsrRecords> listPage(DsrQueryParams query) async {
    try {
      final response = await dio.get<dynamic>(
        '/diagnostic-studies',
        queryParameters: _query({
          ...query.toQueryParameters(),
          'status': ReportStatusMapper.toApiFilter(query.status),
        }),
      );
      final envelope = _require(response, fallbackMessage: 'Failed to load studies');
      return _toPaginatedRecords(envelope.data, query);
    } on DioException catch (e) {
      throw _mapError(e, fallback: 'Failed to load studies');
    }
  }

  Future<DiagnosticStudyRecord> getById(String id) async {
    try {
      final response = await dio.get<dynamic>('/diagnostic-studies/$id');
      final envelope = _require(response, fallbackMessage: 'Failed to load study');
      final data = envelope.data;
      if (data is Map<String, dynamic>) return normalizeDsrRecord(data);
      if (data is Map) return normalizeDsrRecord(Map<String, dynamic>.from(data));
      throw ApiException('Failed to load study', statusCode: response.statusCode);
    } on DioException catch (e) {
      throw _mapError(e, fallback: 'Failed to load study');
    }
  }

  Future<DiagnosticStudyRecord> create(Map<String, dynamic> payload) {
    return _save(
      request: () => dio.post<dynamic>('/diagnostic-studies', data: payload),
      fallbackMessage: 'Failed to create study',
    );
  }

  Future<DiagnosticStudyRecord> update(String id, Map<String, dynamic> payload) {
    return _save(
      request: () => dio.put<dynamic>('/diagnostic-studies/$id', data: payload),
      fallbackMessage: 'Failed to update study',
    );
  }

  Future<void> delete(String id) async {
    try {
      final response = await dio.delete<dynamic>('/diagnostic-studies/$id');
      _require(response, fallbackMessage: 'Failed to delete study');
    } on DioException catch (e) {
      throw _mapError(e, fallback: 'Failed to delete study');
    }
  }

  Future<ExportFile> exportPdf(
    String id, {
    required DiagnosticStudyRecord record,
    required CompanyTypographySettings typography,
  }) {
    return _export(
      kind: ExportKind.pdf,
      path: '/diagnostic-studies/$id/export/pdf',
      fallbackMessage: 'Failed to export PDF',
      lastResort: 'study-$id.pdf',
      constructedFilename: _dsrFilename(record, ExportKind.pdf),
      fontFamily: typography.resolvedPdfFontFamily,
      fontSize: typography.resolvedPdfFontSize,
    );
  }

  Future<ExportFile> exportWord(
    String id, {
    required DiagnosticStudyRecord record,
    required CompanyTypographySettings typography,
  }) {
    return _export(
      kind: ExportKind.word,
      path: '/diagnostic-studies/$id/export/word',
      fallbackMessage: 'Failed to export Word',
      lastResort: 'study-$id.docx',
      constructedFilename: _dsrFilename(record, ExportKind.word),
      fontFamily: typography.resolvedWordFontFamily,
      fontSize: typography.resolvedWordFontSize,
    );
  }

  String _dsrFilename(DiagnosticStudyRecord record, ExportKind kind) {
    return buildDsrExportFilename(
      companyName: record.companyName ?? record.displayCompanyName,
      title: record.title,
      periodFrom: record.companyBackground?.analysisPeriodFrom ??
          parseAnalysisPeriod(record.analysisPeriod).from,
      periodTo: record.companyBackground?.analysisPeriodTo ??
          parseAnalysisPeriod(record.analysisPeriod).to,
      kind: kind,
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

  Future<DiagnosticStudyRecord> _save({
    required Future<Response<dynamic>> Function() request,
    required String fallbackMessage,
  }) async {
    try {
      final response = await request();
      final envelope = _require(response, fallbackMessage: fallbackMessage);
      final data = envelope.data;
      if (data is Map<String, dynamic>) return normalizeDsrRecord(data);
      if (data is Map) return normalizeDsrRecord(Map<String, dynamic>.from(data));
      throw ApiException(fallbackMessage, statusCode: response.statusCode);
    } on DioException catch (e) {
      throw _mapError(e, fallback: fallbackMessage);
    }
  }

  PaginatedDsrRecords _toPaginatedRecords(dynamic data, DsrQueryParams query) {
    final items = ListResponse.extractItems(
      data,
      normalizeDsrRecord,
      nestedKeys: const [
        'items',
        'results',
        'data',
        'studies',
        'diagnostic_studies',
      ],
    );

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final page = _asInt(map['page']) ?? query.page;
      final limit = _asInt(map['limit']) ?? query.limit;
      final total = _asInt(map['total']) ?? items.length;
      final pages = _asInt(map['pages']) ??
          (limit > 0 ? (total / limit).ceil().clamp(1, 999999) : 1);
      return PaginatedDsrRecords(
        items: items,
        total: total,
        page: page,
        limit: limit,
        pages: pages,
      );
    }

    return PaginatedDsrRecords(
      items: items,
      total: items.length,
      page: query.page,
      limit: query.limit,
      pages: 1,
    );
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

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

final dsrRepositoryProvider = Provider<DsrRepository>((ref) {
  return DsrRepository(ref.watch(dioProvider));
});
