import 'dart:convert';
import 'package:flutter/material.dart';

class SmartImage extends StatelessWidget {
  final String? source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final BorderRadius? borderRadius;

  const SmartImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (source == null || source!.isEmpty) {
      return _wrap(placeholder ?? _defaultPlaceholder());
    }

    // Check if it's base64
    final isBase64 = source!.contains(',') || 
                     (!source!.startsWith('http') && !source!.startsWith('assets/'));

    if (isBase64) {
      try {
        final String b64 = source!.contains(',') ? source!.split(',').last : source!;
        return _wrap(Image.memory(
          base64Decode(b64),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => placeholder ?? _defaultPlaceholder(),
        ));
      } catch (e) {
        debugPrint("SmartImage base64 error: $e");
        return _wrap(placeholder ?? _defaultPlaceholder());
      }
    } else if (source!.startsWith('assets/')) {
      return _wrap(Image.asset(
        source!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder ?? _defaultPlaceholder(),
      ));
    } else {
      return _wrap(Image.network(
        source!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder ?? _defaultPlaceholder(),
      ));
    }
  }

  Widget _wrap(Widget child) {
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade100,
      child: Icon(Icons.person, size: (width ?? 40) * 0.5, color: Colors.grey.shade400),
    );
  }
}
