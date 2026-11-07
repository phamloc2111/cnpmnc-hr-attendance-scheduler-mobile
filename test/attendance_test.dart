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
  'deviceId': 'device-iphone-14',
  'deviceName': 'iPhone 14 của An',
  'mockLocation': true,
  'fraudType': 'FAKE_LOCATION',
  'status': 'REJECTED',
  'verificationNote': 'Cảnh báo gian lận: Phát hiện dấu hiệu định vị giả (Mock GPS) — đã báo cho quản lý',
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
          deviceId: 'device-iphone-14',
          deviceName: 'iPhone 14 của An',
          mockLocation: true,
          fraudType: FraudType.fakeLocation,
          status: AttendanceStatus.rejected,
          verificationNote: 'Khớp vị trí và thời gian trên ảnh Timemark',
        ),
      ],
      page,
      1,
    );
  }

  @override
  Future<void> registerDevice({
    required String employeeId,
    required String deviceId,
    String? deviceName,
  }) async {}
}

void main() {
  test('ApiAttendanceRepository decodes attendance records, fraudType and registers device', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api/v1'));
    final client = ApiClient(MemoryTokenStore(), dio: dio);
    addTearDown(client.dispose);
    final repo = ApiAttendanceRepository(client);
    late RequestOptions sent;
    dio.httpClientAdapter = TestAdapter((request) {
      sent = request;
      if (request.method == 'PUT') {
        return jsonBody({
          'employeeId': 'emp-1',
          'employeeName': 'Nguyễn An',
          'deviceId': 'device-s24',
          'deviceName': 'Samsung S24',
          'registeredAt': '2026-11-07T01:00:00Z',
        });
      }
      return jsonBody({
        'items': [attendanceJson],
        'page': 0,
        'totalPages': 1,
      });
    });

    final result = await repo.list(
      page: 0,
      status: AttendanceStatus.rejected,
      checkType: AttendanceType.checkIn,
    );
    expect(sent.path, '/attendance-records');
    expect(result.items.single.employeeName, 'Nguyễn An');
    expect(result.items.single.fraudType, FraudType.fakeLocation);
    expect(result.items.single.deviceId, 'device-iphone-14');

    await repo.registerDevice(
      employeeId: 'emp-1',
      deviceId: 'device-s24',
      deviceName: 'Samsung S24',
    );
    expect(sent.path, '/attendance-records/devices/emp-1');
  });

  testWidgets('AttendanceScreen shows photo, location, device, fraud alert and privacy notice', (
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
    expect(find.text('Cảnh báo: Định vị giả'), findsOneWidget);
    expect(find.text('Thiết bị: iPhone 14 của An'), findsOneWidget);
    expect(
      find.textContaining('Chỉ lấy vị trí tại thời điểm chấm công, không theo dõi liên tục.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
