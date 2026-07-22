import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/quiz_runner_dialog.dart';

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
  Widget build(BuildContext context) => Scaffold(
        drawer: const AppSidebar(role: 'participant'),
        appBar: AppBar(
          title: const Text('My Quizzes'),
          actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _quizzes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Could not load quizzes: ${snapshot.error}'));
            }
            final quizzes = snapshot.data ?? const [];
            if (quizzes.isEmpty) {
              return const Center(child: Text('No quizzes have been assigned to you yet.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(20),
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
            );
          },
        ),
      );
}
