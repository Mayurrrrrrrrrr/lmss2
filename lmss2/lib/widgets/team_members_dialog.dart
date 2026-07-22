import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeamMembersDialog extends StatefulWidget {
  final int managerId;
  final String managerName;

  const TeamMembersDialog({
    super.key,
    required this.managerId,
    required this.managerName,
  });

  @override
  State<TeamMembersDialog> createState() => _TeamMembersDialogState();
}

class _TeamMembersDialogState extends State<TeamMembersDialog> {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));
  bool _isLoading = true;
  String? _error;
  List<dynamic> _teamMembers = [];

  @override
  void initState() {
    super.initState();
    _fetchTeamMembers();
  }

  Future<void> _fetchTeamMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await _dio.get(
        'admin/participants/${widget.managerId}/team',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final dynamic rawData = response.data;
      List<dynamic> list = [];
      if (rawData is List) {
        list = rawData;
      } else if (rawData is Map && rawData.containsKey('participants')) {
        list = rawData['participants'] as List;
      }

      setState(() {
        _teamMembers = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load team members: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 850,
        height: 550,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Subordinate Team Members — ${widget.managerName}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                      : _teamMembers.isEmpty
                          ? const Center(
                              child: Text('No subordinate team members assigned to this manager.'),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SingleChildScrollView(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                                    columns: const [
                                      DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Store Code', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: _teamMembers.map<DataRow>((member) {
                                      return DataRow(
                                        cells: [
                                          DataCell(Text(member['id'].toString())),
                                          DataCell(Text(member['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                                          DataCell(Text(member['full_name'] ?? '')),
                                          DataCell(
                                            Chip(
                                              label: Text((member['role'] ?? 'participant').toUpperCase()),
                                              backgroundColor: Colors.blue.shade50,
                                              labelStyle: const TextStyle(fontSize: 11, color: Colors.blue),
                                            ),
                                          ),
                                          DataCell(Text(member['store_code'] ?? 'N/A')),
                                          DataCell(Text(member['designation'] ?? 'N/A')),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
