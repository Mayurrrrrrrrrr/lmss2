class ParticipantDashboardResponse {
  final List<EnrolledCourse> enrolledCourses;
  final List<Certificate> certificates; // Readded to prevent breaking compile in UI screens
  final List<AvailableQuiz> availableQuizzes;
  final List<RecentAchievement> recentAchievements;
  final LeaderboardRank leaderboardRank;

  ParticipantDashboardResponse({
    required this.enrolledCourses,
    required this.certificates,
    required this.availableQuizzes,
    required this.recentAchievements,
    required this.leaderboardRank,
  });

  factory ParticipantDashboardResponse.fromJson(Map<String, dynamic> json) {
    return ParticipantDashboardResponse(
      enrolledCourses: (json['enrolled_courses'] as List<dynamic>?)
              ?.map((e) => EnrolledCourse.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      certificates: (json['certificates'] as List<dynamic>?)
              ?.map((e) => Certificate.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      availableQuizzes: (json['available_quizzes'] as List<dynamic>?)
              ?.map((e) => AvailableQuiz.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      recentAchievements: (json['recent_achievements'] as List<dynamic>?)
              ?.map((e) => RecentAchievement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      leaderboardRank: LeaderboardRank.fromJson(
          json['leaderboard_rank'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class EnrolledCourse {
  final String id;
  final String title;
  final double progress; // 0.0 to 1.0
  final bool hasPendingQuiz;
  final String? thumbnailUrl;

  EnrolledCourse({
    required this.id,
    required this.title,
    required this.progress,
    required this.hasPendingQuiz,
    this.thumbnailUrl,
  });

  factory EnrolledCourse.fromJson(Map<String, dynamic> json) {
    return EnrolledCourse(
      id: json['id'] as String,
      title: json['title'] as String,
      progress: (json['progress'] as num).toDouble(),
      hasPendingQuiz: json['has_pending_quiz'] as bool? ?? false,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }
}

class Certificate {
  final String id;
  final String courseTitle;
  final String issueDate;
  final String downloadUrl;

  Certificate({
    required this.id,
    required this.courseTitle,
    required this.issueDate,
    required this.downloadUrl,
  });

  factory Certificate.fromJson(Map<String, dynamic> json) {
    return Certificate(
      id: json['id'] as String,
      courseTitle: json['course_title'] as String,
      issueDate: json['issue_date'] as String,
      downloadUrl: json['download_url'] as String,
    );
  }
}

class AvailableQuiz {
  final String id;
  final String title;
  final String? dueDate;

  AvailableQuiz({
    required this.id,
    required this.title,
    this.dueDate,
  });

  factory AvailableQuiz.fromJson(Map<String, dynamic> json) {
    return AvailableQuiz(
      id: json['id'] as String,
      title: json['title'] as String,
      dueDate: json['due_date'] as String?,
    );
  }
}

class RecentAchievement {
  final String id;
  final String title;
  final String date;

  RecentAchievement({
    required this.id,
    required this.title,
    required this.date,
  });

  factory RecentAchievement.fromJson(Map<String, dynamic> json) {
    return RecentAchievement(
      id: json['id'] as String,
      title: json['title'] as String,
      date: json['date'] as String? ?? "",
    );
  }
}

class LeaderboardRank {
  final int rank;
  final int points;

  LeaderboardRank({
    required this.rank,
    required this.points,
  });

  factory LeaderboardRank.fromJson(Map<String, dynamic> json) {
    return LeaderboardRank(
      rank: json['rank'] as int? ?? 0,
      points: json['points'] as int? ?? 0,
    );
  }
}
