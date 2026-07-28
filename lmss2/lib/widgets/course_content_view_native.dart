import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

Widget buildCourseContentView({
  required String contentType,
  required String? mediaUrl,
  required String? htmlContent,
  required int chapterId,
}) {
  final type = contentType.toLowerCase();
  if (type == 'html' || type == 'txt') {
    return _SafeHtmlView(html: htmlContent ?? '');
  }
  if (mediaUrl == null || mediaUrl.isEmpty) {
    return const Center(child: Text('No media is available for this chapter.'));
  }
  if (type == 'pdf' || type == 'ppt' || type == 'pptx' || type == 'word') {
    return PdfViewer.uri(Uri.parse(mediaUrl));
  }
  if (type == 'video' || mediaUrl.toLowerCase().endsWith('.mp4')) {
    return _VideoView(url: mediaUrl);
  }
  if (type == 'image') {
    return InteractiveViewer(
      child: Image.network(mediaUrl, fit: BoxFit.contain),
    );
  }
  return _SafeHtmlView(
    html:
        '<p>This file cannot be previewed safely.</p>'
        '<p><a href="${Uri.encodeFull(mediaUrl)}">Open the original file</a></p>',
  );
}

class _SafeHtmlView extends StatefulWidget {
  final String html;
  const _SafeHtmlView({required this.html});

  @override
  State<_SafeHtmlView> createState() => _SafeHtmlViewState();
}

class _SafeHtmlViewState extends State<_SafeHtmlView> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => request.url == 'about:blank'
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: controller);
}

class _VideoView extends StatefulWidget {
  final String url;
  const _VideoView({required this.url});

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final VideoPlayerController controller;
  late final Future<void> initialized;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    initialized = controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: initialized,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          VideoProgressIndicator(controller, allowScrubbing: true),
          Center(
            child: IconButton.filled(
              iconSize: 42,
              onPressed: () => setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              }),
              icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
          ),
        ],
      );
    },
  );
}
