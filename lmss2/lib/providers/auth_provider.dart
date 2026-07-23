import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isAuthenticated = false;
  String? _token;
  String? _role;
  String? _displayName;
  bool _isImpersonating = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get role => _role;
  String? get token => _token;
  String get displayName => _displayName?.trim().isNotEmpty == true ? _displayName! : 'LMS User';
  bool get isImpersonating => _isImpersonating;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _loadAuthStatus();
  }

  Future<void> _loadAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('jwt_token');
      _role = prefs.getString('user_role');
      _displayName = prefs.getString('display_name');
      _isImpersonating = prefs.getBool('is_impersonating') ?? false;

      if (_token != null && _token!.isNotEmpty) {
        _isAuthenticated = true;
      }
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password, {String appVersion = '1.0.0'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(username, password, appVersion);
      
      _token = response.token;
      _role = response.userProfile['role'] as String?; // Assuming role is returned in userProfile
      _displayName = (response.userProfile['full_name'] ?? response.userProfile['username'])?.toString();
      _isAuthenticated = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _token!);
      if (_role != null) {
        await prefs.setString('user_role', _role!);
      }
      if (_displayName != null) {
        await prefs.setString('display_name', _displayName!);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove('display_name');
    await prefs.remove('is_impersonating');
    await prefs.remove('admin_jwt_token');
    await prefs.remove('admin_user_role');
    await prefs.remove('admin_display_name');
    
    _token = null;
    _role = null;
    _displayName = null;
    _isAuthenticated = false;
    _isImpersonating = false;
    notifyListeners();
  }

  Future<void> impersonate(int userId) async {
    final response = await _apiService.impersonateUser(userId);
    final prefs = await SharedPreferences.getInstance();
    if (!_isImpersonating) {
      await prefs.setString('admin_jwt_token', _token!);
      await prefs.setString('admin_user_role', _role ?? 'admin');
      await prefs.setString('admin_display_name', _displayName ?? 'Admin');
    }
    _token = response.token;
    _role = response.userProfile['role']?.toString().toLowerCase();
    _displayName = (response.userProfile['full_name'] ?? response.userProfile['username'])?.toString();
    _isImpersonating = true;
    await prefs.setString('jwt_token', _token!);
    await prefs.setString('user_role', _role!);
    await prefs.setString('display_name', _displayName ?? 'LMS User');
    await prefs.setBool('is_impersonating', true);
    notifyListeners();
  }

  Future<void> stopImpersonating() async {
    final prefs = await SharedPreferences.getInstance();
    final adminToken = prefs.getString('admin_jwt_token');
    if (adminToken == null || adminToken.isEmpty) {
      await logout();
      return;
    }
    _token = adminToken;
    _role = prefs.getString('admin_user_role') ?? 'admin';
    _displayName = prefs.getString('admin_display_name') ?? 'Admin';
    _isAuthenticated = true;
    _isImpersonating = false;
    await prefs.setString('jwt_token', _token!);
    await prefs.setString('user_role', _role!);
    await prefs.setString('display_name', _displayName!);
    await prefs.remove('is_impersonating');
    await prefs.remove('admin_jwt_token');
    await prefs.remove('admin_user_role');
    await prefs.remove('admin_display_name');
    notifyListeners();
  }

  Future<void> updateDisplayName(String value) async {
    _displayName = value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('display_name', _displayName!);
    notifyListeners();
  }
}
