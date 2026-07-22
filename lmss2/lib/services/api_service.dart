import 'package:dio/dio.dart';
import 'dart:typed_data';
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

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/auth/me');
    return Map<String, dynamic>.from(response.data['user'] ?? const {});
  }

  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    String? email,
    String? phone,
  }) async {
    final response = await _dio.put('/auth/profile', data: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
    });
    return Map<String, dynamic>.from(response.data['user'] ?? const {});
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _dio.post('/auth/change_password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
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

  Future<void> updateTrainerChapter(int id, Map<String, dynamic> data) async =>
      _dio.put('/trainer/chapters/$id', data: data);

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

  Future<Map<String, dynamic>> getTrainerGamification() async {
    final results = await Future.wait([_dio.get('/trainer/badges'), _dio.get('/trainer/rewards'), _dio.get('/trainer/points-settings')]);
    return {'badges': results[0].data['badges'], 'rewards': results[1].data['rewards'], 'redemptions': results[1].data['redemptions'], 'settings': results[2].data['settings']};
  }
  Future<void> saveBadge(Map<String, dynamic> data, [int? id]) async =>
      id == null ? _dio.post('/trainer/badges', data: data) : _dio.put('/trainer/badges/$id', data: data);
  Future<void> deleteBadge(int id) async => _dio.delete('/trainer/badges/$id');
  Future<void> createReward(Map<String, dynamic> data) async => _dio.post('/trainer/rewards', data: data);
  Future<void> deleteReward(int id) async => _dio.delete('/trainer/rewards/$id');
  Future<void> updateRedemption(int id, String status) async =>
      _dio.post('/trainer/redemptions/$id/status', data: {'status': status});
  Future<void> updatePointsSettings(Map<String, String> settings) async =>
      _dio.put('/trainer/points-settings', data: {'settings': settings});
  Future<Map<String, dynamic>> getRewards() async => Map<String, dynamic>.from((await _dio.get('/rewards')).data);
  Future<void> redeemReward(int id) async => _dio.post('/rewards/redeem', data: {'reward_id': id});
  Future<List<Map<String, dynamic>>> getMyBadges() async =>
      List<Map<String, dynamic>>.from((await _dio.get('/badges/mine')).data['badges'] ?? const []);
  Future<Map<String, dynamic>> getLeaderboard({String type = 'individual', String season = 'month'}) async =>
      Map<String, dynamic>.from((await _dio.get('/leaderboard', queryParameters: {'leaderboard_type': type, 'season': season})).data);
  Future<List<Map<String, dynamic>>> getCertificates() async =>
      List<Map<String, dynamic>>.from((await _dio.get('/certificates')).data['certificates'] ?? const []);
  Future<Map<String, dynamic>> getCertificate(int courseId) async =>
      Map<String, dynamic>.from((await _dio.get('/certificates/$courseId')).data);
  Future<Map<String, dynamic>> getCertificateConfig(int courseId) async =>
      Map<String, dynamic>.from((await _dio.get('/trainer/courses/$courseId/certificate-config')).data);
  Future<void> saveCertificateConfig(int courseId, Map<String, dynamic> data) async =>
      _dio.put('/trainer/courses/$courseId/certificate-config', data: data);
  Future<void> resetCertificateConfig(int courseId) async =>
      _dio.delete('/trainer/courses/$courseId/certificate-config');
  Future<Map<String, dynamic>> getNotificationOptions() async => Map<String, dynamic>.from((await _dio.get('/trainer/notification-options')).data);
  Future<List<Map<String, dynamic>>> getSentNotifications() async => List<Map<String, dynamic>>.from((await _dio.get('/trainer/notifications')).data['history'] ?? const []);
  Future<Map<String, dynamic>> sendNotification(Map<String, dynamic> data) async => Map<String, dynamic>.from((await _dio.post('/trainer/notifications', data: data)).data);
  Future<void> nudgeAssignment(int id) async => _dio.post('/trainer/assignments/$id/nudge');
  Future<Map<String, dynamic>> getNotifications() async => Map<String, dynamic>.from((await _dio.get('/notifications')).data);
  Future<void> markNotificationRead({int? id, bool all = false}) async => _dio.post('/notifications/read', data: {'id': id, 'all': all});
  Future<Map<String, dynamic>> getReportOptions() async => Map<String, dynamic>.from((await _dio.get('/reports/options')).data);
  Future<Map<String, dynamic>> getReports({required DateTime from, required DateTime to, String? store, String? city, String? manager, int? courseId}) async =>
      Map<String, dynamic>.from((await _dio.get('/reports', queryParameters: {'date_from': from.toIso8601String().substring(0,10), 'date_to': to.toIso8601String().substring(0,10), if(store!=null&&store.isNotEmpty)'store_code':store, if(city!=null&&city.isNotEmpty)'city':city, if(manager!=null&&manager.isNotEmpty)'manager_name':manager, if(courseId!=null)'course_id':courseId})).data);
  Future<Map<String,dynamic>> getDailyBooster() async=>Map<String,dynamic>.from((await _dio.get('/daily-booster')).data);
  Future<Map<String,dynamic>> submitDailyBooster(Map<int,int> answers) async=>Map<String,dynamic>.from((await _dio.post('/daily-booster',data:{'answers':answers.map((k,v)=>MapEntry(k.toString(),v))})).data);
  Future<Map<String,dynamic>> getTrainerBooster() async=>Map<String,dynamic>.from((await _dio.get('/trainer/booster')).data);
  Future<void> createBoosterQuestion(Map<String,dynamic> data)async=>_dio.post('/trainer/booster/questions',data:data);
  Future<void> deleteBoosterQuestion(int id)async=>_dio.delete('/trainer/booster/questions/$id');
  Future<void> linkBoosterQuiz(int id)async=>_dio.post('/trainer/booster/quizzes/$id');
  Future<void> unlinkBoosterQuiz(int id)async=>_dio.delete('/trainer/booster/quizzes/$id');
  Future<Map<String,dynamic>> getMilestonesKudos()async=>Map<String,dynamic>.from((await _dio.get('/trainer/milestones-kudos')).data);
  Future<void> createMilestone(Map<String,dynamic> data)async=>_dio.post('/trainer/milestones',data:data);
  Future<void> deleteMilestone(int id)async=>_dio.delete('/trainer/milestones/$id');
  Future<void> awardKudos(int userId,int points,String description)async=>_dio.post('/trainer/kudos',data:{'user_id':userId,'points':points,'description':description});
  Future<Map<String,dynamic>> getIntegrations()async=>Map<String,dynamic>.from((await _dio.get('/trainer/integrations')).data);
  Future<void> saveIntegrations(Map<String,dynamic> data)async=>_dio.post('/trainer/integrations',data:data);
  Future<Map<String,dynamic>> getAppVersions()async=>Map<String,dynamic>.from((await _dio.get('/trainer/app-versions')).data);
  Future<Map<String,dynamic>> getAppConfig()async=>Map<String,dynamic>.from((await _dio.get('/app-config')).data);
  Future<void> saveAppConfig(Map<String,dynamic> data)async=>_dio.put('/admin/app-config',data:data);
  Future<Map<String,dynamic>> getLiveOptions() async => Map<String,dynamic>.from((await _dio.get('/live/trainer/options')).data);
  Future<List<Map<String,dynamic>>> getLiveSessions() async => List<Map<String,dynamic>>.from((await _dio.get('/live/trainer/sessions')).data['sessions'] ?? const []);
  Future<Map<String,dynamic>> startLiveSession(Map<String,dynamic> data) async => Map<String,dynamic>.from((await _dio.post('/live/trainer/sessions',data:data)).data);
  Future<Map<String,dynamic>> getLiveHostState(int id) async => Map<String,dynamic>.from((await _dio.get('/live/trainer/sessions/$id')).data);
  Future<void> openLiveQuestion(int id,int index) async => _dio.post('/live/trainer/sessions/$id/question',data:{'index':index});
  Future<void> closeLiveQuestion(int id) async => _dio.post('/live/trainer/sessions/$id/close-question');
  Future<void> closeLiveSession(int id) async => _dio.post('/live/trainer/sessions/$id/close');
  Future<void> deleteLiveSession(int id) async => _dio.delete('/live/trainer/sessions/$id');
  Future<Map<String,dynamic>> getLiveReport(int id) async => Map<String,dynamic>.from((await _dio.get('/live/trainer/sessions/$id/report')).data);
  Future<Map<String,dynamic>> joinLiveSession(String code) async => Map<String,dynamic>.from((await _dio.post('/live/participant/join',data:{'access_code':code})).data);
  Future<Map<String,dynamic>> getLiveParticipantState(int id) async => Map<String,dynamic>.from((await _dio.get('/live/participant/sessions/$id')).data);
  Future<Map<String,dynamic>> submitLiveAnswer(int id,int questionId,int optionId) async => Map<String,dynamic>.from((await _dio.post('/live/participant/sessions/$id/answer',data:{'question_id':questionId,'option_id':optionId})).data);
  Future<Map<String,dynamic>> getAiOptions() async=>Map<String,dynamic>.from((await _dio.get('/ai/trainer/options')).data);
  Future<String> generateCourseDescription(String title,String audience) async=>(await _dio.post('/ai/trainer/course-description',data:{'title':title,'audience':audience})).data['description'].toString();
  Future<Map<String,dynamic>> generateAiQuestions(int quizId,int count,{bool save=false}) async=>Map<String,dynamic>.from((await _dio.post('/ai/trainer/questions',data:{'quiz_id':quizId,'count':count,'save':save})).data);
  Future<Map<String,dynamic>> tagAiDifficulty(int quizId) async=>Map<String,dynamic>.from((await _dio.post('/ai/trainer/tag-difficulty',data:{'quiz_id':quizId})).data);
  Future<Map<String,dynamic>> getAiRisk(int userId) async=>Map<String,dynamic>.from((await _dio.post('/ai/trainer/risk-score',data:{'user_id':userId})).data);
  Future<Map<String,dynamic>> getKnowledgeGaps({int? userId,String? storeCode}) async=>Map<String,dynamic>.from((await _dio.post('/ai/trainer/knowledge-gaps',data:{'user_id':userId,'store_code':storeCode})).data);
  Future<Map<String,dynamic>> createAiNudge(int userId,String context,{bool send=false}) async=>Map<String,dynamic>.from((await _dio.post('/ai/trainer/nudge',data:{'user_id':userId,'context':context,'send_notification':send})).data);
  Future<Map<String,dynamic>> getAiRecommendations() async=>Map<String,dynamic>.from((await _dio.get('/ai/participant/recommendations')).data);
  Future<String> askAi(int chapterId,String question) async=>(await _dio.post('/ai/participant/ask',data:{'chapter_id':chapterId,'question':question})).data['answer'].toString();
  Future<Map<String,dynamic>> getAiTakeaways(int chapterId) async=>Map<String,dynamic>.from((await _dio.post('/ai/participant/takeaways',data:{'chapter_id':chapterId})).data);
  Future<Map<String,dynamic>> getAiHints(int attemptId) async=>Map<String,dynamic>.from((await _dio.post('/ai/participant/hints',data:{'attempt_id':attemptId})).data);
  Future<List<int>> exportQuizQuestions(int quizId) async=>List<int>.from((await _dio.get('/trainer/quizzes/$quizId/questions/export',options:Options(responseType:ResponseType.bytes))).data);
  Future<Map<String,dynamic>> importQuizQuestions(int quizId,List<int> bytes) async=>Map<String,dynamic>.from((await _dio.post('/trainer/quizzes/$quizId/questions/import',data:Uint8List.fromList(bytes),options:Options(contentType:'text/csv'))).data);
  Future<List<int>> exportReportCsv({required String type,required DateTime from,required DateTime to,String? store,String? city,String? manager,int? courseId}) async=>List<int>.from((await _dio.get('/reports/export',queryParameters:{'report_type':type,'date_from':from.toIso8601String().substring(0,10),'date_to':to.toIso8601String().substring(0,10),if(store!=null&&store.isNotEmpty)'store_code':store,if(city!=null&&city.isNotEmpty)'city':city,if(manager!=null&&manager.isNotEmpty)'manager_name':manager,if(courseId!=null)'course_id':courseId},options:Options(responseType:ResponseType.bytes))).data);
  Future<List<Map<String,dynamic>>> searchParticipantContent(String query) async=>List<Map<String,dynamic>>.from((await _dio.get('/participant/search',queryParameters:{'q':query})).data['results']??const[]);
  Future<List<Map<String,dynamic>>> getPublicPages() async=>List<Map<String,dynamic>>.from((await _dio.get('/participant/pages')).data['pages']??const[]);
  Future<Map<String,dynamic>> getPublicPage(String slug) async=>Map<String,dynamic>.from((await _dio.get('/participant/pages/$slug')).data);
}
