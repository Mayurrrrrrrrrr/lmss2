import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/lms_shell.dart';

class TrainerRoleplaysScreen extends StatefulWidget {
  const TrainerRoleplaysScreen({super.key});
  @override State<TrainerRoleplaysScreen> createState() => _TrainerRoleplaysScreenState();
}

class _TrainerRoleplaysScreenState extends State<TrainerRoleplaysScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sessions = [], _participants = [];
  List<String> _stores = [], _managers = [], _topics = [];

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait([_api.getTrainerRoleplays(), _api.getTrainerRoleplayOptions()]);
      final sessionData = values[0], options = values[1];
      if (!mounted) return;
      setState(() {
        _sessions = List<Map<String, dynamic>>.from(sessionData['sessions'] ?? const []);
        _participants = List<Map<String, dynamic>>.from(options['participants'] ?? const []);
        _stores = List<String>.from(options['store_codes'] ?? const []);
        _managers = List<String>.from(options['manager_names'] ?? const []);
        _topics = List<String>.from(options['topics'] ?? const []);
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() { _error = '$e'; _loading = false; }); }
  }

  Future<void> _assignDialog() async {
    final week = TextEditingController(), day = TextEditingController(), topic = TextEditingController();
    String mode = 'individual'; final users = <int>{}; final stores = <String>{}; final managers = <String>{};
    final submitted = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: const Text('Assign roleplay'),
      content: SizedBox(width: 680, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Expanded(child: TextField(controller: week, decoration: const InputDecoration(labelText: 'Week'))), const SizedBox(width: 12), Expanded(child: TextField(controller: day, decoration: const InputDecoration(labelText: 'Day')))]),
        Autocomplete<String>(optionsBuilder: (value) => value.text.isEmpty ? _topics : _topics.where((item) => item.toLowerCase().contains(value.text.toLowerCase())), onSelected: (value) => topic.text = value, fieldViewBuilder: (context, controller, focus, submit) { controller.addListener(() => topic.text = controller.text); return TextField(controller: controller, focusNode: focus, decoration: const InputDecoration(labelText: 'Scenario topic')); }),
        const SizedBox(height: 12),
        SegmentedButton<String>(segments: const [ButtonSegment(value:'individual',label:Text('People')),ButtonSegment(value:'store',label:Text('Stores')),ButtonSegment(value:'manager',label:Text('Managers'))], selected:{mode}, onSelectionChanged:(value)=>update(()=>mode=value.first)),
        const SizedBox(height: 8),
        Container(constraints: const BoxConstraints(maxHeight: 260), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)), child: ListView(children: [
          if (mode == 'individual') ..._participants.map((person) { final id=person['id'] as int; return CheckboxListTile(dense:true,value:users.contains(id),title:Text(person['full_name']?.toString()??person['username']?.toString()??''),subtitle:person['store_code']==null?null:Text(person['store_code'].toString()),onChanged:(v)=>update(()=>v==true?users.add(id):users.remove(id))); }),
          if (mode == 'store') ..._stores.map((value)=>CheckboxListTile(dense:true,value:stores.contains(value),title:Text(value),onChanged:(v)=>update(()=>v==true?stores.add(value):stores.remove(value)))),
          if (mode == 'manager') ..._managers.map((value)=>CheckboxListTile(dense:true,value:managers.contains(value),title:Text(value),onChanged:(v)=>update(()=>v==true?managers.add(value):managers.remove(value)))),
        ])),
      ]))),
      actions: [TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),FilledButton(onPressed:()async{
        if(week.text.trim().isEmpty||day.text.trim().isEmpty||topic.text.trim().isEmpty)return;
        if((mode=='individual'&&users.isEmpty)||(mode=='store'&&stores.isEmpty)||(mode=='manager'&&managers.isEmpty))return;
        await _api.assignTrainerRoleplays(weekNo:week.text.trim(),day:day.text.trim(),scenarioTopic:topic.text.trim(),userIds:mode=='individual'?users.toList():const[],storeCodes:mode=='store'?stores.toList():const[],managerNames:mode=='manager'?managers.toList():const[]);
        if(dialogContext.mounted)Navigator.pop(dialogContext,true);
      },child:const Text('Assign'))],
    )));
    if (submitted == true) await _load();
  }

  Future<void> _evaluate(Map<String, dynamic> session) async {
    double score = 4; final notes = TextEditingController();
    final saved = await showDialog<bool>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,update)=>AlertDialog(title:const Text('Evaluate roleplay'),content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,children:[Text('${session['full_name']} - ${session['scenario_topic']}'),Slider(value:score,min:1,max:5,divisions:8,label:score.toStringAsFixed(1),onChanged:(v)=>update(()=>score=v)),TextField(controller:notes,maxLines:4,decoration:const InputDecoration(labelText:'Debrief notes'))])),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),FilledButton(onPressed:()async{await _api.evaluateTrainerRoleplay(session['id'] as int,score,notes.text.trim());if(dialogContext.mounted)Navigator.pop(dialogContext,true);},child:const Text('Save evaluation'))])));
    if(saved==true)await _load();
  }
  Color _statusColor(String value) => switch(value.toLowerCase()) {'completed'=>Colors.green,'pending'=>Colors.orange,_=>Colors.blue};

  @override Widget build(BuildContext context) => LmsShell(
    title: 'Roleplay Tracker',
    rootPage: true,
    actions: [IconButton(tooltip: 'Refresh roleplays', onPressed:_load,icon:const Icon(Icons.refresh))],
    floatingActionButton: FloatingActionButton.extended(onPressed:_assignDialog,icon:const Icon(Icons.add),label:const Text('Assign roleplay')),
    body: _loading?const Center(child:CircularProgressIndicator()):_error!=null?Center(child:Text('Could not load roleplays: $_error')):ListView.builder(padding:const EdgeInsets.all(20),itemCount:_sessions.length,itemBuilder:(context,index){final item=_sessions[index];final status=item['status']?.toString()??'Assigned';return Card(child:ListTile(leading:CircleAvatar(backgroundColor:_statusColor(status),child:const Icon(Icons.video_camera_front,color:Colors.white)),title:Text(item['scenario_topic']?.toString()??''),subtitle:Text('${item['full_name']??item['username']} - ${item['week_no']} / ${item['day']}\n$status${item['observer_score']!=null?' - Score ${item['observer_score']}/5':''}'),isThreeLine:true,trailing:PopupMenuButton<String>(onSelected:(action)async{if(action=='evaluate')await _evaluate(item);if(action=='delete'){await _api.deleteTrainerRoleplay(item['id'] as int);await _load();}},itemBuilder:(_)=>[if(status.toLowerCase()=='pending')const PopupMenuItem(value:'evaluate',child:Text('Evaluate')),const PopupMenuItem(value:'delete',child:Text('Delete'))])));}),
  );
}
