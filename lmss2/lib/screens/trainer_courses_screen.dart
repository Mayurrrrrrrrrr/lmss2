import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class TrainerCoursesScreen extends StatefulWidget {
  const TrainerCoursesScreen({super.key});
  @override State<TrainerCoursesScreen> createState() => _TrainerCoursesScreenState();
}

class _TrainerCoursesScreenState extends State<TrainerCoursesScreen> {
  final _api = ApiService();
  late Future<List<Map<String, dynamic>>> _courses;
  @override void initState() { super.initState(); _reload(); }
  void _reload() => setState(() => _courses = _api.getTrainerCourses());

  Future<Map<String, dynamic>?> _courseDialog([Map<String, dynamic>? item]) async {
    final title = TextEditingController(text: item?['title']?.toString() ?? '');
    final description = TextEditingController(text: item?['description']?.toString() ?? '');
    return showDialog<Map<String, dynamic>>(context: context, builder: (context) => AlertDialog(
      title: Text(item == null ? 'Create course' : 'Edit course'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Course title')),
        const SizedBox(height: 12),
        TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (title.text.trim().isEmpty) return; Navigator.pop(context, {
          'title': title.text.trim(), 'description': description.text.trim(), 'duration_type': item?['duration_type'] ?? 'No Duration',
          'duration_value': item?['duration_value'], 'assessment_q_count': item?['assessment_q_count'] ?? 0,
          'assessment_score': item?['assessment_score'] ?? 0, 'course_badge_id': item?['course_badge_id'],
          'thumbnail_path': item?['thumbnail_path'],
        }); }, child: const Text('Save'))],
    ));
  }

  Future<void> _save([Map<String, dynamic>? item]) async {
    final data = await _courseDialog(item); if (data == null) return;
    try { if (item == null) { await _api.createTrainerCourse(data); } else { await _api.updateTrainerCourse(item['id'] as int, data); } _reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    drawer: const AppSidebar(role: 'trainer'),
    appBar: AppBar(title: const Text('Course Authoring'), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _save(), icon: const Icon(Icons.add), label: const Text('New course')),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: _courses, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('Could not load courses: ${snapshot.error}'));
      final items = snapshot.data ?? const [];
      if (items.isEmpty) return const Center(child: Text('No courses yet. Create your first course.'));
      return ListView.separated(padding: const EdgeInsets.all(20), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, index) {
        final item = items[index];
        return Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.school)),
          title: Text(item['title']?.toString() ?? 'Untitled'),
          subtitle: Text('${item['module_count'] ?? 0} modules • ${item['chapter_count'] ?? 0} chapters • ${item['participant_count'] ?? 0} learners'),
          onTap: () => context.go('/trainer/courses/${item['id']}?title=${Uri.encodeComponent(item['title']?.toString() ?? '')}'),
          trailing: PopupMenuButton<String>(onSelected: (action) async {
            if (action == 'edit') await _save(item);
            if (action == 'duplicate') { await _api.duplicateTrainerCourse(item['id'] as int); _reload(); }
            if (action == 'certificate' && mounted) context.go('/trainer/courses/${item['id']}/certificate?title=${Uri.encodeComponent(item['title']?.toString() ?? '')}');
            if (action == 'delete' && mounted) {
              final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete course?'), content: const Text('The course will be moved to the recycle state.'), actions: [TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Delete'))])) ?? false;
              if (ok) { await _api.deleteTrainerCourse(item['id'] as int); _reload(); }
            }
          }, itemBuilder: (_) => const [PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'duplicate',child:Text('Duplicate')),PopupMenuItem(value:'certificate',child:Text('Certificate design')),PopupMenuItem(value:'delete',child:Text('Delete'))]),
        ));
      });
    }),
  );
}
