import 'dart:async';

import 'package:dio/dio.dart';

import 'api_response.dart';
import '../storage/token_storage.dart';

typedef SessionExpiredCallback = FutureOr<void> Function();

/// Attaches Bearer tokens and performs single-flight refresh on HTTP 401.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required Dio dio,
    required TokenStorage tokenStorage,
    required Dio refreshDio,
    required SessionExpiredCallback onSessionExpired,
  })  : _dio = dio,
        _tokenStorage = tokenStorage,
        _refreshDio = refreshDio,
        _onSessionExpired = onSessionExpired;

  final Dio _dio;
  final TokenStorage _tokenStorage;
  final Dio _refreshDio;
  final SessionExpiredCallback _onSessionExpired;

  Future<String?>? _refreshFuture;

  static bool shouldSkipBearer(String path) {
    final normalized = path.toLowerCase();
    return normalized.contains('/auth/login') ||
        normalized.contains('/auth/refresh') ||
        normalized.contains('/auth/register');
  }

  static bool shouldSkipRefresh(String path) {
    final normalized = path.toLowerCase();
    return normalized.contains('/auth/login') ||
        normalized.contains('/auth/refresh') ||
        normalized.contains('/auth/logout');
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!shouldSkipBearer(options.path)) {
      final token = await _tokenStorage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    } else {
      options.headers.remove('Authorization');
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final options = err.requestOptions;

    if (response?.statusCode != 401 || shouldSkipRefresh(options.path)) {
      handler.next(err);
      return;
    }

    // Avoid infinite retry loops.
    if (options.extra['auth_retry'] == true) {
      await _failSession();
      handler.next(err);
      return;
    }

    try {
      final newAccess = await _refreshAccessTokenSingleFlight();
      if (newAccess == null || newAccess.isEmpty) {
        await _failSession();
        handler.next(err);
        return;
      }

      final headers = Map<String, dynamic>.from(options.headers)
        ..['Authorization'] = 'Bearer $newAccess';
      final extra = Map<String, dynamic>.from(options.extra)..['auth_retry'] = true;

      final retryResponse = await _dio.fetch(
        options.copyWith(headers: headers, extra: extra),
      );
      handler.resolve(retryResponse);
    } catch (_) {
      await _failSession();
      handler.next(err);
    }
  }

  Future<String?> _refreshAccessTokenSingleFlight() {
    return _refreshFuture ??= _doRefresh().whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }

    final response = await _refreshDio.post<dynamic>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
    );

    final envelope = ApiResponse.fromDioData<Map<String, dynamic>>(
      response.data,
      (json) => Map<String, dynamic>.from(json as Map),
    );

    if (!envelope.success || envelope.data == null) {
      throw ApiException(
        envelope.message.isNotEmpty ? envelope.message : 'Token refresh failed',
        statusCode: response.statusCode,
      );
    }

    final access = envelope.data!['access_token'] as String?;
    if (access == null || access.isEmpty) {
      throw ApiException('Token refresh failed: missing access_token');
    }

    final newRefresh = envelope.data!['refresh_token'] as String?;
    await _tokenStorage.saveTokens(
      accessToken: access,
      refreshToken: newRefresh,
    );
    return access;
  }

  Future<void> _failSession() async {
    await _tokenStorage.clear();
    await Future.sync(_onSessionExpired);
  }
}
