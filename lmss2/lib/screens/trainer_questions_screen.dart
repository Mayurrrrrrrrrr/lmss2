import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class TrainerQuestionsScreen extends StatefulWidget {
  final int quizId; final String title;
  const TrainerQuestionsScreen({super.key, required this.quizId, required this.title});
  @override State<TrainerQuestionsScreen> createState() => _TrainerQuestionsScreenState();
}
class _TrainerQuestionsScreenState extends State<TrainerQuestionsScreen> {
  final _api=ApiService(); late Future<List<Map<String,dynamic>>> _questions;
  @override void initState(){super.initState();_reload();}
  void _reload()=>setState(()=>_questions=_api.getTrainerQuestions(widget.quizId));

  Future<Map<String,dynamic>?> _questionDialog([Map<String,dynamic>? question]) async {
    final text=TextEditingController(text:question?['text']?.toString()??'');
    final source=List<Map<String,dynamic>>.from(question?['options']??const []);
    final optionControllers=List.generate(4,(i)=>TextEditingController(text:i<source.length?source[i]['text']?.toString()??'':''));
    var correct=source.indexWhere((o)=>o['is_correct']==true||o['is_correct']==1); if(correct<0)correct=0;
    var difficulty=question?['difficulty']?.toString()??'medium';
    return showDialog<Map<String,dynamic>>(context:context,builder:(dialogContext)=>StatefulBuilder(builder:(context,update)=>AlertDialog(
      title:Text(question==null?'Add question':'Edit question'),
      content:SizedBox(width:600,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:text,maxLines:3,decoration:const InputDecoration(labelText:'Question')),
        DropdownButtonFormField<String>(initialValue:difficulty,items:const ['easy','medium','hard'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v)=>update(()=>difficulty=v!),decoration:const InputDecoration(labelText:'Difficulty')),
        const SizedBox(height:12),const Align(alignment:Alignment.centerLeft,child:Text('Answers (select the correct answer)',style:TextStyle(fontWeight:FontWeight.bold))),
        ...List.generate(4,(i)=>RadioListTile<int>(value:i,groupValue:correct,onChanged:(v)=>update(()=>correct=v!),title:TextField(controller:optionControllers[i],decoration:InputDecoration(labelText:'Option ${i+1}')))),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const Text('Cancel')),FilledButton(onPressed:(){final options=<Map<String,dynamic>>[];for(var i=0;i<optionControllers.length;i++){if(optionControllers[i].text.trim().isNotEmpty)options.add({'text':optionControllers[i].text.trim(),'is_correct':i==correct});}if(text.text.trim().isEmpty||options.length<2||!options.any((o)=>o['is_correct']==true))return;Navigator.pop(dialogContext,{'text':text.text.trim(),'image_path':question?['image_path'],'difficulty':difficulty,'options':options});},child:const Text('Save'))],
    )));
  }
  Future<void> _save([Map<String,dynamic>? question])async{final data=await _questionDialog(question);if(data==null)return;question==null?await _api.createTrainerQuestion(widget.quizId,data):await _api.updateTrainerQuestion(question['id'] as int,data);_reload();}
  Future<void> _importCsv()async{try{final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:const['csv'],withData:true);if(picked==null)return;final bytes=picked.files.single.bytes;if(bytes==null)throw Exception('Could not read the selected file');final result=await _api.importQuizQuestions(widget.quizId,bytes);_reload();if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(result['message'].toString())));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Import failed: $e')));}}
  Future<void> _exportCsv()async{try{final bytes=await _api.exportQuizQuestions(widget.quizId);await FilePicker.platform.saveFile(dialogTitle:'Save question CSV',fileName:'quiz_${widget.quizId}_questions.csv',type:FileType.custom,allowedExtensions:const['csv'],bytes:Uint8List.fromList(bytes));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Export failed: $e')));}}
  @override Widget build(BuildContext context)=>Scaffold(drawer:const AppSidebar(role:'trainer'),appBar:AppBar(title:Text(widget.title.isEmpty?'Quiz questions':widget.title),actions:[IconButton(tooltip:'Import CSV',onPressed:_importCsv,icon:const Icon(Icons.upload_file)),IconButton(tooltip:'Export CSV',onPressed:_exportCsv,icon:const Icon(Icons.download)),IconButton(onPressed:_reload,icon:const Icon(Icons.refresh))]),floatingActionButton:FloatingActionButton.extended(onPressed:()=>_save(),icon:const Icon(Icons.add),label:const Text('Add question')),body:FutureBuilder<List<Map<String,dynamic>>>(future:_questions,builder:(context,snapshot){if(snapshot.connectionState!=ConnectionState.done)return const Center(child:CircularProgressIndicator());if(snapshot.hasError)return Center(child:Text('${snapshot.error}'));final questions=snapshot.data??const[];if(questions.isEmpty)return const Center(child:Text('No questions yet. Import a CSV or add your first question.'));return ListView.builder(padding:const EdgeInsets.all(20),itemCount:questions.length,itemBuilder:(context,index){final q=questions[index];final options=List<Map<String,dynamic>>.from(q['options']??const[]);return Card(child:ExpansionTile(leading:CircleAvatar(child:Text('${index+1}')),title:Text(q['text']?.toString()??''),subtitle:Text(q['difficulty']?.toString()??''),trailing:PopupMenuButton<String>(onSelected:(action)async{if(action=='edit')await _save(q);if(action=='delete'){await _api.deleteTrainerQuestion(q['id'] as int);_reload();}},itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'delete',child:Text('Delete'))]),children:options.map((o)=>ListTile(leading:Icon(o['is_correct']==true?Icons.check_circle:Icons.circle_outlined,color:o['is_correct']==true?Colors.green:null),title:Text(o['text']?.toString()??''))).toList()));});}));
}
