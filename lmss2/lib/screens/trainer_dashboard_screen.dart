import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/trainer_dashboard_response.dart';
import '../widgets/course_viewer_dialog.dart';
import '../widgets/quiz_runner_dialog.dart';
import '../widgets/lms_shell.dart';
import '../widgets/lms_page.dart';
import '../widgets/lms_states.dart';

class TrainerDashboardScreen extends StatefulWidget {
  const TrainerDashboardScreen({super.key});

  @override
  State<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends State<TrainerDashboardScreen> {
  final ApiService _apiService = ApiService();
  late Future<TrainerDashboardResponse> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _apiService.getTrainerDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return LmsShell(
      title: 'Trainer Dashboard',
      rootPage: true,
      body: FutureBuilder<TrainerDashboardResponse>(
              future: _dashboardFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LmsLoadingState(label: 'Loading trainer dashboard');
                } else if (snapshot.hasError) {
                  return LmsErrorState(message: 'We could not load the trainer dashboard.', onRetry: () => setState(() => _dashboardFuture = _apiService.getTrainerDashboard()));
                } else if (snapshot.hasData) {
                  return _buildDashboardContent(snapshot.data!);
                }
                return const LmsEmptyState(icon: Icons.school_outlined, title: 'No training data yet', message: 'Create or assign a course to begin.');
              },
            ),
    );
  }

  Widget _buildDashboardContent(TrainerDashboardResponse data) {
    return LmsPage(
      title: 'Training overview',
      subtitle: 'Manage courses, monitor participation, and prepare upcoming learning.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsGrid(data.metrics),
          const SizedBox(height: 40),
          
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildAssignedCoursesSection(data.assignedCourses),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: _buildUpcomingQuizzesSection(data.upcomingQuizzes),
                    ),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAssignedCoursesSection(data.assignedCourses),
                    const SizedBox(height: 40),
                    _buildUpcomingQuizzesSection(data.upcomingQuizzes),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(ProgressMetrics metrics) {
    return LayoutBuilder(builder: (context, constraints) {
      int crossAxisCount = 2;
      if (constraints.maxWidth > 1200) {
        crossAxisCount = 4;
      } else if (constraints.maxWidth > 800) {
        crossAxisCount = 4;
      }

      return GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: constraints.maxWidth > 800 ? 2.5 : 2.0,
        children: [
          _buildMetricCard(
            'Total Participants',
            metrics.totalParticipants.toString(),
            Icons.people,
            Colors.blue,
          ),
          _buildMetricCard(
            'Active Participants',
            metrics.activeParticipants.toString(),
            Icons.local_fire_department,
            Colors.orange,
          ),
          _buildMetricCard(
            'Average Score',
            '${metrics.averageScore}%',
            Icons.analytics,
            Colors.green,
          ),
          _buildMetricCard(
            'Pending Evaluations',
            metrics.pendingEvaluations.toString(),
            Icons.assignment_late,
            Colors.redAccent,
          ),
        ],
      );
    });
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedCoursesSection(List<AssignedCourse> courses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assigned Courses',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (courses.isEmpty)
          const Text('No courses assigned yet.')
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: courses.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final course = courses[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final courseId = int.tryParse(course.id);
                    if (courseId == null) return;
                    showDialog<void>(context: context, builder: (_) => CourseViewerDialog(
                      courseId: courseId,
                      courseTitle: course.title,
                      isTrainerPreview: true,
                    ));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              course.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text('${course.participantCount} Students'),
                            backgroundColor: Colors.blue.shade50,
                            labelStyle: TextStyle(color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: course.completionRate,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getProgressColor(course.completionRate),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(course.completionRate * 100).toInt()}% Avg Completion',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.7) return Colors.green;
    if (progress >= 0.4) return Colors.orange;
    return Colors.red;
  }

  Widget _buildUpcomingQuizzesSection(List<UpcomingQuiz> quizzes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upcoming Live Quizzes',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (quizzes.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No upcoming quizzes.')),
            ),
          )
        else
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: quizzes.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final quiz = quizzes[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer, color: Colors.purple),
                  ),
                  title: Text(
                    quiz.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(quiz.courseName, style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 2),
                        Text(
                          quiz.scheduledTime,
                          style: const TextStyle(color: Colors.deepOrange, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog<void>(context: context, builder: (_) => QuizRunnerDialog(
                      quizId: int.parse(quiz.id),
                      quizTitle: quiz.title,
                      isTrainerPreview: true,
                    ));
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
