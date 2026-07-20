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
      // Mock network delay
      await Future.delayed(const Duration(milliseconds: 800));

      // In a real scenario:
      // final response = await _dio.get('admin/participants');
      // final data = response.data['data'] as List;
      // _participants = data.map((e) => Participant.fromJson(e)).toList();

      // Mock Data
      _participants = [
        Participant(
          id: 1,
          username: 'john_doe',
          fullName: 'John Doe',
          storeCode: 'ST001',
          city: 'New York',
          designation: 'Sales Associate',
          department: 'Sales',
          createdAt: '2023-10-01',
          subordinateCount: 0,
        ),
        Participant(
          id: 2,
          username: 'alice_smith',
          fullName: 'Alice Smith',
          storeCode: 'ST002',
          city: 'Los Angeles',
          designation: 'Store Manager',
          department: 'Operations',
          createdAt: '2023-11-15',
          subordinateCount: 5,
        ),
        Participant(
          id: 3,
          username: 'bob_johnson',
          fullName: 'Bob Johnson',
          storeCode: 'ST003',
          city: 'Chicago',
          designation: 'Regional Manager',
          department: 'Management',
          createdAt: '2023-09-10',
          subordinateCount: 12,
        ),
      ];
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
