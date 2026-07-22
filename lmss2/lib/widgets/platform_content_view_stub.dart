import 'package:flutter/material.dart';

Widget buildEmbeddedContent({
  required String viewType,
  String? source,
  String? htmlContent,
  bool video = false,
  Widget? fallback,
}) => fallback ?? const Center(child: Text('This content is available in the web portal.'));
