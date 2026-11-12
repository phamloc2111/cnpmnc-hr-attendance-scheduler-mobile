class PriorityInfo {
  const PriorityInfo({
    required this.score,
    required this.weekStart,
    this.reason,
  });
  final int score;
  final String weekStart;
  final String? reason;
}

class WorkSchedule {
  const WorkSchedule({
    required this.id,
    required this.workDate,
    required this.shiftName,
    required this.startsAt,
    required this.endsAt,
    required this.breakMinutes,
    required this.workingMinutes,
    this.published = false,
    this.requiredPosition,
  });
  final String id;
  final String workDate;
  final String shiftName;
  final DateTime startsAt;
  final DateTime endsAt;
  final int breakMinutes;
  final int workingMinutes;
  final bool published;
  final String? requiredPosition;
}

class SchedulePage {
  const SchedulePage(this.items, this.page, this.totalPages, {this.priority});
  final List<WorkSchedule> items;
  final int page;
  final int totalPages;
  final PriorityInfo? priority;
}

class ScheduleFailure implements Exception {
  const ScheduleFailure(this.message);
  final String message;
}

abstract interface class ScheduleRepository {
  Future<SchedulePage> list(String from, String to, int page);
}

// Vietnam currently uses UTC+7 throughout the year. Avoid device timezone.
DateTime vietnamTime(DateTime value) =>
    value.toUtc().add(const Duration(hours: 7));
String workDateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
DateTime weekStart(DateTime date) => DateTime.utc(
  date.year,
  date.month,
  date.day,
).subtract(Duration(days: date.weekday - 1));
