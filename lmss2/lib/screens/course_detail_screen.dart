import 'package:flutter/material.dart';

import '../models/course_model.dart';
import '../services/api_service.dart';
import '../widgets/lms_shell.dart';
import '../widgets/lms_page.dart';
import '../widgets/lms_states.dart';
import '../widgets/course_content_view.dart';

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

  void _reload() =>
      setState(() => _course = _api.getCourseDetail(widget.courseId));

  Future<void> _askAi(CourseChapter chapter) async {
    final question = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Ask about ${chapter.title}'),
        content: TextField(
          controller: question,
          maxLength: 500,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Your question',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, question.text.trim()),
            child: const Text('Ask'),
          ),
        ],
      ),
    );
    question.dispose();
    if (value == null || value.isEmpty) return;
    try {
      final answer = await _api.askAi(chapter.id, value);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Learning assistant'),
          content: SelectableText(answer),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI answer unavailable: $error')),
        );
    }
  }

  Future<void> _takeaways(CourseChapter chapter) async {
    try {
      final result = await _api.getAiTakeaways(chapter.id);
      final items = List<dynamic>.from(result['takeaways'] ?? const []);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${chapter.title}: key takeaways'),
          content: SizedBox(
            width: 600,
            child: ListView(
              shrinkWrap: true,
              children: items
                  .map(
                    (item) => ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(item.toString()),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Takeaways unavailable: $error')),
        );
    }
  }

  Future<void> _openChapter(CourseChapter chapter) async {
    final started = DateTime.now();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (viewerContext) => Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: Text(chapter.title),
            actions: [
              IconButton(
                tooltip: 'Key takeaways',
                onPressed: () => _takeaways(chapter),
                icon: const Icon(Icons.summarize_outlined),
              ),
              IconButton(
                tooltip: 'Ask learning assistant',
                onPressed: () => _askAi(chapter),
                icon: const Icon(Icons.auto_awesome),
              ),
            ],
          ),
          body: SafeArea(
            child: buildCourseContentView(
              contentType: chapter.contentType,
              mediaUrl: chapter.mediaUrl,
              htmlContent: chapter.htmlContent,
              chapterId: chapter.id,
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(viewerContext),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Complete chapter'),
              ),
            ),
          ),
        ),
      ),
    );
    final elapsed = DateTime.now().difference(started).inSeconds;
    await _api.saveChapterProgress(
      chapterId: chapter.id,
      progress: 100,
      timeSpent: elapsed,
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return LmsShell(
      title: 'Course',
      actions: [
        IconButton(
          tooltip: 'Refresh course',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: FutureBuilder<CourseDetail>(
        future: _course,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LmsLoadingState(label: 'Loading course');
          }
          if (snapshot.hasError) {
            return LmsErrorState(
              message: 'We could not load this course.',
              onRetry: _reload,
            );
          }
          final course = snapshot.data!;
          return LmsPage(
            title: course.title,
            subtitle: course.description.isEmpty ? null : course.description,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                LinearProgressIndicator(value: course.overallProgress / 100),
                const SizedBox(height: 6),
                Text('${course.overallProgress}% complete'),
                const SizedBox(height: 24),
                ...course.modules.map(
                  (module) => Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(
                        module.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: module.chapters
                          .map(
                            (chapter) => ListTile(
                              leading: Icon(
                                chapter.isCompleted
                                    ? Icons.check_circle
                                    : Icons.play_circle_outline,
                                color: chapter.isCompleted
                                    ? Colors.green
                                    : null,
                              ),
                              title: Text(chapter.title),
                              subtitle: Text(
                                '${chapter.contentType.toUpperCase()} • ${chapter.progressPercent}%',
                              ),
                              onTap: () => _openChapter(chapter),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                if (course.linkedQuiz != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.quiz),
                      title: Text(course.linkedQuiz!.title),
                      subtitle: Text(
                        '${course.linkedQuiz!.attemptCount} attempts',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
