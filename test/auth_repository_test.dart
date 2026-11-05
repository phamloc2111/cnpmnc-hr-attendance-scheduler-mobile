import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/token_store.dart';
import 'package:mobile/features/auth/data/api_auth_repository.dart';
import 'package:mobile/features/auth/domain/auth.dart';

class MemoryTokenStore implements TokenStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class TestAdapter implements HttpClientAdapter {
  TestAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(Object? data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  late MemoryTokenStore store;
  late Dio dio;
  late ApiClient client;
  late ApiAuthRepository repo;
  final user = {
    'id': '1',
    'email': 'user@example.com',
    'displayName': 'An',
    'role': 'EMPLOYEE',
  };

  setUp(() {
    store = MemoryTokenStore();
    dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api/v1'));
    client = ApiClient(store, dio: dio);
    repo = ApiAuthRepository(client);
  });
  tearDown(() => client.dispose());

  test(
    'login stores JWT securely and restore revalidates user on server',
    () async {
      final requests = <RequestOptions>[];
      dio.httpClientAdapter = TestAdapter((request) {
        requests.add(request);
        return request.path == '/auth/login'
            ? jsonBody({
                'accessToken': 'jwt',
                'expiresAt': DateTime.now()
                    .add(const Duration(hours: 1))
                    .toUtc()
                    .toIso8601String(),
                'user': user,
              })
            : jsonBody(user);
      });
      final session = await repo.login('user@example.com', 'password');
      expect(session.user.role, UserRole.employee);
      expect(store.value, contains('jwt'));
      final restored = await repo.restore();
      expect(restored!.user.email, 'user@example.com');
      expect(requests.last.headers['Authorization'], 'Bearer jwt');
      expect(requests.first.headers.containsKey('Authorization'), isFalse);
    },
  );

  test('wrong credentials do not store a token or emit expiry', () async {
    var expired = false;
    final subscription = repo.expired.listen((_) => expired = true);
    addTearDown(subscription.cancel);
    dio.httpClientAdapter = TestAdapter(
      (_) => jsonBody({'message': 'Email hoặc mật khẩu không đúng'}, 401),
    );
    await expectLater(
      repo.login('user@example.com', 'wrong'),
      throwsA(
        isA<AuthFailure>().having(
          (error) => error.message,
          'message',
          'Email hoặc mật khẩu không đúng',
        ),
      ),
    );
    expect(store.value, isNull);
    expect(expired, isFalse);
  });

  test('locked account preserves server message', () async {
    dio.httpClientAdapter = TestAdapter(
      (_) => jsonBody({'message': 'Tài khoản đã bị khóa'}, 403),
    );
    await expectLater(
      repo.login('user@example.com', 'password'),
      throwsA(
        isA<AuthFailure>().having(
          (error) => error.message,
          'message',
          'Tài khoản đã bị khóa',
        ),
      ),
    );
  });

  test('logout clears token even if server is unreachable', () async {
    await store.write(
      jsonEncode({
        'accessToken': 'jwt',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      }),
    );
    dio.httpClientAdapter = TestAdapter(
      (_) => jsonBody({'message': 'Unavailable'}, 503),
    );
    await expectLater(repo.logout(), throwsA(isA<AuthFailure>()));
    expect(store.value, isNull);
  });

  test('401 restoring a revoked token clears storage and signs out', () async {
    await store.write(
      jsonEncode({
        'accessToken': 'jwt',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      }),
    );
    dio.httpClientAdapter = TestAdapter(
      (_) => jsonBody({'message': 'Expired'}, 401),
    );
    expect(await repo.restore(), isNull);
    expect(store.value, isNull);
  });

  test('network failure preserves stored session for retry', () async {
    await store.write(
      jsonEncode({
        'accessToken': 'jwt',
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toUtc()
            .toIso8601String(),
      }),
    );
    dio.httpClientAdapter = TestAdapter(
      (_) => throw DioException(requestOptions: RequestOptions()),
    );
    await expectLater(repo.restore(), throwsA(isA<AuthFailure>()));
    expect(store.value, isNotNull);
  });

  test(
    'expired and damaged sessions are cleared without network call',
    () async {
      dio.httpClientAdapter = TestAdapter(
        (_) => throw StateError('Should not request'),
      );
      await store.write(
        jsonEncode({
          'accessToken': 'jwt',
          'expiresAt': DateTime.now()
              .subtract(const Duration(hours: 1))
              .toUtc()
              .toIso8601String(),
        }),
      );
      expect(await repo.restore(), isNull);
      expect(store.value, isNull);
      await store.write('{invalid');
      expect(await repo.restore(), isNull);
      expect(store.value, isNull);
    },
  );
}
