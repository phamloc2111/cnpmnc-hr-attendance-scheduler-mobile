import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/services.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/api_schedule_repository.dart';
import '../domain/schedule.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ApiScheduleRepository(ref.watch(apiClientProvider)),
);
final scheduleNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
typedef ScheduleQuery = ({String from, int page});
final schedulePageProvider = FutureProvider.autoDispose
    .family<SchedulePage, ScheduleQuery>((ref, query) {
      ref.watch(
        authControllerProvider.select((state) => state.session?.user.id),
      );
      final from = DateTime.parse('${query.from}T00:00:00Z');
      return ref
          .watch(scheduleRepositoryProvider)
          .list(
            query.from,
            workDateString(from.add(const Duration(days: 6))),
            query.page,
          );
    }, retry: (retryCount, error) => null);

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});
  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  late DateTime _week;
  int _page = 0;
  @override
  void initState() {
    super.initState();
    _week = weekStart(vietnamTime(ref.read(scheduleNowProvider)()));
  }

  void changeWeek(DateTime date) {
    setState(() {
      _week = weekStart(date);
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = (from: workDateString(_week), page: _page);
    final result = ref.watch(schedulePageProvider(query));
    final localizations = MaterialLocalizations.of(context);
    String dateLabel(DateTime date) => localizations.formatShortDate(date);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch của tôi'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: () => ref.invalidate(schedulePageProvider(query)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Tuần trước',
                  onPressed: () =>
                      changeWeek(_week.subtract(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: _week,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null && mounted) changeWeek(selected);
                    },
                    child: Text(
                      '${dateLabel(_week)} – ${dateLabel(_week.add(const Duration(days: 6)))}',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tuần sau',
                  onPressed: () =>
                      changeWeek(_week.add(const Duration(days: 7))),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                changeWeek(vietnamTime(ref.read(scheduleNowProvider)())),
            child: const Text('Tuần này'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Giờ Việt Nam (UTC+7) · Ngày làm việc là ngày bắt đầu ca.',
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: result.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        error is ScheduleFailure
                            ? error.message
                            : 'Không thể tải lịch làm việc.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(schedulePageProvider(query)),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) => Column(
                children: [
                  // Thẻ điểm ưu tiên tuần của nhân viên (US28)
                  if (data.priority != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF4E8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFC7DEC4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.stars, color: Color(0xFF245D49), size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Điểm ưu tiên tuần này: ${data.priority!.score}/100',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF182B20),
                                    ),
                                  ),
                                  Text(
                                    data.priority!.reason ?? 'Điểm xếp ca dựa trên chuyên cần và dữ liệu chấm công',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF687A70)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: data.items.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Chưa có lịch được công bố trong tuần này. Lịch sẽ xuất hiện khi quản lý công bố phân ca cho bạn.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(schedulePageProvider(query));
                              await ref.read(
                                schedulePageProvider(query).future,
                              );
                            },
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: data.items.length,
                              itemBuilder: (_, index) =>
                                  _ScheduleCard(schedule: data.items[index]),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _page == 0
                              ? null
                              : () => setState(() => _page--),
                          child: const Text('Trang trước'),
                        ),
                        Text(
                          'Trang ${data.page + 1} / ${data.totalPages == 0 ? 1 : data.totalPages}',
                        ),
                        TextButton(
                          onPressed: _page + 1 >= data.totalPages
                              ? null
                              : () => setState(() => _page++),
                          child: const Text('Trang sau'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule});
  final WorkSchedule schedule;
  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final start = vietnamTime(schedule.startsAt);
    final end = vietnamTime(schedule.endsAt);
    String timeLabel(DateTime date) => localizations.formatTimeOfDay(
      TimeOfDay(hour: date.hour, minute: date.minute),
      alwaysUse24HourFormat: true,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localizations.formatFullDate(
                    DateTime.parse('${schedule.workDate}T00:00:00Z'),
                  ),
                ),
                if (schedule.requiredPosition != null && schedule.requiredPosition!.isNotEmpty)
                  Chip(
                    label: Text(
                      schedule.requiredPosition!,
                      style: const TextStyle(fontSize: 11),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              schedule.shiftName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${timeLabel(start)} → ${timeLabel(end)}'
              '${workDateString(start) != workDateString(end) ? ' (ngày hôm sau)' : ''}',
            ),
            Text('Kết thúc: ${localizations.formatShortDate(end)}'),
            Text(
              'Nghỉ ${schedule.breakMinutes} phút · Làm ${schedule.workingMinutes} phút',
            ),
          ],
        ),
      ),
    );
  }
}
