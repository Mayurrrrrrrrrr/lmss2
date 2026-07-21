import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/static_page_model.dart';

class StaticPagesProvider with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));
  
  StaticPagesProvider() {
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
  
  List<StaticPageModel> _pages = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<StaticPageModel> get pages => _pages;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPages() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.get('admin/pages');
      final dynamic rawData = response.data;
      List<dynamic> data = [];
      if (rawData is List) {
        data = rawData;
      } else if (rawData is Map && rawData.containsKey('pages')) {
        data = rawData['pages'] as List;
      }
      _pages = data.map((json) => StaticPageModel.fromJson(json)).toList();
    } catch (e) {
      _errorMessage = 'Failed to load static pages: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void addPage(StaticPageModel page) {
    _pages.add(page);
    notifyListeners();
  }

  void updatePage(StaticPageModel updatedPage) {
    final index = _pages.indexWhere((p) => p.id == updatedPage.id);
    if (index != -1) {
      _pages[index] = updatedPage;
      notifyListeners();
    }
  }

  void deletePage(int id) {
    _pages.removeWhere((page) => page.id == id);
    notifyListeners();
  }
}
