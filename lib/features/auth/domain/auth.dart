enum UserRole {
  employee('EMPLOYEE', 'Nhân viên', '/employee'),
  manager('MANAGER', 'Quản lý', '/management'),
  admin('ADMIN', 'Quản trị', '/administration');

  const UserRole(this.code, this.label, this.home);
  final String code;
  final String label;
  final String home;

  static UserRole parse(String value) =>
      values.firstWhere((role) => role.code == value);
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });
  final String id;
  final String email;
  final String displayName;
  final UserRole role;
}

class AuthSession {
  const AuthSession(this.user, this.expiresAt);
  final AppUser user;
  final DateTime expiresAt;
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  Stream<void> get expired;
  Future<AuthSession?> restore();
  Future<AuthSession> login(String email, String password);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> logout();
  Future<void> clear();
}
