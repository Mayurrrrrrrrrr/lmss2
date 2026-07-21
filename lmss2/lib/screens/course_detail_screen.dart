import 'package:flutter/material.dart';

import '../models/course_model.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final _api = ApiService();
  late Future<CourseDetail> _course;

  @override
  void initState() {
    super.initState();
    _course = _api.getCourseDetail(widget.courseId);
  }

  void _reload() => setState(() => _course = _api.getCourseDetail(widget.courseId));

  Future<void> _openChapter(CourseChapter chapter) async {
    final started = DateTime.now();
    final content = await _api.getChapterContent(chapter.id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(chapter.title),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: SelectableText(
              content['html_content'] as String? ??
                  (chapter.mediaUrl == null
                      ? 'No chapter content is available.'
                      : 'Media: ${chapter.mediaUrl}'),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
    final elapsed = DateTime.now().difference(started).inSeconds;
    await _api.saveChapterProgress(chapterId: chapter.id, progress: 100, timeSpent: elapsed);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      appBar: desktop ? null : AppBar(title: const Text('Course')),
      drawer: desktop ? null : const AppSidebar(role: 'participant'),
      body: Row(children: [
        if (desktop) const SizedBox(width: 250, child: AppSidebar(role: 'participant')),
        Expanded(
          child: FutureBuilder<CourseDetail>(
            future: _course,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Unable to load course: ${snapshot.error}'));
              }
              final course = snapshot.data!;
              return ListView(padding: const EdgeInsets.all(24), children: [
                Text(course.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                if (course.description.isNotEmpty) ...[const SizedBox(height: 8), Text(course.description)],
                const SizedBox(height: 16),
                LinearProgressIndicator(value: course.overallProgress / 100),
                const SizedBox(height: 6),
                Text('${course.overallProgress}% complete'),
                const SizedBox(height: 24),
                ...course.modules.map((module) => Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        title: Text(module.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        children: module.chapters
                            .map((chapter) => ListTile(
                                  leading: Icon(chapter.isCompleted ? Icons.check_circle : Icons.play_circle_outline,
                                      color: chapter.isCompleted ? Colors.green : null),
                                  title: Text(chapter.title),
                                  subtitle: Text('${chapter.contentType.toUpperCase()} • ${chapter.progressPercent}%'),
                                  onTap: () => _openChapter(chapter),
                                ))
                            .toList(),
                      ),
                    )),
                if (course.linkedQuiz != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.quiz),
                      title: Text(course.linkedQuiz!.title),
                      subtitle: Text('${course.linkedQuiz!.attemptCount} attempts'),
                      trailing: const Text('Quiz migration next'),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
