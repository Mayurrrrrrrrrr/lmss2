import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/users_provider.dart';
import '../widgets/lms_shell.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
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

  @override
  Widget build(BuildContext context) {
    return LmsShell(
      title: 'Manage Users',
      rootPage: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Users',
          onPressed: () {
            context.read<UsersProvider>().fetchUsers();
          },
        ),
      ],
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

          // Filter users based on search
          final filteredUsers = provider.users.where((u) {
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
                // Header & Search
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by username, name or role...',
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
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        _showAddEditUserDialog(context, null);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add User'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Data Table
                Expanded(
                  child: Card(
                    elevation: 2,
                    clipBehavior: Clip.antiAlias,
                    child: filteredUsers.isEmpty 
                      ? const Center(child: Text('No users found'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 64), // Approximate padding offset
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey.shade100),
                                columns: const [
                                  DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Created', style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: filteredUsers.map((user) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(user.id.toString(), style: const TextStyle(color: Colors.grey))),
                                      DataCell(Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Text(user.fullName ?? '—')),
                                      DataCell(_buildRoleBadge(user.role)),
                                      DataCell(Text('${user.createdAt.year}-${user.createdAt.month.toString().padLeft(2, '0')}-${user.createdAt.day.toString().padLeft(2, '0')}')),
                                      DataCell(_buildActionButtons(context, user)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
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

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role.toLowerCase()) {
      case 'admin':
        color = Colors.red;
        break;
      case 'trainer':
        color = Colors.orange;
        break;
      case 'area_manager':
        color = Colors.blue;
        break;
      default:
        color = Colors.green;
    }

    // Format role string to be readable (e.g., area_manager -> Area Manager)
    String displayRole = role.split('_').map((word) => 
      word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : ''
    ).join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((255 * 0.1).toInt()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha((255 * 0.5).toInt())),
      ),
      child: Text(
        displayRole,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, UserModel user) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (user.role.toLowerCase() != 'admin')
          Tooltip(
            message: 'Impersonate User',
            child: IconButton(
              icon: const Icon(Icons.login, color: Colors.deepPurple),
              onPressed: () {
                _impersonateUser(context, user);
              },
            ),
          ),
        Tooltip(
          message: 'Edit User',
          child: IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () {
              _showAddEditUserDialog(context, user);
            },
          ),
        ),
        Tooltip(
          message: 'Delete User',
          child: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              _confirmDelete(context, user);
            },
          ),
        ),
      ],
    );
  }

  void _impersonateUser(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Impersonate User'),
        content: Text('Enter the portal as ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Impersonating ${user.username}...')),
              );
              // Implementation would update auth state and navigate to dashboard
            },
            icon: const Icon(Icons.login),
            label: const Text('Enter As'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.username}? Their content stays in the portal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              context.read<UsersProvider>().deleteUser(user.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${user.username} deleted')),
              );
            },
            icon: const Icon(Icons.delete),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditUserDialog(BuildContext context, UserModel? user) {
    final usernameController = TextEditingController(text: user?.username);
    final fullNameController = TextEditingController(text: user?.fullName);
    final passwordController = TextEditingController();
    String selectedRole = user?.role ?? 'participant';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(user == null ? 'Add New User' : 'Edit User: ${user.username}'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: user == null ? 'Password' : 'Password (leave blank to keep)',
                        border: const OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: ['participant', 'trainer', 'area_manager', 'admin'].map((role) {
                        String displayRole = role.split('_').map((word) => 
                          word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : ''
                        ).join(' ');
                        return DropdownMenuItem(
                          value: role,
                          child: Text(displayRole),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedRole = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  // In a real app, you would send this to the backend
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(user == null ? 'User added successfully' : 'User updated successfully')),
                  );
                },
                child: Text(user == null ? 'Add User' : 'Save Changes'),
              ),
            ],
          );
        }
      ),
    );
  }
}
