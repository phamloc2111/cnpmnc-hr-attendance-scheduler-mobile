import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../domain/schedule.dart';

class ApiScheduleRepository implements ScheduleRepository {
  ApiScheduleRepository(this.client);
  final ApiClient client;

  @override
  Future<SchedulePage> list(String from, String to, int page) async {
    try {
      final response = await client.dio.get<Map<String, Object?>>(
        '/work-schedules',
        queryParameters: {'from': from, 'to': to, 'page': page, 'size': 20},
      );
      final data = response.data!;
      final items = (data['items'] as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(
            (item) => WorkSchedule(
              id: item['id'] as String,
              workDate: item['workDate'] as String,
              shiftName: item['shiftName'] as String,
              startsAt: DateTime.parse(item['startsAt'] as String),
              endsAt: DateTime.parse(item['endsAt'] as String),
              breakMinutes: item['breakMinutes'] as int,
              workingMinutes: item['workingMinutes'] as int,
            ),
          )
          .toList(growable: false);
      return SchedulePage(
        items,
        data['page'] as int,
        data['totalPages'] as int,
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      throw ScheduleFailure(
        data is Map<String, Object?> && data['message'] is String
            ? data['message'] as String
            : 'Không thể tải lịch làm việc. Vui lòng thử lại.',
      );
    } on FormatException {
      throw const ScheduleFailure('Dữ liệu lịch không hợp lệ.');
    } on TypeError {
      throw const ScheduleFailure('Dữ liệu lịch không hợp lệ.');
    }
  }
}
