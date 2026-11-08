import 'package:flutter/material.dart';

/// Semantic colors for status, lifecycle, and priority across Alhambra applications.
abstract final class AlhambraColors {
  // Brand base accents
  static const Color primary = Color(0xFF0F52BA); // Sapphire Blue
  static const Color secondary = Color(0xFF4A6572);

  // Status & Lifecycle semantic colors
  static const Color draft = Color(0xFF6C757D);
  static const Color review = Color(0xFFF59E0B);
  static const Color approved = Color(0xFF10B981);
  static const Color published = Color(0xFF3B82F6);
  static const Color superseded = Color(0xFF8B5CF6);
  static const Color archived = Color(0xFF9CA3AF);

  // Feedback semantics
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  const AlhambraColors._();
}
