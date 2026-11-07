import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/services.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/features/attendance/data/api_attendance_repository.dart';
import 'package:mobile/features/attendance/domain/attendance.dart';
import 'package:mobile/features/attendance/presentation/attendance_screen.dart';
import 'auth_repository_test.dart' show MemoryTokenStore, TestAdapter, jsonBody;
import 'auth_widget_test.dart' show FakeAuthRepository;

final attendanceJson = <String, Object?>{
  'id': 'att-1',
  'employeeId': 'emp-1',
  'employeeName': 'Nguyễn An',
  'scheduleId': 'sch-1',
  'workDate': '2026-11-07',
  'shiftName': 'Ca sáng',
  'checkType': 'CHECK_IN',
  'recordedAt': '2026-11-07T00:58:00Z',
  'photoUrl': 'https://example.com/timemark/checkin-an.jpg',
  'photoCapturedAt': '2026-11-07T00:57:50Z',
  'photoLocation': '268 Lý Thường Kiệt, Quận 10',
  'deviceLocation': '268 Lý Thường Kiệt, Phường 14, Quận 10',
  'deviceLatitude': 10.7726,
  'deviceLongitude': 106.6579,
  'status': 'ON_TIME',
  'verificationNote': 'Khớp vị trí và thời gian trên ảnh Timemark',
};

class FakeAttendanceRepository implements AttendanceRepository {
  @override
  Future<AttendancePage> list({
    int page = 0,
    AttendanceStatus? status,
    AttendanceType? checkType,
  }) async {
    return AttendancePage(
      [
        AttendanceRecord(
          id: 'att-1',
          employeeId: 'emp-1',
          employeeName: 'Nguyễn An',
          workDate: '2026-11-07',
          shiftName: 'Ca sáng',
          checkType: AttendanceType.checkIn,
          recordedAt: DateTime.utc(2026, 11, 7, 0, 58),
          photoUrl: 'https://example.com/timemark/checkin-an.jpg',
          photoLocation: '268 Lý Thường Kiệt, Quận 10',
          deviceLocation: '268 Lý Thường Kiệt, Phường 14, Quận 10',
          deviceLatitude: 10.7726,
          deviceLongitude: 106.6579,
          status: AttendanceStatus.onTime,
          verificationNote: 'Khớp vị trí và thời gian trên ảnh Timemark',
        ),
      ],
      page,
      1,
    );
  }
}

void main() {
  test('ApiAttendanceRepository decodes attendance records and sends filters', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api/v1'));
    final client = ApiClient(MemoryTokenStore(), dio: dio);
    addTearDown(client.dispose);
    final repo = ApiAttendanceRepository(client);
    late RequestOptions sent;
    dio.httpClientAdapter = TestAdapter((request) {
      sent = request;
      return jsonBody({
        'items': [attendanceJson],
        'page': 0,
        'totalPages': 1,
      });
    });

    final result = await repo.list(
      page: 0,
      status: AttendanceStatus.onTime,
      checkType: AttendanceType.checkIn,
    );
    expect(sent.path, '/attendance-records');
    expect(sent.queryParameters, {
      'page': 0,
      'size': 20,
      'status': 'ON_TIME',
      'checkType': 'CHECK_IN',
    });
    expect(result.items.single.employeeName, 'Nguyễn An');
    expect(result.items.single.photoLocation, '268 Lý Thường Kiệt, Quận 10');
    expect(result.items.single.status, AttendanceStatus.onTime);
  });

  testWidgets('AttendanceScreen shows photo, photo location, device location and status', (
    tester,
  ) async {
    final auth = FakeAuthRepository();
    addTearDown(auth.events.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          attendanceRepositoryProvider.overrideWithValue(
            FakeAttendanceRepository(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi', 'VN'),
          supportedLocales: [Locale('vi', 'VN')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: AttendanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(
      find.text('Ảnh Timemark: https://example.com/timemark/checkin-an.jpg'),
      findsOneWidget,
    );
    expect(
      find.text('Vị trí trên ảnh: 268 Lý Thường Kiệt, Quận 10'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Định vị điện thoại: 268 Lý Thường Kiệt, Phường 14, Quận 10 (10.7726, 106.6579)',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Ghi chú: Khớp vị trí và thời gian trên ảnh Timemark'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
