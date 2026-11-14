import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui/theme/app_theme.dart';

/// Holds the discovered local font families installed on the user's system.
class InstalledFonts {
  final List<String> allFonts;
  final List<String> monospaceFonts;

  const InstalledFonts({required this.allFonts, required this.monospaceFonts});
}

/// Service for discovering locally installed system fonts without relying on
/// remote web fonts or hardcoded font lists.
class SystemFontService {
  SystemFontService._();

  static final SystemFontService instance = SystemFontService._();

  static const Set<String> _symbolFontBlacklist = {
    'Bookshelf Symbol 7',
    'HoloLens MDL2 Assets',
    'Marlett',
    'MS Outlook',
    'MS Reference Specialty',
    'MT Extra',
    'Segoe Fluent Icons',
    'Segoe MDL2 Assets',
    'Symbol',
    'Webdings',
    'Wingdings',
    'Wingdings 2',
    'Wingdings 3',
  };

  InstalledFonts? _cachedFonts;
  Future<InstalledFonts>? _inFlight;

  /// Returns the cached installed fonts immediately if already loaded.
  InstalledFonts? get cachedFonts => _cachedFonts;

  /// Clears the cached font list so the next call re-queries the OS.
  void clearCache() {
    _cachedFonts = null;
    _inFlight = null;
  }

  /// Overrides the cached fonts (intended for testing).
  @visibleForTesting
  void setMockFonts(InstalledFonts fonts) {
    _cachedFonts = fonts;
    _inFlight = null;
  }

  /// Queries the operating system for installed local font families and
  /// classifies monospace fonts using [TextPainter] glyph metrics.
  Future<InstalledFonts> getInstalledFonts() {
    if (_cachedFonts != null) {
      return Future.value(_cachedFonts);
    }
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      final fallback = _fallbackFonts();
      _cachedFonts = fallback;
      return Future.value(fallback);
    }
    _inFlight ??= _loadInstalledFonts();
    return _inFlight!;
  }

  Future<InstalledFonts> _loadInstalledFonts() async {
    try {
      final rawFamilies = await _queryOsFontFamilies();
      final filtered =
          rawFamilies
              .map((f) => f.trim())
              .where((f) => f.isNotEmpty && !_symbolFontBlacklist.contains(f))
              .toSet()
              .toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (filtered.isEmpty) {
        return _fallbackFonts();
      }

      final monospace = filtered.where(isMonospaceFont).toList();
      final result = InstalledFonts(
        allFonts: filtered,
        monospaceFonts: monospace.isNotEmpty ? monospace : [filtered.first],
      );
      _cachedFonts = result;
      return result;
    } catch (_) {
      return _fallbackFonts();
    } finally {
      _inFlight = null;
    }
  }

  InstalledFonts _fallbackFonts() {
    return const InstalledFonts(
      allFonts: AppTheme.availableRenderFonts,
      monospaceFonts: AppTheme.availableMonospaceFonts,
    );
  }

  Future<List<String>> _queryOsFontFamilies() async {
    if (kIsWeb) {
      return const [];
    }

    if (Platform.isWindows) {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Add-Type -AssemblyName System.Drawing; '
            '[System.Drawing.Text.InstalledFontCollection]::new().Families.Name',
      ]);
      if (result.exitCode == 0) {
        return parseLineSeparatedFamilies(result.stdout.toString());
      }
      return const [];
    }

    if (Platform.isMacOS) {
      final result = await Process.run('osascript', [
        '-l',
        'JavaScript',
        '-e',
        'ObjC.import("AppKit"); '
            r'$.NSFontManager.sharedFontManager.availableFontFamilies.js.map(f => f.js).join("\n")',
      ]);
      if (result.exitCode == 0) {
        final families = parseLineSeparatedFamilies(result.stdout.toString());
        if (families.isNotEmpty) return families;
      }
      return _queryFcList();
    }

    if (Platform.isLinux) {
      return _queryFcList();
    }

    return const [];
  }

  Future<List<String>> _queryFcList() async {
    final result = await Process.run('fc-list', [':', 'family']);
    if (result.exitCode != 0) return const [];
    return parseFcListFamilies(result.stdout.toString());
  }

  /// Parses newline-separated font family names (Windows / macOS).
  @visibleForTesting
  static List<String> parseLineSeparatedFamilies(String output) {
    return output
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  /// Parses `fc-list : family` output where a line may contain comma-separated
  /// family aliases.
  @visibleForTesting
  static List<String> parseFcListFamilies(String output) {
    final families = <String>[];
    for (final line in output.split(RegExp(r'\r?\n'))) {
      for (final part in line.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) {
          families.add(trimmed);
        }
      }
    }
    return families;
  }

  /// Determines whether [fontFamily] is strictly monospace by comparing the
  /// rendered advance widths of narrow and wide characters.
  static bool isMonospaceFont(String fontFamily) {
    double measure(String text) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: fontFamily, fontSize: 20),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final wI = measure('i');
    final wW = measure('W');
    final wDot = measure('.');
    final wM = measure('M');
    if (wI <= 0 || wW <= 0) return false;
    return (wI - wW).abs() < 0.05 && (wDot - wM).abs() < 0.05;
  }
}
