import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';

/// Web version of the PDF viewer registration.
void registerPdfView(String viewId, String url) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int _) {
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.height = '100%'
        ..style.width = '100%';
      return iframe;
    },
  );
}

/// Web version of the PDF viewer widget.
Widget getPdfView(String viewId) {
  return HtmlElementView(viewType: viewId);
}
