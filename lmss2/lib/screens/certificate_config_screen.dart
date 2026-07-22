import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class CertificateConfigScreen extends StatefulWidget {
  final int courseId; final String courseTitle;
  const CertificateConfigScreen({super.key,required this.courseId,required this.courseTitle});
  @override State<CertificateConfigScreen> createState()=>_CertificateConfigScreenState();
}
class _CertificateConfigScreenState extends State<CertificateConfigScreen>{
 final api=ApiService(); bool loading=true,saving=false;String? error;
 final textKeys=['logo_path','title','subtitle','presentation_text','body_text','signatory','signatory_title'];
 final numberKeys=['logo_width','logo_top','logo_left','title_top','subtitle_top','recipient_top','text_top','footer_top'];
 final controls=<String,TextEditingController>{};
 @override void initState(){super.initState();load();}
 @override void dispose(){for(final c in controls.values)c.dispose();super.dispose();}
 Future<void> load()async{try{final d=await api.getCertificateConfig(widget.courseId);for(final key in [...textKeys,...numberKeys]){controls.putIfAbsent(key,()=>TextEditingController());controls[key]!.text=d[key]?.toString()??'';}error=null;}catch(e){error=e.toString();}if(mounted)setState(()=>loading=false);}
 Future<void> save()async{setState(()=>saving=true);try{final data=<String,dynamic>{};for(final k in textKeys)data[k]=controls[k]!.text.trim().isEmpty?null:controls[k]!.text.trim();for(final k in numberKeys)data[k]=int.tryParse(controls[k]!.text)??0;await api.saveCertificateConfig(widget.courseId,data);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Certificate design saved.')));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}if(mounted)setState(()=>saving=false);}
 String label(String key)=>key.split('_').map((p)=>p.isEmpty?p:'${p[0].toUpperCase()}${p.substring(1)}').join(' ');
 @override Widget build(BuildContext context)=>Scaffold(drawer:const AppSidebar(role:'trainer'),appBar:AppBar(title:Text('Certificate — ${widget.courseTitle}'),actions:[TextButton(onPressed:()async{await api.resetCertificateConfig(widget.courseId);await load();},child:const Text('Reset defaults'))]),body:loading?const Center(child:CircularProgressIndicator()):error!=null?Center(child:Text('Could not load certificate design: $error')):ListView(padding:const EdgeInsets.all(24),children:[const Text('Certificate content',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:12),...textKeys.map((k)=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:controls[k],maxLines:k=='body_text'?3:1,decoration:InputDecoration(labelText:label(k),border:const OutlineInputBorder())))),const SizedBox(height:12),const Text('Layout offsets',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:12),Wrap(spacing:12,runSpacing:12,children:numberKeys.map((k)=>SizedBox(width:210,child:TextField(controller:controls[k],keyboardType:TextInputType.number,decoration:InputDecoration(labelText:label(k),border:const OutlineInputBorder())))).toList()),const SizedBox(height:24),Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save),label:Text(saving?'Saving…':'Save certificate design')))]));
}
