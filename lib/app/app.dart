import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/domain/auth.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import 'workspace_screen.dart';
import '../features/schedule/presentation/schedule_screen.dart';

class ShiftSyncApp extends ConsumerStatefulWidget {
  const ShiftSyncApp({super.key});
  @override
  ConsumerState<ShiftSyncApp> createState() => _ShiftSyncAppState();
}

class _ShiftSyncAppState extends ConsumerState<ShiftSyncApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/login',
      redirect: (context, route) {
        final auth = ref.read(authControllerProvider);
        final path = route.uri.path;
        if (auth.restoring) return path == '/splash' ? null : '/splash';
        if (auth.restoreFailed) {
          return path == '/session-error' ? null : '/session-error';
        }
        final role = auth.session?.user.role;
        if (role == null) return path == '/login' ? null : '/login';
        if (['/login', '/splash', '/session-error', '/'].contains(path)) {
          return role.home;
        }
        if (path == '/administration' && role != UserRole.admin) {
          return '/forbidden';
        }
        if (path == '/management' && role == UserRole.employee) {
          return '/forbidden';
        }
        if (['/employee', '/my-schedule'].contains(path) &&
            role != UserRole.employee) {
          return '/forbidden';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
        GoRoute(
          path: '/my-schedule',
          builder: (_, _) => const ScheduleScreen(),
        ),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: '/splash',
          builder: (_, _) =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
        GoRoute(
          path: '/session-error',
          builder: (_, _) => const SessionErrorScreen(),
        ),
        GoRoute(
          path: '/employee',
          builder: (_, _) => const WorkspaceScreen(endpoint: 'employee'),
        ),
        GoRoute(
          path: '/management',
          builder: (_, _) => const WorkspaceScreen(endpoint: 'management'),
        ),
        GoRoute(
          path: '/administration',
          builder: (_, _) => const WorkspaceScreen(endpoint: 'administration'),
        ),
        GoRoute(
          path: '/forbidden',
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Không đủ quyền')),
            body: Center(
              child: FilledButton(
                onPressed: () => context.go(
                  ref.read(authControllerProvider).session!.user.role.home,
                ),
                child: const Text('Về trang của tôi'),
              ),
            ),
          ),
        ),
      ],
    );
    unawaited(
      Future.microtask(
        () => ref.read(authControllerProvider.notifier).restore(),
      ),
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, _) => _router.refresh());
    return MaterialApp.router(
      title: 'ShiftSync',
      debugShowCheckedModeBanner: false,
      locale: const Locale('vi', 'VN'),
      supportedLocales: const [Locale('vi', 'VN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff245d49)),
        scaffoldBackgroundColor: const Color(0xfff6f8f6),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

class SessionErrorScreen extends ConsumerWidget {
  const SessionErrorScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ref.watch(authControllerProvider).error ??
                    'Không thể xác minh phiên đăng nhập.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).restore(),
                child: const Text('Thử lại'),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).clearSession(),
                child: const Text('Về đăng nhập'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
