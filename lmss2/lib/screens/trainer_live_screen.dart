import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../widgets/lms_shell.dart';
import '../widgets/lms_states.dart';

class TrainerLiveScreen extends StatefulWidget {
  const TrainerLiveScreen({super.key});
  @override State<TrainerLiveScreen> createState()=>_TrainerLiveScreenState();
}

class _TrainerLiveScreenState extends State<TrainerLiveScreen>{
  final api=ApiService(); bool loading=true; String? error; List<Map<String,dynamic>> sessions=[];
  @override void initState(){super.initState();load();}
  Future<void> load()async{setState((){loading=true;error=null;});try{sessions=await api.getLiveSessions();}catch(e){error=e.toString();}if(mounted)setState(()=>loading=false);}
  Future<void> create()async{
    try{
      final options=await api.getLiveOptions(); if(!mounted)return;
      final result=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>_StartLiveDialog(options:options));
      if(result==null)return; final created=await api.startLiveSession(result); if(!mounted)return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Session started. Access code: ${created['access_code']}')));
      context.go('/trainer/live/${created['id']}');
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Could not start session: $e')));}
  }
  Future<void> remove(int id)async{await api.deleteLiveSession(id);await load();}
  @override
  Widget build(BuildContext context) => LmsShell(
        title: 'Live Quizzes',
        rootPage: true,
        actions: [
            IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
            IconButton(onPressed: create, icon: const Icon(Icons.add)),
          ],
        floatingActionButton: FloatingActionButton.extended(
          onPressed: create,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start session'),
        ),
        body: loading
            ? const LmsLoadingState(label: 'Loading live quizzes')
            : error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : sessions.isEmpty
                    ? LmsEmptyState(icon: Icons.wifi_tethering, title: 'No live sessions yet', message: 'Start a live quiz when your participants are ready.', action: FilledButton.icon(onPressed: create, icon: const Icon(Icons.play_arrow), label: const Text('Start session')))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sessions.length,
                        itemBuilder: (_, index) {
                          final session = sessions[index];
                          final active = session['status'].toString().toLowerCase() == 'active';
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Icon(active ? Icons.wifi_tethering : Icons.check)),
                              title: Text(session['quiz_title']?.toString() ?? 'Quiz'),
                              subtitle: Text("Code ${session['access_code']} • ${session['participant_count'] ?? 0} joined • ${active ? 'Active' : 'Closed'}"),
                              onTap: () => context.go('/trainer/live/${session['id']}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'report') context.go('/trainer/live/${session['id']}?report=1');
                                  if (value == 'delete') await remove(session['id'] as int);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'report', child: Text('View report')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      );
}

class _StartLiveDialog extends StatefulWidget{final Map<String,dynamic> options;const _StartLiveDialog({required this.options});@override State<_StartLiveDialog> createState()=>_StartLiveDialogState();}
class _StartLiveDialogState extends State<_StartLiveDialog>{int? quiz;int seconds=30;final users=<int>{};final stores=<String>{};final managers=<String>{};
  @override Widget build(BuildContext context){final quizzes=List<Map<String,dynamic>>.from(widget.options['quizzes']??const[]);final participants=List<Map<String,dynamic>>.from(widget.options['participants']??const[]);return AlertDialog(title:const Text('Start live quiz'),content:SizedBox(width:620,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<int>(initialValue:quiz,decoration:const InputDecoration(labelText:'Quiz'),items:quizzes.map((q)=>DropdownMenuItem(value:q['id'] as int,child:Text(q['title'].toString()))).toList(),onChanged:(v)=>setState(()=>quiz=v)),TextFormField(initialValue:'30',keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Seconds per question'),onChanged:(v)=>seconds=int.tryParse(v)??30),const SizedBox(height:12),ExpansionTile(title:Text('Participants (${users.length})'),children:participants.map((p)=>CheckboxListTile(value:users.contains(p['id']),title:Text(p['full_name'].toString()),subtitle:Text([p['store_code'],p['reporting_manager_name']].where((e)=>e!=null&&e.toString().isNotEmpty).join(' • ')),onChanged:(v)=>setState(()=>v==true?users.add(p['id'] as int):users.remove(p['id'])))).toList()),_stringChoices('Stores',widget.options['store_codes'],stores),_stringChoices('Managers',widget.options['manager_names'],managers)]))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:quiz==null?null:()=>Navigator.pop(context,{'quiz_id':quiz,'time_limit':seconds.clamp(5,600),'user_ids':users.toList(),'store_codes':stores.toList(),'manager_names':managers.toList()}),child:const Text('Start'))]);}
  Widget _stringChoices(String title,dynamic source,Set<String> selected)=>ExpansionTile(title:Text('$title (${selected.length})'),children:List<String>.from(source??const[]).map((value)=>CheckboxListTile(value:selected.contains(value),title:Text(value),onChanged:(v)=>setState(()=>v==true?selected.add(value):selected.remove(value)))).toList());
}

class LiveHostScreen extends StatefulWidget{final int sessionId;final bool report;const LiveHostScreen({super.key,required this.sessionId,this.report=false});@override State<LiveHostScreen> createState()=>_LiveHostScreenState();}
class _LiveHostScreenState extends State<LiveHostScreen>{final api=ApiService();Timer? timer;Map<String,dynamic>? data;String? error;bool busy=false;
  @override void initState(){super.initState();load();if(!widget.report)timer=Timer.periodic(const Duration(seconds:2),(_)=>load(silent:true));}
  @override void dispose(){timer?.cancel();super.dispose();}
  Future<void> load({bool silent=false})async{try{data=widget.report?await api.getLiveReport(widget.sessionId):await api.getLiveHostState(widget.sessionId);error=null;}catch(e){error=e.toString();}if(mounted)setState((){});}
  Future<void> act(Future<void> Function() fn)async{setState(()=>busy=true);try{await fn();await load();}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}if(mounted)setState(()=>busy=false);}
  @override Widget build(BuildContext context){final session=Map<String,dynamic>.from(data?['session']??{});final questions=List<Map<String,dynamic>>.from(data?['questions']??const[]);final board=List<Map<String,dynamic>>.from(data?['leaderboard']??const[]);final current=(session['current_question_index'] as num?)?.toInt()??0;final active=session['status']?.toString().toLowerCase()=='active';return Scaffold(appBar:AppBar(title:Text(widget.report?'Live Quiz Report':'Host Live Quiz')),body:error!=null?Center(child:Text(error!,style:const TextStyle(color:Colors.red))):data==null?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[Card(child:Padding(padding:const EdgeInsets.all(20),child:Wrap(spacing:32,runSpacing:12,children:[Text(session['quiz_title']?.toString()??'',style:Theme.of(context).textTheme.headlineSmall),SelectableText('Access code: ${session['access_code']}',style:Theme.of(context).textTheme.headlineSmall),Chip(label:Text(session['status'].toString())),Text('${board.length} joined')]))),if(!widget.report&&active)Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(current==0?'Waiting to begin':'Question $current of ${questions.length}',style:Theme.of(context).textTheme.titleLarge),if(current>0&&current<=questions.length)...[const SizedBox(height:8),Text(questions[current-1]['text'].toString()),const SizedBox(height:12)],Wrap(spacing:8,children:[FilledButton.icon(onPressed:busy||current>=questions.length?null:()=>act(()=>api.openLiveQuestion(widget.sessionId,current+1)),icon:const Icon(Icons.skip_next),label:Text(current==0?'Start first question':'Next question')),OutlinedButton(onPressed:busy||current==0?null:()=>act(()=>api.closeLiveQuestion(widget.sessionId)),child:const Text('Close question')),FilledButton.tonal(onPressed:busy?null:()=>act(()=>api.closeLiveSession(widget.sessionId)),child:const Text('End session'))])]))),const SizedBox(height:12),Text('Leaderboard',style:Theme.of(context).textTheme.titleLarge),if(board.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Waiting for participants to join.'))else ...board.asMap().entries.map((entry){final p=entry.value;return ListTile(leading:CircleAvatar(child:Text('${entry.key+1}')),title:Text(p['full_name']?.toString()??p['username'].toString()),subtitle:Text('${p['answered']} answered • ${p['correct_answers']} correct'),trailing:Text('${p['points']} pts'));}),if(widget.report)...[const Divider(),Text('${(data?['answers'] as List?)?.length??0} recorded answers')]]));}
}
