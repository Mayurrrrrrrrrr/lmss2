import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class TrainerQuizzesScreen extends StatefulWidget {
  const TrainerQuizzesScreen({super.key});
  @override State<TrainerQuizzesScreen> createState() => _TrainerQuizzesScreenState();
}

class _TrainerQuizzesScreenState extends State<TrainerQuizzesScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;
  late Future<List<Map<String, dynamic>>> _quizzes, _retakes;
  @override void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); _reload(); }
  @override void dispose() { _tabs.dispose(); super.dispose(); }
  void _reload() => setState(() { _quizzes = _api.getTrainerQuizzes(); _retakes = _api.getQuizRetakeRequests(); });

  Future<Map<String, dynamic>?> _quizDialog([Map<String, dynamic>? quiz]) async {
    final title = TextEditingController(text: quiz?['title']?.toString() ?? '');
    final description = TextEditingController(text: quiz?['quiz_description']?.toString() ?? '');
    final duration = TextEditingController(text: quiz?['duration_value']?.toString() ?? '');
    var durationType = quiz?['duration_type']?.toString() ?? 'No Duration';
    var random = (quiz?['is_random'] ?? 0) == 1 || quiz?['is_random'] == true;
    var retake = (quiz?['allows_retake'] ?? 0) == 1 || quiz?['allows_retake'] == true;
    return showDialog<Map<String, dynamic>>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: Text(quiz == null ? 'Create quiz' : 'Edit quiz'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Quiz title')),
        TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
        DropdownButtonFormField<String>(initialValue: durationType, decoration: const InputDecoration(labelText: 'Duration type'), items: const ['No Duration','Minutes','Hours','Days','Weeks'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => update(() => durationType = value!)),
        if (durationType != 'No Duration') TextField(controller: duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration value')),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: random, title: const Text('Randomize questions'), onChanged: (value) => update(() => random = value)),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: retake, title: const Text('Allow retakes'), onChanged: (value) => update(() => retake = value)),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')), FilledButton(onPressed: () {
        if (title.text.trim().isEmpty) return;
        Navigator.pop(dialogContext, {'title':title.text.trim(),'quiz_description':description.text.trim(),'module_id':quiz?['module_id'],'linked_module_id':quiz?['linked_module_id'],'scheduled_time':quiz?['scheduled_time'],'duration_type':durationType,'duration_value':durationType=='No Duration'?null:int.tryParse(duration.text),'is_random':random,'allows_retake':retake,'quiz_badge_id':quiz?['quiz_badge_id']});
      }, child: const Text('Save'))],
    )));
  }

  Future<void> _save([Map<String, dynamic>? quiz]) async {
    final data = await _quizDialog(quiz); if (data == null) return;
    try { quiz == null ? await _api.createTrainerQuiz(data) : await _api.updateTrainerQuiz(quiz['id'] as int, data); _reload(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Widget _quizTab() => FutureBuilder<List<Map<String, dynamic>>>(future: _quizzes, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError) return Center(child: Text('Could not load quizzes: ${snapshot.error}'));
    final quizzes = snapshot.data ?? const [];
    if (quizzes.isEmpty) return const Center(child: Text('No quizzes yet. Create your first quiz.'));
    return ListView.separated(padding: const EdgeInsets.all(20), itemCount: quizzes.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (context, index) {
      final quiz = quizzes[index];
      return Card(child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.quiz)),
        title: Text(quiz['title']?.toString() ?? 'Untitled quiz'),
        subtitle: Text('${quiz['question_count'] ?? 0} questions - ${quiz['participant_count'] ?? 0} learners'),
        onTap: () => context.go('/trainer/quizzes/${quiz['id']}?title=${Uri.encodeComponent(quiz['title']?.toString() ?? '')}'),
        trailing: PopupMenuButton<String>(onSelected: (action) async {
          if (action == 'edit') await _save(quiz);
          if (action == 'duplicate') { await _api.duplicateTrainerQuiz(quiz['id'] as int); _reload(); }
          if (action == 'delete') { await _api.deleteTrainerQuiz(quiz['id'] as int); _reload(); }
        }, itemBuilder: (_) => const [PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'duplicate',child:Text('Duplicate')),PopupMenuItem(value:'delete',child:Text('Delete'))]),
      ));
    });
  });

  Widget _retakeTab() => FutureBuilder<List<Map<String, dynamic>>>(future: _retakes, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError) return Center(child: Text('Could not load requests: ${snapshot.error}'));
    final requests = snapshot.data ?? const [];
    if (requests.isEmpty) return const Center(child: Text('No retake requests.'));
    return ListView(padding: const EdgeInsets.all(20), children: requests.map((request) {
      final pending = request['status']?.toString().toLowerCase() == 'pending';
      return Card(child: ListTile(leading: const Icon(Icons.replay), title: Text(request['quiz_title']?.toString() ?? ''), subtitle: Text('${request['full_name'] ?? request['username']} - ${request['status']}'), trailing: pending ? Wrap(children: [IconButton(tooltip:'Approve',icon:const Icon(Icons.check,color:Colors.green),onPressed:()async{await _api.processQuizRetakeRequest(request['id'] as int,true);_reload();}),IconButton(tooltip:'Reject',icon:const Icon(Icons.close,color:Colors.red),onPressed:()async{await _api.processQuizRetakeRequest(request['id'] as int,false);_reload();})]) : null));
    }).toList());
  });

  @override Widget build(BuildContext context) => Scaffold(
    drawer: const AppSidebar(role: 'trainer'),
    appBar: AppBar(title: const Text('Quiz Authoring'), bottom: TabBar(controller: _tabs, tabs: const [Tab(text:'Quizzes'),Tab(text:'Retake requests')]), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => _save(), icon: const Icon(Icons.add), label: const Text('New quiz')),
    body: TabBarView(controller: _tabs, children: [_quizTab(), _retakeTab()]),
  );
}
