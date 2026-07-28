import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../widgets/lms_shell.dart';
import '../widgets/lms_states.dart';

class ParticipantRoleplaysScreen extends StatefulWidget {
  const ParticipantRoleplaysScreen({super.key});
  @override
  State<ParticipantRoleplaysScreen> createState() =>
      _ParticipantRoleplaysScreenState();
}

class _ParticipantRoleplaysScreenState extends State<ParticipantRoleplaysScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _data = _api.getParticipantRoleplays());
  Future<void> _submit(Map<String, dynamic> item) async {
    PlatformFile? selected;
    bool uploading = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Submit roleplay'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item['scenario_topic']?.toString() ?? ''),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          final result = await FilePicker.pickFiles(
                            type: FileType.video,
                            withData: true,
                          );
                          if (result != null) {
                            update(() => selected = result.files.single);
                          }
                        },
                  icon: const Icon(Icons.video_file_outlined),
                  label: Text(
                    selected == null
                        ? 'Choose video'
                        : 'Replace ${selected!.name}',
                  ),
                ),
                if (selected != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${selected!.name} • ${(selected!.size / 1024 / 1024).toStringAsFixed(1)} MB',
                    ),
                  ),
                if (uploading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const Text(
                    'Uploading securely…',
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: uploading
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: uploading || selected?.bytes == null
                  ? null
                  : () async {
                      update(() => uploading = true);
                      try {
                        await _api.uploadParticipantRoleplay(
                          item['id'] as int,
                          selected!.bytes!,
                          selected!.name,
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true);
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          update(() => uploading = false);
                        }
                      }
                    },
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Upload and submit'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _reload();
  }

  Widget _list(List<Map<String, dynamic>> items, String state) => items.isEmpty
      ? LmsEmptyState(
          icon: Icons.video_camera_front_outlined,
          title: 'No $state roleplays',
          message: 'Roleplay activities in this stage will appear here.',
        )
      : ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.video_camera_front),
                ),
                title: Text(item['scenario_topic']?.toString() ?? ''),
                subtitle: Text(
                  '${item['week_no']} / ${item['day']}${item['observer_score'] != null ? '\nScore: ${item['observer_score']}/5' : ''}${item['debrief_notes'] != null ? '\n${item['debrief_notes']}' : ''}',
                ),
                isThreeLine: item['observer_score'] != null,
                trailing: state == 'assigned'
                    ? FilledButton(
                        onPressed: () => _submit(item),
                        child: const Text('Submit'),
                      )
                    : null,
              ),
            );
          },
        );
  @override
  Widget build(BuildContext context) => LmsShell(
    title: 'My Roleplays',
    rootPage: true,
    actions: [
      IconButton(
        tooltip: 'Refresh roleplays',
        onPressed: _reload,
        icon: const Icon(Icons.refresh),
      ),
    ],
    body: Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Assigned'),
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LmsLoadingState(label: 'Loading roleplays');
              }
              if (snapshot.hasError) {
                return LmsErrorState(
                  message: 'We could not load your roleplays.',
                  onRetry: _reload,
                );
              }
              final data = snapshot.data ?? {};
              List<Map<String, dynamic>> rows(String key) =>
                  List<Map<String, dynamic>>.from(data[key] ?? const []);
              return TabBarView(
                controller: _tabs,
                children: [
                  _list(rows('assigned'), 'assigned'),
                  _list(rows('pending'), 'pending'),
                  _list(rows('completed'), 'completed'),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
