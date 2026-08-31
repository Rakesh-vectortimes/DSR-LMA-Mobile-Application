import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsr_lma/core/network/auth_interceptor.dart';
import 'package:dsr_lma/core/storage/token_storage.dart';

class _MemoryTokenStorage implements TokenStorage {
  String? access;
  String? refresh;

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    access = accessToken;
    if (refreshToken != null) refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._handlers);

  final List<ResponseBody Function(RequestOptions)> _handlers;
  int calls = 0;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final index = calls;
    calls++;
    if (index >= _handlers.length) {
      return ResponseBody.fromString(
        jsonEncode({'success': false, 'message': 'unexpected'}),
        500,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return _handlers[index](options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  group('AuthInterceptor path helpers', () {
    test('skips bearer on login/refresh', () {
      expect(AuthInterceptor.shouldSkipBearer('/auth/login'), isTrue);
      expect(AuthInterceptor.shouldSkipBearer('/auth/refresh'), isTrue);
      expect(AuthInterceptor.shouldSkipBearer('/auth/me'), isFalse);
      expect(AuthInterceptor.shouldSkipBearer('/auth/logout'), isFalse);
      expect(AuthInterceptor.shouldSkipBearer('/lean-maturity-assessments'), isFalse);
      expect(AuthInterceptor.shouldSkipBearer('/diagnostic-studies'), isFalse);
    });

    test('skips refresh loop on auth endpoints', () {
      expect(AuthInterceptor.shouldSkipRefresh('/auth/login'), isTrue);
      expect(AuthInterceptor.shouldSkipRefresh('/auth/refresh'), isTrue);
      expect(AuthInterceptor.shouldSkipRefresh('/auth/logout'), isTrue);
      expect(AuthInterceptor.shouldSkipRefresh('/auth/me'), isFalse);
    });
  });

  group('AuthInterceptor single-flight refresh', () {
    test('refreshes once and retries original request', () async {
      final storage = _MemoryTokenStorage()
        ..access = 'old-access'
        ..refresh = 'refresh-1';

      var sessionExpired = false;

      final refreshAdapter = _ScriptedAdapter([
        (_) => _json({
              'success': true,
              'message': 'ok',
              'data': {'access_token': 'new-access', 'token_type': 'bearer'},
            }, 200),
      ]);

      final refreshDio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
        ..httpClientAdapter = refreshAdapter;

      final apiAdapter = _ScriptedAdapter([
        (_) => _json({'success': false, 'message': 'expired'}, 401),
        (options) {
          expect(options.headers['Authorization'], 'Bearer new-access');
          return _json({
            'success': true,
            'message': 'ok',
            'data': {
              '_id': 'u1',
              'name': 'Ada',
              'email': 'ada@example.com',
              'can_write_reports': true,
            },
          }, 200);
        },
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
      dio.httpClientAdapter = apiAdapter;
      dio.interceptors.add(
        AuthInterceptor(
          dio: dio,
          tokenStorage: storage,
          refreshDio: refreshDio,
          onSessionExpired: () => sessionExpired = true,
        ),
      );

      final response = await dio.get<dynamic>('/auth/me');
      expect(response.statusCode, 200);
      expect(storage.access, 'new-access');
      expect(storage.refresh, 'refresh-1');
      expect(sessionExpired, isFalse);
      expect(refreshAdapter.calls, 1);
      expect(apiAdapter.calls, 2);
    });

    test('clears session when refresh fails', () async {
      final storage = _MemoryTokenStorage()
        ..access = 'old-access'
        ..refresh = 'bad-refresh';

      var sessionExpired = false;

      final refreshAdapter = _ScriptedAdapter([
        (_) => _json({'success': false, 'message': 'invalid refresh'}, 401),
      ]);

      final refreshDio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
        ..httpClientAdapter = refreshAdapter;

      final apiAdapter = _ScriptedAdapter([
        (_) => _json({'success': false, 'message': 'expired'}, 401),
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
      dio.httpClientAdapter = apiAdapter;
      dio.interceptors.add(
        AuthInterceptor(
          dio: dio,
          tokenStorage: storage,
          refreshDio: refreshDio,
          onSessionExpired: () => sessionExpired = true,
        ),
      );

      await expectLater(
        () => dio.get<dynamic>('/auth/me'),
        throwsA(isA<DioException>()),
      );
      expect(storage.access, isNull);
      expect(storage.refresh, isNull);
      expect(sessionExpired, isTrue);
    });

    test('does not refresh on login 401', () async {
      final storage = _MemoryTokenStorage()
        ..access = 'old-access'
        ..refresh = 'refresh-1';

      var sessionExpired = false;

      final refreshAdapter = _ScriptedAdapter([]);
      final refreshDio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'))
        ..httpClientAdapter = refreshAdapter;

      final apiAdapter = _ScriptedAdapter([
        (options) {
          expect(options.headers.containsKey('Authorization'), isFalse);
          return _json({'success': false, 'message': 'Invalid credentials'}, 401);
        },
      ]);

      final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
      dio.httpClientAdapter = apiAdapter;
      dio.interceptors.add(
        AuthInterceptor(
          dio: dio,
          tokenStorage: storage,
          refreshDio: refreshDio,
          onSessionExpired: () => sessionExpired = true,
        ),
      );

      await expectLater(
        () => dio.post<dynamic>('/auth/login', data: {'email': 'a@b.com', 'password': 'x'}),
        throwsA(isA<DioException>()),
      );
      expect(refreshAdapter.calls, 0);
      expect(apiAdapter.calls, 1);
      expect(storage.access, 'old-access');
      expect(sessionExpired, isFalse);
    });
  });
}
