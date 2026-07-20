import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';
import '../providers/users_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_sidebar.dart';

class ImpersonateScreen extends StatefulWidget {
  const ImpersonateScreen({super.key});

  @override
  State<ImpersonateScreen> createState() => _ImpersonateScreenState();
}

class _ImpersonateScreenState extends State<ImpersonateScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersProvider>().fetchUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _impersonateUser(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Impersonation'),
        content: Text('Are you sure you want to impersonate ${user.username} (Role: ${user.role})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              // In a real app, you would swap out the auth token in AuthProvider
              // and redirect them. For now, we mock it by updating the role
              // and redirecting to their respective dashboard.
              
              // Simulate API call and state update
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Now impersonating ${user.username}...')),
              );
              
              String route = '/dashboard';
              if (user.role == 'trainer') {
                route = '/trainer/dashboard';
              } else if (user.role == 'participant') {
                route = '/participant/dashboard';
              }
              
              context.go(route);
            },
            icon: const Icon(Icons.login),
            label: const Text('Impersonate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impersonate User'),
      ),
      drawer: const AppSidebar(role: 'admin'),
      body: Consumer<UsersProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.errorMessage!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchUsers(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Filter out admins and apply search
          final impersonatableUsers = provider.users.where((u) {
            if (u.role.toLowerCase() == 'admin') return false;
            
            final query = _searchQuery.toLowerCase();
            return u.username.toLowerCase().contains(query) ||
                (u.fullName != null && u.fullName!.toLowerCase().contains(query)) ||
                u.role.toLowerCase().contains(query);
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search user to impersonate...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          }
                        ) 
                      : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card(
                    elevation: 2,
                    clipBehavior: Clip.antiAlias,
                    child: impersonatableUsers.isEmpty 
                      ? const Center(child: Text('No users available for impersonation.'))
                      : ListView.separated(
                          itemCount: impersonatableUsers.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = impersonatableUsers[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getRoleColor(user.role).withOpacity(0.2),
                                child: Icon(Icons.person, color: _getRoleColor(user.role)),
                              ),
                              title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${user.fullName ?? 'No Name'} • ${user.role}'),
                              trailing: ElevatedButton.icon(
                                onPressed: () => _impersonateUser(user),
                                icon: const Icon(Icons.visibility, size: 16),
                                label: const Text('Impersonate'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'trainer':
        return Colors.orange;
      case 'area_manager':
        return Colors.blue;
      case 'participant':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
