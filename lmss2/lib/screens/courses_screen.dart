import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/course_model.dart';
import '../services/api_service.dart';
import '../widgets/lms_shell.dart';
import '../widgets/lms_page.dart';
import '../widgets/lms_states.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}
class _CoursesScreenState extends State<CoursesScreen> {
  final _api = ApiService();
  late Future<List<CourseSummary>> _courses;

  @override
  void initState() {
    super.initState();
    _courses = _api.getCourses();
  }

  void _reload() => setState(() => _courses = _api.getCourses());

  @override
  Widget build(BuildContext context) {
    return LmsShell(
      title: 'My Courses',
      rootPage: true,
      actions: [IconButton(tooltip: 'Refresh courses', onPressed: _reload, icon: const Icon(Icons.refresh))],
      body: FutureBuilder<List<CourseSummary>>(
            future: _courses,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LmsLoadingState(label: 'Loading your courses');
              }
              if (snapshot.hasError) {
                return LmsErrorState(message: 'We could not load your assigned courses.', onRetry: _reload);
              }
              final courses = snapshot.data ?? const [];
              if (courses.isEmpty) return const LmsEmptyState(icon: Icons.menu_book_outlined, title: 'No courses assigned', message: 'New courses will appear here when your trainer assigns them.');
              return LmsPage(title: 'Continue learning', subtitle: '${courses.length} assigned ${courses.length == 1 ? 'course' : 'courses'}', child: Column(children: [
                  ...courses.map((course) => Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: const CircleAvatar(child: Icon(Icons.menu_book)),
                          title: Text(course.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (course.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(course.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                            const SizedBox(height: 10),
                            LinearProgressIndicator(value: course.progressPercent / 100),
                            const SizedBox(height: 5),
                            Text('${course.progressPercent}% • ${course.completedChapters}/${course.totalChapters} chapters'),
                          ]),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.go('/participant/courses/${course.id}'),
                        ),
                      )),
                ]));
            },
          ),
    );
  }
}
