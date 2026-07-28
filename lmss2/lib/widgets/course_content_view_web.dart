import 'package:flutter/material.dart';

import 'platform_content_view.dart';

Widget buildCourseContentView({
  required String contentType,
  required String? mediaUrl,
  required String? htmlContent,
  required int chapterId,
}) {
  final type = contentType.toLowerCase();
  if (type == 'html' || type == 'txt') {
    return buildEmbeddedContent(
      viewType: 'course-html-$chapterId',
      htmlContent: htmlContent?.trim().isNotEmpty == true
          ? htmlContent!
          : '<p>No content is available.</p>',
    );
  }
  if (mediaUrl == null || mediaUrl.isEmpty) {
    return const Center(child: Text('No media is available for this chapter.'));
  }
  if (type == 'video' || mediaUrl.toLowerCase().endsWith('.mp4')) {
    return buildEmbeddedContent(
      viewType: 'course-video-$chapterId',
      source: mediaUrl,
      video: true,
    );
  }
  return buildEmbeddedContent(
    viewType: 'course-document-$chapterId',
    source: mediaUrl,
  );
}
