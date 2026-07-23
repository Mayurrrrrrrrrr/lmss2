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
import 'screens/participant_quizzes_screen.dart';
import 'providers/participants_provider.dart';
import 'screens/profile_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/impersonate_screen.dart';
import 'screens/error_logs_screen.dart';
import 'screens/recycle_bin_screen.dart';
import 'screens/stores_screen.dart';
import 'screens/designations_screen.dart';
import 'screens/departments_screen.dart';
import 'screens/courses_screen.dart';
import 'screens/course_detail_screen.dart';
import 'screens/trainer_courses_screen.dart';
import 'screens/trainer_course_builder_screen.dart';
import 'screens/trainer_assignments_screen.dart';
import 'screens/trainer_quizzes_screen.dart';
import 'screens/trainer_questions_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/public_static_page_screen.dart';
import 'screens/trainer_roleplays_screen.dart';
import 'screens/participant_roleplays_screen.dart';
import 'screens/trainer_tasks_screen.dart';
import 'screens/participant_tasks_screen.dart';
import 'screens/trainer_gamification_screen.dart';
import 'screens/participant_gamification_screen.dart';
import 'screens/certificate_screen.dart';
import 'screens/certificate_config_screen.dart';
import 'screens/trainer_notifications_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/brain_booster_screen.dart';
import 'screens/trainer_booster_screen.dart';
import 'screens/trainer_milestones_screen.dart';
import 'screens/integrations_screen.dart';
import 'screens/app_versions_screen.dart';
import 'screens/trainer_live_screen.dart';
import 'screens/participant_live_screen.dart';
import 'screens/trainer_ai_tools_screen.dart';
import 'screens/participant_ai_tools_screen.dart';
import 'screens/app_config_screen.dart';
import 'screens/participant_content_screen.dart';
import 'theme/lms_theme.dart';

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
          builder: (context, state) {
            switch (authProvider.role) {
              case 'trainer':
                return const TrainerDashboardScreen();
              case 'participant':
              case 'area_manager':
                return const ParticipantDashboardScreen();
              default:
                return const AdminDashboardScreen();
            }
          },
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
          path: '/trainer/courses',
          builder: (context, state) => const TrainerCoursesScreen(),
        ),
        GoRoute(
          path: '/trainer/courses/:courseId',
          builder: (context, state) => TrainerCourseBuilderScreen(
            courseId: int.parse(state.pathParameters['courseId']!),
            title: state.uri.queryParameters['title'] ?? '',
          ),
        ),
        GoRoute(
          path: '/trainer/assignments',
          builder: (context, state) => const TrainerAssignmentsScreen(),
        ),
        GoRoute(
          path: '/trainer/quizzes',
          builder: (context, state) => const TrainerQuizzesScreen(),
        ),
        GoRoute(
          path: '/trainer/quizzes/:quizId',
          builder: (context, state) => TrainerQuestionsScreen(
            quizId: int.parse(state.pathParameters['quizId']!),
            title: state.uri.queryParameters['title'] ?? '',
          ),
        ),
        GoRoute(
          path: '/trainer/courses/:courseId/certificate',
          builder: (context, state) => CertificateConfigScreen(
            courseId: int.parse(state.pathParameters['courseId']!),
            courseTitle: state.uri.queryParameters['title'] ?? '',
          ),
        ),
        GoRoute(
          path: '/trainer/roleplays',
          builder: (context, state) => const TrainerRoleplaysScreen(),
        ),
        GoRoute(
          path: '/trainer/tasks',
          builder: (context, state) => const TrainerTasksScreen(),
        ),
        GoRoute(
          path: '/trainer/gamification',
          builder: (context, state) => const TrainerGamificationScreen(),
        ),
        GoRoute(
          path: '/trainer/notifications',
          builder: (context, state) => const TrainerNotificationsScreen(),
        ),
        GoRoute(path:'/trainer/booster',builder:(context,state)=>const TrainerBoosterScreen()),
        GoRoute(path:'/trainer/milestones',builder:(context,state)=>const TrainerMilestonesScreen()),
        GoRoute(path:'/trainer/integrations',builder:(context,state)=>const IntegrationsScreen()),
        GoRoute(path:'/trainer/app-versions',builder:(context,state)=>const AppVersionsScreen()),
        GoRoute(path:'/trainer/live',builder:(context,state)=>const TrainerLiveScreen()),
        GoRoute(path:'/trainer/live/:sessionId',builder:(context,state)=>LiveHostScreen(sessionId:int.parse(state.pathParameters['sessionId']!),report:state.uri.queryParameters['report']=='1')),
        GoRoute(path:'/trainer/ai-tools',builder:(context,state)=>const TrainerAiToolsScreen()),
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
          path: '/participant/courses',
          builder: (context, state) => const CoursesScreen(),
        ),
        GoRoute(
          path: '/participant/quizzes',
          builder: (context, state) => const ParticipantQuizzesScreen(),
        ),
        GoRoute(
          path: '/participant/courses/:courseId',
          builder: (context, state) => CourseDetailScreen(
            courseId: int.parse(state.pathParameters['courseId']!),
          ),
        ),
        GoRoute(
          path: '/participant/roleplays',
          builder: (context, state) => const ParticipantRoleplaysScreen(),
        ),
        GoRoute(
          path: '/participant/tasks',
          builder: (context, state) => const ParticipantTasksScreen(),
        ),
        GoRoute(
          path: '/participant/gamification',
          builder: (context, state) => const ParticipantGamificationScreen(),
        ),
        GoRoute(
          path: '/participant/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(path:'/participant/booster',builder:(context,state)=>const BrainBoosterScreen()),
        GoRoute(path:'/participant/live',builder:(context,state)=>const ParticipantLiveJoinScreen()),
        GoRoute(path:'/participant/live/:sessionId',builder:(context,state)=>ParticipantLiveScreen(sessionId:int.parse(state.pathParameters['sessionId']!))),
        GoRoute(path:'/participant/ai-tools',builder:(context,state)=>const ParticipantAiToolsScreen()),
        GoRoute(path:'/participant/content',builder:(context,state)=>const ParticipantContentScreen()),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/participant/certificates/:courseId',
          builder: (context, state) => CertificateScreen(courseId: int.parse(state.pathParameters['courseId']!)),
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
        GoRoute(path:'/admin/app-config',builder:(context,state)=>const AppConfigScreen()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Firefly Learning Hub',
      debugShowCheckedModeBanner: false,
      theme: LmsTheme.light(),
      routerConfig: _router,
    );
  }
}
