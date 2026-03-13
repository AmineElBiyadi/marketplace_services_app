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
    if (source == null || source!.isEmpty || source == "null" || source == "undefined") {
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
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey.shade100,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint("SmartImage Network Error: $error | URL: $source");
          return placeholder ?? _defaultPlaceholder();
        },
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
    double iconSize = 24.0;
    if (width != null && width!.isFinite) {
      iconSize = width! * 0.5;
    } else if (height != null && height!.isFinite) {
      iconSize = height! * 0.5;
    }
    
    debugPrint("SmartImage source: $source");
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade200,
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: iconSize > 50 ? 50 : iconSize,
          color: Colors.white70,
        ),
      ),
    );
  }
}
