import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/services.dart';
import 'package:mobile/features/schedule/domain/schedule.dart';
import 'package:mobile/features/schedule/presentation/schedule_screen.dart';
import 'auth_widget_test.dart' show FakeAuthRepository;

class FakeScheduleRepository implements ScheduleRepository {
  final requests = <({String from, String to, int page})>[];
  bool fail = false;
  bool empty = false;
  Completer<SchedulePage>? pending;
  @override
  Future<SchedulePage> list(String from, String to, int page) async {
    requests.add((from: from, to: to, page: page));
    if (pending != null) return pending!.future;
    if (fail) throw const ScheduleFailure('Mất kết nối');
    return SchedulePage(
      empty
          ? []
          : [
              WorkSchedule(
                id: 'schedule-1',
                workDate: '2026-11-05',
                shiftName: 'Ca đêm',
                startsAt: DateTime.utc(2026, 11, 5, 15),
                endsAt: DateTime.utc(2026, 11, 5, 23),
                breakMinutes: 30,
                workingMinutes: 450,
              ),
            ],
      page,
      empty ? 0 : 2,
    );
  }
}

void main() {
  Future<void> mount(WidgetTester tester, FakeScheduleRepository repo) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          scheduleRepositoryProvider.overrideWithValue(repo),
          scheduleNowProvider.overrideWithValue(
            () => DateTime.utc(2026, 11, 5, 3),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi', 'VN'),
          supportedLocales: [Locale('vi', 'VN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ScheduleScreen(),
        ),
      ),
    );
  }

  testWidgets('shows loading while schedule request is pending', (
    tester,
  ) async {
    final repo = FakeScheduleRepository()..pending = Completer<SchedulePage>();
    await mount(tester, repo);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.pending!.complete(const SchedulePage([], 0, 0));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có lịch trong tuần này'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('shows overnight shift in Vietnam time and net minutes', (
    tester,
  ) async {
    final repo = FakeScheduleRepository();
    await mount(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Ca đêm'), findsOneWidget);
    expect(find.text('22:00 → 06:00 (ngày hôm sau)'), findsOneWidget);
    expect(find.text('Nghỉ 30 phút · Làm 450 phút'), findsOneWidget);
    expect(repo.requests.single, (
      from: '2026-11-02',
      to: '2026-11-08',
      page: 0,
    ));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('shows empty schedule', (tester) async {
    await mount(tester, FakeScheduleRepository()..empty = true);
    await tester.pumpAndSettle();
    expect(find.textContaining('Chưa có lịch trong tuần này'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Trang sau'))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('retries a failed schedule request', (tester) async {
    final repo = FakeScheduleRepository()..fail = true;
    await mount(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Ca đêm'), findsOneWidget);
    expect(repo.requests, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('week navigation reloads date range and resets pagination', (
    tester,
  ) async {
    final repo = FakeScheduleRepository();
    await mount(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trang sau'));
    await tester.pumpAndSettle();
    expect(repo.requests.last.page, 1);
    await tester.tap(find.byTooltip('Tuần sau'));
    await tester.pumpAndSettle();
    expect(repo.requests.last, (from: '2026-11-09', to: '2026-11-15', page: 0));
    await tester.tap(find.text('Tuần này'));
    await tester.pumpAndSettle();
    expect(repo.requests.last.from, '2026-11-02');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
