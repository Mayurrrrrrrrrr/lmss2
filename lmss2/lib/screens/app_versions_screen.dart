import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/lms_shell.dart';

class AppVersionsScreen extends StatefulWidget {
  const AppVersionsScreen({super.key});

  @override
  State<AppVersionsScreen> createState() => _AppVersionsScreenState();
}

class _AppVersionsScreenState extends State<AppVersionsScreen> {
  final api = ApiService();
  bool loading = true;
  String latest = '';
  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  List<int> parts(String v) => v.split('.').map((x) => int.tryParse(x) ?? 0).toList();

  bool current(String? v) {
    if (v == null) return false;
    final a = parts(v), b = parts(latest);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return true;
  }

  Future<void> load() async {
    try {
      final d = await api.getAppVersions();
      latest = d['latest_version']?.toString() ?? '';
      users = List<Map<String, dynamic>>.from(d['users'] ?? const []);
    } catch (e) {
      // Handle error gracefully
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LmsShell(
      title: 'Android App Versions',
      rootPage: true,
      actions: [
        IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
      ],
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.system_update),
                    title: Text('Current release: v$latest'),
                    subtitle: const Text('Participants on older versions should update.'),
                  ),
                ),
                ...users.map((u) {
                  final v = u['app_version']?.toString();
                  final isCurr = current(v);
                  return Card(
                    child: ListTile(
                      title: Text(u['full_name']?.toString() ?? ''),
                      subtitle: Text('${u['username']} • Last ping ${u['last_app_ping'] ?? 'Never'}'),
                      trailing: Chip(
                        label: Text(v == null
                            ? 'Not installed'
                            : isCurr
                                ? 'v$v • Current'
                                : 'v$v • Update'),
                        backgroundColor: v != null && isCurr
                            ? Colors.green.shade100
                            : v == null
                                ? Colors.grey.shade200
                                : Colors.red.shade100,
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
