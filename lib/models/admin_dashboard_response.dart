class AdminDashboardResponse {
  final bool success;
  final DashboardStats? stats;
  final List<RecentLogin> recentLogins;
  final List<RecentPage> recentPages;

  AdminDashboardResponse({
    required this.success,
    this.stats,
    required this.recentLogins,
    required this.recentPages,
  });

  factory AdminDashboardResponse.fromJson(Map<String, dynamic> json) {
    return AdminDashboardResponse(
      success: json['success'] ?? false,
      stats: json['stats'] != null ? DashboardStats.fromJson(json['stats']) : null,
      recentLogins: (json['recent_logins'] as List<dynamic>?)
              ?.map((e) => RecentLogin.fromJson(e))
              .toList() ??
          [],
      recentPages: (json['recent_pages'] as List<dynamic>?)
              ?.map((e) => RecentPage.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class DashboardStats {
  final int totalUsers;
  final int totalTrainers;
  final int totalParticipants;
  final int newUsers;
  final int newTrainers;
  final int newParticipants;
  final int totalCourses;
  final int newCourses;
  final int totalPages;
  final int newPages;

  DashboardStats({
    required this.totalUsers,
    required this.totalTrainers,
    required this.totalParticipants,
    required this.newUsers,
    required this.newTrainers,
    required this.newParticipants,
    required this.totalCourses,
    required this.newCourses,
    required this.totalPages,
    required this.newPages,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalUsers: json['total_users'] ?? 0,
      totalTrainers: json['total_trainers'] ?? 0,
      totalParticipants: json['total_participants'] ?? 0,
      newUsers: json['new_users'] ?? 0,
      newTrainers: json['new_trainers'] ?? 0,
      newParticipants: json['new_participants'] ?? 0,
      totalCourses: json['total_courses'] ?? 0,
      newCourses: json['new_courses'] ?? 0,
      totalPages: json['total_pages'] ?? 0,
      newPages: json['new_pages'] ?? 0,
    );
  }
}

class RecentLogin {
  final String username;
  final String role;
  final String loginTime;

  RecentLogin({
    required this.username,
    required this.role,
    required this.loginTime,
  });

  factory RecentLogin.fromJson(Map<String, dynamic> json) {
    return RecentLogin(
      username: json['username'] ?? '',
      role: json['role'] ?? '',
      loginTime: json['login_time'] ?? '',
    );
  }
}

class RecentPage {
  final int id;
  final String title;
  final String urlSlug;
  final String createdAt;

  RecentPage({
    required this.id,
    required this.title,
    required this.urlSlug,
    required this.createdAt,
  });

  factory RecentPage.fromJson(Map<String, dynamic> json) {
    return RecentPage(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      urlSlug: json['url_slug'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
