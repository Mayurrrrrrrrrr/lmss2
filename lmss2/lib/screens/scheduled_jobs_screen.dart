import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/lms_shell.dart';
import '../widgets/lms_states.dart';

class ScheduledJobsScreen extends StatefulWidget {
  const ScheduledJobsScreen({super.key});
  @override
  State<ScheduledJobsScreen> createState() => _ScheduledJobsScreenState();
}

class _ScheduledJobsScreenState extends State<ScheduledJobsScreen> {
  final api = ApiService();
  late Future<Map<String, dynamic>> data;
  @override
  void initState() { super.initState(); reload(); }
  void reload() => setState(() => data = api.getScheduledJobs());

  @override
  Widget build(BuildContext context) => LmsShell(
    title: 'Scheduled Jobs',
    actions: [IconButton(tooltip: 'Refresh job history', onPressed: reload, icon: const Icon(Icons.refresh))],
    body: FutureBuilder<Map<String, dynamic>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const LmsLoadingState(label: 'Loading scheduled jobs');
        if (snapshot.hasError) return LmsErrorState(message: 'We could not load scheduled-job history.', onRetry: reload);
        final jobs = List<Map<String, dynamic>>.from(snapshot.data?['jobs'] ?? const []);
        final runs = List<Map<String, dynamic>>.from(snapshot.data?['runs'] ?? const []);
        return ListView(padding: const EdgeInsets.all(24), children: [
          Text('Production schedules', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: jobs.map((job) => SizedBox(
            width: 360,
            child: Card(child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.schedule)),
              title: Text(job['description'].toString()),
              subtitle: Text(job['schedule'].toString()),
            )),
          )).toList()),
          const SizedBox(height: 28),
          Text('Recent executions', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (runs.isEmpty)
            const LmsEmptyState(icon: Icons.history, title: 'No executions recorded yet', message: 'History appears after the first production timer run.')
          else
            ...runs.map((run) {
              final success = run['status'] == 'success';
              return Card(child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: (success ? Colors.green : Colors.red).withValues(alpha: .12),
                  child: Icon(success ? Icons.check : Icons.error_outline, color: success ? Colors.green : Colors.red),
                ),
                title: Text(run['job_name'].toString()),
                subtitle: Text('${run['started_at']} • ${run['affected_rows'] ?? 0} records${run['error_message'] == null ? '' : '\n${run['error_message']}'}'),
                isThreeLine: run['error_message'] != null,
                trailing: Chip(label: Text(run['status'].toString())),
              ));
            }),
        ]);
      },
    ),
  );
}
