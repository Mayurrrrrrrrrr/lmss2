import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';

class UsersProvider with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));
  
  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Mocking the API response for now as per requirements
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
      
      // MOCK DATA including Admin, Trainer, Area Manager, and Participant
      final mockData = [
        {'id': 1, 'username': 'admin_user', 'full_name': 'Super Admin', 'role': 'admin', 'created_at': '2023-01-01T10:00:00Z'},
        {'id': 2, 'username': 'trainer_jane', 'full_name': 'Jane Doe', 'role': 'trainer', 'created_at': '2023-02-15T14:30:00Z'},
        {'id': 3, 'username': 'participant_bob', 'full_name': 'Bob Smith', 'role': 'participant', 'created_at': '2023-03-20T09:15:00Z'},
        {'id': 4, 'username': 'area_mgr_alice', 'full_name': 'Alice Johnson', 'role': 'area_manager', 'created_at': '2023-04-10T11:45:00Z'},
      ];

      _users = mockData.map((json) => UserModel.fromJson(json)).toList();
      
      /* Actual API call scaffolding:
      final response = await _dio.get('/admin/users');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['users'] ?? response.data;
        _users = data.map((json) => UserModel.fromJson(json)).toList();
      } else {
        _errorMessage = 'Failed to load users. Status: ${response.statusCode}';
      }
      */
    } catch (e) {
      _errorMessage = 'Failed to load users: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void deleteUser(int id) {
    // Mock delete
    _users.removeWhere((user) => user.id == id);
    notifyListeners();
  }
}
