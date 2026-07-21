import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class TrainerAiToolsScreen extends StatefulWidget {
  const TrainerAiToolsScreen({super.key});

  @override
  State<TrainerAiToolsScreen> createState() => _TrainerAiToolsScreenState();
}

class _TrainerAiToolsScreenState extends State<TrainerAiToolsScreen> {
  final api = ApiService();
  final title = TextEditingController();
  final audience = TextEditingController(text: 'retail and sales professionals');
  final nudgeContext = TextEditingController();
  Map<String, dynamic>? options;
  bool busy = false;
  String? error;
  dynamic output;
  int? quizId;
  int? userId;
  String? store;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    title.dispose();
    audience.dispose();
    nudgeContext.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      options = await api.getAiOptions();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() {});
  }

  Future<void> run(Future<dynamic> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      output = await action();
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final quizzes = List<Map<String, dynamic>>.from(options?['quizzes'] ?? const []);
    final people = List<Map<String, dynamic>>.from(options?['participants'] ?? const []);
    final stores = List<String>.from(options?['store_codes'] ?? const []);
    return Scaffold(
      drawer: const AppSidebar(role: 'trainer'),
      appBar: AppBar(title: const Text('AI Toolkit')),
      body: options == null && error == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (error != null)
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(error!, style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                _section(context, 'Course description', [
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Course title', border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                  TextField(controller: audience, decoration: const InputDecoration(labelText: 'Audience', border: OutlineInputBorder())),
                  FilledButton(
                    onPressed: busy || title.text.trim().isEmpty ? null : () => run(() => api.generateCourseDescription(title.text.trim(), audience.text.trim())),
                    child: const Text('Generate description'),
                  ),
                ]),
                _section(context, 'Quiz creation', [
                  DropdownButtonFormField<int>(
                    initialValue: quizId,
                    decoration: const InputDecoration(labelText: 'Quiz', border: OutlineInputBorder()),
                    items: quizzes.map((q) => DropdownMenuItem(value: q['id'] as int, child: Text(q['title'].toString()))).toList(),
                    onChanged: (value) => setState(() => quizId = value),
                  ),
                  Wrap(spacing: 8, children: [
                    FilledButton(onPressed: busy || quizId == null ? null : () => run(() => api.generateAiQuestions(quizId!, 5)), child: const Text('Preview 5 questions')),
                    FilledButton.tonal(onPressed: busy || quizId == null ? null : () => run(() => api.generateAiQuestions(quizId!, 5, save: true)), child: const Text('Generate and save')),
                    OutlinedButton(onPressed: busy || quizId == null ? null : () => run(() => api.tagAiDifficulty(quizId!)), child: const Text('Tag missing difficulty')),
                  ]),
                ]),
                _section(context, 'Participant coaching', [
                  DropdownButtonFormField<int>(
                    initialValue: userId,
                    decoration: const InputDecoration(labelText: 'Participant', border: OutlineInputBorder()),
                    items: people.map((p) => DropdownMenuItem(value: p['id'] as int, child: Text(p['full_name'].toString()))).toList(),
                    onChanged: (value) => setState(() => userId = value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: store,
                    decoration: const InputDecoration(labelText: 'Store knowledge-gap analysis', border: OutlineInputBorder()),
                    items: stores.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                    onChanged: (value) => setState(() => store = value),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: nudgeContext, maxLines: 2, decoration: const InputDecoration(labelText: 'Nudge context', border: OutlineInputBorder())),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton(onPressed: busy || userId == null ? null : () => run(() => api.getAiRisk(userId!)), child: const Text('Assess risk')),
                    OutlinedButton(onPressed: busy || userId == null ? null : () => run(() => api.getKnowledgeGaps(userId: userId)), child: const Text('Participant gaps')),
                    OutlinedButton(onPressed: busy || store == null ? null : () => run(() => api.getKnowledgeGaps(storeCode: store)), child: const Text('Store gaps')),
                    FilledButton.tonal(onPressed: busy || userId == null ? null : () => run(() => api.createAiNudge(userId!, nudgeContext.text)), child: const Text('Draft nudge')),
                    FilledButton.tonal(onPressed: busy || userId == null ? null : () => run(() => api.createAiNudge(userId!, nudgeContext.text, send: true)), child: const Text('Draft and notify')),
                  ]),
                ]),
                if (busy) const LinearProgressIndicator(),
                if (output != null) _section(context, 'Latest result', [SelectableText(const JsonEncoder.withIndent('  ').convert(output))]),
              ],
            ),
    );
  }

  Widget _section(BuildContext context, String heading, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(heading, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...children.map((widget) => Padding(padding: const EdgeInsets.only(bottom: 10), child: widget)),
            ],
          ),
        ),
      );
}
