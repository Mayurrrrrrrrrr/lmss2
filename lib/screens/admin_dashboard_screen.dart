import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/admin_dashboard_response.dart';
import '../widgets/app_sidebar.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<AdminDashboardResponse> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _apiService.getAdminDashboard();
  }

  @override
  Widget build(BuildContext context) {
    // We use a Scaffold with a Drawer and a main content area.
    // To make it modern, we might want a persistent sidebar on large screens,
    // but for standard flutter, a Drawer is typical. We can check screen width.
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: isDesktop ? null : AppBar(title: const Text('Admin Dashboard')),
      drawer: isDesktop ? null : const AppSidebar(),
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(
              width: 250,
              child: AppSidebar(),
            ),
          Expanded(
            child: FutureBuilder<AdminDashboardResponse>(
              future: _dashboardFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (snapshot.hasData) {
                  return _buildDashboardContent(snapshot.data!);
                }
                return const Center(child: Text('No data'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(AdminDashboardResponse data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back, Admin',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Portal management and overview dashboard.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          
          if (data.stats != null) ...[
            _buildStatsGrid(data.stats!),
            const SizedBox(height: 40),
          ],
          
          const Text(
            'Recent System Activity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildRecentLoginsTable(data.recentLogins),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(DashboardStats stats) {
    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = 2;
      if (constraints.maxWidth > 1200) {
        crossAxisCount = 4;
      } else if (constraints.maxWidth > 800) {
        crossAxisCount = 3;
      }

      return GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.5,
        children: [
          _buildStatCard(
            'Total Users',
            stats.totalUsers.toString(),
            Icons.people,
            Colors.blue,
            stats.newUsers > 0 ? '+${stats.newUsers} this week' : null,
          ),
          _buildStatCard(
            'Trainers',
            stats.totalTrainers.toString(),
            Icons.school,
            Colors.orange,
            stats.newTrainers > 0 ? '+${stats.newTrainers} this week' : null,
          ),
          _buildStatCard(
            'Participants',
            stats.totalParticipants.toString(),
            Icons.person_outline,
            Colors.purple,
            stats.newParticipants > 0 ? '+${stats.newParticipants} this week' : null,
          ),
          _buildStatCard(
            'Courses',
            stats.totalCourses.toString(),
            Icons.menu_book,
            Colors.green,
            stats.newCourses > 0 ? '+${stats.newCourses} this week' : null,
          ),
          _buildStatCard(
            'Static Pages',
            stats.totalPages.toString(),
            Icons.pages,
            Colors.redAccent,
            stats.newPages > 0 ? '+${stats.newPages} this week' : null,
          ),
        ],
      );
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String? trend) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  if (trend != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      trend,
                      style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentLoginsTable(List<RecentLogin> logins) {
    if (logins.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('No recent activity.')),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: logins.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final login = logins[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getRoleColor(login.role).withValues(alpha: 0.2),
              child: Icon(_getRoleIcon(login.role), color: _getRoleColor(login.role)),
            ),
            title: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  const TextSpan(text: 'User '),
                  TextSpan(text: login.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const TextSpan(text: ' logged in as '),
                  TextSpan(
                    text: login.role.toUpperCase(),
                    style: TextStyle(
                      color: _getRoleColor(login.role),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            subtitle: Text(login.loginTime), // Note: You might want a timeago formatter here
          );
        },
      ),
    );
  }
  
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Colors.red;
      case 'trainer': return Colors.orange;
      case 'participant': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Icons.admin_panel_settings;
      case 'trainer': return Icons.school;
      case 'participant': return Icons.person;
      default: return Icons.person_outline;
    }
  }
}
