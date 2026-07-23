import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/quiz_runner_dialog.dart';
import '../widgets/lms_shell.dart';
import '../widgets/lms_page.dart';
import '../widgets/lms_states.dart';

class ParticipantQuizzesScreen extends StatefulWidget {
  const ParticipantQuizzesScreen({super.key});

  @override
  State<ParticipantQuizzesScreen> createState() => _ParticipantQuizzesScreenState();
}

class _ParticipantQuizzesScreenState extends State<ParticipantQuizzesScreen> {
  final _api = ApiService();
  late Future<List<Map<String, dynamic>>> _quizzes;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _quizzes = _api.getParticipantQuizzes());

  @override
  Widget build(BuildContext context) => LmsShell(
        title: 'My Quizzes',
        rootPage: true,
        actions: [IconButton(tooltip: 'Refresh quizzes', onPressed: _reload, icon: const Icon(Icons.refresh))],
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _quizzes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LmsLoadingState(label: 'Loading your quizzes');
            }
            if (snapshot.hasError) {
              return LmsErrorState(message: 'We could not load your quizzes.', onRetry: _reload);
            }
            final quizzes = snapshot.data ?? const [];
            if (quizzes.isEmpty) {
              return const LmsEmptyState(icon: Icons.quiz_outlined, title: 'No quizzes assigned', message: 'Assigned and course-linked quizzes will appear here.');
            }
            return LmsPage(title: 'Available quizzes', subtitle: 'Complete assigned assessments and review your progress.', child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: quizzes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final quiz = quizzes[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.quiz)),
                    title: Text(quiz['title']?.toString() ?? 'Quiz'),
                    subtitle: Text(quiz['description']?.toString().isNotEmpty == true
                        ? quiz['description'].toString()
                        : '${quiz['duration_minutes'] ?? 10} minutes'),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => QuizRunnerDialog(
                        quizId: quiz['id'] as int,
                        quizTitle: quiz['title']?.toString() ?? 'Quiz',
                      ),
                    ).then((_) => _reload()),
                  ),
                );
              },
            ));
          },
        ),
      );
}
