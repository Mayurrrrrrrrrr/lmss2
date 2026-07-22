import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;

class PublicStaticPageScreen extends StatefulWidget {
  final String slug;

  const PublicStaticPageScreen({
    super.key,
    required this.slug,
  });

  @override
  State<PublicStaticPageScreen> createState() => _PublicStaticPageScreenState();
}

class _PublicStaticPageScreenState extends State<PublicStaticPageScreen> {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _pageData;

  @override
  void initState() {
    super.initState();
    _fetchPageContent();
  }

  Future<void> _fetchPageContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _dio.get(
        'public/pages/${Uri.encodeComponent(widget.slug)}',
      );

      if (response.data is Map && response.data['content'] != null) {
        setState(() {
          _pageData = Map<String, dynamic>.from(response.data);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Page not found.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading page content: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String viewType = 'public-static-page-${widget.slug}';
    final String rawHtml = _pageData?['content'] ?? '';
    final String contentHtml = rawHtml
        .replaceAllMapped(RegExp(r'>rn(\s*)<'), (match) => '>\n${match.group(1) ?? ''}<')
        .replaceAllMapped(RegExp(r'([;{}])rn(\s*)'), (match) => '${match.group(1)}\n${match.group(2) ?? ''}');

    if (kIsWeb && contentHtml.isNotEmpty) {
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          final element = html.IFrameElement()
            ..srcdoc = contentHtml
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';
          return element;
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(_pageData?['title'] ?? 'Page Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(fontSize: 16, color: Colors.red)),
                    ],
                  ),
                )
              : kIsWeb
                  ? HtmlElementView(viewType: viewType)
                  : SingleChildScrollView(padding: const EdgeInsets.all(24), child: Text(contentHtml)),
    );
  }
}
