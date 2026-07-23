import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/lms_shell.dart';
import '../widgets/lms_states.dart';

class TrainerBoosterScreen extends StatefulWidget { const TrainerBoosterScreen({super.key}); @override State<TrainerBoosterScreen> createState() => _TrainerBoosterScreenState(); }
class _TrainerBoosterScreenState extends State<TrainerBoosterScreen> {
  final api = ApiService(); bool loading = true; String? error;
  List<Map<String, dynamic>> questions = [], linked = [], available = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { try { final data = await api.getTrainerBooster(); questions = List<Map<String, dynamic>>.from(data['questions'] ?? const []); linked = List<Map<String, dynamic>>.from(data['linked_quizzes'] ?? const []); available = List<Map<String, dynamic>>.from(data['available_quizzes'] ?? const []); error = null; } catch (e) { error = e.toString(); } if (mounted) setState(() => loading = false); }
  Future<void> add() async {
    final question = TextEditingController(); final options = List.generate(4, (_) => TextEditingController()); var correct = 0;
    final saved = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: const Text('Add booster question'),
      content: SizedBox(width: 520, child: ListView(shrinkWrap: true, children: [
        TextField(controller: question, decoration: const InputDecoration(labelText: 'Question')),
        RadioGroup<int>(groupValue: correct, onChanged: (value) { if (value != null) update(() => correct = value); }, child: Column(children: options.asMap().entries.map((entry) => RadioListTile<int>(value: entry.key, title: TextField(controller: entry.value, decoration: InputDecoration(labelText: 'Option ${entry.key + 1}')))).toList())),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), FilledButton(onPressed: () async { if (question.text.trim().isEmpty || options.any((option) => option.text.trim().isEmpty)) return; await api.createBoosterQuestion({'text': question.text.trim(), 'image_path': null, 'options': options.asMap().entries.map((entry) => {'text': entry.value.text.trim(), 'is_correct': entry.key == correct}).toList()}); if (dialogContext.mounted) Navigator.pop(dialogContext, true); }, child: const Text('Save'))],
    )));
    if (saved == true) { loading = true; await load(); }
  }
  @override Widget build(BuildContext context) => LmsShell(title: 'Brain Booster Questions', rootPage: true, actions: [IconButton(tooltip: 'Refresh question pool', onPressed: load, icon: const Icon(Icons.refresh))], floatingActionButton: FloatingActionButton.extended(onPressed: add, icon: const Icon(Icons.add), label: const Text('Add question')), body: loading ? const LmsLoadingState(label: 'Loading booster questions') : error != null ? LmsErrorState(message: 'We could not load the Booster question pool.', onRetry: load) : ListView(padding: const EdgeInsets.all(20), children: [const Text('Question pool', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), ...questions.map((question) => Card(child: ListTile(title: Text(question['text'].toString()), subtitle: Text(List<Map<String, dynamic>>.from(question['options']).map((option) => '${option['is_correct'] == true ? '✓' : '•'} ${option['text']}').join('\n')), trailing: IconButton(tooltip: 'Delete question', onPressed: () async { await api.deleteBoosterQuestion(question['id'] as int); await load(); }, icon: const Icon(Icons.delete_outline))))), const SizedBox(height: 20), const Text('Linked quiz pools', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), ...linked.map((quiz) => ListTile(title: Text(quiz['title'].toString()), trailing: IconButton(tooltip: 'Unlink quiz', onPressed: () async { await api.unlinkBoosterQuiz(quiz['id'] as int); await load(); }, icon: const Icon(Icons.link_off)))), if (available.isNotEmpty) DropdownButtonFormField<int>(decoration: const InputDecoration(labelText: 'Link another quiz'), items: available.map((quiz) => DropdownMenuItem(value: quiz['id'] as int, child: Text(quiz['title'].toString()))).toList(), onChanged: (id) async { if (id != null) { await api.linkBoosterQuiz(id); await load(); } })]));
}
