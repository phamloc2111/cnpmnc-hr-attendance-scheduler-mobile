import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/services.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../schedule/domain/schedule.dart' show vietnamTime;
import '../data/api_attendance_repository.dart';
import '../domain/attendance.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => ApiAttendanceRepository(ref.watch(apiClientProvider)),
);

typedef AttendanceQuery = ({
  int page,
  AttendanceStatus? status,
  AttendanceType? checkType,
});

final attendancePageProvider = FutureProvider.autoDispose
    .family<AttendancePage, AttendanceQuery>((ref, query) {
      ref.watch(
        authControllerProvider.select((state) => state.session?.user.id),
      );
      return ref.watch(attendanceRepositoryProvider).list(
        page: query.page,
        status: query.status,
        checkType: query.checkType,
      );
    }, retry: (retryCount, error) => null);

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});
  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  int _page = 0;
  AttendanceStatus? _status;
  AttendanceType? _checkType;

  @override
  Widget build(BuildContext context) {
    final query = (page: _page, status: _status, checkType: _checkType);
    final result = ref.watch(attendancePageProvider(query));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kết quả điểm danh'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: () => ref.invalidate(attendancePageProvider(query)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<AttendanceStatus?>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Kết quả',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tất cả kết quả'),
                      ),
                      for (final status in AttendanceStatus.values)
                        DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _status = value;
                      _page = 0;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AttendanceType?>(
                    initialValue: _checkType,
                    decoration: const InputDecoration(
                      labelText: 'Loại lượt',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Tất cả loại lượt'),
                      ),
                      for (final type in AttendanceType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _checkType = value;
                      _page = 0;
                    }),
                  ),
                ),
              ],
            ),
          ),
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
                        error is AttendanceFailure
                            ? error.message
                            : 'Không thể tải danh sách điểm danh.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            ref.invalidate(attendancePageProvider(query)),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) => Column(
                children: [
                  Expanded(
                    child: data.items.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('Chưa có lượt điểm danh phù hợp.'),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: data.items.length,
                            itemBuilder: (_, index) => _AttendanceCard(
                              record: data.items[index],
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

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final recorded = vietnamTime(record.recordedAt);
    final timeText = localizations.formatTimeOfDay(
      TimeOfDay(hour: recorded.hour, minute: recorded.minute),
      alwaysUse24HourFormat: true,
    );
    final coords =
        record.deviceLatitude != null && record.deviceLongitude != null
        ? ' (${record.deviceLatitude!.toStringAsFixed(4)}, ${record.deviceLongitude!.toStringAsFixed(4)})'
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    record.employeeName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(label: Text(record.status.label)),
              ],
            ),
            Text(
              '${record.workDate} · ${record.shiftName} · ${record.checkType.label} ($timeText)',
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.photo_camera_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text('Ảnh Timemark: ${record.photoUrl}')),
              ],
            ),
            const SizedBox(height: 4),
            Text('Vị trí trên ảnh: ${record.photoLocation}'),
            Text('Định vị điện thoại: ${record.deviceLocation}$coords'),
            if (record.verificationNote != null &&
                record.verificationNote!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Ghi chú: ${record.verificationNote}'),
            ],
          ],
        ),
      ),
    );
  }
}
