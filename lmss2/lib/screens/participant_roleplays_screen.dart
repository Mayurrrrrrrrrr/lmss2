import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class ParticipantRoleplaysScreen extends StatefulWidget {
  const ParticipantRoleplaysScreen({super.key});
  @override State<ParticipantRoleplaysScreen> createState()=>_ParticipantRoleplaysScreenState();
}
class _ParticipantRoleplaysScreenState extends State<ParticipantRoleplaysScreen> with SingleTickerProviderStateMixin {
  final _api=ApiService(); late TabController _tabs; late Future<Map<String,dynamic>> _data;
  @override void initState(){super.initState();_tabs=TabController(length:3,vsync:this);_reload();}
  @override void dispose(){_tabs.dispose();super.dispose();}
  void _reload()=>setState(()=>_data=_api.getParticipantRoleplays());
  Future<void> _submit(Map<String,dynamic> item)async{final url=TextEditingController(),remarks=TextEditingController();final saved=await showDialog<bool>(context:context,builder:(dialogContext)=>AlertDialog(title:const Text('Submit roleplay'),content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,children:[Text(item['scenario_topic']?.toString()??''),TextField(controller:url,decoration:const InputDecoration(labelText:'Video URL (HTTPS)')),TextField(controller:remarks,maxLines:3,decoration:const InputDecoration(labelText:'Remarks'))])),actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext,false),child:const Text('Cancel')),FilledButton(onPressed:()async{final value=url.text.trim();if(!value.startsWith('https://')&&!value.startsWith('http://'))return;await _api.submitParticipantRoleplay(item['id'] as int,value,remarks.text.trim());if(dialogContext.mounted)Navigator.pop(dialogContext,true);},child:const Text('Submit'))]));if(saved==true)_reload();}
  Widget _list(List<Map<String,dynamic>> items,String state)=>items.isEmpty?Center(child:Text('No $state roleplays.')):ListView.builder(padding:const EdgeInsets.all(20),itemCount:items.length,itemBuilder:(context,index){final item=items[index];return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.video_camera_front)),title:Text(item['scenario_topic']?.toString()??''),subtitle:Text('${item['week_no']} / ${item['day']}${item['observer_score']!=null?'\nScore: ${item['observer_score']}/5':''}${item['debrief_notes']!=null?'\n${item['debrief_notes']}':''}'),isThreeLine:item['observer_score']!=null,trailing:state=='assigned'?FilledButton(onPressed:()=>_submit(item),child:const Text('Submit')):null));});
  @override Widget build(BuildContext context)=>Scaffold(drawer:const AppSidebar(role:'participant'),appBar:AppBar(title:const Text('My Roleplays'),bottom:TabBar(controller:_tabs,tabs:const[Tab(text:'Assigned'),Tab(text:'Pending'),Tab(text:'Completed')]),actions:[IconButton(onPressed:_reload,icon:const Icon(Icons.refresh))]),body:FutureBuilder<Map<String,dynamic>>(future:_data,builder:(context,snapshot){if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(snapshot.hasError)return Center(child:Text('Could not load roleplays: ${snapshot.error}'));final data=snapshot.data??{};List<Map<String,dynamic>> rows(String key)=>List<Map<String,dynamic>>.from(data[key]??const[]);return TabBarView(controller:_tabs,children:[_list(rows('assigned'),'assigned'),_list(rows('pending'),'pending'),_list(rows('completed'),'completed')]);}));
}
