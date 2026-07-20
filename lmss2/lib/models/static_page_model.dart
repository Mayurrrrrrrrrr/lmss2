class StaticPageModel {
  final int id;
  final String title;
  final String slug;
  final String content;
  final bool isActive;
  final DateTime createdAt;

  StaticPageModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.content,
    required this.isActive,
    required this.createdAt,
  });

  factory StaticPageModel.fromJson(Map<String, dynamic> json) {
    return StaticPageModel(
      id: json['id'],
      title: json['title'],
      slug: json['slug'],
      content: json['content'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
