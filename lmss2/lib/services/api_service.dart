import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/admin_dashboard_response.dart';
import '../models/login_response.dart';
import '../models/participant_dashboard_response.dart';
import '../models/trainer_dashboard_response.dart';
import '../models/course_model.dart';

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

  Future<List<CourseSummary>> getCourses() async {
    final response = await _dio.get('/courses/list');
    final data = response.data as Map<String, dynamic>;
    return (data['courses'] as List<dynamic>? ?? const [])
        .map((item) => CourseSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CourseDetail> getCourseDetail(int courseId) async {
    final response = await _dio.get('/courses/detail', queryParameters: {'course_id': courseId});
    return CourseDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getChapterContent(int chapterId) async {
    final response = await _dio.get('/courses/chapter_content', queryParameters: {'chapter_id': chapterId});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveChapterProgress({
    required int chapterId,
    required int progress,
    required int timeSpent,
  }) async {
    final response = await _dio.post('/courses/save_progress', data: {
      'chapter_id': chapterId,
      'progress': progress,
      'time_spent': timeSpent,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getTrainerCourses() async {
    final response = await _dio.get('/trainer/courses');
    return List<Map<String, dynamic>>.from(response.data['courses'] ?? const []);
  }

  Future<int> createTrainerCourse(Map<String, dynamic> data) async {
    final response = await _dio.post('/trainer/courses', data: data);
    return response.data['id'] as int;
  }

  Future<void> updateTrainerCourse(int id, Map<String, dynamic> data) async =>
      _dio.put('/trainer/courses/$id', data: data);

  Future<void> deleteTrainerCourse(int id) async => _dio.delete('/trainer/courses/$id');

  Future<int> duplicateTrainerCourse(int id) async {
    final response = await _dio.post('/trainer/courses/$id/duplicate');
    return response.data['id'] as int;
  }

  Future<List<Map<String, dynamic>>> getTrainerModules(int courseId) async {
    final response = await _dio.get('/trainer/courses/$courseId/modules');
    return List<Map<String, dynamic>>.from(response.data['modules'] ?? const []);
  }

  Future<int> createTrainerModule(int courseId, Map<String, dynamic> data) async {
    final response = await _dio.post('/trainer/courses/$courseId/modules', data: data);
    return response.data['id'] as int;
  }

  Future<void> updateTrainerModule(int id, Map<String, dynamic> data) async =>
      _dio.put('/trainer/modules/$id', data: data);

  Future<void> deleteTrainerModule(int id) async => _dio.delete('/trainer/modules/$id');

  Future<List<Map<String, dynamic>>> getTrainerChapters(int moduleId) async {
    final response = await _dio.get('/trainer/modules/$moduleId/chapters');
    return List<Map<String, dynamic>>.from(response.data['chapters'] ?? const []);
  }

  Future<int> createTrainerChapter(int moduleId, Map<String, dynamic> data) async {
    final response = await _dio.post('/trainer/modules/$moduleId/chapters', data: data);
    return response.data['id'] as int;
  }

  Future<void> deleteTrainerChapter(int id) async => _dio.delete('/trainer/chapters/$id');

  Future<Map<String, dynamic>> getTrainerAssignmentOptions() async {
    final response = await _dio.get('/trainer/assignment-options');
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getTrainerAssignments({int page = 1, int limit = 50}) async {
    final response = await _dio.get('/trainer/assignments', queryParameters: {'page': page, 'limit': limit});
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> bulkAssignTrainerCourses({
    required List<int> courseIds,
    List<int> userIds = const [],
    List<String> storeCodes = const [],
    List<String> managerNames = const [],
  }) async {
    final response = await _dio.post('/trainer/assignments/bulk', data: {
      'course_ids': courseIds,
      'user_ids': userIds,
      'store_codes': storeCodes,
      'manager_names': managerNames,
    });
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> removeTrainerAssignment(int id) async => _dio.delete('/trainer/assignments/$id');

  Future<List<Map<String, dynamic>>> getTrainerQuizzes() async {
    final response = await _dio.get('/trainer/quizzes');
    return List<Map<String, dynamic>>.from(response.data['quizzes'] ?? const []);
  }

  Future<int> createTrainerQuiz(Map<String, dynamic> data) async {
    final response = await _dio.post('/trainer/quizzes', data: data);
    return response.data['id'] as int;
  }

  Future<void> updateTrainerQuiz(int id, Map<String, dynamic> data) async => _dio.put('/trainer/quizzes/$id', data: data);
  Future<void> deleteTrainerQuiz(int id) async => _dio.delete('/trainer/quizzes/$id');
  Future<int> duplicateTrainerQuiz(int id) async {
    final response = await _dio.post('/trainer/quizzes/$id/duplicate');
    return response.data['id'] as int;
  }

  Future<List<Map<String, dynamic>>> getTrainerQuestions(int quizId) async {
    final response = await _dio.get('/trainer/quizzes/$quizId/questions');
    return List<Map<String, dynamic>>.from(response.data['questions'] ?? const []);
  }

  Future<int> createTrainerQuestion(int quizId, Map<String, dynamic> data) async {
    final response = await _dio.post('/trainer/quizzes/$quizId/questions', data: data);
    return response.data['id'] as int;
  }

  Future<void> updateTrainerQuestion(int id, Map<String, dynamic> data) async => _dio.put('/trainer/questions/$id', data: data);
  Future<void> deleteTrainerQuestion(int id) async => _dio.delete('/trainer/questions/$id');

  Future<List<Map<String, dynamic>>> getQuizRetakeRequests() async {
    final response = await _dio.get('/trainer/quiz-retake-requests');
    return List<Map<String, dynamic>>.from(response.data['requests'] ?? const []);
  }

  Future<void> processQuizRetakeRequest(int id, bool approve) async =>
      _dio.post('/trainer/quiz-retake-requests/$id/${approve ? 'approve' : 'reject'}');

  Future<Map<String, dynamic>> getTrainerRoleplayOptions() async {
    final response = await _dio.get('/trainer/roleplay-options');
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getTrainerRoleplays({String? status, int page = 1, int limit = 100}) async {
    final response = await _dio.get('/trainer/roleplays', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      'page': page,
      'limit': limit,
    });
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> assignTrainerRoleplays({
    required String weekNo,
    required String day,
    required String scenarioTopic,
    List<int> userIds = const [],
    List<String> storeCodes = const [],
    List<String> managerNames = const [],
  }) async {
    final response = await _dio.post('/trainer/roleplays/assign', data: {
      'week_no': weekNo, 'day': day, 'scenario_topic': scenarioTopic,
      'user_ids': userIds, 'store_codes': storeCodes, 'manager_names': managerNames,
    });
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> evaluateTrainerRoleplay(int id, double score, String notes) async =>
      _dio.post('/trainer/roleplays/$id/evaluate', data: {'observer_score': score, 'debrief_notes': notes});
  Future<void> deleteTrainerRoleplay(int id) async => _dio.delete('/trainer/roleplays/$id');

  Future<Map<String, dynamic>> getParticipantRoleplays() async {
    final response = await _dio.get('/roleplays/list');
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> submitParticipantRoleplay(int id, String videoUrl, String remarks) async =>
      _dio.post('/roleplays/$id/submit', data: {'video_url': videoUrl, 'participant_remarks': remarks});

  Future<Map<String, dynamic>> getTaskOptions() async =>
      Map<String, dynamic>.from((await _dio.get('/trainer/task-options')).data);
  Future<Map<String, dynamic>> getTrainerTasks() async =>
      Map<String, dynamic>.from((await _dio.get('/trainer/tasks')).data);
  Future<void> createTask(Map<String, dynamic> data) async => _dio.post('/trainer/tasks', data: data);
  Future<void> deleteTask(int id) async => _dio.delete('/trainer/tasks/$id');
  Future<void> reviewTaskCompletion(int id, String status) async =>
      _dio.post('/trainer/task-completions/$id/review', data: {'status': status});
  Future<List<Map<String, dynamic>>> getParticipantTasks() async {
    final response = await _dio.get('/tasks/list');
    return List<Map<String, dynamic>>.from(response.data['tasks'] ?? const []);
  }
  Future<void> submitTaskText(int id, String text) async =>
      _dio.post('/tasks/$id/submit/text', data: {'text_response': text});
  Future<void> submitTaskPhoto(int id, List<int> bytes, String contentType) async =>
      _dio.post('/tasks/$id/submit/photo', data: bytes, options: Options(contentType: contentType));
  String taskEvidenceUrl(int completionId) =>
      'https://lms2.yuktaa.com/api/v2/tasks/evidence/$completionId';
}
