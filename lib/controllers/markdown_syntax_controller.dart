import 'package:flutter/material.dart';

import '../services/spell_check_service.dart';
import '../ui/theme/app_theme.dart';

/// Semantic token types recognised by the Markdown syntax highlighter.
enum MarkdownTokenType {
  header1,
  header2,
  header3,
  header4,
  header5,
  header6,
  headerMarker,
  bold,
  italic,
  boldItalic,
  strikethrough,
  linkText,
  linkUrl,
  imageMarker,
  citationKey,
  citationLocator,
  citationBracket,
  footnoteKey,
  footnoteBracket,
  latexInline,
  latexDisplay,
  latexDelimiter,
  inlineCode,
  codeBlock,
  codeFence,
  blockquoteText,
  blockquoteMarker,
  listMarker,
  horizontalRule,
  delimiter,
}

/// Colour scheme definitions for Markdown syntax highlighting.
class MarkdownSyntaxTheme {
  final String schemeId;
  final Brightness brightness;

  // Delimiters & markers
  final Color delimiterColor;
  final Color headerMarkerColor;

  // Cached pre-resolved styles keyed by schemeId and baseStyle
  static String? _cachedSchemeIdDark;
  static TextStyle? _cachedBaseStyleDark;
  static List<TextStyle>? _resolvedStylesDark;
  static String? _cachedSchemeIdLight;
  static TextStyle? _cachedBaseStyleLight;
  static List<TextStyle>? _resolvedStylesLight;

  List<TextStyle> getResolvedStyles(TextStyle baseStyle) {
    if (brightness == Brightness.dark) {
      if (_cachedSchemeIdDark == schemeId &&
          _cachedBaseStyleDark == baseStyle &&
          _resolvedStylesDark != null) {
        return _resolvedStylesDark!;
      }
      _cachedSchemeIdDark = schemeId;
      _cachedBaseStyleDark = baseStyle;
      final styles = List<TextStyle>.generate(
        MarkdownTokenType.values.length,
        (i) => getStyle(MarkdownTokenType.values[i], baseStyle),
        growable: false,
      );
      _resolvedStylesDark = styles;
      return styles;
    } else {
      if (_cachedSchemeIdLight == schemeId &&
          _cachedBaseStyleLight == baseStyle &&
          _resolvedStylesLight != null) {
        return _resolvedStylesLight!;
      }
      _cachedSchemeIdLight = schemeId;
      _cachedBaseStyleLight = baseStyle;
      final styles = List<TextStyle>.generate(
        MarkdownTokenType.values.length,
        (i) => getStyle(MarkdownTokenType.values[i], baseStyle),
        growable: false,
      );
      _resolvedStylesLight = styles;
      return styles;
    }
  }

  // Headers
  final Color header1Color;
  final Color header2Color;
  final Color header3Color;
  final Color header4to6Color;

  // Text formatting
  final Color boldColor;
  final Color italicColor;
  final Color boldItalicColor;
  final Color strikethroughColor;

  // Code
  final Color inlineCodeColor;
  final Color inlineCodeBg;
  final Color codeBlockColor;
  final Color codeBlockBg;
  final Color codeFenceColor;

  // Links & Images
  final Color linkTextColor;
  final Color linkUrlColor;
  final Color imageMarkerColor;

  // Citations & Footnotes
  final Color citationKeyColor;
  final Color citationLocatorColor;
  final Color citationBracketColor;
  final Color footnoteKeyColor;
  final Color footnoteBracketColor;

  // LaTeX Math
  final Color latexInlineColor;
  final Color latexDisplayColor;
  final Color latexDisplayBg;
  final Color latexDelimiterColor;

  // Blockquotes & Lists
  final Color blockquoteTextColor;
  final Color blockquoteMarkerColor;
  final Color listMarkerColor;
  final Color horizontalRuleColor;

  const MarkdownSyntaxTheme({
    this.schemeId = 'default',
    required this.brightness,
    required this.delimiterColor,
    required this.headerMarkerColor,
    required this.header1Color,
    required this.header2Color,
    required this.header3Color,
    required this.header4to6Color,
    required this.boldColor,
    required this.italicColor,
    required this.boldItalicColor,
    required this.strikethroughColor,
    required this.inlineCodeColor,
    required this.inlineCodeBg,
    required this.codeBlockColor,
    required this.codeBlockBg,
    required this.codeFenceColor,
    required this.linkTextColor,
    required this.linkUrlColor,
    required this.imageMarkerColor,
    required this.citationKeyColor,
    required this.citationLocatorColor,
    required this.citationBracketColor,
    required this.footnoteKeyColor,
    required this.footnoteBracketColor,
    required this.latexInlineColor,
    required this.latexDisplayColor,
    required this.latexDisplayBg,
    required this.latexDelimiterColor,
    required this.blockquoteTextColor,
    required this.blockquoteMarkerColor,
    required this.listMarkerColor,
    required this.horizontalRuleColor,
  });

  /// Constructs a MarkdownSyntaxTheme adapted to the given [AppColorScheme].
  factory MarkdownSyntaxTheme.fromScheme(AppColorScheme scheme) {
    final isDark = scheme.isDark;
    return MarkdownSyntaxTheme(
      schemeId: scheme.id,
      brightness: scheme.brightness,
      delimiterColor: scheme.textMuted,
      headerMarkerColor: scheme.header2Color,
      header1Color: scheme.header1Color,
      header2Color: scheme.header2Color,
      header3Color: scheme.header3Color,
      header4to6Color: scheme.header4to6Color,
      boldColor: scheme.textPrimary,
      italicColor: scheme.textSecondary,
      boldItalicColor: isDark ? scheme.warningOrImageColor : scheme.textPrimary,
      strikethroughColor: scheme.textMuted,
      inlineCodeColor: scheme.inlineCodeColor,
      inlineCodeBg: scheme.border.withValues(alpha: isDark ? 0.35 : 0.45),
      codeBlockColor: scheme.textSecondary,
      codeBlockBg: scheme.sidebar.withValues(alpha: isDark ? 0.5 : 0.6),
      codeFenceColor: scheme.textMuted,
      linkTextColor: scheme.accent,
      linkUrlColor: scheme.textSecondary,
      imageMarkerColor: scheme.warningOrImageColor,
      citationKeyColor: scheme.citationColor,
      citationLocatorColor: scheme.textSecondary,
      citationBracketColor: scheme.header3Color,
      footnoteKeyColor: scheme.warningOrImageColor,
      footnoteBracketColor: scheme.warningOrImageColor,
      latexInlineColor: scheme.mathColor,
      latexDisplayColor: scheme.mathColor,
      latexDisplayBg: scheme.mathColor.withValues(alpha: 0.12),
      latexDelimiterColor: scheme.mathColor,
      blockquoteTextColor: scheme.textSecondary,
      blockquoteMarkerColor: scheme.textMuted,
      listMarkerColor: scheme.header1Color,
      horizontalRuleColor: scheme.border,
    );
  }

