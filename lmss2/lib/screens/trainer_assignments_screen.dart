import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_sidebar.dart';

class TrainerAssignmentsScreen extends StatefulWidget {
  const TrainerAssignmentsScreen({super.key});
  @override State<TrainerAssignmentsScreen> createState() => _TrainerAssignmentsScreenState();
}

class _TrainerAssignmentsScreenState extends State<TrainerAssignmentsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _courses = [], _participants = [], _assignments = [];
  List<String> _stores = [], _managers = [];
  final Set<int> _courseIds = {}, _userIds = {};
  final Set<String> _storeCodes = {}, _managerNames = {};
  String _targetMode = 'individual';

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final values = await Future.wait([_api.getTrainerCourses(), _api.getTrainerAssignmentOptions(), _api.getTrainerAssignments()]);
      final options = values[1] as Map<String, dynamic>, assignmentData = values[2] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _courses = List<Map<String, dynamic>>.from(values[0] as List);
        _participants = List<Map<String, dynamic>>.from(options['participants'] ?? const []);
        _stores = List<String>.from(options['store_codes'] ?? const []);
        _managers = List<String>.from(options['manager_names'] ?? const []);
        _assignments = List<Map<String, dynamic>>.from(assignmentData['assignments'] ?? const []);
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() { _error = '$e'; _loading = false; }); }
  }

  Future<void> _assign() async {
    if (_courseIds.isEmpty || (_targetMode == 'individual' && _userIds.isEmpty) || (_targetMode == 'store' && _storeCodes.isEmpty) || (_targetMode == 'manager' && _managerNames.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one course and one target.'))); return;
    }
    try {
      final result = await _api.bulkAssignTrainerCourses(courseIds: _courseIds.toList(), userIds: _targetMode == 'individual' ? _userIds.toList() : const [], storeCodes: _targetMode == 'store' ? _storeCodes.toList() : const [], managerNames: _targetMode == 'manager' ? _managerNames.toList() : const []);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${result['assigned']} assigned, ${result['skipped']} already assigned.')));
      _userIds.clear(); _storeCodes.clear(); _managerNames.clear(); await _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Widget _choiceList<T>(List<T> values, Set<T> selected, String Function(T) label) => Container(
    constraints: const BoxConstraints(maxHeight: 260),
    decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
    child: ListView.builder(shrinkWrap: true, itemCount: values.length, itemBuilder: (context, index) {
      final value = values[index];
      return CheckboxListTile(dense: true, value: selected.contains(value), title: Text(label(value)), onChanged: (checked) => setState(() { checked == true ? selected.add(value) : selected.remove(value); }));
    }),
  );

  Widget _participantList() => Container(
    constraints: const BoxConstraints(maxHeight: 260),
    decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)),
    child: ListView(children: _participants.map((participant) {
      final id = participant['id'] as int;
      final name = participant['full_name']?.toString();
      return CheckboxListTile(
        dense: true,
        value: _userIds.contains(id),
        title: Text(name == null || name.isEmpty ? participant['username']?.toString() ?? '' : name),
        subtitle: participant['store_code'] == null ? null : Text(participant['store_code'].toString()),
        onChanged: (checked) => setState(() => checked == true ? _userIds.add(id) : _userIds.remove(id)),
      );
    }).toList()),
  );

  @override Widget build(BuildContext context) => Scaffold(
    drawer: const AppSidebar(role: 'trainer'),
    appBar: AppBar(title: const Text('Course Assignments'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Text('Could not load assignments: $_error')) : ListView(padding: const EdgeInsets.all(20), children: [
      Text('Assign courses', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: LayoutBuilder(builder: (context, box) {
        final narrow = box.maxWidth < 760;
        final targetBox = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('2. Select recipients', style: TextStyle(fontWeight: FontWeight.bold)),
          SegmentedButton<String>(segments: const [ButtonSegment(value:'individual',label:Text('People')),ButtonSegment(value:'store',label:Text('Stores')),ButtonSegment(value:'manager',label:Text('Managers'))],selected:{_targetMode},onSelectionChanged:(v)=>setState(()=>_targetMode=v.first)),
          const SizedBox(height:8),
          if (_targetMode == 'individual') _participantList(),
          if (_targetMode == 'store') _choiceList<String>(_stores,_storeCodes,(v)=>v),
          if (_targetMode == 'manager') _choiceList<String>(_managers,_managerNames,(v)=>v),
        ]);
        Widget fixedCourses() => Container(constraints: const BoxConstraints(maxHeight: 260), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8)), child: ListView(children: _courses.map((c) { final id=c['id'] as int; return CheckboxListTile(dense:true,value:_courseIds.contains(id),title:Text(c['title']?.toString()??''),onChanged:(v)=>setState(()=>v==true?_courseIds.add(id):_courseIds.remove(id))); }).toList()));
        final left=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('1. Select courses',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:8),fixedCourses()]);
        final content=narrow?Column(children:[left,const SizedBox(height:18),targetBox]):Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:left),const SizedBox(width:20),Expanded(child:targetBox)]);
        return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[content,const SizedBox(height:16),Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:_assign,icon:const Icon(Icons.send),label:const Text('Assign selected courses')))]);
      }))),
      const SizedBox(height: 24), Text('Current assignments', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 8),
      if (_assignments.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No assignments yet.'))),
      ..._assignments.map((a) => Card(child: ListTile(leading: const Icon(Icons.assignment_turned_in), title: Text(a['course_title']?.toString() ?? ''), subtitle: Text('${a['full_name'] ?? a['username']} - Assigned ${a['assigned_date'] ?? ''}'), trailing: IconButton(tooltip:'Remove assignment',icon:const Icon(Icons.delete_outline),onPressed:() async { await _api.removeTrainerAssignment(a['id'] as int); await _load(); })))),
    ]),
  );
}
