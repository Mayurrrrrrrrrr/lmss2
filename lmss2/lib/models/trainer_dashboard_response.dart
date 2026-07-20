class TrainerDashboardResponse {
  final List<AssignedCourse> assignedCourses;
  final List<UpcomingQuiz> upcomingQuizzes;
  final ProgressMetrics metrics;

  TrainerDashboardResponse({
    required this.assignedCourses,
    required this.upcomingQuizzes,
    required this.metrics,
  });

  factory TrainerDashboardResponse.fromJson(Map<String, dynamic> json) {
    return TrainerDashboardResponse(
      assignedCourses: (json['assigned_courses'] as List?)
              ?.map((e) => AssignedCourse.fromJson(e))
              .toList() ??
          [],
      upcomingQuizzes: (json['upcoming_quizzes'] as List?)
              ?.map((e) => UpcomingQuiz.fromJson(e))
              .toList() ??
          [],
      metrics: ProgressMetrics.fromJson(json['metrics'] ?? {}),
    );
  }
}

class AssignedCourse {
  final String id;
  final String title;
  final int participantCount;
  final double completionRate;

  AssignedCourse({
    required this.id,
    required this.title,
    required this.participantCount,
    required this.completionRate,
  });

  factory AssignedCourse.fromJson(Map<String, dynamic> json) {
    return AssignedCourse(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      participantCount: json['participant_count'] ?? 0,
      completionRate: (json['completion_rate'] ?? 0).toDouble(),
    );
  }
}

class UpcomingQuiz {
  final String id;
  final String title;
  final String scheduledTime;
  final String courseName;

  UpcomingQuiz({
    required this.id,
    required this.title,
    required this.scheduledTime,
    required this.courseName,
  });

  factory UpcomingQuiz.fromJson(Map<String, dynamic> json) {
    return UpcomingQuiz(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      scheduledTime: json['scheduled_time'] ?? '',
      courseName: json['course_name'] ?? '',
    );
  }
}

class ProgressMetrics {
  final int totalParticipants;
  final int activeParticipants;
  final double averageScore;
  final int pendingEvaluations;

  ProgressMetrics({
    required this.totalParticipants,
    required this.activeParticipants,
    required this.averageScore,
    required this.pendingEvaluations,
  });

  factory ProgressMetrics.fromJson(Map<String, dynamic> json) {
    return ProgressMetrics(
      totalParticipants: json['total_participants'] ?? 0,
      activeParticipants: json['active_participants'] ?? 0,
      averageScore: (json['average_score'] ?? 0).toDouble(),
      pendingEvaluations: json['pending_evaluations'] ?? 0,
    );
  }
}
