import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class TrainerCourseBuilderScreen extends StatefulWidget {
  final int courseId; final String title;
  const TrainerCourseBuilderScreen({super.key, required this.courseId, required this.title});
  @override State<TrainerCourseBuilderScreen> createState() => _TrainerCourseBuilderScreenState();
}
class _TrainerCourseBuilderScreenState extends State<TrainerCourseBuilderScreen> {
  final _api=ApiService(); late Future<List<Map<String,dynamic>>> _modules;
  @override void initState(){super.initState();_reload();}
  void _reload()=>setState(()=>_modules=_api.getTrainerModules(widget.courseId));
  Future<String?> _ask(String heading,String label,{String initial=''}) { final c=TextEditingController(text:initial); return showDialog<String>(context:context,builder:(x)=>AlertDialog(title:Text(heading),content:TextField(controller:c,autofocus:true,decoration:InputDecoration(labelText:label)),actions:[TextButton(onPressed:()=>Navigator.pop(x),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,c.text.trim()),child:const Text('Save'))])); }
  Future<void> _addModule() async { final title=await _ask('Add module','Module title'); if(title==null||title.isEmpty)return; await _api.createTrainerModule(widget.courseId,{'title':title,'sequence_order':100}); _reload(); }
  Future<void> _editModule(Map<String,dynamic> module) async { final title=await _ask('Edit module','Module title',initial:module['title']?.toString()??'');if(title==null||title.isEmpty)return;await _api.updateTrainerModule(module['id'] as int,{'title':title,'sequence_order':(module['sequence_order'] as num?)?.toInt()??100});_reload(); }
  Future<void> _chapterDialog(int moduleId,[Map<String,dynamic>? existing]) async {
    final title=TextEditingController(text:existing?['title']?.toString()??''),content=TextEditingController(text:existing?['content_path']?.toString()??''); String type=existing?['content_type']?.toString()??'html';
    final data=await showDialog<Map<String,dynamic>>(context:context,builder:(x)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(title:Text(existing==null?'Add chapter':'Edit chapter'),content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'Chapter title')),DropdownButtonFormField<String>(initialValue:type,items:const ['html','youtube','pdf','word','ppt','video','audio','image','txt'].map((v)=>DropdownMenuItem(value:v,child:Text(v.toUpperCase()))).toList(),onChanged:(v)=>setLocal(()=>type=v!),decoration:const InputDecoration(labelText:'Content type')),TextField(controller:content,maxLines:3,decoration:const InputDecoration(labelText:'Content, URL, or uploaded-file URL'))])),actions:[TextButton(onPressed:()=>Navigator.pop(x),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,{'title':title.text.trim(),'content_type':type,'content_path':content.text.trim(),'sequence_order':(existing?['sequence_order'] as num?)?.toInt()??100,'duration_seconds':(existing?['duration_seconds'] as num?)?.toInt()??60}),child:const Text('Save'))])));
    if(data==null||data['title'].toString().isEmpty||data['content_path'].toString().isEmpty)return;if(existing==null){await _api.createTrainerChapter(moduleId,data);}else{await _api.updateTrainerChapter(existing['id'] as int,data);}_reload();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: const AppSidebar(role: 'trainer'),
    appBar: AppBar(
      title: Text(widget.title.isEmpty ? 'Course builder' : widget.title),
      actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _addModule,
      icon: const Icon(Icons.add),
      label: const Text('Add module'),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _modules,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) return Center(child: Text('${snapshot.error}'));
        final modules = snapshot.data ?? const [];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Modules & chapters', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...modules.map((module) => Card(
              child: ExpansionTile(
                title: Text(module['title']?.toString() ?? ''),
                subtitle: Text('${module['chapter_count'] ?? 0} chapters'),
                trailing: IconButton(tooltip:'Edit module',icon:const Icon(Icons.edit_outlined),onPressed:()=>_editModule(module)),
                children: [
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _api.getTrainerChapters(module['id'] as int),
                    builder: (context, chaptersSnapshot) {
                      if (!chaptersSnapshot.hasData) {
                        return const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator());
                      }
                      return Column(children: [
                        ...(chaptersSnapshot.data ?? const []).map((chapter) => ListTile(
                          leading: const Icon(Icons.description),
                          title: Text(chapter['title']?.toString() ?? ''),
                          subtitle: Text(chapter['content_type']?.toString().toUpperCase() ?? ''),
                          trailing: Wrap(children:[IconButton(tooltip:'Edit chapter',icon:const Icon(Icons.edit_outlined),onPressed:()=>_chapterDialog(module['id'] as int,chapter)),IconButton(tooltip:'Delete chapter',icon: const Icon(Icons.delete_outline),onPressed: () async { await _api.deleteTrainerChapter(chapter['id'] as int); _reload(); })]),
                        )),
                        ListTile(leading: const Icon(Icons.add), title: const Text('Add chapter'), onTap: () => _chapterDialog(module['id'] as int)),
                        ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete module'), onTap: () async { await _api.deleteTrainerModule(module['id'] as int); _reload(); }),
                      ]);
                    },
                  ),
                ],
              ),
            )),
          ],
        );
      },
    ),
  );
}
