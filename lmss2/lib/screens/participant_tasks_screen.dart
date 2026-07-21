import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class ParticipantTasksScreen extends StatefulWidget {
  const ParticipantTasksScreen({super.key});
  @override State<ParticipantTasksScreen> createState() => _ParticipantTasksScreenState();
}

class _ParticipantTasksScreenState extends State<ParticipantTasksScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tasks = [];

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { _tasks = await _api.getParticipantTasks(); }
    catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submitText(Map<String, dynamic> task) async {
    final controller = TextEditingController(text: task['text_response']?.toString() ?? '');
    final value = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(task['title']?.toString() ?? 'Submit task'),
      content: TextField(controller: controller, maxLines: 6, decoration: const InputDecoration(labelText: 'Response', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () { final text = controller.text.trim(); if (text.isNotEmpty) Navigator.pop(dialogContext, text); }, child: const Text('Submit'))],
    ));
    if (value != null) { await _api.submitTaskText(task['id'] as int, value); await _load(); }
  }

  Future<void> _submitPhoto(Map<String, dynamic> task) async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png'], withData: true);
    final file = result?.files.single;
    if (file?.bytes == null) return;
    if (file!.size > 5 * 1024 * 1024) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose an image smaller than 5 MB.'))); return; }
    final type = file.extension?.toLowerCase() == 'png' ? 'image/png' : 'image/jpeg';
    await _api.submitTaskPhoto(task['id'] as int, file.bytes!, type);
    await _load();
  }

  Color _statusColor(String status) => switch (status.toLowerCase()) { 'approved' => Colors.green, 'rejected' => Colors.red, 'pending_review' => Colors.orange, _ => Colors.blueGrey };
  @override Widget build(BuildContext context) => Scaffold(
    drawer: const AppSidebar(role: 'participant'),
    appBar: AppBar(title: const Text('My Tasks'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text('Could not load tasks: $_error')) : _tasks.isEmpty ? const Center(child: Text('No active tasks assigned.')) : ListView.builder(
      padding: const EdgeInsets.all(20), itemCount: _tasks.length, itemBuilder: (context, index) {
        final task = _tasks[index]; final status = task['status']?.toString() ?? 'pending'; final isPhoto = task['verification_type'] == 'photo';
        return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(task['title']?.toString() ?? '', style: Theme.of(context).textTheme.titleMedium)), Chip(label: Text(status.replaceAll('_', ' ')), backgroundColor: _statusColor(status).withValues(alpha: .15))]),
          if ((task['description']?.toString() ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(task['description'].toString())),
          const SizedBox(height: 12), Text(isPhoto ? 'Verification: Photo${task['photo_source'] == 'camera' ? ' (camera)' : ''}' : 'Verification: Written response'),
          const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => isPhoto ? _submitPhoto(task) : _submitText(task), icon: Icon(isPhoto ? Icons.add_a_photo : Icons.edit_note), label: Text(status == 'rejected' ? 'Resubmit' : status == 'pending' ? 'Submit' : 'Update submission'))),
        ])));
      }),
  );
}
