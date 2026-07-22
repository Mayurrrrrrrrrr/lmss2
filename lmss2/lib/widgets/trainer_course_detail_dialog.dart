import 'package:flutter/material.dart';
import 'course_viewer_dialog.dart';
import 'quiz_runner_dialog.dart';

class TrainerCourseDetailDialog extends StatelessWidget {
  final String courseTitle;
  final int participantCount;
  final double completionRate;

  const TrainerCourseDetailDialog({
    super.key,
    required this.courseTitle,
    required this.participantCount,
    required this.completionRate,
  });

  @override
  Widget build(BuildContext context) {
    final int pct = (completionRate * 100).toInt();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 800,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    courseTitle,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Top Stat Cards
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text('Enrolled Learners', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('$participantCount', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text('Average Completion Rate', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('$pct%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Trainer Action Controls (Course & Quiz Preview)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.preview, color: Colors.purple, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Trainer Content Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Test-drive PDF, HTML, Video, YouTube links & Quiz runner as a learner.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => CourseViewerDialog(
                          courseId: 1,
                          courseTitle: courseTitle,
                          isTrainerPreview: true,
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Preview Course'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => QuizRunnerDialog(
                          quizId: 1,
                          quizTitle: '$courseTitle Quiz',
                          isTrainerPreview: true,
                        ),
                      );
                    },
                    icon: const Icon(Icons.quiz),
                    label: const Text('Preview Quiz'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Course Syllabus Modules',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              child: ListTile(
                leading: const Icon(Icons.folder, color: Colors.blue),
                title: const Text('Module 1: Orientation & Video/PDF Material'),
                subtitle: const Text('Chapters: 4 (Video, YouTube, PDF, HTML) | Completion: 88%'),
                trailing: Chip(
                  label: const Text('Active'),
                  backgroundColor: Colors.green.shade100,
                  labelStyle: TextStyle(color: Colors.green.shade800),
                ),
              ),
            ),
            Card(
              elevation: 1,
              child: ListTile(
                leading: const Icon(Icons.folder, color: Colors.blue),
                title: const Text('Module 2: Practice Assessment Quiz'),
                subtitle: const Text('Chapters: 2 | Completion: 62%'),
                trailing: Chip(
                  label: const Text('Active'),
                  backgroundColor: Colors.green.shade100,
                  labelStyle: TextStyle(color: Colors.green.shade800),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
