import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class TrainerTasksScreen extends StatefulWidget {
  const TrainerTasksScreen({super.key});
  @override State<TrainerTasksScreen> createState() => _TrainerTasksScreenState();
}

class _TrainerTasksScreenState extends State<TrainerTasksScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabs;
  bool _loading = true; String? _error;
  List<Map<String, dynamic>> _tasks = [], _pending = [], _participants = [];
  @override void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _load(); }
  @override void dispose() { _tabs.dispose(); super.dispose(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { final results = await Future.wait([_api.getTrainerTasks(), _api.getTaskOptions()]); _tasks = List<Map<String, dynamic>>.from(results[0]['tasks'] ?? const []); _pending = List<Map<String, dynamic>>.from(results[0]['pending_completions'] ?? const []); _participants = List<Map<String, dynamic>>.from(results[1]['participants'] ?? const []); }
    catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final title = TextEditingController(), description = TextEditingController();
    String verification = 'text', source = 'any'; final selected = <int>{};
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: const Text('Create operational task'),
      content: SizedBox(width: 620, height: 520, child: ListView(children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Task title')),
        const SizedBox(height: 12), TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Instructions')),
        const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: verification, decoration: const InputDecoration(labelText: 'Verification'), items: const [DropdownMenuItem(value: 'text', child: Text('Written response')), DropdownMenuItem(value: 'photo', child: Text('Photo'))], onChanged: (v) => update(() => verification = v!)),
        if (verification == 'photo') DropdownButtonFormField<String>(initialValue: source, decoration: const InputDecoration(labelText: 'Photo source'), items: const [DropdownMenuItem(value: 'any', child: Text('Camera or gallery')), DropdownMenuItem(value: 'camera', child: Text('Camera required'))], onChanged: (v) => update(() => source = v!)),
        const Padding(padding: EdgeInsets.only(top: 16, bottom: 6), child: Text('Assign participants', style: TextStyle(fontWeight: FontWeight.bold))),
        ..._participants.map((p) { final id = p['id'] as int; return CheckboxListTile(dense: true, value: selected.contains(id), title: Text(p['full_name']?.toString() ?? p['username'].toString()), subtitle: Text([p['store_code'], p['reporting_manager_name']].where((v) => v != null && v.toString().isNotEmpty).join(' • ')), onChanged: (checked) => update(() => checked == true ? selected.add(id) : selected.remove(id))); }),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () async { if (title.text.trim().isEmpty || selected.isEmpty) return; await _api.createTask({'title': title.text.trim(), 'description': description.text.trim(), 'verification_type': verification, 'photo_source': source, 'user_ids': selected.toList()}); if (dialogContext.mounted) Navigator.pop(dialogContext, true); }, child: const Text('Create and assign'))],
    )));
    if (saved == true) await _load();
  }

  Future<void> _review(Map<String, dynamic> item, String status) async { await _api.reviewTaskCompletion(item['id'] as int, status); await _load(); }
  @override Widget build(BuildContext context) => Scaffold(
    drawer: const AppSidebar(role: 'trainer'),
    appBar: AppBar(title: const Text('Operational Tasks'), bottom: TabBar(controller: _tabs, tabs: [const Tab(text: 'Tasks'), Tab(text: 'Pending review (${_pending.length})')]), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('Create task')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text('Could not load tasks: $_error')) : TabBarView(controller: _tabs, children: [
      _tasks.isEmpty ? const Center(child: Text('No tasks created.')) : ListView.builder(padding: const EdgeInsets.all(20), itemCount: _tasks.length, itemBuilder: (context, i) { final task = _tasks[i]; return Card(child: ListTile(leading: CircleAvatar(child: Icon(task['verification_type'] == 'photo' ? Icons.photo_camera : Icons.notes)), title: Text(task['title']?.toString() ?? ''), subtitle: Text('${task['assignment_count'] ?? 0} assigned • ${task['verification_type']} verification'), trailing: IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: () async { await _api.deleteTask(task['id'] as int); await _load(); }))); }),
      _pending.isEmpty ? const Center(child: Text('No submissions waiting for review.')) : ListView.builder(padding: const EdgeInsets.all(20), itemCount: _pending.length, itemBuilder: (context, i) { final item = _pending[i]; return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.hourglass_top)), title: Text(item['task_title']?.toString() ?? ''), subtitle: Text('${item['full_name'] ?? item['username']}\n${item['text_response'] ?? (item['image_url'] != null ? 'Photo evidence submitted' : '')}'), isThreeLine: true, trailing: Wrap(spacing: 8, children: [IconButton(tooltip: 'Reject', onPressed: () => _review(item, 'rejected'), icon: const Icon(Icons.close, color: Colors.red)), IconButton(tooltip: 'Approve', onPressed: () => _review(item, 'approved'), icon: const Icon(Icons.check, color: Colors.green))]))); }),
    ]),
  );
}
