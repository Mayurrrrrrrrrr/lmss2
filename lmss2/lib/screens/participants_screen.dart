import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/participants_provider.dart';
import '../models/participant.dart';
import '../widgets/team_members_dialog.dart';
import '../widgets/edit_participant_dialog.dart';
import '../widgets/lms_shell.dart';

class ParticipantsScreen extends StatefulWidget {
  const ParticipantsScreen({super.key});

  @override
  State<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends State<ParticipantsScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParticipantsProvider>().fetchParticipants();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParticipantsProvider>();
    
    final filteredParticipants = provider.participants.where((p) {
      final searchLower = _searchQuery.toLowerCase();
      return p.username.toLowerCase().contains(searchLower) ||
          p.fullName.toLowerCase().contains(searchLower) ||
          p.storeCode.toLowerCase().contains(searchLower) ||
          p.city.toLowerCase().contains(searchLower) ||
          p.designation.toLowerCase().contains(searchLower) ||
          p.department.toLowerCase().contains(searchLower);
    }).toList();

    return LmsShell(
      title: 'Manage Participants',
      rootPage: true,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top action bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search Participants...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    // Export logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Export functionality to be implemented')),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    // Add participant logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add Participant clicked')),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Participant'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Data table card
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                color: Colors.white,
                child: provider.isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : provider.error != null
                    ? Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.resolveWith(
                                (states) => Colors.grey.shade50
                              ),
                              dataRowMinHeight: 56,
                              dataRowMaxHeight: 56,
                              columns: const [
                                DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Username', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Store Code', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('City', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Created', style: TextStyle(fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                              rows: filteredParticipants.map((p) => DataRow(
                                cells: [
                                  DataCell(Text(p.id.toString())),
                                  DataCell(Text(p.username, style: const TextStyle(fontWeight: FontWeight.w500))),
                                  DataCell(Text(p.fullName)),
                                  DataCell(Text(p.storeCode)),
                                  DataCell(Text(p.city)),
                                  DataCell(Text(p.designation.isNotEmpty ? p.designation : 'N/A')),
                                  DataCell(Text(p.department.isNotEmpty ? p.department : 'N/A')),
                                  DataCell(Text(p.createdAt, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => TeamMembersDialog(
                                                managerId: p.id,
                                                managerName: p.fullName.isNotEmpty ? p.fullName : p.username,
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.people_outline, size: 18),
                                          label: Text('Team (${p.subordinateCount})'),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => EditParticipantDialog(participant: p),
                                            ).then((updated) {
                                              if (updated == true && context.mounted) {
                                                context.read<ParticipantsProvider>().fetchParticipants();
                                              }
                                            });
                                          },
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          label: const Text('Edit'),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () {
                                            // Delete
                                            _confirmDelete(context, p);
                                          },
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          label: const Text('Delete', style: TextStyle(color: Colors.red)),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ]
                              )).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Participant p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Participant'),
        content: Text('Are you sure you want to delete ${p.username}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ParticipantsProvider>().deleteParticipant(p.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted ${p.username}')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
