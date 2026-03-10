import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PremiumBadge extends StatelessWidget {
  final bool showCrown;
  final String text;

  const PremiumBadge({
    super.key,
    this.showCrown = true,
    this.text = 'Premium',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.premium,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCrown) ...[
            const Icon(
              Icons.star,
              size: 12,
              color: AppColors.premiumForeground,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.premiumForeground,
            ),
          ),
        ],
      ),
    );
  }
}

enum BadgeType {
  basic,
  success,
  warning,
  error,
  info,
  premium,
  custom,
}

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeType type;
  final IconData? icon;
  final Color? color;
  final Color? customColor;
  final Color? backgroundColor;

  const StatusBadge({
    super.key,
    required this.text,
    this.type = BadgeType.basic,
    this.icon,
    this.color,
    this.customColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;

    switch (type) {
      case BadgeType.success:
        textColor = AppColors.success;
        bgColor = AppColors.success.withValues(alpha: 0.1);
        break;
      case BadgeType.warning:
        textColor = AppColors.warning;
        bgColor = AppColors.warning.withValues(alpha: 0.1);
        break;
      case BadgeType.error:
        textColor = AppColors.error;
        bgColor = AppColors.error.withValues(alpha: 0.1);
        break;
      case BadgeType.premium:
        textColor = AppColors.premiumForeground;
        bgColor = AppColors.premium;
        break;
      case BadgeType.custom:
        textColor = color ?? customColor ?? AppColors.primary;
        bgColor = backgroundColor ?? AppColors.primary.withValues(alpha: 0.1);
        break;
      case BadgeType.info:
      case BadgeType.basic:
        textColor = AppColors.primary;
        bgColor = AppColors.primary.withValues(alpha: 0.1);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: textColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
