import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/participant.dart';

class ParticipantsProvider with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));

  ParticipantsProvider() {
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

  
  List<Participant> _participants = [];
  bool _isLoading = false;
  String? _error;

  List<Participant> get participants => _participants;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchParticipants() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _dio.get('admin/participants');
      final dynamic rawData = response.data;
      List<dynamic> data = [];
      if (rawData is List) {
        data = rawData;
      } else if (rawData is Map && rawData.containsKey('participants')) {
        data = rawData['participants'] as List;
      }
      _participants = data.map((e) => Participant.fromJson(e)).toList();
    } catch (e) {
      _error = 'Failed to load participants: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void deleteParticipant(int id) {
    // In a real scenario: _dio.delete('admin/participants/$id');
    _participants.removeWhere((p) => p.id == id);
    notifyListeners();
  }
}
