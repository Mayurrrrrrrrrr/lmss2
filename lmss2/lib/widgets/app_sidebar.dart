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
    final effectiveRole = context.watch<AuthProvider>().role ?? role;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.grey),
                ),
                SizedBox(height: 10),
                Text(
                  'Admin User', // Replace with dynamic username
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
          _buildSectionHeader('Main'),
          _buildListTile(context, Icons.dashboard, 'Home', '/dashboard', currentRoute),

          if (effectiveRole == 'participant' || effectiveRole == 'area_manager') ...[
            _buildSectionHeader('Learning'),
            _buildListTile(context, Icons.menu_book, 'My Courses', '/participant/courses', currentRoute),
            _buildListTile(context, Icons.video_camera_front, 'My Roleplays', '/participant/roleplays', currentRoute),
            _buildListTile(context, Icons.task_alt, 'My Tasks', '/participant/tasks', currentRoute),
            _buildListTile(context, Icons.emoji_events, 'Rewards & Achievements', '/participant/gamification', currentRoute),
            _buildListTile(context, Icons.notifications, 'Notifications', '/participant/notifications', currentRoute),
            if (effectiveRole == 'area_manager') _buildListTile(context, Icons.analytics, 'Team Reports', '/reports', currentRoute),
          ],

          if (effectiveRole == 'trainer') ...[
            _buildSectionHeader('Training'),
            _buildListTile(context, Icons.school, 'Course Authoring', '/trainer/courses', currentRoute),
            _buildListTile(context, Icons.assignment_ind, 'Course Assignments', '/trainer/assignments', currentRoute),
            _buildListTile(context, Icons.quiz, 'Quiz Authoring', '/trainer/quizzes', currentRoute),
            _buildListTile(context, Icons.video_camera_front, 'Roleplay Tracker', '/trainer/roleplays', currentRoute),
            _buildListTile(context, Icons.task, 'Operational Tasks', '/trainer/tasks', currentRoute),
            _buildListTile(context, Icons.emoji_events, 'Gamification', '/trainer/gamification', currentRoute),
            _buildListTile(context, Icons.campaign, 'Notifications', '/trainer/notifications', currentRoute),
            _buildListTile(context, Icons.analytics, 'Reports', '/reports', currentRoute),
          ],

          if (effectiveRole == 'admin') ...[
            _buildSectionHeader('Management'),
            _buildListTile(context, Icons.group, 'Manage Users', '/admin/users', currentRoute),
            _buildListTile(context, Icons.people, 'Participants', '/admin/participants', currentRoute),
            _buildListTile(context, Icons.analytics, 'Reports', '/reports', currentRoute),
            _buildListTile(context, Icons.pages, 'Static Pages', '/admin/pages', currentRoute),

            _buildSectionHeader('Masters'),
            _buildListTile(context, Icons.store, 'Store Master', '/admin/stores', currentRoute),
            _buildListTile(context, Icons.badge, 'Designations', '/admin/designations', currentRoute),
            _buildListTile(context, Icons.account_tree, 'Departments', '/admin/departments', currentRoute),

            _buildSectionHeader('System'),
            _buildListTile(context, Icons.error_outline, 'Error Logs', '/admin/logs', currentRoute),
            _buildListTile(context, Icons.monitor_heart, 'Diagnostics', '/admin/diagnostics', currentRoute),
            _buildListTile(context, Icons.delete_outline, 'Recycle Bin', '/admin/recycle', currentRoute),
            _buildListTile(context, Icons.visibility, 'Impersonate User', '/admin/impersonate', currentRoute),
          ],
          
          const Divider(),
          _buildListTile(context, Icons.person_outline, 'My Profile', '/profile', currentRoute),
          _buildListTile(context, Icons.lock_outline, 'Change Password', '/password', currentRoute),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () {
              context.read<AuthProvider>().logout();
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
    final isActive = currentRoute == route;
    return ListTile(
      leading: Icon(icon, color: isActive ? Colors.blue : Colors.black54),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? Colors.blue : Colors.black87,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isActive,
      onTap: () {
        context.go(route);
      },
    );
  }
}
