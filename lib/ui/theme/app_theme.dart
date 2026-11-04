import 'package:flutter/material.dart';

/// Clean, modern theme definitions for MDWriter.
class AppTheme {
  // Light palette
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSidebar = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);
  static const Color lightAccent = Color(0xFF2563EB); // Royal Blue
  static const Color lightPreviewCanvas = Color(0xFFE2E8F0); // Neutral desktop grey
  static const Color lightPreviewPage = Color(0xFFFFFFFF); // Floating paper sheet
  static const Color lightPreviewBorder = Color(0xFFCBD5E1); // Paper perimeter border

  // Dark palette
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSidebar = Color(0xFF131D2E);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);
  static const Color darkAccent = Color(0xFF3B82F6);
  static const Color darkPreviewCanvas = Color(0xFF0F172A); // Deep workspace canvas
  static const Color darkPreviewPage = Color(0xFF1E293B); // Floating dark paper sheet
  static const Color darkPreviewBorder = Color(0xFF334155); // Paper perimeter border

  // Monospace fonts for editor (strictly monospace)
  static const List<String> availableMonospaceFonts = [
    'Consolas',
    'Cascadia Code',
    'Courier New',
    'Fira Code',
    'JetBrains Mono',
    'Source Code Pro',
    'Inconsolata',
    'Roboto Mono',
    'Lucida Console',
    'Menlo',
    'Monaco',
  ];

  // Render fonts for Markdown preview (headers & body)
  static const List<String> availableRenderFonts = [
    'Segoe UI',
    'Inter',
    'Roboto',
    'Arial',
    'Helvetica',
    'Georgia',
    'Times New Roman',
    'Garamond',
    'Palatino',
    'Cambria',
    'Merriweather',
    'Open Sans',
    'Lato',
    'Consolas',
  ];

  static const String editorFontFamily = 'Consolas';
  static const List<String> editorFontFamilyFallback = [
    'Cascadia Code',
    'Courier New',
    'Fira Code',
    'Menlo',
    'Monaco',
    'monospace',
  ];

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      colorScheme: ColorScheme.light(
        primary: lightAccent,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        outline: lightBorder,
      ),
      fontFamily: 'Segoe UI',
      dividerColor: lightBorder,
      tabBarTheme: TabBarThemeData(
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return lightAccent.withValues(alpha: 0.12);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.black.withValues(alpha: 0.04);
          }
          return Colors.transparent;
        }),
        splashFactory: NoSplash.splashFactory,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: lightBorder),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: darkBg,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: ColorScheme.dark(
        primary: darkAccent,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        outline: darkBorder,
      ),
      fontFamily: 'Segoe UI',
      dividerColor: darkBorder,
      tabBarTheme: TabBarThemeData(
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.pressed)) {
            return darkAccent.withValues(alpha: 0.15);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.white.withValues(alpha: 0.06);
          }
          return Colors.transparent;
        }),
        splashFactory: NoSplash.splashFactory,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: darkBorder),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: lightBg,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: lightTextPrimary, fontSize: 12),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}
