import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../models/participant_dashboard_response.dart';
import '../widgets/course_viewer_dialog.dart';
import '../widgets/quiz_runner_dialog.dart';
import '../widgets/lms_shell.dart';
import '../widgets/lms_page.dart';
import '../widgets/lms_states.dart';

class ParticipantDashboardScreen extends StatefulWidget {
  const ParticipantDashboardScreen({super.key});

  @override
  State<ParticipantDashboardScreen> createState() => _ParticipantDashboardScreenState();
}

class _ParticipantDashboardScreenState extends State<ParticipantDashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<ParticipantDashboardResponse> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _apiService.getParticipantDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return LmsShell(
      title: 'My Dashboard',
      rootPage: true,
      body: FutureBuilder<ParticipantDashboardResponse>(
              future: _dashboardFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LmsLoadingState(label: 'Loading your dashboard');
                } else if (snapshot.hasError) {
                  return LmsErrorState(message: 'We could not load your learning dashboard.', onRetry: () => setState(() => _dashboardFuture = _apiService.getParticipantDashboard()));
                } else if (snapshot.hasData) {
                  return _buildDashboardContent(snapshot.data!);
                }
                return const LmsEmptyState(icon: Icons.dashboard_outlined, title: 'Nothing to show yet', message: 'Your assigned learning will appear here.');
              },
            ),
    );
  }

  Widget _buildDashboardContent(ParticipantDashboardResponse data) {
    return LmsPage(
      title: 'My learning',
      subtitle: 'Continue courses, complete quizzes, and collect certificates.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enrolled Courses',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildEnrolledCoursesList(data.enrolledCourses),

          const SizedBox(height: 32),
          const Text(
            'Available Quizzes',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildAvailableQuizzes(data.availableQuizzes),
          
          const SizedBox(height: 32),
          const Text(
            'My Certificates',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildCertificatesList(data.certificates),
        ],
      ),
    );
  }

  Widget _buildEnrolledCoursesList(List<EnrolledCourse> courses) {
    if (courses.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('You are not enrolled in any courses yet.')),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = 1;
      if (constraints.maxWidth > 1200) {
        crossAxisCount = 3;
      } else if (constraints.maxWidth > 800) {
        crossAxisCount = 2;
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
        ),
        itemCount: courses.length,
        itemBuilder: (context, index) {
          final course = courses[index];
          return _buildCourseCard(course);
        },
      );
    });
  }

  Widget _buildCourseCard(EnrolledCourse course) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              color: Colors.blue.withValues(alpha: 0.1),
              width: double.infinity,
              child: const Icon(Icons.menu_book, size: 48, color: Colors.blue),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${(course.progress * 100).toInt()}% Completed'),
                    if (course.hasPendingQuiz)
                      const Text(
                        'Quiz Pending',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: course.progress,
                  backgroundColor: Colors.grey.withValues(alpha: 0.2),
                  color: course.progress == 1.0 ? Colors.green : Colors.blue,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _continueCourse(course),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(course.progress == 1.0 ? 'Review Course' : 'Continue'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatesList(List<Certificate> certificates) {
    if (certificates.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Center(child: Text('No certificates earned yet.')),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: certificates.length,
      itemBuilder: (context, index) {
        final cert = certificates[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: const CircleAvatar(
              backgroundColor: Colors.amber,
              child: Icon(Icons.workspace_premium, color: Colors.white),
            ),
            title: Text(cert.courseTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Issued on: ${cert.issueDate}'),
            trailing: OutlinedButton.icon(
              onPressed: () {
                _downloadCertificate(cert);
              },
              icon: const Icon(Icons.download),
              label: const Text('Download'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailableQuizzes(List<AvailableQuiz> quizzes) {
    if (quizzes.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No quizzes are currently due.')),
        ),
      );
    }
    return Column(
      children: quizzes.map((quiz) => Card(
        child: ListTile(
          leading: const Icon(Icons.quiz_outlined),
          title: Text(quiz.title),
          subtitle: quiz.dueDate == null ? null : Text('Due: ${quiz.dueDate}'),
          trailing: FilledButton(
            onPressed: () => _takeQuiz(quiz),
            child: const Text('Start Quiz'),
          ),
        ),
      )).toList(),
    );
  }

  void _takeQuiz(AvailableQuiz quiz) {
    showDialog(
      context: context,
      builder: (context) => QuizRunnerDialog(
        quizId: int.parse(quiz.id),
        quizTitle: quiz.title,
      ),
    ).then((updated) {
      if (updated == true) {
        setState(() {
          _dashboardFuture = _apiService.getParticipantDashboard();
        });
      }
    });
  }

  void _continueCourse(EnrolledCourse course) {
    showDialog(
      context: context,
      builder: (context) => CourseViewerDialog(
        courseId: int.parse(course.id),
        courseTitle: course.title,
      ),
    ).then((_) {
      setState(() {
        _dashboardFuture = _apiService.getParticipantDashboard();
      });
    });
  }

  void _downloadCertificate(Certificate cert) {
    context.go('/participant/certificates/${cert.id}');
  }
}
