import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lms_frontend/providers/auth_provider.dart';
import 'package:lms_frontend/widgets/lms_shell.dart';
import 'package:lms_frontend/theme/lms_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthProvider Tests', () {
    test('Initial state when no token is present', () async {
      SharedPreferences.setMockInitialValues({});
      final authProvider = AuthProvider();
      
      // Wait for initialization to complete
      await Future.delayed(Duration.zero);
      
      expect(authProvider.isInitialized, isTrue);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.role, null);
      expect(authProvider.isImpersonating, isFalse);
    });

    test('Initial state when token and role are present', () async {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'fake_jwt_token',
        'user_role': 'trainer',
        'display_name': 'Trainer Name',
        'is_impersonating': false,
      });
      final authProvider = AuthProvider();
      
      await Future.delayed(Duration.zero);
      
      expect(authProvider.isInitialized, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.role, 'trainer');
      expect(authProvider.displayName, 'Trainer Name');
      expect(authProvider.isImpersonating, isFalse);
    });

    test('Impersonation state changes', () async {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'admin_token',
        'user_role': 'admin',
        'display_name': 'Admin Name',
      });
      final authProvider = AuthProvider();
      await Future.delayed(Duration.zero);

      expect(authProvider.isImpersonating, isFalse);
      expect(authProvider.role, 'admin');

      // Setup impersonation data in SharedPreferences manually for verification
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'impersonated_token',
        'user_role': 'trainer',
        'display_name': 'Impersonated User',
        'is_impersonating': true,
        'admin_jwt_token': 'admin_token',
        'admin_user_role': 'admin',
        'admin_display_name': 'Admin Name',
      });
      final authProvider2 = AuthProvider();
      await Future.delayed(Duration.zero);

      expect(authProvider2.isInitialized, isTrue);
      expect(authProvider2.isAuthenticated, isTrue);
      expect(authProvider2.isImpersonating, isTrue);
      expect(authProvider2.role, 'trainer');
      expect(authProvider2.displayName, 'Impersonated User');

      // Now we can test stopImpersonating() because it only reads from prefs
      await authProvider2.stopImpersonating();
      expect(authProvider2.isImpersonating, isFalse);
      expect(authProvider2.role, 'admin');
      expect(authProvider2.displayName, 'Admin Name');
    });

    test('Logout clears storage', () async {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'some_token',
        'user_role': 'participant',
        'display_name': 'Participant User',
      });
      final authProvider = AuthProvider();
      await Future.delayed(Duration.zero);

      expect(authProvider.isAuthenticated, isTrue);

      await authProvider.logout();

      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.token, null);
      expect(authProvider.role, null);
      expect(authProvider.isImpersonating, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('jwt_token'), isFalse);
      expect(prefs.containsKey('user_role'), isFalse);
      expect(prefs.containsKey('display_name'), isFalse);
    });
  });

  group('LmsShell Responsive Tests', () {
    Widget buildShellHelper({required double width, required String role}) {
      SharedPreferences.setMockInitialValues({
        'jwt_token': 'token',
        'user_role': role,
      });

      final authProvider = AuthProvider();

      final router = GoRouter(
        initialLocation: '/test',
        routes: [
          GoRoute(
            path: '/test',
            builder: (context, state) {
              final provider = context.watch<AuthProvider>();
              if (!provider.isInitialized) {
                return const Scaffold(body: CircularProgressIndicator());
              }
              return MediaQuery(
                data: MediaQueryData(size: Size(width, 800)),
                child: const LmsShell(
                  title: 'Test LMS Shell',
                  body: Text('Shell Content'),
                  rootPage: true,
                ),
              );
            },
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const Text('Dashboard'),
          ),
        ],
      );

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: MaterialApp.router(
          theme: LmsTheme.light(),
          routerConfig: router,
        ),
      );
    }

    testWidgets('Renders sidebar on Desktop viewport', (WidgetTester tester) async {
      await tester.pumpWidget(buildShellHelper(width: 1200, role: 'admin'));
      await tester.pumpAndSettle();

      expect(find.byType(LmsShell), findsOneWidget);
      expect(find.text('Shell Content'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('Renders AppBar and Bottom Navigation on Mobile viewport', (WidgetTester tester) async {
      await tester.pumpWidget(buildShellHelper(width: 360, role: 'participant'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Test LMS Shell'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Shell Content'), findsOneWidget);
    });
  });
}
