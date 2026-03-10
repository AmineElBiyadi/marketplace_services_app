import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BadgeType { basic, success, warning, error }

class StatusBadge extends StatelessWidget {
  final String text;
  final BadgeType type;
  final IconData? icon;

  const StatusBadge({
    Key? key,
    required this.text,
    this.type = BadgeType.basic,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (type) {
      case BadgeType.success:
        bgColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        break;
      case BadgeType.warning:
        bgColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        break;
      case BadgeType.error:
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        break;
      case BadgeType.basic:
      default:
        bgColor = Colors.white.withOpacity(0.2);
        textColor = Colors.white;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
