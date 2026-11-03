import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/export/export_filename.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/list_response.dart';
import '../domain/lma_registration_rules.dart';
import 'models/lma_registration_models.dart';

class LmaRegistrationRepository {
  LmaRegistrationRepository({
    required Dio publicDio,
    required Dio dio,
  })  : _publicDio = publicDio,
        _dio = dio;

  final Dio _publicDio;
  final Dio _dio;

  Future<PublicLmaFormConfig> loadConfig() async {
    final data = await _data(
      _publicDio.get<dynamic>('/public/lma-registration/config'),
      fallback: 'Failed to load the registration form',
    );
    return parsePublicLmaConfig(data);
  }

  Future<LmaRegistrationSubmitResult> submit(
      Map<String, dynamic> payload) async {
    try {
      final response = await _publicDio.post<dynamic>(
        '/public/lma-registration',
        data: payload,
      );
      final envelope =
          _require(response, fallback: 'Failed to save the registration');
      return LmaRegistrationSubmitResult.fromEnvelope(
        message: envelope.message,
        data: envelope.data,
      );
    } on DioException catch (e) {
      throw _mapDio(e, fallback: 'Failed to save the registration');
    }
  }

  Future<ExportFile> previewPdf(Map<String, dynamic> payload) {
    return _pdf(
      _publicDio.post<List<int>>(
        '/public/lma-registration/preview-pdf',
        data: payload,
        options: _pdfOptions,
      ),
      fallbackName: 'lma-registration-preview.pdf',
      fallbackMessage: 'Failed to prepare the PDF',
    );
  }

  Future<ExportFile> registrationPdf(String id) {
    return _pdf(
      _publicDio.get<List<int>>(
        '/public/lma-registration/$id/pdf',
        options: _pdfOptions,
      ),
      fallbackName: 'lma-registration-$id.pdf',
      fallbackMessage: 'Failed to download the PDF',
    );
  }

  Future<LmaQrSettings> qrSettings() async {
    final data = await _data(
      _dio.get<dynamic>('/lma-registrations/qr-settings'),
      fallback: 'Failed to load QR settings',
    );
    return LmaQrSettings.fromJson(data);
  }

  Future<LmaQrSettings> saveQrUrl(String url) async {
    final data = await _data(
      _dio.post<dynamic>(
        '/lma-registrations/qr-settings',
        data: {'url': url.trim()},
      ),
      fallback: 'Failed to save the QR code',
    );
    if (data == null) return qrSettings();
    final settings = LmaQrSettings.fromJson(data);
    if (settings.current == null && settings.items.isEmpty) return qrSettings();
    return settings;
  }

  Future<List<LmaRegistrationSummary>> list({int? status}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/lma-registrations',
        queryParameters: status == null ? null : {'status': status},
      );
      final envelope =
          _require(response, fallback: 'Failed to load registrations');
      return ListResponse.extractItems(
        envelope.data,
        LmaRegistrationSummary.fromJson,
        nestedKeys: const [
          'items',
          'results',
          'registrations',
          'lma_registrations',
          'data',
        ],
      );
    } on DioException catch (e) {
      throw _mapDio(e, fallback: 'Failed to load registrations');
    }
  }

  Future<LmaRegistrationDetail> getById(String id) async {
    final data = await _data(
      _dio.get<dynamic>('/lma-registrations/$id'),
      fallback: 'Failed to load the registration',
    );
    final map = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
    return LmaRegistrationDetail.fromJson(map);
  }

  Future<LmaRegistrationDetail> approve(String id) async {
    final data = await _data(
      _dio.post<dynamic>('/lma-registrations/$id/approve',
          data: const <String, dynamic>{}),
      fallback: 'Failed to approve the registration',
    );
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      map.putIfAbsent('id', () => id);
      map.putIfAbsent('status', () => LmaRegistrationStatus.approved);
      return LmaRegistrationDetail.fromJson(map);
    }
    return getById(id);
  }

  Future<dynamic> _data(Future<Response<dynamic>> request,
      {required String fallback}) async {
    try {
      final response = await request;
      return _require(response, fallback: fallback).data;
    } on DioException catch (e) {
      throw _mapDio(e, fallback: fallback);
    }
  }

  Future<ExportFile> _pdf(
    Future<Response<List<int>>> request, {
    required String fallbackName,
    required String fallbackMessage,
  }) async {
    try {
      final response = await request;
      final status = response.statusCode ?? 0;
      final bytes = Uint8List.fromList(response.data ?? const <int>[]);
      if (status >= 400 || bytes.isEmpty || _looksLikeJson(bytes)) {
        throw ApiException(_messageFromBytes(bytes, fallbackMessage),
            statusCode: status);
      }
      final filename = resolveExportFilename(
        contentDisposition: response.headers.value('content-disposition'),
        fallback: fallbackName,
        lastResort: fallbackName,
      );
      return ExportFile(bytes: bytes, filename: filename, kind: ExportKind.pdf);
    } on DioException catch (e) {
      throw _mapPdfError(e, fallback: fallbackMessage);
    }
  }

  ApiResponse<dynamic> _require(Response<dynamic> response,
      {required String fallback}) {
    final envelope = ApiResponse.fromDioData<dynamic>(response.data, null);
    final status = response.statusCode ?? 0;
    if (status >= 400 || !envelope.success) {
      throw ApiException(
        envelope.message.isNotEmpty ? envelope.message : fallback,
        statusCode: status,
        success: envelope.success,
      );
    }
    return envelope;
  }

  ApiException _mapDio(DioException error, {required String fallback}) {
    return ApiException(
      ApiException.messageFromBody(error.response?.data, fallback: fallback),
      statusCode: error.response?.statusCode,
    );
  }

  ApiException _mapPdfError(DioException error, {required String fallback}) {
    final data = error.response?.data;
    if (data is List<int>) {
      return ApiException(
          _messageFromBytes(Uint8List.fromList(data), fallback));
    }
    if (data is Uint8List) {
      return ApiException(_messageFromBytes(data, fallback));
    }
    return _mapDio(error, fallback: fallback);
  }

  bool _looksLikeJson(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final start =
        utf8.decode(bytes.take(1).toList(), allowMalformed: true).trimLeft();
    return start.startsWith('{') || start.startsWith('[');
  }

  String _messageFromBytes(Uint8List bytes, String fallback) {
    try {
      return ApiException.messageFromBody(jsonDecode(utf8.decode(bytes)),
          fallback: fallback);
    } catch (_) {
      return fallback;
    }
  }
}

final _pdfOptions = Options(
  responseType: ResponseType.bytes,
  receiveTimeout: const Duration(minutes: 2),
);

final lmaRegistrationRepositoryProvider =
    Provider<LmaRegistrationRepository>((ref) {
  return LmaRegistrationRepository(
    publicDio: ref.watch(refreshDioProvider),
    dio: ref.watch(dioProvider),
  );
});
