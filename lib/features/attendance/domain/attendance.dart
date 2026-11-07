enum AttendanceType {
  checkIn('CHECK_IN', 'Vào ca'),
  checkOut('CHECK_OUT', 'Ra ca');

  const AttendanceType(this.code, this.label);
  final String code;
  final String label;

  static AttendanceType fromCode(Object? code) => values.firstWhere(
    (item) => item.code == code,
    orElse: () => throw const FormatException('Invalid attendance check type'),
  );
}

enum AttendanceStatus {
  onTime('ON_TIME', 'Đúng giờ'),
  late('LATE', 'Đi trễ'),
  earlyLeave('EARLY_LEAVE', 'Về sớm'),
  absent('ABSENT', 'Vắng'),
  rejected('REJECTED', 'Không hợp lệ');

  const AttendanceStatus(this.code, this.label);
  final String code;
  final String label;

  static AttendanceStatus fromCode(Object? code) => values.firstWhere(
    (item) => item.code == code,
    orElse: () => throw const FormatException('Invalid attendance status'),
  );
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.workDate,
    required this.shiftName,
    required this.checkType,
    required this.recordedAt,
    required this.photoUrl,
    required this.photoLocation,
    required this.deviceLocation,
    required this.status,
    this.scheduleId,
    this.photoCapturedAt,
    this.deviceLatitude,
    this.deviceLongitude,
    this.verificationNote,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final String? scheduleId;
  final String workDate;
  final String shiftName;
  final AttendanceType checkType;
  final DateTime recordedAt;
  final String photoUrl;
  final DateTime? photoCapturedAt;
  final String photoLocation;
  final String deviceLocation;
  final double? deviceLatitude;
  final double? deviceLongitude;
  final AttendanceStatus status;
  final String? verificationNote;
}

class AttendancePage {
  const AttendancePage(this.items, this.page, this.totalPages);
  final List<AttendanceRecord> items;
  final int page;
  final int totalPages;
}

class AttendanceFailure implements Exception {
  const AttendanceFailure(this.message);
  final String message;
}

abstract interface class AttendanceRepository {
  Future<AttendancePage> list({
    int page = 0,
    AttendanceStatus? status,
    AttendanceType? checkType,
  });
}
