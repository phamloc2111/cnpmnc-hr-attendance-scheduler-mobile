import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/services.dart';
import 'package:mobile/app/workspace_screen.dart';
import 'package:mobile/features/auth/domain/auth.dart';
import 'package:mobile/features/schedule/presentation/schedule_screen.dart';
import 'auth_widget_test.dart' show FakeAuthRepository;
import 'schedule_widget_test.dart' show FakeScheduleRepository;

void main() {
  Future<void> start(WidgetTester tester, UserRole role) async {
    final auth = FakeAuthRepository(role: role);
    addTearDown(auth.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          workspaceProvider(role.home.substring(1)).overrideWith(
            (ref) async => {
              'title': 'Không gian làm việc',
              'description': 'Chào mừng',
            },
          ),
          scheduleRepositoryProvider.overrideWithValue(
            FakeScheduleRepository(),
          ),
          scheduleNowProvider.overrideWithValue(
            () => DateTime.utc(2026, 11, 5),
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
  }

  testWidgets('employee opens schedule through the drawer and returns home', (
    tester,
  ) async {
    await start(tester, UserRole.employee);
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lịch của tôi'));
    await tester.pumpAndSettle();
    expect(find.text('Ca đêm'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Xin chào, Nguyễn An.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final role in [UserRole.manager, UserRole.admin]) {
    testWidgets('${role.code} cannot open employee schedule directly', (
      tester,
    ) async {
      await start(tester, role);
      GoRouter.of(
        tester.element(find.text('Xin chào, Nguyễn An.')),
      ).go('/my-schedule');
      await tester.pumpAndSettle();
      expect(find.text('Không đủ quyền'), findsOneWidget);
      expect(find.text('Ca đêm'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
