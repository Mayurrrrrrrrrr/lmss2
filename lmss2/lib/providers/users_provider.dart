import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UsersProvider with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));

  UsersProvider() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  
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
      final response = await _dio.get('/admin/users');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['users'] ?? response.data;
        _users = data.map((json) => UserModel.fromJson(json)).toList();
      } else {
        _errorMessage = 'Failed to load users. Status: ${response.statusCode}';
      }
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
