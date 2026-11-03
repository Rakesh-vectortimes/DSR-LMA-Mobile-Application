import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';
import 'dual_stack_connect.dart';

/// Callback set by [authControllerProvider] so Dio can force logout on refresh failure.
final sessionExpiredHandlerProvider = Provider<SessionExpiredHandler>((ref) {
  return SessionExpiredHandler();
});

class SessionExpiredHandler {
  void Function()? _handler;

  void bind(void Function() handler) => _handler = handler;

  void call() => _handler?.call();
}

/// Dio without auth interceptors — used only for token refresh to avoid loops.
final refreshDioProvider = Provider<Dio>((ref) {
  final config = AppConfig.instance;
  return _apiDio(config.apiV1BaseUrl);
});

/// Authenticated Dio client with Bearer + single-flight 401 refresh.
final dioProvider = Provider<Dio>((ref) {
  final config = AppConfig.instance;
  final tokenStorage = ref.watch(tokenStorageProvider);
  final refreshDio = ref.watch(refreshDioProvider);
  final sessionHandler = ref.watch(sessionExpiredHandlerProvider);

  final dio = _apiDio(config.apiV1BaseUrl);

  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      tokenStorage: tokenStorage,
      refreshDio: refreshDio,
      onSessionExpired: () => sessionHandler.call(),
    ),
  );

  return dio;
});

Dio _apiDio(String baseUrl) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      return HttpClient()
        ..idleTimeout = const Duration(seconds: 3)
        ..connectionFactory = dualStackConnectionFactory;
    },
  );
  return dio;
}
