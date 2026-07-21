class CourseSummary {
  final int id;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final int totalChapters;
  final int completedChapters;
  final int progressPercent;

  const CourseSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.totalChapters,
    required this.completedChapters,
    required this.progressPercent,
  });

  factory CourseSummary.fromJson(Map<String, dynamic> json) => CourseSummary(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        thumbnailUrl: json['thumbnail_url'] as String?,
        totalChapters: (json['total_chapters'] as num?)?.toInt() ?? 0,
        completedChapters: (json['completed_chapters'] as num?)?.toInt() ?? 0,
        progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      );
}
class CourseDetail {
  final int id;
  final String title;
  final String description;
  final int assessmentScore;
  final int overallProgress;
  final List<CourseModule> modules;
  final LinkedQuiz? linkedQuiz;

  const CourseDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.assessmentScore,
    required this.overallProgress,
    required this.modules,
    this.linkedQuiz,
  });

  factory CourseDetail.fromJson(Map<String, dynamic> json) {
    final course = json['course'] as Map<String, dynamic>? ?? const {};
    return CourseDetail(
      id: (course['id'] as num).toInt(),
      title: course['title'] as String? ?? '',
      description: course['description'] as String? ?? '',
      assessmentScore: (course['assessment_score'] as num?)?.toInt() ?? 0,
      overallProgress: (course['overall_progress'] as num?)?.toInt() ?? 0,
      modules: (json['modules'] as List<dynamic>? ?? const [])
          .map((item) => CourseModule.fromJson(item as Map<String, dynamic>))
          .toList(),
      linkedQuiz: json['linked_quiz'] == null
          ? null
          : LinkedQuiz.fromJson(json['linked_quiz'] as Map<String, dynamic>),
    );
  }
}

class CourseModule {
  final int id;
  final String title;
  final int sequenceOrder;
  final List<CourseChapter> chapters;

  const CourseModule({required this.id, required this.title, required this.sequenceOrder, required this.chapters});

  factory CourseModule.fromJson(Map<String, dynamic> json) => CourseModule(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        sequenceOrder: (json['sequence_order'] as num?)?.toInt() ?? 0,
        chapters: (json['chapters'] as List<dynamic>? ?? const [])
            .map((item) => CourseChapter.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class CourseChapter {
  final int id;
  final String title;
  final String contentType;
  final String? mediaUrl;
  final bool isCompleted;
  final int progressPercent;

  const CourseChapter({
    required this.id,
    required this.title,
    required this.contentType,
    required this.mediaUrl,
    required this.isCompleted,
    required this.progressPercent,
  });

  factory CourseChapter.fromJson(Map<String, dynamic> json) => CourseChapter(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        contentType: json['content_type'] as String? ?? '',
        mediaUrl: json['media_url'] as String?,
        isCompleted: json['is_completed'] as bool? ?? false,
        progressPercent: (json['progress_percent'] as num?)?.toInt() ?? 0,
      );
}

class LinkedQuiz {
  final int id;
  final String title;
  final int attemptCount;

  const LinkedQuiz({required this.id, required this.title, required this.attemptCount});

  factory LinkedQuiz.fromJson(Map<String, dynamic> json) => LinkedQuiz(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
      );
}
