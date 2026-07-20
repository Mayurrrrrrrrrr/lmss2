import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/admin_dashboard_response.dart';
import '../models/login_response.dart';
import '../models/participant_dashboard_response.dart';
import '../models/trainer_dashboard_response.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: 'https://lms2.yuktaa.com/api/v2',
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

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
        '/auth/login',
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

  Future<ParticipantDashboardResponse> getParticipantDashboard() async {
    try {
      final response = await _dio.get('/participant/dashboard');
      return ParticipantDashboardResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load participant dashboard data: $e');
    }
  }

  Future<TrainerDashboardResponse> getTrainerDashboard() async {
    try {
      final response = await _dio.get('/trainer/dashboard');
      return TrainerDashboardResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load trainer dashboard data: $e');
    }
  }
}
