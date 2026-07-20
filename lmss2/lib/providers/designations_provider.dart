import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/designation_model.dart';

class DesignationsProvider with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));

  DesignationsProvider() {
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

  
  List<DesignationModel> _designations = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<DesignationModel> get designations => _designations;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDesignations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.get('/admin/designations');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['designations'] ?? response.data;
        _designations = data.map((json) => DesignationModel.fromJson(json)).toList();
      } else {
        _errorMessage = 'Failed to load designations. Status: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Failed to load designations: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void deleteDesignation(int id) {
    _designations.removeWhere((item) => item.id == id);
    notifyListeners();
  }
}