  /// Active dark theme palette tailored to the selected dark colour scheme.
  factory MarkdownSyntaxTheme.dark() {
    return MarkdownSyntaxTheme.fromScheme(AppTheme.activeDarkScheme);
  }

  /// Active light theme palette tailored to the selected light colour scheme.
  factory MarkdownSyntaxTheme.light() {
    return MarkdownSyntaxTheme.fromScheme(AppTheme.activeLightScheme);
  }

  /// Create a style appropriate for the given token type, modifying baseStyle.
  TextStyle getStyle(MarkdownTokenType type, TextStyle baseStyle) {
    switch (type) {
      case MarkdownTokenType.header1:
        return baseStyle.copyWith(
          color: header1Color,
          fontWeight: FontWeight.bold,
        );
      case MarkdownTokenType.header2:
        return baseStyle.copyWith(
          color: header2Color,
          fontWeight: FontWeight.bold,
        );
      case MarkdownTokenType.header3:
        return baseStyle.copyWith(
          color: header3Color,
          fontWeight: FontWeight.bold,
        );
      case MarkdownTokenType.header4:
      case MarkdownTokenType.header5:
      case MarkdownTokenType.header6:
        return baseStyle.copyWith(
          color: header4to6Color,
          fontWeight: FontWeight.bold,
        );
      case MarkdownTokenType.headerMarker:
        return baseStyle.copyWith(
          color: headerMarkerColor,
          fontWeight: FontWeight.bold,
        );
      case MarkdownTokenType.bold:
        return baseStyle.copyWith(
          color: boldColor,
          fontWeight: FontWeight.bold,
        );
      case MarkdownTokenType.italic:
        return baseStyle.copyWith(
          color: italicColor,
          fontStyle: FontStyle.italic,
        );
      case MarkdownTokenType.boldItalic:
        return baseStyle.copyWith(
          color: boldItalicColor,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        );
      case MarkdownTokenType.strikethrough:
        return baseStyle.copyWith(
          color: strikethroughColor,
          decoration: TextDecoration.lineThrough,
        );
      case MarkdownTokenType.inlineCode:
        return baseStyle.copyWith(
          color: inlineCodeColor,
          backgroundColor: inlineCodeBg,
        );
      case MarkdownTokenType.codeBlock:
        return baseStyle.copyWith(
          color: codeBlockColor,
          backgroundColor: codeBlockBg,
        );
      case MarkdownTokenType.codeFence:
        return baseStyle.copyWith(color: codeFenceColor);
      case MarkdownTokenType.linkText:
        return baseStyle.copyWith(
          color: linkTextColor,
          decoration: TextDecoration.underline,
          decorationColor: linkTextColor,
        );
      case MarkdownTokenType.linkUrl:
        return baseStyle.copyWith(color: linkUrlColor);
      case MarkdownTokenType.imageMarker:
        return baseStyle.copyWith(
          color: imageMarkerColor,
          fontWeight: FontWeight.bold,
        );
      case MarkdownTokenType.citationKey:
        return baseStyle.copyWith(
          color: citationKeyColor,
          fontWeight: FontWeight.w600,
        );
      case MarkdownTokenType.citationLocator:
        return baseStyle.copyWith(color: citationLocatorColor);
      case MarkdownTokenType.citationBracket:
        return baseStyle.copyWith(
          color: citationBracketColor,
          fontWeight: FontWeight.w600,
        );
      case MarkdownTokenType.footnoteKey:
        return baseStyle.copyWith(
          color: footnoteKeyColor,
          fontWeight: FontWeight.w600,
        );
      case MarkdownTokenType.footnoteBracket:
        return baseStyle.copyWith(
          color: footnoteBracketColor,
          fontWeight: FontWeight.w600,
        );
      case MarkdownTokenType.latexInline:
        return baseStyle.copyWith(
          color: latexInlineColor,
          fontWeight: FontWeight.w500,
        );
      case MarkdownTokenType.latexDisplay:
        return baseStyle.copyWith(
          color: latexDisplayColor,
          fontWeight: FontWeight.w500,
          backgroundColor: latexDisplayBg,
        );
      case MarkdownTokenType.latexDelimiter:
        return baseStyle.copyWith(
          color: latexDelimiterColor,
          fontWeight: FontWeight.w600,
        );
      case MarkdownTokenType.blockquoteText:
        return baseStyle.copyWith(
          color: blockquoteTextColor,
          fontStyle: FontStyle.italic,
        );
      case MarkdownTokenType.blockquoteMarker:
        return baseStyle.copyWith(
          color: blockquoteMarkerColor,
          fontWeight: FontWeight.bold,
        );
      case MarkdownTokenType.listMarker:
        return baseStyle.copyWith(
          color: listMarkerColor,
          fontWeight: FontWeight.bold,
        );
      case MarkdownTokenType.horizontalRule:
        return baseStyle.copyWith(color: horizontalRuleColor);
      case MarkdownTokenType.delimiter:
        return baseStyle.copyWith(color: delimiterColor);
    }
  }
}

/// Represents an individual highlighted text segment.
class HighlightSpan {
  final int start;
  final int end;
  final MarkdownTokenType type;
  final TextStyle style;

  const HighlightSpan({
    required this.start,
    required this.end,
    required this.type,
    required this.style,
  });
}

/// Represents an unstyled syntactic token parsed from Markdown.
class ParsedToken {
  final int start;
  final int end;
  final MarkdownTokenType type;

  const ParsedToken({
    required this.start,
    required this.end,
    required this.type,
  });
}

/// Efficient disjoint interval set using binary search to replace large boolean arrays.
class _RangeSet {
  final List<int> _starts = [];
  final List<int> _ends = [];

