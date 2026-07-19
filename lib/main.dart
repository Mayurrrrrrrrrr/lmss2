import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/users_provider.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/users_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UsersProvider()),
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

        if (!isAuthenticated && !isLoginRoute) {
          return '/';
        }

        if (isAuthenticated && isLoginRoute) {
          return '/dashboard';
        }

        return null;
      },
      routes: [
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
