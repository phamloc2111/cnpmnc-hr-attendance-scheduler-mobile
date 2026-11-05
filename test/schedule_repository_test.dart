import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/features/schedule/data/api_schedule_repository.dart';
import 'package:mobile/features/schedule/domain/schedule.dart';
import 'auth_repository_test.dart' show MemoryTokenStore, TestAdapter, jsonBody;

final scheduleJson = <String, Object?>{
  'id': 'schedule-1',
  'workDate': '2026-11-05',
  'shiftName': 'Ca đêm',
  'startsAt': '2026-11-05T15:00:00Z',
  'endsAt': '2026-11-05T23:00:00Z',
  'breakMinutes': 30,
  'workingMinutes': 450,
};

void main() {
  late Dio dio;
  late ApiClient client;
  late ApiScheduleRepository repo;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api/v1'));
    client = ApiClient(MemoryTokenStore(), dio: dio);
    repo = ApiScheduleRepository(client);
  });
  tearDown(() => client.dispose());

  test(
    'repository sends date range and page and decodes UTC timestamps',
    () async {
      late RequestOptions sent;
      dio.httpClientAdapter = TestAdapter((request) {
        sent = request;
        return jsonBody({
          'items': [scheduleJson],
          'page': 1,
          'totalPages': 2,
        });
      });
      final result = await repo.list('2026-11-02', '2026-11-08', 1);
      expect(sent.path, '/work-schedules');
      expect(sent.queryParameters, {
        'from': '2026-11-02',
        'to': '2026-11-08',
        'page': 1,
        'size': 20,
      });
      expect(result.page, 1);
      expect(result.totalPages, 2);
      expect(result.items.single.startsAt, DateTime.utc(2026, 11, 5, 15));
      expect(result.items.single.workingMinutes, 450);
    },
  );
  test('repository preserves server errors', () async {
    dio.httpClientAdapter = TestAdapter(
      (_) => jsonBody({'message': 'Không đủ quyền'}, 403),
    );
    await expectLater(
      repo.list('2026-11-02', '2026-11-08', 0),
      throwsA(
        isA<ScheduleFailure>().having(
          (error) => error.message,
          'message',
          'Không đủ quyền',
        ),
      ),
    );
  });
  test('repository rejects malformed response', () async {
    dio.httpClientAdapter = TestAdapter(
      (_) => jsonBody({
        'items': [
          {'id': 4},
        ],
        'page': 0,
        'totalPages': 1,
      }),
    );
    await expectLater(
      repo.list('2026-11-02', '2026-11-08', 0),
      throwsA(isA<ScheduleFailure>()),
    );
  });
  test('UTC+7 conversion and Monday stay correct across month boundary', () {
    final date = vietnamTime(DateTime.utc(2026, 11, 1, 18));
    expect(workDateString(date), '2026-11-02');
    expect(workDateString(weekStart(date)), '2026-11-02');
    expect(workDateString(weekStart(DateTime.utc(2026, 11, 1))), '2026-10-26');
    expect(vietnamTime(DateTime.utc(2026, 11, 5, 23)).hour, 6);
  });
}
