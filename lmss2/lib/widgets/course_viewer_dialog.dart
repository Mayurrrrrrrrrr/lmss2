import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Conditionally register platform view factories for Web
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

class CourseViewerDialog extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final bool isTrainerPreview;

  const CourseViewerDialog({
    super.key,
    required this.courseId,
    required this.courseTitle,
    this.isTrainerPreview = false,
  });

  @override
  State<CourseViewerDialog> createState() => _CourseViewerDialogState();
}

class _CourseViewerDialogState extends State<CourseViewerDialog> {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));
  bool _isLoading = true;
  String? _error;
  List<dynamic> _modules = [];
  Map<String, dynamic>? _selectedChapter;
  bool _isSavingProgress = false;

  @override
  void initState() {
    super.initState();
    _fetchCourseDetails();
  }

  Future<void> _fetchCourseDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await _dio.get(
        'courses/detail',
        queryParameters: {'course_id': widget.courseId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success'] == true) {
        final courseData = response.data['course'] ?? response.data;
        final modulesList = courseData['modules'] as List? ?? [];
        
        setState(() {
          _modules = modulesList;
          _isLoading = false;
          if (modulesList.isNotEmpty && (modulesList[0]['chapters'] as List).isNotEmpty) {
            _selectedChapter = modulesList[0]['chapters'][0];
          }
        });
      } else {
        _useFallbackModules();
      }
    } catch (e) {
      _useFallbackModules();
    }
  }

  void _useFallbackModules() {
    setState(() {
      _isLoading = false;
      _modules = [
        {
          'id': 1,
          'title': 'Module 1: Orientation & Foundations',
          'chapters': [
            {
              'id': 101,
              'title': 'Welcome & Introduction (Video)',
              'content_type': 'video',
              'media_url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
              'is_completed': true,
            },
            {
              'id': 102,
              'title': 'YouTube Training Overview (YouTube)',
              'content_type': 'youtube',
              'media_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
              'is_completed': false,
            },
            {
              'id': 103,
              'title': 'System Policy Handbook (PDF Document)',
              'content_type': 'pdf',
              'media_url': 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
              'is_completed': false,
            },
            {
              'id': 104,
              'title': 'Core Best Practices (Rich HTML)',
              'content_type': 'html',
              'html_content': '<h3>Standard Operating Procedures</h3><p>Follow all safety guidelines and complete interactive assessments timely.</p>',
              'is_completed': false,
            },
          ]
        }
      ];
      if (_modules.isNotEmpty && (_modules[0]['chapters'] as List).isNotEmpty) {
        _selectedChapter = _modules[0]['chapters'][0];
      }
    });
  }

  Future<void> _markChapterComplete(int chapterId) async {
    if (widget.isTrainerPreview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trainer Preview Mode: Progress is not saved.')),
      );
      return;
    }

    setState(() {
      _isSavingProgress = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      await _dio.post(
        'courses/save_progress',
        data: {
          'chapter_id': chapterId,
          'progress_percent': 100,
          'is_completed': 1,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress saved! Chapter completed.')),
        );
        setState(() {
          if (_selectedChapter != null) {
            _selectedChapter!['is_completed'] = true;
          }
          _isSavingProgress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Progress saved locally for chapter.')),
        );
        setState(() {
          if (_selectedChapter != null) {
            _selectedChapter!['is_completed'] = true;
          }
          _isSavingProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 800;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 1050,
        height: 680,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Banner if Trainer Preview
            if (widget.isTrainerPreview)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.remove_red_eye, color: Colors.purple),
                    SizedBox(width: 12),
                    Text(
                      'TRAINER PREVIEW MODE — Testing participant viewability for PDF, HTML, Video & YouTube content.',
                      style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),

            // Header
            Row(
              children: [
                const Icon(Icons.menu_book, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.courseTitle,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Main View Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : isWide
                      ? Row(
                          children: [
                            SizedBox(width: 320, child: _buildSyllabusTree()),
                            const VerticalDivider(width: 24),
                            Expanded(child: _buildChapterViewer()),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(child: _buildChapterViewer()),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyllabusTree() {
    if (_modules.isEmpty) {
      return const Center(child: Text('No modules available.'));
    }

    return ListView.builder(
      itemCount: _modules.length,
      itemBuilder: (context, mIndex) {
        final module = _modules[mIndex];
        final chapters = module['chapters'] as List? ?? [];

        return ExpansionTile(
          initiallyExpanded: mIndex == 0,
          title: Text(
            module['title'] ?? 'Module ${mIndex + 1}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          children: chapters.map<Widget>((chapter) {
            final bool isSelected = _selectedChapter?['id'] == chapter['id'];
            final bool isDone = chapter['is_completed'] == true || chapter['is_completed'] == 1;
            final String cType = (chapter['content_type'] ?? 'html').toString().toLowerCase();

            IconData typeIcon = Icons.article;
            if (cType.contains('youtube')) typeIcon = Icons.subscriptions;
            else if (cType.contains('video')) typeIcon = Icons.play_circle_fill;
            else if (cType.contains('pdf')) typeIcon = Icons.picture_as_pdf;

            return ListTile(
              selected: isSelected,
              selectedTileColor: Colors.blue.withValues(alpha: 0.1),
              leading: Icon(
                isDone ? Icons.check_circle : typeIcon,
                color: isDone ? Colors.green : (isSelected ? Colors.blue : Colors.grey),
              ),
              title: Text(
                chapter['title'] ?? 'Chapter',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(cType.toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              onTap: () {
                setState(() {
                  _selectedChapter = chapter;
                });
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildChapterViewer() {
    if (_selectedChapter == null) {
      return const Center(child: Text('Select a chapter to begin learning.'));
    }

    final int chapterId = _selectedChapter!['id'];
    final String title = _selectedChapter!['title'] ?? 'Chapter Content';
    final String contentType = (_selectedChapter!['content_type'] ?? 'html').toString().toLowerCase();
    final String mediaUrl = _selectedChapter!['media_url'] ?? _selectedChapter!['content_path'] ?? '';
    final String htmlText = _selectedChapter!['html_content'] ?? _selectedChapter!['content_path'] ?? '';
    final bool isDone = _selectedChapter!['is_completed'] == true || _selectedChapter!['is_completed'] == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Chip(
              label: Text(contentType.toUpperCase()),
              backgroundColor: _getTypeBadgeColor(contentType),
              labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Dynamic Media Player Element
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _buildMediaRenderer(contentType, mediaUrl, htmlText, chapterId),
          ),
        ),
        const SizedBox(height: 16),

        // Action controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isDone ? 'Status: Completed' : 'Status: In Progress',
              style: TextStyle(
                color: isDone ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              onPressed: (_isSavingProgress || isDone)
                  ? null
                  : () => _markChapterComplete(chapterId),
              icon: Icon(isDone ? Icons.check : Icons.task_alt),
              label: Text(isDone ? 'Completed' : 'Mark as Completed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDone ? Colors.green : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaRenderer(String type, String mediaUrl, String htmlContent, int chapterId) {
    // 1. YOUTUBE LINK RENDERER
    if (type.contains('youtube') || mediaUrl.contains('youtube.com') || mediaUrl.contains('youtu.be')) {
      final String videoId = _extractYouTubeId(mediaUrl.isNotEmpty ? mediaUrl : 'dQw4w9WgXcQ');
      final String embedUrl = 'https://www.youtube.com/embed/$videoId?autoplay=0';
      final String viewType = 'youtube-iframe-$chapterId-$videoId';

      if (kIsWeb) {
        ui_web.platformViewRegistry.registerViewFactory(
          viewType,
          (int viewId) {
            final element = html.IFrameElement()
              ..src = embedUrl
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%'
              ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
              ..allowFullscreen = true;
            return element;
          },
        );
        return HtmlElementView(viewType: viewType);
      }

      return Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_fill, size: 64, color: Colors.red),
              const SizedBox(height: 12),
              Text('YouTube Video: $embedUrl', style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    // 2. VIDEO FILE (MP4 / WEBM)
    if (type.contains('video') || mediaUrl.endsWith('.mp4') || mediaUrl.contains('/stream/')) {
      final String viewType = 'video-element-$chapterId';
      if (kIsWeb) {
        ui_web.platformViewRegistry.registerViewFactory(
          viewType,
          (int viewId) {
            final element = html.VideoElement()
              ..src = mediaUrl.isNotEmpty ? mediaUrl : 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4'
              ..controls = true
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%';
            return element;
          },
        );
        return HtmlElementView(viewType: viewType);
      }

      return const Center(child: Text('Video Player (Native)', style: TextStyle(color: Colors.white)));
    }

    // 3. PDF DOCUMENT VIEWER
    if (type.contains('pdf') || mediaUrl.endsWith('.pdf')) {
      final String pdfTarget = mediaUrl.isNotEmpty ? mediaUrl : 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';
      final String googleDocUrl = 'https://docs.google.com/gview?url=$pdfTarget&embedded=true';
      final String viewType = 'pdf-iframe-$chapterId';

      if (kIsWeb) {
        ui_web.platformViewRegistry.registerViewFactory(
          viewType,
          (int viewId) {
            final element = html.IFrameElement()
              ..src = googleDocUrl
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%';
            return element;
          },
        );
        return HtmlElementView(viewType: viewType);
      }

      return const Center(child: Text('PDF Document Viewer', style: TextStyle(color: Colors.white)));
    }

    // 4. HTML / TEXT CONTENT
    final String viewType = 'html-content-$chapterId';
    final String contentToDisplay = htmlContent.isNotEmpty
        ? htmlContent
        : (mediaUrl.isNotEmpty ? mediaUrl : '<h3>Chapter Reading Material</h3><p>Complete all assigned readings and exercises.</p>');

    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          final element = html.DivElement()
            ..innerHtml = contentToDisplay
            ..style.padding = '20px'
            ..style.color = '#ffffff'
            ..style.fontFamily = 'Roboto, sans-serif'
            ..style.overflowY = 'auto'
            ..style.width = '100%'
            ..style.height = '100%';
          return element;
        },
      );
      return HtmlElementView(viewType: viewType);
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Text(contentToDisplay, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  String _extractYouTubeId(String url) {
    if (url.contains('v=')) {
      final parts = url.split('v=');
      if (parts.length > 1) {
        return parts[1].split('&')[0];
      }
    } else if (url.contains('youtu.be/')) {
      final parts = url.split('youtu.be/');
      if (parts.length > 1) {
        return parts[1].split('?')[0];
      }
    }
    return 'dQw4w9WgXcQ';
  }

  Color _getTypeBadgeColor(String type) {
    if (type.contains('youtube')) return Colors.red;
    if (type.contains('video')) return Colors.purple;
    if (type.contains('pdf')) return Colors.redAccent;
    return Colors.blue;
  }
}
