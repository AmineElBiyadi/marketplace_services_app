import 'package:flutter/material.dart';

/// Unimplemented version of the PDF viewer for non-web platforms.
Widget getPdfView(String viewId) => const SizedBox.shrink();

/// Unimplemented version of the registration for non-web platforms.
void registerPdfView(String viewId, String url) {
  // No-op on mobile/desktop
}
