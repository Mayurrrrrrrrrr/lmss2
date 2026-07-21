import 'package:flutter/material.dart';

class CertificateViewerDialog extends StatelessWidget {
  final String courseTitle;
  final String learnerName;
  final String issueDate;

  const CertificateViewerDialog({
    super.key,
    required this.courseTitle,
    required this.learnerName,
    required this.issueDate,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 800,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.shade400, width: 6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.workspace_premium, size: 48, color: Colors.amber),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'CERTIFICATE OF COMPLETION',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is proudly presented to',
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              learnerName.isNotEmpty ? learnerName : 'John Doe',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'for successfully mastering the curriculum and passing all assessments in',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              courseTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Issued Date:', style: TextStyle(color: Colors.grey)),
                    Text(issueDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Verified By:', style: TextStyle(color: Colors.grey)),
                    Text('LMS Academic Board', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading Certificate PDF...')),
                );
              },
              icon: const Icon(Icons.print),
              label: const Text('Print / Download Certificate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
