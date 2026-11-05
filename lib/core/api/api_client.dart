import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'token_store.dart';

class ApiClient {
  ApiClient(this.store, {Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://10.0.2.2:8080/api/v1',
              ),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ) {
    this.dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            if (options.extra['anonymous'] != true) {
              final value = await store.read();
              if (value != null) {
                final stored = jsonDecode(value) as Map<String, Object?>;
                final expiry = DateTime.parse(stored['expiresAt'] as String);
                if (expiry.isAfter(DateTime.now())) {
                  options.headers['Authorization'] =
                      'Bearer ${stored['accessToken']}';
                } else {
                  await store.clear();
                  _expired.add(null);
                }
              }
            }
            handler.next(options);
          } catch (_) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: 'Không thể đọc phiên đăng nhập an toàn.',
              ),
            );
          }
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['anonymous'] != true) {
            try {
              await store.clear();
            } catch (_) {
              // The server has rejected this token. Complete the HTTP error
              // even if the device's keychain is temporarily unavailable.
            } finally {
              if (!_expired.isClosed) _expired.add(null);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  final TokenStore store;
  final _expired = StreamController<void>.broadcast();
  Stream<void> get expired => _expired.stream;

  void dispose() {
    dio.close(force: true);
    unawaited(_expired.close());
  }
}
