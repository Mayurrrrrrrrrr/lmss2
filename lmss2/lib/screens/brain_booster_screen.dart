import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

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
  Widget build(BuildContext context) => Scaffold(
    drawer: const AppSidebar(role: 'participant'),
    appBar: AppBar(title: const Text('Daily Brain Booster'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<Map<String, dynamic>>(future: data, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('Could not load booster: ${snapshot.error}'));
      final booster = snapshot.data!;
      if (booster['available'] != true) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('⚡', style: TextStyle(fontSize: 64)), const Text('Today’s booster is complete!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), Text('Score ${booster['score'] ?? 0}/3 • +${booster['xp_earned'] ?? 0} XP'), const Text('Come back tomorrow for another challenge.')]));
      final questions = List<Map<String, dynamic>>.from(booster['questions'] ?? const []);
      return ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Answer three questions to earn up to 45 XP.', style: TextStyle(fontSize: 18)),
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
      ]);
    }),
  );
}
