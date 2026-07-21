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
        'admin/page_content',
        queryParameters: {'slug': widget.slug},
      );

      if (response.data['success'] == true) {
        setState(() {
          _pageData = response.data['page'];
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
    final String contentHtml = _pageData?['content'] ?? '';

    if (kIsWeb && contentHtml.isNotEmpty) {
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          final element = html.DivElement()
            ..innerHtml = contentHtml
            ..style.padding = '32px'
            ..style.color = '#111827'
            ..style.fontFamily = 'Roboto, sans-serif'
            ..style.backgroundColor = '#ffffff'
            ..style.maxWidth = '1000px'
            ..style.margin = '0 auto'
            ..style.overflowY = 'auto'
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
              : Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: kIsWeb
                        ? HtmlElementView(viewType: viewType)
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Text(contentHtml),
                          ),
                  ),
                ),
    );
  }
}
