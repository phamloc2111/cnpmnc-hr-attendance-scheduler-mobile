import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/domain/auth.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/change_password_dialog.dart';
import 'services.dart';

final workspaceProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, String>((ref, endpoint) async {
      try {
        final response = await ref
            .watch(apiClientProvider)
            .dio
            .get<Object?>('/workspaces/$endpoint');
        return response.data as Map<String, Object?>;
      } on DioException catch (error) {
        final data = error.response?.data;
        throw AuthFailure(
          data is Map<String, Object?> && data['message'] is String
              ? data['message'] as String
              : 'Không thể tải không gian làm việc.',
        );
      }
    });

class WorkspaceScreen extends ConsumerWidget {
  const WorkspaceScreen({super.key, required this.endpoint});
  final String endpoint;

  Future<void> _changePassword(BuildContext context) async {
    final changed = await showChangePasswordDialog(context);
    if (changed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đổi mật khẩu thành công.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.session?.user;
    if (user == null) return const SizedBox.shrink();
    final workspace = ref.watch(workspaceProvider(endpoint));
    return Scaffold(
      appBar: AppBar(
        title: const Text('ShiftSync'),
        actions: [
          IconButton(
            tooltip: 'Đổi mật khẩu',
            onPressed: auth.loading ? null : () => _changePassword(context),
            icon: const Icon(Icons.key_outlined),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: auth.loading
                ? null
                : () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              ListTile(
                title: Text(user.displayName),
                subtitle: Text(user.role.label),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Tổng quan'),
                onTap: () {
                  Navigator.pop(context);
                  context.go(user.role.home);
                },
              ),
              if (user.role == UserRole.admin)
                ListTile(
                  title: const Text('Không gian quản lý'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/management');
                  },
                ),
              if (user.role == UserRole.employee) ...[
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Lịch của tôi'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/my-schedule');
                  },
                ),
                const ListTile(
                  enabled: false,
                  title: Text('Chấm công'),
                  subtitle: Text('Sắp có'),
                ),
                const ListTile(
                  enabled: false,
                  title: Text('Lịch rảnh'),
                  subtitle: Text('Sắp có'),
                ),
              ] else ...[
                const ListTile(
                  enabled: false,
                  title: Text('Lịch làm việc'),
                  subtitle: Text('Sắp có'),
                ),
                const ListTile(
                  enabled: false,
                  title: Text('Bảng công'),
                  subtitle: Text('Sắp có'),
                ),
                const ListTile(
                  enabled: false,
                  title: Text('Báo cáo'),
                  subtitle: Text('Sắp có'),
                ),
              ],
              if (user.role == UserRole.admin) ...[
                const Divider(),
                const ListTile(
                  enabled: false,
                  title: Text('Tài khoản'),
                  subtitle: Text('Sắp có'),
                ),
                const ListTile(
                  enabled: false,
                  title: Text('Cài đặt'),
                  subtitle: Text('Sắp có'),
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Đổi mật khẩu'),
                onTap: () {
                  Navigator.pop(context);
                  _changePassword(context);
                },
              ),
            ],
          ),
        ),
      ),
      body: workspace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error is AuthFailure
                      ? error.message
                      : 'Không thể tải dữ liệu.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(workspaceProvider(endpoint)),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.all(28),
          children: [
            Chip(label: Text(user.role.label)),
            const SizedBox(height: 24),
            Text(
              'Xin chào, ${user.displayName}.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(data['title'] as String),
            const SizedBox(height: 12),
            Text(data['description'] as String),
            const SizedBox(height: 32),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, color: Color(0xff245d49)),
                    SizedBox(height: 16),
                    Text(
                      'Bạn đã sẵn sàng',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Các chức năng chấm công và xếp lịch sẽ xuất hiện tại đây khi được triển khai.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