  bool isRangeFree(int start, int end) {
    if (start < 0 || end <= start) return false;
    int low = 0;
    int high = _starts.length - 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final oStart = _starts[mid];
      final oEnd = _ends[mid];

      if (start < oEnd && end > oStart) {
        return false;
      }
      if (end <= oStart) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }
    return true;
  }

  void markOccupied(int start, int end) {
    if (start < 0 || end <= start) return;
    int low = 0;
    int high = _starts.length - 1;
    int insertIdx = _starts.length;

    while (low <= high) {
      final mid = (low + high) >> 1;
      if (_starts[mid] >= start) {
        insertIdx = mid;
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    _starts.insert(insertIdx, start);
    _ends.insert(insertIdx, end);

    // Merge overlapping or adjacent intervals
    int i = insertIdx > 0 ? insertIdx - 1 : 0;
    while (i < _starts.length - 1) {
      if (_starts[i + 1] <= _ends[i]) {
        if (_ends[i + 1] > _ends[i]) {
          _ends[i] = _ends[i + 1];
        }
        _starts.removeAt(i + 1);
        _ends.removeAt(i + 1);
      } else {
        i++;
      }
    }
  }

  /// Returns the unoccupied slices within [start, end)
  List<(int, int)> getFreeSlices(int start, int end) {
    if (start >= end) return const [];
    final slices = <(int, int)>[];
    int cursor = start;

    for (int i = 0; i < _starts.length; i++) {
      final oStart = _starts[i];
      final oEnd = _ends[i];

      if (oEnd <= cursor) continue;
      if (oStart >= end) break;

      if (oStart > cursor) {
        slices.add((cursor, oStart < end ? oStart : end));
      }
      cursor = oEnd > cursor ? oEnd : cursor;
      if (cursor >= end) break;
    }

    if (cursor < end) {
      slices.add((cursor, end));
    }
    return slices;
  }
}

/// High-performance Markdown syntax parser producing non-overlapping styled spans.
class MarkdownSyntaxHighlighter {
  /// Regular expressions compiled once for optimal real-time keystroke responsiveness.
  static final RegExp _fencedCodeBlockRegex = RegExp(
    r'^([`~]{3,})[^\n]*\n([\s\S]*?\n)?\1[ \t]*$',
    multiLine: true,
  );

  static final RegExp _unclosedFencedBlockRegex = RegExp(
    r'^([`~]{3,})[^\n]*(?:\n[\s\S]*)$',
    multiLine: true,
  );

  static final RegExp _displayMathRegex = RegExp(
    r'(?:\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\])',
  );

  static final RegExp _inlineCodeRegex = RegExp(r'(`+)([^\n`]+?)\1');

  static final RegExp _inlineMathRegex = RegExp(
    r'(?:(?<![\w\\])\$(?!\s)([^\$\n]+?)(?<!\s|\$)\$|\\\((.+?)\\\))',
  );

  // Pandoc academic citation syntaxes: [@key], [@key, p. 12], [-@key], [@k1; @k2]
  static final RegExp _bracketedCitationRegex = RegExp(
    r'\[(-?@[a-zA-Z0-9_\-:#\/]+(?:[^\n\]]*))\]',
  );

  // In-text citation: @key or @key [p. 12]
  static final RegExp _inTextCitationRegex = RegExp(
    r'(?<![\w@])@([a-zA-Z0-9_\-:#\/]+)(?:[ \t]*\[([^\]]+)\])?',
  );

  // Footnote definition: [^1]: Footnote body
  static final RegExp _footnoteDefRegex = RegExp(
    r'^(\[\^([a-zA-Z0-9_\-]+)\]:)[ \t]*(.*)$',
    multiLine: true,
  );

  // Footnote reference: [^1]
  static final RegExp _footnoteRefRegex = RegExp(r'\[\^([a-zA-Z0-9_\-]+)\]');

  // Markdown links & images
  static final RegExp _imageRegex = RegExp(
    r'(!\[)([^\]]*?)(\]\()([^\)\s]+)(?:\s+"([^"]*?)")?(\))',
  );

  static final RegExp _linkRegex = RegExp(
    r'(\[)([^\]]+?)(\]\()([^\)\s]+)(?:\s+"([^"]*?)")?(\))',
  );

  static final RegExp _autolinkRegex = RegExp(
    r'<((?:https?|ftp|file):\/\/[^\s>]+)>|<([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})>',
  );

  static final RegExp _headerRegex = RegExp(
    r'^(#{1,6})(?:[ \t]+([^\n]*))?$',
    multiLine: true,
  );

  static final RegExp _blockquoteRegex = RegExp(
    r'^(>[ \t]*)(.*)$',
    multiLine: true,
  );

  static final RegExp _horizontalRuleRegex = RegExp(
    r'^(?:[-*_]){3,}[ \t]*$',
    multiLine: true,
  );

  static final RegExp _listMarkerRegex = RegExp(
    r'^(?:[ \t]*)([-*+]|\d+\.)[ \t]+',
    multiLine: true,
  );

  static final RegExp _boldItalicRegex = RegExp(
    r'(\*\*\*|___)(?!\s)([^\n]+?)(?<!\s)\1',
  );

  static final RegExp _boldRegex = RegExp(r'(\*\*|__)(?!\s)([^\n]+?)(?<!\s)\1');

  static final RegExp _italicRegex = RegExp(
    r'(\*|_)(?!\s)([^*\n_]+?)(?<!\s)\1',
  );

  static final RegExp _strikethroughRegex = RegExp(
    r'(~~)(?!\s)([^\n~]+?)(?<!\s)(~~)',
  );

  /// Parse text into semantic tokens with non-overlapping boundaries.
  static List<ParsedToken> parseTokens(String text) {
    if (text.isEmpty) return const [];

    final tokens = <ParsedToken>[];
    final rangeSet = _RangeSet();

    void addToken(int start, int end, MarkdownTokenType type) {
      if (start < 0 || end > text.length || start >= end) return;
      tokens.add(ParsedToken(start: start, end: end, type: type));
    }

    // -------------------------------------------------------------------------
    // Priority 1: Fenced Code Blocks (Closed and unclosed)
    // -------------------------------------------------------------------------
    if (text.contains('```') || text.contains('~~~')) {
      for (final match in _fencedCodeBlockRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          final fullMatch = match.group(0)!;
          final firstNewline = fullMatch.indexOf('\n');
          final lastNewline = fullMatch.lastIndexOf('\n');

          if (firstNewline != -1 && lastNewline > firstNewline) {
            // Opening fence line
            addToken(
              match.start,
              match.start + firstNewline,
              MarkdownTokenType.codeFence,
            );
            // Body lines
            addToken(
              match.start + firstNewline,
              match.start + lastNewline,
              MarkdownTokenType.codeBlock,
            );
            // Closing fence line
            addToken(
              match.start + lastNewline,
              match.end,
              MarkdownTokenType.codeFence,
            );
          } else {
            addToken(match.start, match.end, MarkdownTokenType.codeBlock);
          }
        }
      }

      for (final match in _unclosedFencedBlockRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          final fullMatch = match.group(0)!;
          final firstNewline = fullMatch.indexOf('\n');
          if (firstNewline != -1) {
            addToken(
              match.start,
              match.start + firstNewline,
              MarkdownTokenType.codeFence,
            );
            addToken(
              match.start + firstNewline,
              match.end,
              MarkdownTokenType.codeBlock,
            );
          } else {
            addToken(match.start, match.end, MarkdownTokenType.codeFence);
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 2: LaTeX Display Math Blocks ($$...$$ and \[...\])
    // -------------------------------------------------------------------------
    if (text.contains(r'$$') || text.contains(r'\[')) {
      for (final match in _displayMathRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          final full = match.group(0)!;
          final isDollar = full.startsWith(r'$$');
          final delimLen = isDollar ? 2 : 2;

          addToken(
            match.start,
            match.start + delimLen,
            MarkdownTokenType.latexDelimiter,
          );
          if (match.end - delimLen > match.start + delimLen) {
            addToken(
              match.start + delimLen,
              match.end - delimLen,
              MarkdownTokenType.latexDisplay,
            );
          }
          addToken(
            match.end - delimLen,
            match.end,
            MarkdownTokenType.latexDelimiter,
          );
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 3: Inline Code (`...`)
    // -------------------------------------------------------------------------
    if (text.contains('`')) {
      for (final match in _inlineCodeRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          final ticks = match.group(1)!;
          final tickLen = ticks.length;

          addToken(
            match.start,
            match.start + tickLen,
            MarkdownTokenType.delimiter,
          );
          if (match.end - tickLen > match.start + tickLen) {
            addToken(
              match.start + tickLen,
              match.end - tickLen,
              MarkdownTokenType.inlineCode,
            );
          }
          addToken(match.end - tickLen, match.end, MarkdownTokenType.delimiter);
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 4: LaTeX Inline Math ($...$ and \(...\))
    // -------------------------------------------------------------------------
    if (text.contains(r'$') || text.contains(r'\(')) {
      for (final match in _inlineMathRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          final full = match.group(0)!;
          final isDollar = full.startsWith(r'$');
          final delimLen = isDollar ? 1 : 2;

          addToken(
            match.start,
            match.start + delimLen,
            MarkdownTokenType.latexDelimiter,
          );
          if (match.end - delimLen > match.start + delimLen) {
            addToken(
              match.start + delimLen,
              match.end - delimLen,
              MarkdownTokenType.latexInline,
            );
          }
          addToken(
            match.end - delimLen,
            match.end,
            MarkdownTokenType.latexDelimiter,
          );
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 5: Academic Citations (Pandoc Bracketed & In-Text)
    // -------------------------------------------------------------------------
    if (text.contains('@')) {
      for (final match in _bracketedCitationRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          addToken(
            match.start,
            match.start + 1,
            MarkdownTokenType.citationBracket,
          );

          final innerContent = match.group(1)!;
          final innerStart = match.start + 1;
          final citeKeyRegex = RegExp(r'-?@[a-zA-Z0-9_\-:#\/]+');
          int cursor = innerStart;

          for (final kMatch in citeKeyRegex.allMatches(innerContent)) {
            final kStart = innerStart + kMatch.start;
            final kEnd = innerStart + kMatch.end;

            if (kStart > cursor) {
              addToken(cursor, kStart, MarkdownTokenType.citationLocator);
            }
            addToken(kStart, kEnd, MarkdownTokenType.citationKey);
            cursor = kEnd;
          }

          if (cursor < match.end - 1) {
            addToken(cursor, match.end - 1, MarkdownTokenType.citationLocator);
          }

          addToken(match.end - 1, match.end, MarkdownTokenType.citationBracket);
        }
      }

      for (final match in _inTextCitationRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          final keyWithAt = '@${match.group(1)!}';
          final keyEnd = match.start + keyWithAt.length;

          addToken(match.start, keyEnd, MarkdownTokenType.citationKey);

          final locator = match.group(2);
          if (locator != null) {
            final bracketStart = text.indexOf('[', keyEnd);
            if (bracketStart != -1 && bracketStart < match.end) {
              if (bracketStart > keyEnd) {
                addToken(keyEnd, bracketStart, MarkdownTokenType.delimiter);
              }
              addToken(
                bracketStart,
                bracketStart + 1,
                MarkdownTokenType.citationBracket,
              );
              addToken(
                bracketStart + 1,
                match.end - 1,
                MarkdownTokenType.citationLocator,
              );
              addToken(
                match.end - 1,
                match.end,
                MarkdownTokenType.citationBracket,
              );
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 6: Footnotes (Definitions & In-text references)
    // -------------------------------------------------------------------------
    if (text.contains('[^')) {
      for (final match in _footnoteDefRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          final labelPrefix = match.group(1)!; // [^1]:
          addToken(
            match.start,
            match.start + labelPrefix.length,
            MarkdownTokenType.footnoteKey,
          );
          if (match.end > match.start + labelPrefix.length) {
            addToken(
              match.start + labelPrefix.length,
              match.end,
              MarkdownTokenType.delimiter,
            );
          }
        }
      }

      for (final match in _footnoteRefRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          addToken(
            match.start,
            match.start + 2,
            MarkdownTokenType.footnoteBracket,
          ); // [^
          addToken(
            match.start + 2,
            match.end - 1,
            MarkdownTokenType.footnoteKey,
          );
          addToken(
            match.end - 1,
            match.end,
            MarkdownTokenType.footnoteBracket,
          ); // ]
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 7: Images and Markdown Links
    // -------------------------------------------------------------------------
    if (text.contains('![')) {
      for (final match in _imageRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          addToken(match.start, match.start + 1, MarkdownTokenType.imageMarker);
          addToken(
            match.start + 1,
            match.start + 2,
            MarkdownTokenType.delimiter,
          );

          final alt = match.group(2) ?? '';
          final altStart = match.start + 2;
          final altEnd = altStart + alt.length;
          if (alt.isNotEmpty) {
            addToken(altStart, altEnd, MarkdownTokenType.linkText);
          }

          addToken(altEnd, altEnd + 2, MarkdownTokenType.delimiter);

          final url = match.group(4) ?? '';
          final urlStart = altEnd + 2;
          final urlEnd = urlStart + url.length;
          if (url.isNotEmpty) {
            addToken(urlStart, urlEnd, MarkdownTokenType.linkUrl);
          }

          if (match.end > urlEnd) {
            addToken(urlEnd, match.end, MarkdownTokenType.delimiter);
          }
        }
      }
    }

    if (text.contains('](')) {
      for (final match in _linkRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          addToken(match.start, match.start + 1, MarkdownTokenType.delimiter);

          final anchor = match.group(2) ?? '';
          final anchorStart = match.start + 1;
          final anchorEnd = anchorStart + anchor.length;
          if (anchor.isNotEmpty) {
            addToken(anchorStart, anchorEnd, MarkdownTokenType.linkText);
          }

          addToken(anchorEnd, anchorEnd + 2, MarkdownTokenType.delimiter);

          final url = match.group(4) ?? '';
          final urlStart = anchorEnd + 2;
          final urlEnd = urlStart + url.length;
          if (url.isNotEmpty) {
            addToken(urlStart, urlEnd, MarkdownTokenType.linkUrl);
          }

          if (match.end > urlEnd) {
            addToken(urlEnd, match.end, MarkdownTokenType.delimiter);
          }
        }
      }
    }

    if (text.contains('<')) {
      for (final match in _autolinkRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          addToken(match.start, match.start + 1, MarkdownTokenType.delimiter);
          addToken(match.start + 1, match.end - 1, MarkdownTokenType.linkText);
          addToken(match.end - 1, match.end, MarkdownTokenType.delimiter);
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 8: Horizontal Rules
    // -------------------------------------------------------------------------
    if (text.contains('---') || text.contains('***') || text.contains('___')) {
      for (final match in _horizontalRuleRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          addToken(match.start, match.end, MarkdownTokenType.horizontalRule);
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 9: Headers (#, ##, ###, etc.)
    // -------------------------------------------------------------------------
    if (text.contains('#')) {
      for (final match in _headerRegex.allMatches(text)) {
        final hashes = match.group(1)!;
        final level = hashes.length.clamp(1, 6);
        final markerStart = match.start;
        final markerEnd = match.start + hashes.length;

        if (rangeSet.isRangeFree(markerStart, markerEnd)) {
          rangeSet.markOccupied(markerStart, markerEnd);
          addToken(markerStart, markerEnd, MarkdownTokenType.headerMarker);
        }

        final headerTokenType = switch (level) {
          1 => MarkdownTokenType.header1,
          2 => MarkdownTokenType.header2,
          3 => MarkdownTokenType.header3,
          4 => MarkdownTokenType.header4,
          5 => MarkdownTokenType.header5,
          _ => MarkdownTokenType.header6,
        };

        final freeSlices = rangeSet.getFreeSlices(markerEnd, match.end);
        for (final slice in freeSlices) {
          rangeSet.markOccupied(slice.$1, slice.$2);
          addToken(slice.$1, slice.$2, headerTokenType);
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 10: Blockquotes (> quote)
    // -------------------------------------------------------------------------
    if (text.contains('>')) {
      for (final match in _blockquoteRegex.allMatches(text)) {
        final marker = match.group(1)!;
        final markerStart = match.start;
        final markerEnd = match.start + marker.length;

        if (rangeSet.isRangeFree(markerStart, markerEnd)) {
          rangeSet.markOccupied(markerStart, markerEnd);
          addToken(markerStart, markerEnd, MarkdownTokenType.blockquoteMarker);
        }

        final freeSlices = rangeSet.getFreeSlices(markerEnd, match.end);
        for (final slice in freeSlices) {
          rangeSet.markOccupied(slice.$1, slice.$2);
          addToken(slice.$1, slice.$2, MarkdownTokenType.blockquoteText);
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 11: List Markers (-, *, +, 1.)
    // -------------------------------------------------------------------------
    if (text.contains('-') ||
        text.contains('*') ||
        text.contains('+') ||
        text.contains('.')) {
      for (final match in _listMarkerRegex.allMatches(text)) {
        final marker = match.group(1);
        if (marker != null) {
          final fullMatch = match.group(0)!;
          final markerOffset = fullMatch.indexOf(marker);
          final markerStart = match.start + markerOffset;
          final markerEnd = markerStart + marker.length;
          if (rangeSet.isRangeFree(markerStart, markerEnd)) {
            rangeSet.markOccupied(markerStart, markerEnd);
            addToken(markerStart, markerEnd, MarkdownTokenType.listMarker);
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 12: Text Formatting (Bold-Italics, Bold, Italics, Strikethrough)
    // -------------------------------------------------------------------------
    if (text.contains('***') || text.contains('___')) {
      for (final match in _boldItalicRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          final delimLen = match.group(1)!.length; // 3
          addToken(
            match.start,
            match.start + delimLen,
            MarkdownTokenType.delimiter,
          );
          if (match.end - delimLen > match.start + delimLen) {
            addToken(
              match.start + delimLen,
              match.end - delimLen,
              MarkdownTokenType.boldItalic,
            );
          }
          addToken(
            match.end - delimLen,
            match.end,
            MarkdownTokenType.delimiter,
          );
        }
      }
    }

    if (text.contains('**') || text.contains('__')) {
      for (final match in _boldRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          final delimLen = match.group(1)!.length; // 2
          addToken(
            match.start,
            match.start + delimLen,
            MarkdownTokenType.delimiter,
          );
          if (match.end - delimLen > match.start + delimLen) {
            addToken(
              match.start + delimLen,
              match.end - delimLen,
              MarkdownTokenType.bold,
            );
          }
          addToken(
            match.end - delimLen,
            match.end,
            MarkdownTokenType.delimiter,
          );
        }
      }
    }

    if (text.contains('*') || text.contains('_')) {
      for (final match in _italicRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          final delimLen = match.group(1)!.length; // 1
          addToken(
            match.start,
            match.start + delimLen,
            MarkdownTokenType.delimiter,
          );
          if (match.end - delimLen > match.start + delimLen) {
            addToken(
              match.start + delimLen,
              match.end - delimLen,
              MarkdownTokenType.italic,
            );
          }
          addToken(
            match.end - delimLen,
            match.end,
            MarkdownTokenType.delimiter,
          );
        }
      }
    }

    if (text.contains('~~')) {
      for (final match in _strikethroughRegex.allMatches(text)) {
        if (rangeSet.isRangeFree(match.start, match.end)) {
          rangeSet.markOccupied(match.start, match.end);
          final delimLen = 2; // ~~
          addToken(
            match.start,
            match.start + delimLen,
            MarkdownTokenType.delimiter,
          );
          if (match.end - delimLen > match.start + delimLen) {
            addToken(
              match.start + delimLen,
              match.end - delimLen,
              MarkdownTokenType.strikethrough,
            );
          }
          addToken(
            match.end - delimLen,
            match.end,
            MarkdownTokenType.delimiter,
          );
        }
      }
    }

    // Sort all tokens strictly by start position
    tokens.sort((a, b) => a.start.compareTo(b.start));
    return tokens;
  }

  /// Incrementally updates syntax tokens for single-line / local edits in O(line length)
  /// instead of scanning the entire document with 20 regular expressions on every keystroke.
  ///
  /// Returns a record `(tokens, needsFullReconcile)`, or `null` if a full pass should run immediately.
  static (List<ParsedToken>, bool)? updateTokensIncrementally({
    required String oldText,
    required String newText,
    required List<ParsedToken> oldTokens,
    bool allowDeferredMultiLine = false,
  }) {
    if (oldText == newText) return (oldTokens, false);
    if (oldText.isEmpty || newText.isEmpty) return null;

    final oldLen = oldText.length;
    final newLen = newText.length;
    final minLen = oldLen < newLen ? oldLen : newLen;

    // 1. Find first differing character from the start
    int diffStart = 0;
    while (diffStart < minLen &&
        oldText.codeUnitAt(diffStart) == newText.codeUnitAt(diffStart)) {
      diffStart++;
    }

    // 2. Find last differing character from the end
    int oldDiffEnd = oldLen;
    int newDiffEnd = newLen;
    while (oldDiffEnd > diffStart &&
        newDiffEnd > diffStart &&
        oldText.codeUnitAt(oldDiffEnd - 1) ==
            newText.codeUnitAt(newDiffEnd - 1)) {
      oldDiffEnd--;
      newDiffEnd--;
    }

    // 3. Expand to enclosing line boundaries
    final int lineStart = diffStart > 0
        ? oldText.lastIndexOf('\n', diffStart - 1) + 1
        : 0;
    int oldLineEnd = oldText.indexOf('\n', oldDiffEnd);
    if (oldLineEnd == -1) oldLineEnd = oldLen;
    int newLineEnd = newText.indexOf('\n', newDiffEnd);
    if (newLineEnd == -1) newLineEnd = newLen;

    // If the edit spans a massive chunk (e.g. pasting a huge file), fall back unless deferred
    if (newLineEnd - lineStart > 4000 || oldLineEnd - lineStart > 4000) {
      if (!allowDeferredMultiLine) return null;
    }

    final oldSlice = oldText.substring(lineStart, oldLineEnd);
    final newSlice = newText.substring(lineStart, newLineEnd);

    bool hasMultiLineConstruct(String s) {
      return s.contains('```') ||
          s.contains('~~~') ||
          s.contains(r'$$') ||
          s.contains(r'\[') ||
          s.contains(r'\]');
    }

    bool touchesMultiLine =
        hasMultiLineConstruct(oldSlice) || hasMultiLineConstruct(newSlice);

    if (!touchesMultiLine) {
      for (final t in oldTokens) {
        if (t.end <= lineStart) continue;
        if (t.start >= oldLineEnd) break;
        if (t.type == MarkdownTokenType.codeBlock ||
            t.type == MarkdownTokenType.codeFence ||
            t.type == MarkdownTokenType.latexDisplay) {
          touchesMultiLine = true;
          break;
        }
      }
    }

    if (touchesMultiLine && !allowDeferredMultiLine) {
      return null;
    }

    // 4. Parse tokens only on the modified line slice
    final sliceTokens = (newLineEnd - lineStart <= 4000)
        ? parseTokens(newSlice)
        : const <ParsedToken>[];
    final delta = newLen - oldLen;

    final updated = <ParsedToken>[];
    bool insertedSlice = false;

    for (final t in oldTokens) {
      if (t.end <= lineStart) {
        updated.add(t);
      } else if (t.start >= oldLineEnd) {
        if (!insertedSlice) {
          for (final st in sliceTokens) {
            updated.add(
              ParsedToken(
                start: st.start + lineStart,
                end: st.end + lineStart,
                type: st.type,
              ),
            );
          }
          insertedSlice = true;
        }
        updated.add(
          ParsedToken(start: t.start + delta, end: t.end + delta, type: t.type),
        );
      }
    }

    if (!insertedSlice) {
      for (final st in sliceTokens) {
        updated.add(
          ParsedToken(
            start: st.start + lineStart,
            end: st.end + lineStart,
            type: st.type,
          ),
        );
      }
    }

    return (updated, touchesMultiLine);
  }

  /// Parse the given raw text and return a non-overlapping, sorted list of HighlightSpan.
  static List<HighlightSpan> parseSpans({
    required String text,
    required MarkdownSyntaxTheme theme,
    required TextStyle baseStyle,
  }) {
    if (text.isEmpty) return const [];
    final tokens = parseTokens(text);
    final styles = theme.getResolvedStyles(baseStyle);
    final spans = List<HighlightSpan>.generate(tokens.length, (i) {
      final t = tokens[i];
      return HighlightSpan(
        start: t.start,
        end: t.end,
        type: t.type,
        style: styles[t.type.index],
      );
    }, growable: false);
    return spans;
  }

  static final RegExp _visibleSpaceRegex = RegExp(r' +(?=\r?\n|$)|(?<= ) +');

  /// Builds a complete TextSpan hierarchy for rendering in an editable TextField from tokens.
  /// When [windowStart] and [windowEnd] are provided (e.g. during active typing on large files),
  /// only tokens within `[windowStart, windowEnd)` are expanded into styled spans, drastically
  /// reducing native text-shaping overhead while keeping the visible viewport fully highlighted.
  static TextSpan buildSpanFromTokens({
    required String text,
    required List<ParsedToken> tokens,
    required TextStyle baseStyle,
    required MarkdownSyntaxTheme theme,
    TextRange? composingRange,
    int? windowStart,
    int? windowEnd,
    List<SpellErrorRange>? spellErrors,
    Color spellErrorColor = const Color(0xFFEF4444),
    TextRange? searchHighlightRange,
    Color searchHighlightColor = const Color(0x55F59E0B),
  }) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    // Preserve trailing spaces at line endings and consecutive spaces visually
    // using non-breaking spaces (\u00A0, same UTF-16 length) so Flutter/Skia
    // never collapses them at wrap boundaries or hides the cursor advance.
    final displayText = text.contains(' ')
        ? text.replaceAllMapped(
            _visibleSpaceRegex,
            (m) => '\u00A0' * m.group(0)!.length,
          )
        : text;

    final styles = theme.getResolvedStyles(baseStyle);
    final children = <TextSpan>[];
    int cursor = 0;
    int spellCursor = 0;

    final int effWindowStart = windowStart ?? 0;
    final int effWindowEnd = windowEnd ?? text.length;

    void appendLeafSlice(int start, int end, TextStyle style) {
      if (start >= end) return;
      final piece = displayText.substring(start, end);

      // Handle IME composing underline
      if (composingRange != null &&
          composingRange.isValid &&
          !composingRange.isCollapsed) {
        final compStart = composingRange.start.clamp(0, text.length);
        final compEnd = composingRange.end.clamp(0, text.length);

        if (start < compEnd && end > compStart) {
          final intersectStart = start.clamp(compStart, compEnd);
          final intersectEnd = end.clamp(compStart, compEnd);

          if (intersectStart > start) {
            children.add(
              TextSpan(
                text: displayText.substring(start, intersectStart),
                style: style,
              ),
            );
          }

          children.add(
            TextSpan(
              text: displayText.substring(intersectStart, intersectEnd),
              style: style.copyWith(decoration: TextDecoration.underline),
            ),
          );

          if (end > intersectEnd) {
            children.add(
              TextSpan(
                text: displayText.substring(intersectEnd, end),
                style: style,
              ),
            );
          }
          return;
        }
      }

      children.add(TextSpan(text: piece, style: style));
    }

    void appendStyledSlice(int start, int end, TextStyle style) {
      if (start >= end) return;
      if (searchHighlightRange != null &&
          searchHighlightRange.isValid &&
          !searchHighlightRange.isCollapsed) {
        final hlStart = searchHighlightRange.start.clamp(0, text.length);
        final hlEnd = searchHighlightRange.end.clamp(0, text.length);
        if (start < hlEnd && end > hlStart) {
          final intersectStart = start.clamp(hlStart, hlEnd);
          final intersectEnd = end.clamp(hlStart, hlEnd);
          if (intersectStart > start) {
            appendLeafSlice(start, intersectStart, style);
          }
          appendLeafSlice(
            intersectStart,
            intersectEnd,
            style.copyWith(backgroundColor: searchHighlightColor),
          );
          if (end > intersectEnd) {
            appendLeafSlice(intersectEnd, end, style);
          }
          return;
        }
      }
      appendLeafSlice(start, end, style);
    }

    void appendPiece(int start, int end, TextStyle style) {
      if (start >= end) return;
      if (spellErrors == null || spellErrors.isEmpty) {
        appendStyledSlice(start, end, style);
        return;
      }

      while (spellCursor < spellErrors.length &&
          spellErrors[spellCursor].end <= start) {
        spellCursor++;
      }

      int pos = start;
      while (spellCursor < spellErrors.length &&
          spellErrors[spellCursor].start < end) {
        final err = spellErrors[spellCursor];
        if (err.start > pos) {
          appendStyledSlice(pos, err.start, style);
          pos = err.start;
        }

        final errEnd = err.end < end ? err.end : end;
        if (errEnd > pos) {
          final existingDeco = style.decoration;
          final combinedDeco =
              (existingDeco != null && existingDeco != TextDecoration.none)
              ? TextDecoration.combine([existingDeco, TextDecoration.underline])
              : TextDecoration.underline;
          final errorStyle = style.copyWith(
            decoration: combinedDeco,
            decorationColor: spellErrorColor,
            decorationStyle: TextDecorationStyle.wavy,
            decorationThickness: 2.6,
          );
          appendStyledSlice(pos, errEnd, errorStyle);
          pos = errEnd;
        }

        if (err.end <= end) {
          spellCursor++;
        } else {
          break;
        }
      }

      if (pos < end) {
        appendStyledSlice(pos, end, style);
      }
    }

    for (final token in tokens) {
      if (token.end <= effWindowStart) continue;
      if (token.start >= effWindowEnd) break;

      final tStart = token.start < effWindowStart
          ? effWindowStart
          : token.start;
      final tEnd = token.end > effWindowEnd ? effWindowEnd : token.end;
      if (tStart >= tEnd) continue;

      if (tStart > cursor) {
        appendPiece(cursor, tStart, baseStyle);
      }
      appendPiece(tStart, tEnd, styles[token.type.index]);
      cursor = tEnd;
    }

    if (cursor < text.length) {
      appendPiece(cursor, text.length, baseStyle);
    }

    return TextSpan(style: baseStyle, children: children);
  }

  /// Builds a complete TextSpan hierarchy for rendering in an editable TextField.
  static TextSpan buildTextSpan({
    required String text,
    required TextStyle baseStyle,
    required bool isDark,
    TextRange? composingRange,
  }) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final theme = isDark
        ? MarkdownSyntaxTheme.dark()
        : MarkdownSyntaxTheme.light();
    final tokens = parseTokens(text);
    return buildSpanFromTokens(
      text: text,
      tokens: tokens,
      baseStyle: baseStyle,
      theme: theme,
      composingRange: composingRange,
    );
  }
}

/// A specialised TextEditingController that renders real-time syntax highlighting
/// for Markdown formatting with cached AST tokens for instantaneous dark/light theme switching
/// and O(1) incremental line-scoped token updates during typing on large documents.
class MarkdownSyntaxEditingController extends TextEditingController {
  MarkdownSyntaxEditingController({
    super.text,
    SpellCheckService? spellCheckService,
  }) {
    _spellCheckService = spellCheckService;
  }

  static const int _largeDocumentThreshold = 30000;
  static const int _activeTypingWindowRadius = 10000;

  SpellCheckService? _spellCheckService;
  String? _lastText;
  List<ParsedToken>? _cachedTokens;
  bool? _lastIsDark;
  String? _lastSchemeId;
  TextStyle? _lastStyle;
  TextSpan? _cachedSpan;
  bool? _needsFullReconcile;
  bool? _wasWindowed;
  bool? _isActivelyTyping;

  List<SpellErrorRange> _spellErrors = const [];
  String? _lastSpellText;
  bool? _lastSpellEnabled;
  String? _lastSpellLanguage;
  bool _spellDirty = true;
  TextRange? _searchHighlightRange;

  TextRange? get searchHighlightRange => _searchHighlightRange;

  /// Sets or clears the active search match highlight in the editor.
  void setSearchHighlight(TextRange? range) {
    if (_searchHighlightRange == range) return;
    _searchHighlightRange = range;
    _cachedSpan = null;
    notifyListeners();
  }

  SpellCheckService? get spellCheckService => _spellCheckService;
  set spellCheckService(SpellCheckService? service) {
    _spellCheckService = service;
    invalidateSpellCheck();
  }

  /// Current detected spelling errors in the document.
  List<SpellErrorRange> get spellErrors => _spellErrors;

  /// Invalidates cached spellcheck results and triggers a re-render.
  void invalidateSpellCheck() {
    _spellDirty = true;
    _cachedSpan = null;
    notifyListeners();
  }

  /// Returns the [SpellErrorRange] at [offset], or `null` if none.
  SpellErrorRange? spellErrorAtOffset(int offset) {
    if (_spellErrors.isEmpty) return null;
    int low = 0;
    int high = _spellErrors.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final err = _spellErrors[mid];
      if (offset < err.start) {
        high = mid - 1;
      } else if (offset > err.end) {
        low = mid + 1;
      } else {
        return err;
      }
    }
    return null;
  }

  /// Indicates whether the user is currently in an active typing session
  /// (before the 1.5-second idle render timer has elapsed).
  bool get isActivelyTyping => _isActivelyTyping == true;
  set isActivelyTyping(bool val) => _isActivelyTyping = val;

  /// Performs a full syntax token reconciliation once typing has paused for the idle period.
  void reconcileFullHighlight() {
    final wasTyping = _isActivelyTyping == true;
    _isActivelyTyping = false;
    if (_needsFullReconcile == true || _wasWindowed == true || wasTyping) {
      _needsFullReconcile = false;
      _wasWindowed = false;
      _cachedTokens = MarkdownSyntaxHighlighter.parseTokens(value.text);
      _spellDirty = true;
      _cachedSpan = null;
      notifyListeners();
    }
  }

  /// Invalidates the cached styled span and notifies listeners when the active colour scheme changes.
  void refreshThemeHighlighting() {
    _cachedSpan = null;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeSchemeId = AppTheme.activeSchemeForBrightness(isDark).id;
    final baseStyle = style ?? const TextStyle();
    final currentText = value.text;
    final spellEnabled = _spellCheckService?.isEnabled ?? false;
    final spellLanguage = _spellCheckService?.languageTag;

    final composingRange = (withComposing && value.isComposingRangeValid)
        ? value.composing
        : null;

    if (composingRange == null &&
        !_spellDirty &&
        !isActivelyTyping &&
        currentText == _lastText &&
        isDark == _lastIsDark &&
        activeSchemeId == _lastSchemeId &&
        baseStyle == _lastStyle &&
        spellEnabled == _lastSpellEnabled &&
        spellLanguage == _lastSpellLanguage &&
        _cachedSpan != null) {
      return _cachedSpan!;
    }

    final syntaxTheme = isDark
        ? MarkdownSyntaxTheme.dark()
        : MarkdownSyntaxTheme.light();

    // Instantaneous theme switching or incremental typing update:
    List<ParsedToken> tokens;
    if (_cachedTokens != null && currentText == _lastText) {
      tokens = _cachedTokens!;
    } else if (_cachedTokens != null && _lastText != null) {
      final isLarge = currentText.length >= _largeDocumentThreshold;
      final incremental = MarkdownSyntaxHighlighter.updateTokensIncrementally(
        oldText: _lastText!,
        newText: currentText,
        oldTokens: _cachedTokens!,
        allowDeferredMultiLine: isActivelyTyping && isLarge,
      );
      if (incremental != null) {
        tokens = incremental.$1;
        if (incremental.$2) {
          _needsFullReconcile = true;
        }
        _cachedTokens = tokens;
      } else {
        tokens = MarkdownSyntaxHighlighter.parseTokens(currentText);
        _cachedTokens = tokens;
        _needsFullReconcile = false;
      }
    } else {
      tokens = MarkdownSyntaxHighlighter.parseTokens(currentText);
      _cachedTokens = tokens;
      _needsFullReconcile = false;
    }

    if (spellEnabled && _spellCheckService != null) {
      if (_spellDirty ||
          currentText != _lastSpellText ||
          spellEnabled != _lastSpellEnabled ||
          spellLanguage != _lastSpellLanguage) {
        _spellErrors = _spellCheckService!.findSpellingErrors(
          text: currentText,
          tokens: tokens,
        );
        _lastSpellText = currentText;
        _lastSpellEnabled = spellEnabled;
        _lastSpellLanguage = spellLanguage;
        _spellDirty = false;
      }
    } else {
      _spellErrors = const [];
      _lastSpellText = currentText;
      _lastSpellEnabled = spellEnabled;
      _lastSpellLanguage = spellLanguage;
      _spellDirty = false;
    }

    int? windowStart;
    int? windowEnd;
    if (isActivelyTyping &&
        currentText.length >= _largeDocumentThreshold &&
        value.selection.isValid) {
      final cursor = value.selection.baseOffset.clamp(0, currentText.length);
      windowStart = (cursor - _activeTypingWindowRadius).clamp(
        0,
        currentText.length,
      );
      windowEnd = (cursor + _activeTypingWindowRadius).clamp(
        0,
        currentText.length,
      );
      _wasWindowed = true;
    } else {
      _wasWindowed = false;
    }

    final span = MarkdownSyntaxHighlighter.buildSpanFromTokens(
      text: currentText,
      tokens: tokens,
      baseStyle: baseStyle,
      theme: syntaxTheme,
      composingRange: composingRange,
      windowStart: windowStart,
      windowEnd: windowEnd,
      spellErrors: _spellErrors,
      spellErrorColor: isDark
          ? const Color(0xFFFF5252)
          : const Color(0xFFDC2626),
      searchHighlightRange: _searchHighlightRange,
      searchHighlightColor: Theme.of(context).colorScheme.primary
          .withValues(alpha: isDark ? 0.38 : 0.25),
    );

    if (composingRange == null && !isActivelyTyping) {
      _lastText = currentText;
      _lastIsDark = isDark;
      _lastSchemeId = activeSchemeId;
      _lastStyle = baseStyle;
      _cachedSpan = span;
    } else if (composingRange == null) {
      _lastText = currentText;
      _lastIsDark = isDark;
      _lastSchemeId = activeSchemeId;
      _lastStyle = baseStyle;
    }

    return span;
  }
}
