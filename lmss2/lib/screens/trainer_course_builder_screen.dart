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
  Future<String?> _ask(String heading,String label) { final c=TextEditingController(); return showDialog<String>(context:context,builder:(x)=>AlertDialog(title:Text(heading),content:TextField(controller:c,decoration:InputDecoration(labelText:label)),actions:[TextButton(onPressed:()=>Navigator.pop(x),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,c.text.trim()),child:const Text('Add'))])); }
  Future<void> _addModule() async { final title=await _ask('Add module','Module title'); if(title==null||title.isEmpty)return; await _api.createTrainerModule(widget.courseId,{'title':title,'sequence_order':100}); _reload(); }
  Future<void> _addChapter(int moduleId) async {
    final title=TextEditingController(),content=TextEditingController(); String type='html';
    final data=await showDialog<Map<String,dynamic>>(context:context,builder:(x)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(title:const Text('Add chapter'),content:SizedBox(width:520,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'Chapter title')),DropdownButtonFormField<String>(initialValue:type,items:const ['html','youtube','pdf','ppt','video','audio','image','txt'].map((v)=>DropdownMenuItem(value:v,child:Text(v.toUpperCase()))).toList(),onChanged:(v)=>setLocal(()=>type=v!),decoration:const InputDecoration(labelText:'Content type')),TextField(controller:content,maxLines:3,decoration:const InputDecoration(labelText:'Content, URL, or uploaded-file URL'))])),actions:[TextButton(onPressed:()=>Navigator.pop(x),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(x,{'title':title.text.trim(),'content_type':type,'content_path':content.text.trim(),'sequence_order':100,'duration_seconds':60}),child:const Text('Add'))])));
    if(data==null||data['title'].toString().isEmpty||data['content_path'].toString().isEmpty)return; await _api.createTrainerChapter(moduleId,data); _reload();
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
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async { await _api.deleteTrainerChapter(chapter['id'] as int); _reload(); },
                          ),
                        )),
                        ListTile(leading: const Icon(Icons.add), title: const Text('Add chapter'), onTap: () => _addChapter(module['id'] as int)),
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
