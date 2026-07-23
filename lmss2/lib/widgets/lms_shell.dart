import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/lms_theme.dart';
import 'app_sidebar.dart';

class LmsShell extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget> actions;
  final bool rootPage;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBarBottom;
  const LmsShell({super.key, required this.title, required this.body, this.actions = const [], this.rootPage = false, this.floatingActionButton, this.appBarBottom});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= LmsBreakpoints.desktop;
    final role = context.watch<AuthProvider>().role ?? 'participant';
    return Scaffold(
      appBar: desktop ? null : AppBar(
        automaticallyImplyLeading: rootPage,
        leading: rootPage ? null : IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _back(context, role),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
        bottom: appBarBottom,
      ),
      drawer: desktop ? null : AppSidebar(role: role),
      bottomNavigationBar: width < LmsBreakpoints.compact
          ? Builder(builder: (innerContext) => _MobileNavigation(role: role, scaffoldContext: innerContext))
          : null,
      floatingActionButton: floatingActionButton,
      body: Row(children: [
        if (desktop) SizedBox(width: 272, child: AppSidebar(role: role)),
        Expanded(child: body),
      ]),
    );
  }

  void _back(BuildContext context, String role) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(role == 'trainer' ? '/trainer/dashboard' : role == 'admin' ? '/dashboard' : '/participant/dashboard');
    }
  }
}

class _MobileNavigation extends StatelessWidget {
  final String role;
  final BuildContext scaffoldContext;
  const _MobileNavigation({required this.role, required this.scaffoldContext});

  @override
  Widget build(BuildContext context) {
    final route = GoRouterState.of(context).matchedLocation;
    final entries = role == 'trainer'
        ? const [
            ('Home', Icons.home_outlined, '/trainer/dashboard'),
            ('Courses', Icons.school_outlined, '/trainer/courses'),
            ('Quizzes', Icons.quiz_outlined, '/trainer/quizzes'),
            ('Assign', Icons.assignment_ind_outlined, '/trainer/assignments'),
            ('More', Icons.menu, '/trainer/more'),
          ]
        : const [
            ('Home', Icons.home_outlined, '/participant/dashboard'),
            ('Courses', Icons.menu_book_outlined, '/participant/courses'),
            ('Quizzes', Icons.quiz_outlined, '/participant/quizzes'),
            ('Booster', Icons.psychology_outlined, '/participant/booster'),
            ('More', Icons.menu, '/participant/more'),
          ];
    var selected = entries.indexWhere((entry) => route == entry.$3 || route.startsWith('${entry.$3}/'));
    if (selected < 0) selected = 4;
    return NavigationBar(
      selectedIndex: selected,
      onDestinationSelected: (index) {
        if (index == 4) {
          Scaffold.of(scaffoldContext).openDrawer();
        } else {
          context.go(entries[index].$3);
        }
      },
      destinations: entries.map((entry) => NavigationDestination(icon: Icon(entry.$2), label: entry.$1)).toList(),
    );
  }
}
