import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/lms_shell.dart';
import '../widgets/lms_page.dart';
import '../widgets/lms_states.dart';

class BrainBoosterScreen extends StatefulWidget {
  const BrainBoosterScreen({super.key});
  @override
  State<BrainBoosterScreen> createState() => _BrainBoosterScreenState();
}

class _BrainBoosterScreenState extends State<BrainBoosterScreen> {
  final api = ApiService();
  late Future<Map<String, dynamic>> data;
  final answers = <int, int>{};

  @override
  void initState() { super.initState(); reload(); }
  void reload() => setState(() => data = api.getDailyBooster());
  Future<void> submit() async {
    final result = await api.submitDailyBooster(answers);
    if (mounted) {
      await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Booster complete!'), content: Text('Score: ${result['score']}/${result['total']}\nXP earned: +${result['xp_earned']}'), actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))]));
    }
    reload();
  }

  @override
  Widget build(BuildContext context) => LmsShell(
    title: 'Daily Brain Booster',
    rootPage: true,
    actions: [IconButton(tooltip: 'Refresh booster', onPressed: reload, icon: const Icon(Icons.refresh))],
    body: FutureBuilder<Map<String, dynamic>>(future: data, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const LmsLoadingState(label: 'Loading today’s booster');
      if (snapshot.hasError) return LmsErrorState(message: 'We could not load today’s booster.', onRetry: reload);
      final booster = snapshot.data!;
      if (booster['available'] != true) return LmsEmptyState(icon: Icons.bolt, title: 'Today’s booster is complete', message: 'Score ${booster['score'] ?? 0}/3 • +${booster['xp_earned'] ?? 0} XP. Come back tomorrow for another challenge.');
      final questions = List<Map<String, dynamic>>.from(booster['questions'] ?? const []);
      return LmsPage(title: 'Three quick questions', subtitle: 'Build your streak and earn up to 45 XP.', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...questions.asMap().entries.map((entry) {
          final question = entry.value;
          final id = question['id'] as int;
          final options = List<Map<String, dynamic>>.from(question['options']);
          return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Q${entry.key + 1}. ${question['text']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            RadioGroup<int>(groupValue: answers[id], onChanged: (value) { if (value != null) setState(() => answers[id] = value); }, child: Column(children: options.map((option) => RadioListTile<int>(value: option['id'] as int, title: Text(option['text'].toString()))).toList())),
          ])));
        }),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: answers.length == questions.length ? submit : null, icon: const Icon(Icons.bolt), label: const Text('Submit answers'))),
      ]));
    }),
  );
}
