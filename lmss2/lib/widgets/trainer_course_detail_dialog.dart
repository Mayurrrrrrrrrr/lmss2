import 'package:flutter/material.dart';

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
        width: 750,
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
            const Text(
              'Course Modules & Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              child: ListTile(
                leading: const Icon(Icons.folder, color: Colors.blue),
                title: const Text('Module 1: Foundations & Architecture'),
                subtitle: const Text('Chapters: 4 | Completion: 88%'),
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
                title: const Text('Module 2: Advanced Integrations & DB'),
                subtitle: const Text('Chapters: 3 | Completion: 62%'),
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
