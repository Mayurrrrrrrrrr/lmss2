import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isAuthenticated = false;
  String? _token;
  String? _role;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get role => _role;
  String? get token => _token;

  AuthProvider() {
    _loadAuthStatus();
  }

  Future<void> _loadAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _role = prefs.getString('user_role');
    
    if (_token != null && _token!.isNotEmpty) {
      _isAuthenticated = true;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password, {String appVersion = '1.0.0'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(username, password, appVersion);
      
      _token = response.token;
      _role = response.userProfile['role'] as String?; // Assuming role is returned in userProfile
      _isAuthenticated = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _token!);
      if (_role != null) {
        await prefs.setString('user_role', _role!);
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
    
    _token = null;
    _role = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
