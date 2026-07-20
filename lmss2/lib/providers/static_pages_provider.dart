import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/static_page_model.dart';

class StaticPagesProvider with ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));
  
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
      // Mocking the API response for now
      await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
      
      final mockData = [
        {
          'id': 1,
          'title': 'About Us',
          'slug': 'about-us',
          'content': '<h1>About Us</h1><p>Welcome to our LMS platform!</p>',
          'is_active': true,
          'created_at': '2023-01-01T10:00:00Z'
        },
        {
          'id': 2,
          'title': 'Privacy Policy',
          'slug': 'privacy-policy',
          'content': '<h1>Privacy Policy</h1><p>Your data is safe with us.</p>',
          'is_active': true,
          'created_at': '2023-02-15T14:30:00Z'
        },
        {
          'id': 3,
          'title': 'Terms & Conditions',
          'slug': 'terms',
          'content': '<h1>Terms</h1><p>Please read these terms carefully before using the service.</p>',
          'is_active': false,
          'created_at': '2023-03-20T09:15:00Z'
        },
      ];

      _pages = mockData.map((json) => StaticPageModel.fromJson(json)).toList();
      
      /* Actual API call scaffolding:
      final response = await _dio.get('/admin/pages');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['pages'] ?? response.data;
        _pages = data.map((json) => StaticPageModel.fromJson(json)).toList();
      } else {
        _errorMessage = 'Failed to load static pages. Status: ${response.statusCode}';
      }
      */
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
