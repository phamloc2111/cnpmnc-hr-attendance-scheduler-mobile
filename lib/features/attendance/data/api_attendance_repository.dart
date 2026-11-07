import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../domain/attendance.dart';

class ApiAttendanceRepository implements AttendanceRepository {
  ApiAttendanceRepository(this.client);
  final ApiClient client;

  @override
  Future<AttendancePage> list({
    int page = 0,
    AttendanceStatus? status,
    AttendanceType? checkType,
  }) async {
    try {
      final query = <String, Object?>{
        'page': page,
        'size': 20,
        if (status != null) 'status': status.code,
        if (checkType != null) 'checkType': checkType.code,
      };
      final response = await client.dio.get<Map<String, Object?>>(
        '/attendance-records',
        queryParameters: query,
      );
      final data = response.data!;
      final items = (data['items'] as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(
            (item) => AttendanceRecord(
              id: item['id'] as String,
              employeeId: item['employeeId'] as String,
              employeeName: item['employeeName'] as String,
              scheduleId: item['scheduleId'] as String?,
              workDate: item['workDate'] as String,
              shiftName: item['shiftName'] as String,
              checkType: AttendanceType.fromCode(item['checkType']),
              recordedAt: DateTime.parse(item['recordedAt'] as String),
              photoUrl: item['photoUrl'] as String,
              photoCapturedAt: item['photoCapturedAt'] is String
                  ? DateTime.parse(item['photoCapturedAt'] as String)
                  : null,
              photoLocation: item['photoLocation'] as String,
              deviceLocation: item['deviceLocation'] as String,
              deviceLatitude: (item['deviceLatitude'] as num?)?.toDouble(),
              deviceLongitude: (item['deviceLongitude'] as num?)?.toDouble(),
              deviceId: item['deviceId'] as String?,
              deviceName: item['deviceName'] as String?,
              mockLocation: item['mockLocation'] == true,
              fraudType: FraudType.fromCode(item['fraudType']),
              status: AttendanceStatus.fromCode(item['status']),
              verificationNote: item['verificationNote'] as String?,
            ),
          )
          .toList(growable: false);
      return AttendancePage(
        items,
        data['page'] as int,
        data['totalPages'] as int,
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      throw AttendanceFailure(
        data is Map<String, Object?> && data['message'] is String
            ? data['message'] as String
            : 'Không thể tải danh sách điểm danh. Vui lòng thử lại.',
      );
    } on FormatException {
      throw const AttendanceFailure('Dữ liệu điểm danh không hợp lệ.');
    } on TypeError {
      throw const AttendanceFailure('Dữ liệu điểm danh không hợp lệ.');
    }
  }

  @override
  Future<void> registerDevice({
    required String employeeId,
    required String deviceId,
    String? deviceName,
  }) async {
    try {
      await client.dio.put<Map<String, Object?>>(
        '/attendance-records/devices/$employeeId',
        data: <String, Object?>{
          'deviceId': deviceId,
          'deviceName': deviceName,
        },
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      throw AttendanceFailure(
        data is Map<String, Object?> && data['message'] is String
            ? data['message'] as String
            : 'Không thể đăng ký lại thiết bị.',
      );
    }
  }
}
