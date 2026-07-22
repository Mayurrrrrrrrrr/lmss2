import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/participant.dart';

class EditParticipantDialog extends StatefulWidget {
  final Participant participant;

  const EditParticipantDialog({
    super.key,
    required this.participant,
  });

  @override
  State<EditParticipantDialog> createState() => _EditParticipantDialogState();
}

class _EditParticipantDialogState extends State<EditParticipantDialog> {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _fullNameController;
  late TextEditingController _storeCodeController;
  late TextEditingController _cityController;
  late TextEditingController _designationController;
  late TextEditingController _departmentController;
  late String _selectedRole;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.participant.fullName);
    _storeCodeController = TextEditingController(text: widget.participant.storeCode);
    _cityController = TextEditingController(text: widget.participant.city);
    _designationController = TextEditingController(text: widget.participant.designation);
    _departmentController = TextEditingController(text: widget.participant.department);
    _selectedRole = widget.participant.role;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _storeCodeController.dispose();
    _cityController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      await _dio.put(
        'admin/participants/${widget.participant.id}',
        data: {
          'full_name': _fullNameController.text.trim(),
          'store_code': _storeCodeController.text.trim(),
          'city': _cityController.text.trim(),
          'designation': _designationController.text.trim(),
          'department': _departmentController.text.trim(),
          'role': _selectedRole,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Participant profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update participant: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Participant (${widget.participant.username})',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Enter full name' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _storeCodeController,
                      decoration: const InputDecoration(labelText: 'Store Code', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _designationController,
                      decoration: const InputDecoration(labelText: 'Designation', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _departmentController,
                      decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'participant', child: Text('Participant / Store Employee')),
                  DropdownMenuItem(value: 'area_manager', child: Text('Area Manager / Team Lead')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRole = val);
                },
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveChanges,
                    icon: const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
