import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/services.dart';
import 'package:mobile/app/workspace_screen.dart';
import 'package:mobile/features/auth/domain/auth.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.role = UserRole.employee,
    this.failLogin = false,
    this.restoreFails = false,
    this.currentPassword = 'password-123',
  });
  final UserRole role;
  final bool failLogin;
  bool restoreFails;
  String currentPassword;
  String? changedTo;
  bool loggedOut = false;
  final events = StreamController<void>.broadcast();
  @override
  Stream<void> get expired => events.stream;
  @override
  Future<AuthSession?> restore() async {
    if (restoreFails) throw const AuthFailure('offline');
    return null;
  }

  @override
  Future<AuthSession> login(String email, String password) async {
    if (failLogin) throw const AuthFailure('Email hoặc mật khẩu không đúng');
    return AuthSession(
      AppUser(id: '1', email: email, displayName: 'Nguyễn An', role: role),
      DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (currentPassword != this.currentPassword) {
      throw const AuthFailure('Mật khẩu cũ không đúng');
    }
    this.currentPassword = newPassword;
    changedTo = newPassword;
  }

  @override
  Future<void> logout() async {
    loggedOut = true;
  }

  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('SS-13 direct admin route is denied to an employee', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    addTearDown(repo.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          workspaceProvider('employee').overrideWith(
            (ref) async => {
              'title': 'Không gian làm việc',
              'description': 'Chào mừng bạn',
            },
          ),
        ],
        child: const ShiftSyncApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu'),
      'password',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
    GoRouter.of(
      tester.element(find.text('Xin chào, Nguyễn An.')),
    ).go('/administration');
    await tester.pumpAndSettle();
    expect(find.text('Không đủ quyền'), findsOneWidget);
    await tester.tap(find.text('Về trang của tôi'));
    await tester.pumpAndSettle();
    expect(find.text('Xin chào, Nguyễn An.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  Future<void> start(WidgetTester tester, FakeAuthRepository repo) async {
    addTearDown(repo.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          for (final endpoint in ['employee', 'management', 'administration'])
            workspaceProvider(endpoint).overrideWith(
              (ref) async => {
                'title': 'Không gian làm việc',
                'description': 'Chào mừng bạn',
              },
            ),
        ],
        child: const ShiftSyncApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> login(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'employee@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu'),
      'password-123',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
  }

  testWidgets('SS-12 login, logout and prevent returning to protected screen', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await start(tester, repo);
    await login(tester);
    expect(find.text('Xin chào, Nguyễn An.'), findsOneWidget);
    await tester.tap(find.byTooltip('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(repo.loggedOut, isTrue);
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    expect(find.text('Xin chào, Nguyễn An.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('SS-12 wrong password shows safe error and allows retry', (
    tester,
  ) async {
    await start(tester, FakeAuthRepository(failLogin: true));
    await login(tester);
    expect(find.text('Email hoặc mật khẩu không đúng'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('SS-12 restore network failure supports retry', (tester) async {
    final repo = FakeAuthRepository(restoreFails: true);
    await start(tester, repo);
    expect(find.text('Thử lại'), findsOneWidget);
    repo.restoreFails = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final role in UserRole.values) {
    testWidgets('SS-13 menu matches ${role.code}', (tester) async {
      await start(tester, FakeAuthRepository(role: role));
      await login(tester);
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
      expect(
        find.text('Tài khoản'),
        role == UserRole.admin ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Cài đặt'),
        role == UserRole.admin ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Lịch của tôi'),
        role == UserRole.employee ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Bảng công'),
        role != UserRole.employee ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('SS-12 expired session returns to login', (tester) async {
    final repo = FakeAuthRepository();
    await start(tester, repo);
    await login(tester);
    repo.events.add(null);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Đăng nhập'), findsOneWidget);
    expect(
      find.text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'SS-14 change password succeeds with valid current password and 8+ char new password',
    (tester) async {
      final repo = FakeAuthRepository(currentPassword: 'password-123');
      await start(tester, repo);
      await login(tester);
      await tester.tap(find.byTooltip('Đổi mật khẩu'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu cũ'),
        'password-123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu mới'),
        'NewPass8',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(repo.changedTo, 'NewPass8');
      expect(find.text('Đổi mật khẩu thành công.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'SS-14 change password shows error and does not change when current password is wrong',
    (tester) async {
      final repo = FakeAuthRepository(currentPassword: 'password-123');
      await start(tester, repo);
      await login(tester);
      await tester.tap(find.byTooltip('Đổi mật khẩu'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu cũ'),
        'wrong-old',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mật khẩu mới'),
        'NewPass8',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(repo.changedTo, isNull);
      expect(find.text('Mật khẩu cũ không đúng'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
