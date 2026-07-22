import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_sidebar.dart';

class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2'));
  bool _isLoading = true;
  List<dynamic> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDeletedItems();
  }

  Future<void> _fetchDeletedItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await _dio.get(
        '/admin/recycle',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() {
          _items = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load deleted items: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restoreItem(Map<String, dynamic> item) async {
    // Mock restore API call
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restored ${item['title']} successfully')),
    );
    setState(() {
      _items.removeWhere((element) => element['id'] == item['id'] && element['type'] == item['type']);
    });
  }

  Future<void> _purgeItem(Map<String, dynamic> item) async {
    // Mock purge API call
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Permanently deleted ${item['title']}')),
    );
    setState(() {
      _items.removeWhere((element) => element['id'] == item['id'] && element['type'] == item['type']);
    });
  }

  Future<void> _purgeAll() async {
    // Mock purge all API call
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All items permanently deleted')),
    );
    setState(() {
      _items.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: isDesktop ? null : AppBar(title: const Text('Recycle Bin')),
      drawer: isDesktop ? null : const AppSidebar(role: 'admin'),
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(
              width: 250,
              child: AppSidebar(role: 'admin'),
            ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDeletedItems,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recycle Bin',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'All trainer-deleted content lives here. Restore or permanently purge.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_items.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Purge All'),
                            content: const Text('Permanently delete all items? This cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _purgeAll();
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Purge All', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_forever, color: Colors.white),
                      label: Text('Purge All (${_items.length})', style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _fetchDeletedItems,
                    tooltip: 'Refresh',
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _items.isEmpty
                ? _buildEmptyState()
                : Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _buildItemTile(item);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Text('✨', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text(
            'Recycle Bin is Empty',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'No deleted content found. All data is intact.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTile(Map<String, dynamic> item) {
    IconData typeIcon;
    Color typeColor;

    switch (item['type']) {
      case 'course':
        typeIcon = Icons.library_books;
        typeColor = Colors.blue;
        break;
      case 'module':
        typeIcon = Icons.folder;
        typeColor = Colors.orange;
        break;
      case 'chapter':
        typeIcon = Icons.description;
        typeColor = Colors.green;
        break;
      case 'quiz':
        typeIcon = Icons.help_outline;
        typeColor = Colors.purple;
        break;
      case 'question':
        typeIcon = Icons.question_answer;
        typeColor = Colors.teal;
        break;
      default:
        typeIcon = Icons.insert_drive_file;
        typeColor = Colors.grey;
    }

    String formattedDate = item['deleted_at'];
    try {
      final DateTime date = DateTime.parse(item['deleted_at']).toLocal();
      formattedDate = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (_) {}

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: typeColor.withOpacity(0.1),
        child: Icon(typeIcon, color: typeColor),
      ),
      title: Text(
        item['title'] ?? 'No Title',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('ID: ${item['id']}', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Text('Type: ${item['type'].toString().toUpperCase()}', style: TextStyle(fontSize: 12, color: typeColor, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                Text('Deleted: $formattedDate', style: const TextStyle(fontSize: 12)),
              ],
            ),
            if (item['extra_info'] != null && item['extra_info'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text('Relations: ${item['extra_info']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text('Trainer: ${item['trainer']}', style: const TextStyle(fontSize: 12)),
            )
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            onPressed: () => _restoreItem(item),
            icon: const Icon(Icons.restore),
            label: const Text('Restore'),
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Permanently Delete'),
                  content: Text('Are you sure you want to permanently delete "${item['title']}"? This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _purgeItem(item);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.delete),
            label: const Text('Purge'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
