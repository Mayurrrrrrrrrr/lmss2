import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../widgets/lms_page.dart';
import '../widgets/lms_shell.dart';
import '../widgets/lms_states.dart';

class OperationsHubScreen extends StatefulWidget {
  const OperationsHubScreen({super.key});

  @override
  State<OperationsHubScreen> createState() => _OperationsHubScreenState();
}

class _OperationsHubScreenState extends State<OperationsHubScreen> {
  final api = ApiService();
  late Future<List<Map<String, dynamic>>> data;

  @override
  void initState() {
    super.initState();
    data = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final values = await Future.wait([
      api.getOperationsDashboard(),
      api.getOperationsCapabilities(),
    ]);
    return values;
  }

  void reload() => setState(() => data = _load());

  @override
  Widget build(BuildContext context) => LmsShell(
    title: 'Operations Hub',
    rootPage: true,
    actions: [
      IconButton(
        tooltip: 'Refresh operations',
        onPressed: reload,
        icon: const Icon(Icons.refresh),
      ),
    ],
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LmsLoadingState(label: 'Loading operations');
        }
        if (snapshot.hasError) {
          return LmsErrorState(
            message: 'The operations hub is temporarily unavailable.',
            onRetry: reload,
          );
        }
        final dashboard = snapshot.data![0];
        final capabilities = snapshot.data![1];
        final metrics = Map<String, dynamic>.from(dashboard['metrics']);
        final modules = List<Map<String, dynamic>>.from(
          capabilities['modules'],
        );
        final actions = List<Map<String, dynamic>>.from(
          dashboard['next_actions'],
        );
        return LmsPage(
          title: 'Today in retail operations',
          subtitle:
              'Learning, task evidence, coaching and store execution in one workspace.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: metrics.entries
                    .map(
                      (entry) => SizedBox(
                        width: 210,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key.replaceAll('_', ' '),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${entry.value}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text(
                'Next actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ...actions.map(
                (action) => Card(
                  child: ListTile(
                    title: Text(action['label'].toString()),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () => context.go(action['route'].toString()),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Operations modules',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ...modules.map(
                (module) => ListTile(
                  leading: Icon(
                    module['enabled'] == true
                        ? Icons.check_circle
                        : Icons.lock_outline,
                  ),
                  title: Text(module['label'].toString()),
                  subtitle: module['stage'] == null
                      ? null
                      : Text('Prepared for the next operations rollout'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
