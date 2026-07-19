import 'package:dio/dio.dart';
import '../models/admin_dashboard_response.dart';
import '../models/login_response.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://lms2.yuktaa.com/api/v2',
    // In a real app, add auth interceptors here
  ));

  Future<AdminDashboardResponse> getAdminDashboard() async {
    try {
      final response = await _dio.get('/admin/dashboard');
      return AdminDashboardResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load dashboard data: $e');
    }
  }

  Future<LoginResponse> login(String username, String password, String appVersion) async {
    try {
      final response = await _dio.post(
        '/login',
        data: {
          'username': username,
          'password': password,
          'app_version': appVersion,
        },
      );

      if (response.statusCode == 200) {
        return LoginResponse.fromJson(response.data);
      } else {
        throw Exception('Failed to login. Status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        throw Exception(e.response?.data['message'] ?? 'Login failed');
      }
      throw Exception('Network error occurred during login');
    }
  }
}
