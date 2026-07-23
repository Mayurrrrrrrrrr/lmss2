import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AppSidebar extends StatelessWidget {
  final String role;
  
  const AppSidebar({super.key, this.role = 'admin'});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final auth = context.watch<AuthProvider>();
    final effectiveRole = auth.role ?? role;
    final roleLabel = effectiveRole
        .split('_')
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Text(
                  auth.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  roleLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (auth.isImpersonating)
            Material(
              color: Colors.amber.shade100,
              child: ListTile(
                leading: const Icon(Icons.visibility, color: Colors.deepOrange),
                title: const Text('Impersonation active'),
                subtitle: Text('Viewing as ${auth.displayName}'),
                titleTextStyle: Theme.of(context).textTheme.titleSmall,
                subtitleTextStyle: Theme.of(context).textTheme.bodySmall,
                trailing: const Icon(Icons.close),
                onTap: () async {
                  await context.read<AuthProvider>().stopImpersonating();
                  if (context.mounted) context.go('/dashboard');
                },
              ),
            ),
          _buildSectionHeader('Main'),
          _buildListTile(context, Icons.dashboard, 'Home', '/dashboard', currentRoute),

          if (effectiveRole == 'participant' || effectiveRole == 'area_manager') ...[
            _buildSectionHeader('Learning'),
            _buildListTile(context, Icons.menu_book, 'My Courses', '/participant/courses', currentRoute),
            _buildListTile(context, Icons.quiz, 'My Quizzes', '/participant/quizzes', currentRoute),
            _buildListTile(context, Icons.video_camera_front, 'My Roleplays', '/participant/roleplays', currentRoute),
            _buildListTile(context, Icons.task_alt, 'My Tasks', '/participant/tasks', currentRoute),
            _buildListTile(context, Icons.emoji_events, 'Rewards & Achievements', '/participant/gamification', currentRoute),
            _buildListTile(context, Icons.notifications, 'Notifications', '/participant/notifications', currentRoute),
            _buildListTile(context, Icons.psychology, 'Daily Brain Booster', '/participant/booster', currentRoute),
            _buildListTile(context, Icons.wifi_tethering, 'Join Live Quiz', '/participant/live', currentRoute),
            _buildListTile(context, Icons.auto_awesome, 'AI Learning Assistant', '/participant/ai-tools', currentRoute),
            _buildListTile(context, Icons.search, 'Search & Information', '/participant/content', currentRoute),
            if (effectiveRole == 'area_manager') _buildListTile(context, Icons.analytics, 'Team Reports', '/reports', currentRoute),
          ],

          if (effectiveRole == 'trainer') ...[
            _buildSectionHeader('Training'),
            _buildListTile(context, Icons.school, 'Course Authoring', '/trainer/courses', currentRoute),
            _buildListTile(context, Icons.assignment_ind, 'Course Assignments', '/trainer/assignments', currentRoute),
            _buildListTile(context, Icons.quiz, 'Quiz Authoring', '/trainer/quizzes', currentRoute),
            _buildListTile(context, Icons.wifi_tethering, 'Live Quizzes', '/trainer/live', currentRoute),
            _buildListTile(context, Icons.auto_awesome, 'AI Toolkit', '/trainer/ai-tools', currentRoute),
            _buildListTile(context, Icons.video_camera_front, 'Roleplay Tracker', '/trainer/roleplays', currentRoute),
            _buildListTile(context, Icons.task, 'Operational Tasks', '/trainer/tasks', currentRoute),
            _buildListTile(context, Icons.emoji_events, 'Gamification', '/trainer/gamification', currentRoute),
            _buildListTile(context, Icons.campaign, 'Notifications', '/trainer/notifications', currentRoute),
            _buildListTile(context, Icons.psychology, 'Brain Booster', '/trainer/booster', currentRoute),
            _buildListTile(context, Icons.military_tech, 'Milestones & Kudos', '/trainer/milestones', currentRoute),
            _buildListTile(context, Icons.analytics, 'Reports', '/reports', currentRoute),
            _buildListTile(context, Icons.phone_android, 'App Versions', '/trainer/app-versions', currentRoute),
            _buildListTile(context, Icons.integration_instructions, 'Email & AI Settings', '/trainer/integrations', currentRoute),
          ],

          if (effectiveRole == 'admin') ...[
            _buildSectionHeader('Management'),
            _buildListTile(context, Icons.group, 'Manage Users', '/admin/users', currentRoute),
            _buildListTile(context, Icons.people, 'Participants', '/admin/participants', currentRoute),
            _buildListTile(context, Icons.analytics, 'Reports', '/reports', currentRoute),
            _buildListTile(context, Icons.phone_android, 'App Versions', '/trainer/app-versions', currentRoute),
            _buildListTile(context, Icons.settings_cell, 'Mobile App Configuration', '/admin/app-config', currentRoute),
            _buildListTile(context, Icons.wifi_tethering, 'Live Quizzes', '/trainer/live', currentRoute),
            _buildListTile(context, Icons.auto_awesome, 'AI Toolkit', '/trainer/ai-tools', currentRoute),
            _buildListTile(context, Icons.pages, 'Static Pages', '/admin/pages', currentRoute),

            _buildSectionHeader('Masters'),
            _buildListTile(context, Icons.store, 'Store Master', '/admin/stores', currentRoute),
            _buildListTile(context, Icons.badge, 'Designations', '/admin/designations', currentRoute),
            _buildListTile(context, Icons.account_tree, 'Departments', '/admin/departments', currentRoute),

            _buildSectionHeader('System'),
            _buildListTile(context, Icons.error_outline, 'Error Logs', '/admin/logs', currentRoute),
            _buildListTile(context, Icons.monitor_heart, 'Diagnostics', '/admin/diagnostics', currentRoute),
            _buildListTile(context, Icons.schedule, 'Scheduled Jobs', '/admin/scheduled-jobs', currentRoute),
            _buildListTile(context, Icons.delete_outline, 'Recycle Bin', '/admin/recycle', currentRoute),
            _buildListTile(context, Icons.visibility, 'Impersonate User', '/admin/impersonate', currentRoute),
          ],
          
          const Divider(),
          _buildListTile(context, Icons.person_outline, 'My Profile', '/profile', currentRoute),
          _buildListTile(context, Icons.lock_outline, 'Change Password', '/password', currentRoute),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, String route, String currentRoute) {
    final isActive = currentRoute == route || currentRoute.startsWith('$route/');
    return Semantics(
      button: true,
      selected: isActive,
      label: title,
      child: Tooltip(
        message: title,
        waitDuration: const Duration(milliseconds: 700),
        child: ListTile(
          leading: Icon(
            icon,
            color: isActive ? Theme.of(context).colorScheme.primary : Colors.black54,
          ),
          title: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isActive ? Theme.of(context).colorScheme.primary : Colors.black87,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          selected: isActive,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          onTap: () => context.go(route),
        ),
      ),
    );
  }
}
