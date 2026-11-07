import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../domain/auth.dart';

class ApiAuthRepository implements AuthRepository {
  const ApiAuthRepository(this.client);
  final ApiClient client;
  @override
  Stream<void> get expired => client.expired;

  AppUser _user(Object? value) {
    final json = value as Map<String, Object?>;
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      role: UserRole.parse(json['role'] as String),
    );
  }

  AuthFailure _failure(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, Object?> && data['message'] is String) {
      return AuthFailure(data['message'] as String);
    }
    return const AuthFailure('Không thể kết nối máy chủ. Vui lòng thử lại.');
  }

  @override
  Future<AuthSession> login(String email, String password) async {
    try {
      final response = await client.dio.post<Object?>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
        options: Options(extra: {'anonymous': true}),
      );
      final data = response.data as Map<String, Object?>;
      final user = _user(data['user']);
      final expiry = DateTime.parse(data['expiresAt'] as String);
      final token = data['accessToken'] as String;
      await client.store.write(
        jsonEncode({
          'accessToken': token,
          'expiresAt': expiry.toUtc().toIso8601String(),
        }),
      );
      return AuthSession(user, expiry);
    } on DioException catch (error) {
      throw _failure(error);
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure(
        'Không thể lưu phiên đăng nhập an toàn. Vui lòng thử lại.',
      );
    }
  }

  @override
  Future<AuthSession?> restore() async {
    final stored = await client.store.read();
    if (stored == null) return null;
    DateTime expiry;
    try {
      final data = jsonDecode(stored) as Map<String, Object?>;
      expiry = DateTime.parse(data['expiresAt'] as String);
      if (data['accessToken'] is! String) throw const FormatException();
    } catch (_) {
      await clear();
      return null;
    }
    if (!expiry.isAfter(DateTime.now())) {
      await clear();
      return null;
    }
    try {
      final response = await client.dio.get<Object?>('/auth/me');
      return AuthSession(_user(response.data), expiry);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) return null;
      throw _failure(error);
    }
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      await client.dio.post<void>(
        '/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await client.dio.post<void>('/auth/logout');
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        throw const AuthFailure(
          'Đã xóa phiên trên thiết bị. Chưa thể xác nhận đăng xuất trên máy chủ; phiên sẽ tự hết hạn.',
        );
      }
    } finally {
      await clear();
    }
  }

  @override
  Future<void> clear() => client.store.clear();
}
