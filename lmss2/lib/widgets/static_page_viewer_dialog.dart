import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../models/static_page_model.dart';

class StaticPageViewerDialog extends StatelessWidget {
  final StaticPageModel page;

  const StaticPageViewerDialog({
    super.key,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    final String liveUrl = 'https://lms2.yuktaa.com/#/pages/${page.slug}';
    final String viewType = 'static-page-html-${page.id}';

    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(
        viewType,
        (int viewId) {
          final element = html.DivElement()
            ..innerHtml = page.content.isNotEmpty ? page.content : '<h3>${page.title}</h3><p>No content provisioned yet.</p>'
            ..style.padding = '24px'
            ..style.color = '#1f2937'
            ..style.fontFamily = 'Roboto, sans-serif'
            ..style.backgroundColor = '#ffffff'
            ..style.overflowY = 'auto'
            ..style.width = '100%'
            ..style.height = '100%';
          return element;
        },
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 900,
        height: 650,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              children: [
                const Icon(Icons.public, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        page.title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Live Link: $liveUrl',
                        style: const TextStyle(fontSize: 13, color: Colors.blue),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: liveUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Live page link copied to clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.link, size: 18),
                  label: const Text('Copy Link'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Page Body Content
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: kIsWeb
                    ? HtmlElementView(viewType: viewType)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Text(page.content),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close Preview'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
