import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryForeground = Color(0xFFFFFFFF);

  // Secondary colors
  static const Color secondary = Color(0xFFF1F5F9);
  static const Color secondaryForeground = Color(0xFF0F172A);

  // Background
  static const Color background = Color(0xFFFAFAFA);
  static const Color foreground = Color(0xFF0F172A);

  // Card
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = Color(0xFF0F172A);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Muted
  static const Color muted = Color(0xFFF1F5F9);
  static const Color mutedForeground = Color(0xFF64748B);

  // Text aliases
  // Added to fix missing property issues
  static const Color textPrimary = foreground;
  static const Color textSecondary = mutedForeground;
  static const Color divider = border;
  static const Color buttonText = primaryForeground;


  // Accent
  static const Color accent = Color(0xFFF59E0B);
  static const Color accentForeground = Color(0xFF0F172A);

  // Destructive
  static const Color destructive = Color(0xFFEF4444);
  static const Color destructiveForeground = Color(0xFFFFFFFF);

  // Border
  static const Color border = Color(0xFFE2E8F0);
  static const Color input = Color(0xFFE2E8F0);
  static const Color ring = Color(0xFF6366F1);

  // Premium
  static const Color premium = Color(0xFFF59E0B);
  static const Color premiumForeground = Color(0xFF0F172A);

  // Category colors
  static const Color category1 = Color(0xFFDBEAFE); // Blue
  static const Color category2 = Color(0xFFD1FAE5); // Green
  static const Color category3 = Color(0xFFFEF3C7); // Yellow
  static const Color category4 = Color(0xFFDCFCE7); // Light green
  static const Color category5 = Color(0xFFFCE7F3); // Pink
  static const Color category6 = Color(0xFFE0E7FF); // Indigo

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}
