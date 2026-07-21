import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/static_page_model.dart';

class StaticPagesProvider with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));

  StaticPagesProvider() {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = (await SharedPreferences.getInstance()).getString('jwt_token');
      if (token != null && token.isNotEmpty) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
  }
  
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

  Future<void> addPage(StaticPageModel page) async {
    await _dio.post('admin/pages', data: {'title': page.title, 'slug': page.slug, 'content': page.content, 'is_active': page.isActive});
    await fetchPages();
  }

  Future<void> updatePage(StaticPageModel updatedPage) async {
    await _dio.put('admin/pages/${updatedPage.id}', data: {'title': updatedPage.title, 'slug': updatedPage.slug, 'content': updatedPage.content, 'is_active': updatedPage.isActive});
    await fetchPages();
  }

  Future<void> deletePage(int id) async {
    await _dio.delete('admin/pages/$id');
    await fetchPages();
  }
}
