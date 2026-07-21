import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourseViewerDialog extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  const CourseViewerDialog({
    super.key,
    required this.courseId,
    required this.courseTitle,
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
          // Select first chapter automatically if available
          if (modulesList.isNotEmpty && (modulesList[0]['chapters'] as List).isNotEmpty) {
            _selectedChapter = modulesList[0]['chapters'][0];
          }
        });
      } else {
        setState(() {
          _error = 'Failed to load course structure.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading course details: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markChapterComplete(int chapterId) async {
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
          SnackBar(content: Text('Failed to save progress: $e')),
        );
        setState(() {
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
        width: 1000,
        height: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
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
            const Divider(height: 24),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(_error!, style: const TextStyle(color: Colors.red)))
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

            return ListTile(
              selected: isSelected,
              selectedTileColor: Colors.blue.withValues(alpha: 0.1),
              leading: Icon(
                isDone ? Icons.check_circle : Icons.play_circle_outline,
                color: isDone ? Colors.green : Colors.grey,
              ),
              title: Text(
                chapter['title'] ?? 'Chapter',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
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

    final chapterId = _selectedChapter!['id'];
    final title = _selectedChapter!['title'] ?? 'Chapter Content';
    final isDone = _selectedChapter!['is_completed'] == true || _selectedChapter!['is_completed'] == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_fill, size: 64, color: Colors.white70),
                          SizedBox(height: 8),
                          Text(
                            'Interactive Video / Presentation Player',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Chapter Overview & Notes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Welcome to this learning module. Complete the video and review materials above before marking this chapter as finished.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
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
}
