import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/department_model.dart';

class DepartmentsProvider with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));

  DepartmentsProvider() {
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

  
  List<DepartmentModel> _departments = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<DepartmentModel> get departments => _departments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDepartments() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.get('/admin/departments');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['departments'] ?? response.data;
        _departments = data.map((json) => DepartmentModel.fromJson(json)).toList();
      } else {
        _errorMessage = 'Failed to load departments. Status: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Failed to load departments: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void deleteDepartment(int id) {
    _departments.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}
