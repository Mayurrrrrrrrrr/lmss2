import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final _registeredViewTypes = <String>{};

Widget buildEmbeddedContent({
  required String viewType,
  String? source,
  String? htmlContent,
  bool video = false,
  Widget? fallback,
}) {
  if (_registeredViewTypes.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      if (video) {
        return web.HTMLVideoElement()
          ..src = source ?? ''
          ..controls = true
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
      }
      final frame = web.HTMLIFrameElement()
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      if (htmlContent != null) {
        frame.srcdoc = htmlContent.toJS;
      } else {
        frame.src = source ?? '';
      }
      return frame;
    });
  }
  return HtmlElementView(viewType: viewType);
}
