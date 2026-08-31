import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_response.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/token_storage.dart';
import 'models/user.dart';

class AuthRepository {
  AuthRepository({
    required Dio dio,
    required TokenStorage tokenStorage,
  })  : _dio = dio,
        _tokenStorage = tokenStorage;

  final Dio _dio;
  final TokenStorage _tokenStorage;

  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );
      return _parseTokensResponse(response, fallbackMessage: 'Login failed');
    } on DioException catch (e) {
      throw _mapDio(e, fallback: 'Unable to sign in. Check your connection.');
    }
  }

  Future<User> me() async {
    try {
      final response = await _dio.get<dynamic>('/auth/me');
      final envelope = _requireSuccessMap(response, fallbackMessage: 'Failed to load profile');
      final data = envelope.data;
      if (data == null) {
        throw ApiException('Failed to load profile', statusCode: response.statusCode);
      }
      return User.fromJson(data);
    } on DioException catch (e) {
      throw _mapDio(e, fallback: 'Unable to restore session.');
    }
  }

  Future<AuthTokens> refresh(String refreshToken) async {
    try {
      final response = await _dio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return _parseTokensResponse(response, fallbackMessage: 'Session expired');
    } on DioException catch (e) {
      throw _mapDio(e, fallback: 'Session expired. Please sign in again.');
    }
  }

  /// Best-effort logout; always clears local tokens afterward (caller should too).
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _dio.post<dynamic>(
          '/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      }
    } catch (_) {
      // Ignore API failures — local clear is mandatory.
    } finally {
      await _tokenStorage.clear();
    }
  }

  Future<void> saveSession(AuthTokens tokens) {
    return _tokenStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
  }

  Future<void> clearSession() => _tokenStorage.clear();

  Future<String?> readAccessToken() => _tokenStorage.readAccessToken();

  Future<String?> readRefreshToken() => _tokenStorage.readRefreshToken();

  AuthTokens _parseTokensResponse(
    Response<dynamic> response, {
    required String fallbackMessage,
  }) {
    final envelope = _requireSuccessMap(response, fallbackMessage: fallbackMessage);
    final data = envelope.data;
    if (data == null) {
      throw ApiException(fallbackMessage, statusCode: response.statusCode);
    }
    final tokens = AuthTokens.fromJson(data);
    if (tokens.accessToken.isEmpty) {
      throw ApiException(fallbackMessage, statusCode: response.statusCode);
    }
    return tokens;
  }

  ApiResponse<Map<String, dynamic>> _requireSuccessMap(
    Response<dynamic> response, {
    required String fallbackMessage,
  }) {
    final envelope = ApiResponse.fromDioData<Map<String, dynamic>>(
      response.data,
      (json) => Map<String, dynamic>.from(json as Map),
    );

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
    if (e.response != null) {
      return ApiException(
        ApiException.messageFromBody(e.response?.data, fallback: fallback),
        statusCode: e.response?.statusCode,
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException('Connection timed out. Please try again.');
      case DioExceptionType.connectionError:
        return ApiException('Unable to reach the server. Check your connection.');
      default:
        return ApiException(fallback);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(dioProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});
