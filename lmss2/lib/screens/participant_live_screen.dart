import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class ParticipantLiveJoinScreen extends StatefulWidget { const ParticipantLiveJoinScreen({super.key}); @override State<ParticipantLiveJoinScreen> createState() => _ParticipantLiveJoinScreenState(); }
class _ParticipantLiveJoinScreenState extends State<ParticipantLiveJoinScreen> {
  final api = ApiService(); final code = TextEditingController(); bool busy = false; String? error;
  Future<void> join() async { if (code.text.trim().isEmpty) return; setState(() { busy = true; error = null; }); try { final result = await api.joinLiveSession(code.text); if (mounted) context.go('/participant/live/${result['session_id']}'); } catch (e) { error = e.toString(); } if (mounted) setState(() => busy = false); }
  @override void dispose() { code.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(drawer: const AppSidebar(role: 'participant'), appBar: AppBar(title: const Text('Join Live Quiz')), body: Center(child: Card(child: Padding(padding: const EdgeInsets.all(28), child: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.wifi_tethering, size: 64), const SizedBox(height: 16), Text('Enter the access code from your trainer', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center), const SizedBox(height: 20), TextField(controller: code, textCapitalization: TextCapitalization.characters, maxLength: 12, onSubmitted: (_) => join(), decoration: const InputDecoration(labelText: 'Access code', border: OutlineInputBorder())), if (error != null) Text(error!, style: const TextStyle(color: Colors.red)), const SizedBox(height: 12), FilledButton.icon(onPressed: busy ? null : join, icon: busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login), label: const Text('Join session'))]))))));
}

class ParticipantLiveScreen extends StatefulWidget { final int sessionId; const ParticipantLiveScreen({super.key, required this.sessionId}); @override State<ParticipantLiveScreen> createState() => _ParticipantLiveScreenState(); }
class _ParticipantLiveScreenState extends State<ParticipantLiveScreen> {
  final api = ApiService(); Timer? timer; Map<String, dynamic>? data; String? error; int? selected; bool sending = false;
  @override void initState() { super.initState(); load(); timer = Timer.periodic(const Duration(seconds: 2), (_) => load()); }
  @override void dispose() { timer?.cancel(); super.dispose(); }
  Future<void> load() async { try { final next = await api.getLiveParticipantState(widget.sessionId); final oldQuestion = data?['question']?['id']; if (next['question']?['id'] != oldQuestion) selected = null; data = next; error = null; } catch (e) { error = e.toString(); } if (mounted) setState(() {}); }
  Future<void> submit() async { final question = data?['question']; if (selected == null || question == null) return; setState(() => sending = true); try { await api.submitLiveAnswer(widget.sessionId, question['id'] as int, selected!); await load(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } if (mounted) setState(() => sending = false); }
  @override Widget build(BuildContext context) {
    final session = Map<String, dynamic>.from(data?['session'] ?? {}); final question = data?['question'] as Map<String, dynamic>?; final answer = data?['answer'] as Map<String, dynamic>?; final closed = session['status']?.toString().toLowerCase() == 'closed'; final board = List<Map<String, dynamic>>.from(data?['leaderboard'] ?? const []);
    if (error != null) return Scaffold(appBar: AppBar(), body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!, style: const TextStyle(color: Colors.red)), FilledButton(onPressed: load, child: const Text('Retry'))])));
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (closed) return Scaffold(appBar: AppBar(title: Text(session['quiz_title']?.toString() ?? 'Live Quiz')), body: _results(context, board));
    if (question == null) return Scaffold(appBar: AppBar(title: Text(session['quiz_title']?.toString() ?? 'Live Quiz')), body: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.hourglass_top, size: 64), SizedBox(height: 16), Text('Waiting for the trainer to start the next question…')])));
    final locked = answer != null || session['is_question_closed'] == 1;
    return Scaffold(appBar: AppBar(title: Text(session['quiz_title']?.toString() ?? 'Live Quiz')), body: ListView(padding: const EdgeInsets.all(20), children: [Text('Question ${session['current_question_index']} of ${data?['total_questions']}', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 12), Text(question['text'].toString(), style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 20), RadioGroup<int>(groupValue: selected ?? (answer?['selected_option_id'] as int?), onChanged: (value) { if (!locked && value != null) setState(() => selected = value); }, child: Column(children: List<Map<String, dynamic>>.from(question['options'] ?? const []).map((option) => Card(child: RadioListTile<int>(value: option['id'] as int, title: Text(option['text'].toString())))).toList())), if (answer != null) Card(color: (answer['is_correct'] == true ? Colors.green : Colors.orange).withValues(alpha: .12), child: ListTile(leading: Icon(answer['is_correct'] == true ? Icons.check_circle : Icons.info), title: Text(answer['is_correct'] == true ? 'Correct!' : 'Answer recorded'), subtitle: Text('${answer['points_earned']} points'))), if (answer == null) FilledButton(onPressed: sending || selected == null ? null : submit, child: Text(sending ? 'Submitting…' : 'Submit answer'))]));
  }
  Widget _results(BuildContext context, List<Map<String, dynamic>> board) => ListView(padding: const EdgeInsets.all(20), children: [const Icon(Icons.emoji_events, size: 72, color: Colors.amber), Text('Session complete', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 20), ...board.asMap().entries.map((entry) => ListTile(leading: CircleAvatar(child: Text('${entry.key + 1}')), title: Text(entry.value['full_name']?.toString() ?? entry.value['username'].toString()), subtitle: Text('${entry.value['correct_answers']} correct'), trailing: Text('${entry.value['points']} pts')))]);
}
