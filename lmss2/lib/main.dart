import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/users_provider.dart';
import 'providers/static_pages_provider.dart';
import 'providers/stores_provider.dart';
import 'providers/designations_provider.dart';
import 'providers/departments_provider.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/users_screen.dart';
import 'screens/static_pages_screen.dart';
import 'screens/participants_screen.dart';
import 'screens/trainer_dashboard_screen.dart';
import 'screens/participant_dashboard_screen.dart';
import 'providers/participants_provider.dart';
import 'screens/profile_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/impersonate_screen.dart';
import 'screens/error_logs_screen.dart';
import 'screens/recycle_bin_screen.dart';
import 'screens/stores_screen.dart';
import 'screens/designations_screen.dart';
import 'screens/departments_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/public_static_page_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UsersProvider()),
        ChangeNotifierProvider(create: (_) => ParticipantsProvider()),
        ChangeNotifierProvider(create: (_) => StaticPagesProvider()),
        ChangeNotifierProvider(create: (_) => StoresProvider()),
        ChangeNotifierProvider(create: (_) => DesignationsProvider()),
        ChangeNotifierProvider(create: (_) => DepartmentsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();

    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isLoginRoute = state.matchedLocation == '/';
        final isPublicPage = state.matchedLocation.startsWith('/pages/');

        if (!isAuthenticated && !isLoginRoute && !isPublicPage) {
          return '/';
        }

        if (isAuthenticated && isLoginRoute) {
          return '/dashboard';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/pages/:slug',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return PublicStaticPageScreen(slug: slug);
          },
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/dashboard',
          redirect: (context, state) => '/dashboard',
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const UsersScreen(),
        ),
        GoRoute(
          path: '/admin/participants',
          builder: (context, state) => const ParticipantsScreen(),
        ),
        GoRoute(
          path: '/admin/pages',
          builder: (context, state) => const StaticPagesScreen(),
        ),
        GoRoute(
          path: '/trainer/dashboard',
          builder: (context, state) => const TrainerDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/logs',
          builder: (context, state) => const ErrorLogsScreen(),
        ),
        GoRoute(
          path: '/admin/recycle',
          builder: (context, state) => const RecycleBinScreen(),
        ),
        GoRoute(
          path: '/participant/dashboard',
          builder: (context, state) => const ParticipantDashboardScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/password',
          builder: (context, state) => const ChangePasswordScreen(),
        ),
        GoRoute(
          path: '/admin/impersonate',
          builder: (context, state) => const ImpersonateScreen(),
        ),
        GoRoute(
          path: '/admin/stores',
          builder: (context, state) => const StoresScreen(),
        ),
        GoRoute(
          path: '/admin/designations',
          builder: (context, state) => const DesignationsScreen(),
        ),
        GoRoute(
          path: '/admin/departments',
          builder: (context, state) => const DepartmentsScreen(),
        ),
        GoRoute(
          path: '/admin/diagnostics',
          builder: (context, state) => const DiagnosticsScreen(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LMS Admin Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
