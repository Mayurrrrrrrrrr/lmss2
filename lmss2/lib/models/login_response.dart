class LoginResponse {
  final String token;
  final Map<String, dynamic> userProfile;

  LoginResponse({required this.token, required this.userProfile});

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] ?? '',
      userProfile: json['user_profile'] ?? {},
    );
  }
}
