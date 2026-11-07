import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/services.dart';
import '../domain/auth.dart';

class AuthState {
  const AuthState({
    this.session,
    this.loading = false,
    this.restoring = false,
    this.restoreFailed = false,
    this.error,
  });
  final AuthSession? session;
  final bool loading;
  final bool restoring;
  final bool restoreFailed;
  final String? error;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  Timer? _expiry;
  bool _disposed = false;

  @override
  AuthState build() {
    final repo = ref.watch(authRepositoryProvider);
    final subscription = repo.expired.listen((_) {
      _expiry?.cancel();
      if (!_disposed) {
        state = const AuthState(
          error: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }
    });
    ref.onDispose(() {
      _disposed = true;
      _expiry?.cancel();
      unawaited(subscription.cancel());
    });
    return const AuthState(restoring: true);
  }

  void _accept(AuthSession? session) {
    if (_disposed) return;
    _expiry?.cancel();
    if (session != null) {
      _expiry = Timer(session.expiresAt.difference(DateTime.now()), () {
        unawaited(clearSession());
      });
    }
    state = AuthState(session: session);
  }

  Future<void> restore() async {
    state = const AuthState(restoring: true);
    try {
      _accept(await ref.read(authRepositoryProvider).restore());
    } catch (_) {
      if (!_disposed) {
        state = const AuthState(
          restoreFailed: true,
          error:
              'Không thể xác minh phiên đăng nhập. Kiểm tra kết nối và thử lại.',
        );
      }
    }
  }

  Future<void> login(String email, String password) async {
    if (state.loading) return;
    state = const AuthState(loading: true);
    try {
      _accept(await ref.read(authRepositoryProvider).login(email, password));
    } on AuthFailure catch (error) {
      if (!_disposed) state = AuthState(error: error.message);
    } catch (_) {
      if (!_disposed) {
        state = const AuthState(
          error: 'Đăng nhập không thành công. Vui lòng thử lại.',
        );
      }
    }
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) => ref
      .read(authRepositoryProvider)
      .changePassword(currentPassword, newPassword);

  Future<void> logout() async {
    if (state.loading) return;
    state = AuthState(session: state.session, loading: true);
    String? notice;
    var storageFailure = false;
    try {
      await ref.read(authRepositoryProvider).logout();
    } on AuthFailure catch (error) {
      notice = error.message;
    } catch (_) {
      storageFailure = true;
      notice = 'Không thể đăng xuất an toàn. Vui lòng thử lại.';
    } finally {
      _expiry?.cancel();
      if (!_disposed) {
        state = AuthState(error: notice, restoreFailed: storageFailure);
      }
    }
  }

  Future<void> clearSession() async {
    try {
      await ref.read(authRepositoryProvider).clear();
      _accept(null);
    } catch (_) {
      if (!_disposed) {
        state = const AuthState(
          restoreFailed: true,
          error: 'Không thể xóa phiên đăng nhập an toàn. Vui lòng thử lại.',
        );
      }
    }
  }
}
