import 'package:flutter/material.dart';

class AppSidebar extends StatelessWidget {
  final String role;
  
  const AppSidebar({super.key, this.role = 'admin'});

  @override
  Widget build(BuildContext context) {
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
          _buildListTile(Icons.dashboard, 'Home', true),

          if (role == 'admin') ...[
            _buildSectionHeader('Management'),
            _buildListTile(Icons.group, 'Manage Users', false),
            _buildListTile(Icons.pages, 'Static Pages', false),

            _buildSectionHeader('Masters'),
            _buildListTile(Icons.store, 'Store Master', false),
            _buildListTile(Icons.badge, 'Designations', false),
            _buildListTile(Icons.account_tree, 'Departments', false),

            _buildSectionHeader('System'),
            _buildListTile(Icons.error_outline, 'Error Logs', false),
            _buildListTile(Icons.monitor_heart, 'Diagnostics', false),
            _buildListTile(Icons.delete_outline, 'Recycle Bin', false),
            _buildListTile(Icons.visibility, 'Impersonate User', false),
          ],
          
          const Divider(),
          _buildListTile(Icons.person_outline, 'My Profile', false),
          _buildListTile(Icons.lock_outline, 'Change Password', false),
          _buildListTile(Icons.logout, 'Sign Out', false, textColor: Colors.red),
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

  Widget _buildListTile(IconData icon, String title, bool isActive, {Color? textColor}) {
    return ListTile(
      leading: Icon(icon, color: isActive ? Colors.blue : (textColor ?? Colors.black54)),
      title: Text(
        title,
        style: TextStyle(
          color: isActive ? Colors.blue : (textColor ?? Colors.black87),
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isActive,
      onTap: () {
        // Navigation logic here
      },
    );
  }
}
