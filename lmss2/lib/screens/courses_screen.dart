import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/course_model.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

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
    final desktop = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      appBar: desktop ? null : AppBar(title: const Text('My Courses')),
      drawer: desktop ? null : const AppSidebar(role: 'participant'),
      body: Row(children: [
        if (desktop) const SizedBox(width: 250, child: AppSidebar(role: 'participant')),
        Expanded(
          child: FutureBuilder<List<CourseSummary>>(
            future: _courses,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Unable to load courses: ${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ]));
              }
              final courses = snapshot.data ?? const [];
              if (courses.isEmpty) return const Center(child: Text('No courses are assigned to you.'));
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text('My Courses', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
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
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}
