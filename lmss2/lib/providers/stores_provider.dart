import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/store_model.dart';

class StoresProvider with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));

  StoresProvider() {
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

  
  List<StoreModel> _stores = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<StoreModel> get stores => _stores;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchStores() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.get('/admin/stores');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['stores'] ?? response.data;
        _stores = data.map((json) => StoreModel.fromJson(json)).toList();
      } else {
        _errorMessage = 'Failed to load stores. Status: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Failed to load stores: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void deleteStore(int id) {
    _stores.removeWhere((store) => store.id == id);
    notifyListeners();
  }
}
