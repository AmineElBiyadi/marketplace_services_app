import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ClientHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? greeting;
  final bool showBackButton;
  final Widget? trailing;
  final Widget? bottom;
  final double? bottomPadding;

  const ClientHeader({
    super.key,
    this.title,
    this.subtitle,
    this.greeting,
    this.showBackButton = false,
    this.trailing,
    this.bottom,
    this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding ?? 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF818CF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo Row
          Row(
            children: [
              if (showBackButton) ...[
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  ),
                ),
              ],
              Image.asset(
                'assets/logo.png',
                height: 30,
                errorBuilder: (context, error, stackTrace) => const SizedBox(height: 30),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Presto — snap your fingers, we handle the rest.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          
          if (greeting != null || title != null || subtitle != null) ...[
            const SizedBox(height: 20),
            if (greeting != null)
              Text(
                greeting!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (title != null)
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
          
          if (bottom != null) ...[
            const SizedBox(height: 16),
            bottom!,
          ],
        ],
      ),
    );
  }
}
