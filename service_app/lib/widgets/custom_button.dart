import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isCompact;
  final bool disabled;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? height;
  final double? borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isCompact = false,
    this.disabled = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.textColor,
    this.borderColor,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColors.primary;
    final fgColor = textColor ?? foregroundColor ?? AppColors.primaryForeground;
    final padding = isCompact 
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 16);

    if (isOutlined) {
      return OutlinedButton(
        onPressed: (isLoading || disabled) ? null : onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor ?? AppColors.accent, width: 2),
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 12),
          ),
        ),
        child: _buildChild(fgColor: textColor ?? AppColors.foreground),
      );
    }

    return ElevatedButton(
      onPressed: (isLoading || disabled) ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
        padding: padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 12),
        ),
      ),
      child: _buildChild(fgColor: fgColor),
    );
  }

  Widget _buildChild({required Color fgColor}) {
    if (isLoading) {
      return SizedBox(
        height: height ?? 20,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: fgColor,
            size: isCompact ? 18 : 20,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: fgColor,
      ),
    );
  }
}
