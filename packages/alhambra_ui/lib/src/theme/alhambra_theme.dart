import 'package:flutter/material.dart';
import 'color_scheme.dart';
import 'dimensions.dart';
import 'spacing.dart';

/// Base theme factory for Alhambra applications.
/// Provides default light and dark themes with consistent token bindings.
final class AlhambraTheme {
  AlhambraTheme._();

  static ThemeData light({
    Color primary = AlhambraColors.primary,
    Color secondary = AlhambraColors.secondary,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: secondary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AlhambraDimensions.radiusMd),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: const EdgeInsets.all(AlhambraSpacing.sm),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AlhambraDimensions.radiusMd),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AlhambraDimensions.radiusMd),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AlhambraDimensions.radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AlhambraSpacing.md,
          vertical: AlhambraSpacing.sm,
        ),
      ),
    );
  }

  static ThemeData dark({
    Color primary = AlhambraColors.primary,
    Color secondary = AlhambraColors.secondary,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      secondary: secondary,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AlhambraDimensions.radiusMd),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: const EdgeInsets.all(AlhambraSpacing.sm),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AlhambraDimensions.radiusMd),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AlhambraDimensions.radiusMd),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AlhambraDimensions.radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AlhambraSpacing.md,
          vertical: AlhambraSpacing.sm,
        ),
      ),
    );
  }
}
