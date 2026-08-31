import 'package:dio/dio.dart';

import 'api_response.dart';
import 'list_response.dart';

/// Shared GET helpers for list/detail repositories.
mixin ApiGetHelper {
  Dio get dio;

  Future<List<T>> getList<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Map<String, dynamic> json) fromJson,
    List<String> nestedKeys = const [
      'items',
      'results',
      'data',
      'studies',
      'diagnostic_studies',
      'assessments',
      'lean_maturity_assessments',
      'companies',
      'employees',
    ],
    String fallbackMessage = 'Failed to load data',
  }) async {
    try {
      final response = await dio.get<dynamic>(
        path,
        queryParameters: _cleanQuery(queryParameters),
      );
      final envelope = _requireSuccess(response, fallbackMessage: fallbackMessage);
      return ListResponse.extractItems(
        envelope.data,
        fromJson,
        nestedKeys: nestedKeys,
      );
    } on DioException catch (e) {
      throw _mapDio(e, fallback: fallbackMessage);
    }
  }

  Future<T> getObject<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Map<String, dynamic> json) fromJson,
    String fallbackMessage = 'Failed to load data',
  }) async {
    try {
      final response = await dio.get<dynamic>(
        path,
        queryParameters: _cleanQuery(queryParameters),
      );
      final envelope = _requireSuccess(response, fallbackMessage: fallbackMessage);
      final data = envelope.data;
      if (data is Map<String, dynamic>) return fromJson(data);
      if (data is Map) return fromJson(Map<String, dynamic>.from(data));
      throw ApiException(fallbackMessage, statusCode: response.statusCode);
    } on DioException catch (e) {
      throw _mapDio(e, fallback: fallbackMessage);
    }
  }

  Future<dynamic> getRawData(
    String path, {
    Map<String, dynamic>? queryParameters,
    String fallbackMessage = 'Failed to load data',
  }) async {
    try {
      final response = await dio.get<dynamic>(
        path,
        queryParameters: _cleanQuery(queryParameters),
      );
      return _requireSuccess(response, fallbackMessage: fallbackMessage).data;
    } on DioException catch (e) {
      throw _mapDio(e, fallback: fallbackMessage);
    }
  }

  Future<T> postObject<T>(
    String path, {
    Object? data,
    required T Function(Map<String, dynamic> json) fromJson,
    String fallbackMessage = 'Failed to save',
  }) async {
    try {
      final response = await dio.post<dynamic>(path, data: data);
      final envelope = _requireSuccess(response, fallbackMessage: fallbackMessage);
      return _mapObject(envelope.data, fromJson, fallbackMessage, response.statusCode);
    } on DioException catch (e) {
      throw _mapDio(e, fallback: fallbackMessage);
    }
  }

  Future<T> putObject<T>(
    String path, {
    Object? data,
    required T Function(Map<String, dynamic> json) fromJson,
    String fallbackMessage = 'Failed to save',
  }) async {
    try {
      final response = await dio.put<dynamic>(path, data: data);
      final envelope = _requireSuccess(response, fallbackMessage: fallbackMessage);
      return _mapObject(envelope.data, fromJson, fallbackMessage, response.statusCode);
    } on DioException catch (e) {
      throw _mapDio(e, fallback: fallbackMessage);
    }
  }

  Future<void> deleteObject(
    String path, {
    String fallbackMessage = 'Failed to delete',
  }) async {
    try {
      final response = await dio.delete<dynamic>(path);
      _requireSuccess(response, fallbackMessage: fallbackMessage);
    } on DioException catch (e) {
      throw _mapDio(e, fallback: fallbackMessage);
    }
  }

  T _mapObject<T>(
    dynamic data,
    T Function(Map<String, dynamic> json) fromJson,
    String fallbackMessage,
    int? statusCode,
  ) {
    if (data is Map<String, dynamic>) return fromJson(data);
    if (data is Map) return fromJson(Map<String, dynamic>.from(data));
    throw ApiException(fallbackMessage, statusCode: statusCode);
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
}
