class UserModel {
  final int id;
  final String username;
  final String? fullName;
  final String role;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.username,
    this.fullName,
    required this.role,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      role: json['role'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
