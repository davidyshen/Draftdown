import 'package:flutter/material.dart';

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
  final Brightness brightness;

  // Delimiters & markers
  final Color delimiterColor;
  final Color headerMarkerColor;

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

  /// Sophisticated dark theme palette tailored to slate/navy background.
  factory MarkdownSyntaxTheme.dark() {
    return const MarkdownSyntaxTheme(
      brightness: Brightness.dark,
      delimiterColor: Color(0xFF64748B), // Slate 500
      headerMarkerColor: Color(0xFF60A5FA), // Blue 400
      header1Color: Color(0xFF38BDF8), // Sky 400
      header2Color: Color(0xFF60A5FA), // Blue 400
      header3Color: Color(0xFF818CF8), // Indigo 400
      header4to6Color: Color(0xFFA5B4FC), // Indigo 300
      boldColor: Color(0xFFF8FAFC), // Slate 50 crisp
      italicColor: Color(0xFFE2E8F0), // Slate 200
      boldItalicColor: Color(0xFFFDE68A), // Amber 200
      strikethroughColor: Color(0xFF64748B),
      inlineCodeColor: Color(0xFFF472B6), // Pink 400
      inlineCodeBg: Color(0x33475569),
      codeBlockColor: Color(0xFFE2E8F0),
      codeBlockBg: Color(0x221E293B),
      codeFenceColor: Color(0xFF94A3B8),
      linkTextColor: Color(0xFF60A5FA), // Blue 400
      linkUrlColor: Color(0xFF94A3B8), // Slate 400
      imageMarkerColor: Color(0xFFF59E0B), // Amber 500
      citationKeyColor: Color(0xFFC084FC), // Purple 400
      citationLocatorColor: Color(0xFFCBD5E1),
      citationBracketColor: Color(0xFF818CF8),
      footnoteKeyColor: Color(0xFFFBBF24), // Amber 400
      footnoteBracketColor: Color(0xFFF59E0B),
      latexInlineColor: Color(0xFF34D399), // Emerald 400
      latexDisplayColor: Color(0xFF34D399),
      latexDisplayBg: Color(0x1F10B981), // Emerald tint
      latexDelimiterColor: Color(0xFF10B981), // Emerald 500
      blockquoteTextColor: Color(0xFF94A3B8),
      blockquoteMarkerColor: Color(0xFF64748B),
      listMarkerColor: Color(0xFF38BDF8),
      horizontalRuleColor: Color(0xFF475569),
    );
  }

  /// Clean, readable light theme palette tailored to white/slate paper background.
  factory MarkdownSyntaxTheme.light() {
    return const MarkdownSyntaxTheme(
      brightness: Brightness.light,
      delimiterColor: Color(0xFF94A3B8), // Slate 400
      headerMarkerColor: Color(0xFF2563EB), // Blue 600
      header1Color: Color(0xFF1D4ED8), // Blue 700
      header2Color: Color(0xFF2563EB), // Blue 600
      header3Color: Color(0xFF4338CA), // Indigo 700
      header4to6Color: Color(0xFF475569), // Slate 600
      boldColor: Color(0xFF0F172A), // Slate 900
      italicColor: Color(0xFF334155), // Slate 700
      boldItalicColor: Color(0xFF0F172A),
      strikethroughColor: Color(0xFF94A3B8),
      inlineCodeColor: Color(0xFFBE185D), // Pink 700
      inlineCodeBg: Color(0x140F172A),
      codeBlockColor: Color(0xFF334155),
      codeBlockBg: Color(0x0F0F172A),
      codeFenceColor: Color(0xFF64748B),
      linkTextColor: Color(0xFF2563EB), // Blue 600
      linkUrlColor: Color(0xFF64748B), // Slate 500
      imageMarkerColor: Color(0xFFD97706), // Amber 600
      citationKeyColor: Color(0xFF7C3AED), // Violet 600
      citationLocatorColor: Color(0xFF64748B),
      citationBracketColor: Color(0xFF6366F1),
      footnoteKeyColor: Color(0xFFD97706), // Amber 600
      footnoteBracketColor: Color(0xFFB45309),
      latexInlineColor: Color(0xFF047857), // Emerald 700
      latexDisplayColor: Color(0xFF047857),
      latexDisplayBg: Color(0x14059669), // Emerald tint
      latexDelimiterColor: Color(0xFF059669), // Emerald 600
      blockquoteTextColor: Color(0xFF64748B),
      blockquoteMarkerColor: Color(0xFF94A3B8),
      listMarkerColor: Color(0xFF2563EB),
      horizontalRuleColor: Color(0xFFCBD5E1),
    );
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
        return baseStyle.copyWith(
          color: codeFenceColor,
        );
      case MarkdownTokenType.linkText:
        return baseStyle.copyWith(
          color: linkTextColor,
          decoration: TextDecoration.underline,
          decorationColor: linkTextColor,
        );
      case MarkdownTokenType.linkUrl:
        return baseStyle.copyWith(
          color: linkUrlColor,
        );
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
        return baseStyle.copyWith(
          color: citationLocatorColor,
        );
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
        return baseStyle.copyWith(
          color: horizontalRuleColor,
        );
      case MarkdownTokenType.delimiter:
        return baseStyle.copyWith(
          color: delimiterColor,
        );
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

  static final RegExp _inlineCodeRegex = RegExp(
    r'(`+)([^\n`]+?)\1',
  );

  static final RegExp _inlineMathRegex = RegExp(
    r'(?:(?<![\w\\])\$(?!\s)([^\$\n]+?)(?<!\s|\$)\$|\\\((.+?)\\\))',
  );

  // Pandoc academic citation syntaxes: [@key], [@key, p. 12], [-@key], [@k1; @k2]
  static final RegExp _bracketedCitationRegex = RegExp(
    r'\[(-?@[a-zA-Z0-9_\-:#\/]+(?:[^\n\]]*))\]',
  );

  // In-text citation: @key or @key [p. 12]
  static final RegExp _inTextCitationRegex = RegExp(
    r'(?<![\w@])@([a-zA-Z0-9_\-:#\/]+)(?:\[([^\]]+)\])?',
  );

  // Footnote definition: [^1]: Footnote body
  static final RegExp _footnoteDefRegex = RegExp(
    r'^(\[\^([a-zA-Z0-9_\-]+)\]:)[ \t]*(.*)$',
    multiLine: true,
  );

  // Footnote reference: [^1]
  static final RegExp _footnoteRefRegex = RegExp(
    r'\[\^([a-zA-Z0-9_\-]+)\]',
  );

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

  static final RegExp _boldRegex = RegExp(
    r'(\*\*|__)(?!\s)([^\n]+?)(?<!\s)\1',
  );

  static final RegExp _italicRegex = RegExp(
    r'(\*|_)(?!\s)([^*\n_]+?)(?<!\s)\1',
  );

  static final RegExp _strikethroughRegex = RegExp(
    r'(~~)(?!\s)([^\n~]+?)(?<!\s)(~~)',
  );

  /// Parse the given raw text and return a non-overlapping, sorted list of HighlightSpan.
  static List<HighlightSpan> parseSpans({
    required String text,
    required MarkdownSyntaxTheme theme,
    required TextStyle baseStyle,
  }) {
    if (text.isEmpty) return const [];

    final spans = <HighlightSpan>[];
    final occupied = List<bool>.filled(text.length, false);

    bool isRangeFree(int start, int end) {
      if (start < 0 || end > text.length || start >= end) return false;
      for (int i = start; i < end; i++) {
        if (occupied[i]) return false;
      }
      return true;
    }

    void markOccupied(int start, int end) {
      final safeEnd = end.clamp(0, text.length);
      final safeStart = start.clamp(0, safeEnd);
      for (int i = safeStart; i < safeEnd; i++) {
        occupied[i] = true;
      }
    }

    void addSpan(int start, int end, MarkdownTokenType type) {
      if (start < 0 || end > text.length || start >= end) return;
      spans.add(HighlightSpan(
        start: start,
        end: end,
        type: type,
        style: theme.getStyle(type, baseStyle),
      ));
    }

    // -------------------------------------------------------------------------
    // Priority 1: Fenced Code Blocks (Closed and unclosed)
    // -------------------------------------------------------------------------
    for (final match in _fencedCodeBlockRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        final fullMatch = match.group(0)!;
        final firstNewline = fullMatch.indexOf('\n');
        final lastNewline = fullMatch.lastIndexOf('\n');

        if (firstNewline != -1 && lastNewline > firstNewline) {
          // Opening fence line
          addSpan(match.start, match.start + firstNewline, MarkdownTokenType.codeFence);
          // Body lines
          addSpan(match.start + firstNewline, match.start + lastNewline, MarkdownTokenType.codeBlock);
          // Closing fence line
          addSpan(match.start + lastNewline, match.end, MarkdownTokenType.codeFence);
        } else {
          addSpan(match.start, match.end, MarkdownTokenType.codeBlock);
        }
      }
    }

    for (final match in _unclosedFencedBlockRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        final fullMatch = match.group(0)!;
        final firstNewline = fullMatch.indexOf('\n');
        if (firstNewline != -1) {
          addSpan(match.start, match.start + firstNewline, MarkdownTokenType.codeFence);
          addSpan(match.start + firstNewline, match.end, MarkdownTokenType.codeBlock);
        } else {
          addSpan(match.start, match.end, MarkdownTokenType.codeFence);
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 2: LaTeX Display Math Blocks ($$...$$ and \[...\])
    // -------------------------------------------------------------------------
    for (final match in _displayMathRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        final full = match.group(0)!;
        final isDollar = full.startsWith(r'$$');
        final delimLen = isDollar ? 2 : 2;

        addSpan(match.start, match.start + delimLen, MarkdownTokenType.latexDelimiter);
        if (match.end - delimLen > match.start + delimLen) {
          addSpan(match.start + delimLen, match.end - delimLen, MarkdownTokenType.latexDisplay);
        }
        addSpan(match.end - delimLen, match.end, MarkdownTokenType.latexDelimiter);
      }
    }

    // -------------------------------------------------------------------------
    // Priority 3: Inline Code (`...`)
    // -------------------------------------------------------------------------
    for (final match in _inlineCodeRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        final ticks = match.group(1)!;
        final tickLen = ticks.length;

        addSpan(match.start, match.start + tickLen, MarkdownTokenType.delimiter);
        if (match.end - tickLen > match.start + tickLen) {
          addSpan(match.start + tickLen, match.end - tickLen, MarkdownTokenType.inlineCode);
        }
        addSpan(match.end - tickLen, match.end, MarkdownTokenType.delimiter);
      }
    }

    // -------------------------------------------------------------------------
    // Priority 4: LaTeX Inline Math ($...$ and \(...\))
    // -------------------------------------------------------------------------
    for (final match in _inlineMathRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        final full = match.group(0)!;
        final isDollar = full.startsWith(r'$');
        final delimLen = isDollar ? 1 : 2;

        addSpan(match.start, match.start + delimLen, MarkdownTokenType.latexDelimiter);
        if (match.end - delimLen > match.start + delimLen) {
          addSpan(match.start + delimLen, match.end - delimLen, MarkdownTokenType.latexInline);
        }
        addSpan(match.end - delimLen, match.end, MarkdownTokenType.latexDelimiter);
      }
    }

    // -------------------------------------------------------------------------
    // Priority 5: Academic Citations (Pandoc Bracketed & In-Text)
    // -------------------------------------------------------------------------
    for (final match in _bracketedCitationRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        // Bracket '['
        addSpan(match.start, match.start + 1, MarkdownTokenType.citationBracket);

        final innerContent = match.group(1)!;
        final innerStart = match.start + 1;

        // Highlight citekeys (@key or -@key) and locators inside the bracket
        final citeKeyRegex = RegExp(r'-?@[a-zA-Z0-9_\-:#\/]+');
        int cursor = innerStart;

        for (final kMatch in citeKeyRegex.allMatches(innerContent)) {
          final kStart = innerStart + kMatch.start;
          final kEnd = innerStart + kMatch.end;

          if (kStart > cursor) {
            addSpan(cursor, kStart, MarkdownTokenType.citationLocator);
          }
          addSpan(kStart, kEnd, MarkdownTokenType.citationKey);
          cursor = kEnd;
        }

        if (cursor < match.end - 1) {
          addSpan(cursor, match.end - 1, MarkdownTokenType.citationLocator);
        }

        // Bracket ']'
        addSpan(match.end - 1, match.end, MarkdownTokenType.citationBracket);
      }
    }

    for (final match in _inTextCitationRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        final keyWithAt = '@${match.group(1)!}';
        final keyEnd = match.start + keyWithAt.length;

        addSpan(match.start, keyEnd, MarkdownTokenType.citationKey);

        final locator = match.group(2);
        if (locator != null) {
          final bracketStart = text.indexOf('[', keyEnd);
          if (bracketStart != -1 && bracketStart < match.end) {
            if (bracketStart > keyEnd) {
              addSpan(keyEnd, bracketStart, MarkdownTokenType.delimiter);
            }
            addSpan(bracketStart, bracketStart + 1, MarkdownTokenType.citationBracket);
            addSpan(bracketStart + 1, match.end - 1, MarkdownTokenType.citationLocator);
            addSpan(match.end - 1, match.end, MarkdownTokenType.citationBracket);
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // Priority 6: Footnotes (Definitions & In-text references)
    // -------------------------------------------------------------------------
    for (final match in _footnoteDefRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        final labelPrefix = match.group(1)!; // [^1]:
        addSpan(match.start, match.start + labelPrefix.length, MarkdownTokenType.footnoteKey);
        if (match.end > match.start + labelPrefix.length) {
          addSpan(match.start + labelPrefix.length, match.end, MarkdownTokenType.delimiter);
        }
      }
    }

    for (final match in _footnoteRefRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        addSpan(match.start, match.start + 2, MarkdownTokenType.footnoteBracket); // [^
        addSpan(match.start + 2, match.end - 1, MarkdownTokenType.footnoteKey);
        addSpan(match.end - 1, match.end, MarkdownTokenType.footnoteBracket); // ]
      }
    }

    // -------------------------------------------------------------------------
    // Priority 7: Images and Markdown Links
    // -------------------------------------------------------------------------
    for (final match in _imageRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        // ![
        addSpan(match.start, match.start + 1, MarkdownTokenType.imageMarker);
        addSpan(match.start + 1, match.start + 2, MarkdownTokenType.delimiter);

        final alt = match.group(2) ?? '';
        final altStart = match.start + 2;
        final altEnd = altStart + alt.length;
        if (alt.isNotEmpty) {
          addSpan(altStart, altEnd, MarkdownTokenType.linkText);
        }

        // ](
        addSpan(altEnd, altEnd + 2, MarkdownTokenType.delimiter);

        final url = match.group(4) ?? '';
        final urlStart = altEnd + 2;
        final urlEnd = urlStart + url.length;
        if (url.isNotEmpty) {
          addSpan(urlStart, urlEnd, MarkdownTokenType.linkUrl);
        }

        // Remainder including optional title and ')'
        if (match.end > urlEnd) {
          addSpan(urlEnd, match.end, MarkdownTokenType.delimiter);
        }
      }
    }

    for (final match in _linkRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        // [
        addSpan(match.start, match.start + 1, MarkdownTokenType.delimiter);

        final anchor = match.group(2) ?? '';
        final anchorStart = match.start + 1;
        final anchorEnd = anchorStart + anchor.length;
        if (anchor.isNotEmpty) {
          addSpan(anchorStart, anchorEnd, MarkdownTokenType.linkText);
        }

        // ](
        addSpan(anchorEnd, anchorEnd + 2, MarkdownTokenType.delimiter);

        final url = match.group(4) ?? '';
        final urlStart = anchorEnd + 2;
        final urlEnd = urlStart + url.length;
        if (url.isNotEmpty) {
          addSpan(urlStart, urlEnd, MarkdownTokenType.linkUrl);
        }

        // Remainder including optional title and ')'
        if (match.end > urlEnd) {
          addSpan(urlEnd, match.end, MarkdownTokenType.delimiter);
        }
      }
    }

    for (final match in _autolinkRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        addSpan(match.start, match.start + 1, MarkdownTokenType.delimiter); // <
        addSpan(match.start + 1, match.end - 1, MarkdownTokenType.linkText);
        addSpan(match.end - 1, match.end, MarkdownTokenType.delimiter); // >
      }
    }

    // -------------------------------------------------------------------------
    // Priority 8: Horizontal Rules
    // -------------------------------------------------------------------------
    for (final match in _horizontalRuleRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        addSpan(match.start, match.end, MarkdownTokenType.horizontalRule);
      }
    }

    // -------------------------------------------------------------------------
    // Priority 9: Headers (#, ##, ###, etc.)
    // -------------------------------------------------------------------------
    for (final match in _headerRegex.allMatches(text)) {
      final hashes = match.group(1)!;
      final level = hashes.length.clamp(1, 6);
      final markerStart = match.start;
      final markerEnd = match.start + hashes.length;

      // Header marker hashes
      if (isRangeFree(markerStart, markerEnd)) {
        markOccupied(markerStart, markerEnd);
        addSpan(markerStart, markerEnd, MarkdownTokenType.headerMarker);
      }

      final headerTokenType = switch (level) {
        1 => MarkdownTokenType.header1,
        2 => MarkdownTokenType.header2,
        3 => MarkdownTokenType.header3,
        4 => MarkdownTokenType.header4,
        5 => MarkdownTokenType.header5,
        _ => MarkdownTokenType.header6,
      };

      // Header line content
      int segStart = markerEnd;
      while (segStart < match.end) {
        if (occupied[segStart]) {
          segStart++;
          continue;
        }
        int segEnd = segStart;
        while (segEnd < match.end && !occupied[segEnd]) {
          segEnd++;
        }
        if (segEnd > segStart) {
          markOccupied(segStart, segEnd);
          addSpan(segStart, segEnd, headerTokenType);
        }
        segStart = segEnd;
      }
    }

    // -------------------------------------------------------------------------
    // Priority 10: Blockquotes (> quote)
    // -------------------------------------------------------------------------
    for (final match in _blockquoteRegex.allMatches(text)) {
      final marker = match.group(1)!;
      final markerStart = match.start;
      final markerEnd = match.start + marker.length;

      if (isRangeFree(markerStart, markerEnd)) {
        markOccupied(markerStart, markerEnd);
        addSpan(markerStart, markerEnd, MarkdownTokenType.blockquoteMarker);
      }

      int segStart = markerEnd;
      while (segStart < match.end) {
        if (occupied[segStart]) {
          segStart++;
          continue;
        }
        int segEnd = segStart;
        while (segEnd < match.end && !occupied[segEnd]) {
          segEnd++;
        }
        if (segEnd > segStart) {
          markOccupied(segStart, segEnd);
          addSpan(segStart, segEnd, MarkdownTokenType.blockquoteText);
        }
        segStart = segEnd;
      }
    }

    // -------------------------------------------------------------------------
    // Priority 11: List Markers (-, *, +, 1.)
    // -------------------------------------------------------------------------
    for (final match in _listMarkerRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        addSpan(match.start, match.end, MarkdownTokenType.listMarker);
      }
    }

    // -------------------------------------------------------------------------
    // Priority 12: Text Formatting (Bold-Italics, Bold, Italics, Strikethrough)
    // -------------------------------------------------------------------------
    for (final match in _boldItalicRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        final delimLen = match.group(1)!.length; // 3
        addSpan(match.start, match.start + delimLen, MarkdownTokenType.delimiter);
        if (match.end - delimLen > match.start + delimLen) {
          addSpan(match.start + delimLen, match.end - delimLen, MarkdownTokenType.boldItalic);
        }
        addSpan(match.end - delimLen, match.end, MarkdownTokenType.delimiter);
      }
    }

    for (final match in _boldRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        final delimLen = match.group(1)!.length; // 2
        addSpan(match.start, match.start + delimLen, MarkdownTokenType.delimiter);
        if (match.end - delimLen > match.start + delimLen) {
          addSpan(match.start + delimLen, match.end - delimLen, MarkdownTokenType.bold);
        }
        addSpan(match.end - delimLen, match.end, MarkdownTokenType.delimiter);
      }
    }

    for (final match in _italicRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        final delimLen = match.group(1)!.length; // 1
        addSpan(match.start, match.start + delimLen, MarkdownTokenType.delimiter);
        if (match.end - delimLen > match.start + delimLen) {
          addSpan(match.start + delimLen, match.end - delimLen, MarkdownTokenType.italic);
        }
        addSpan(match.end - delimLen, match.end, MarkdownTokenType.delimiter);
      }
    }

    for (final match in _strikethroughRegex.allMatches(text)) {
      if (isRangeFree(match.start, match.end)) {
        markOccupied(match.start, match.end);
        final delimLen = 2; // ~~
        addSpan(match.start, match.start + delimLen, MarkdownTokenType.delimiter);
        if (match.end - delimLen > match.start + delimLen) {
          addSpan(match.start + delimLen, match.end - delimLen, MarkdownTokenType.strikethrough);
        }
        addSpan(match.end - delimLen, match.end, MarkdownTokenType.delimiter);
      }
    }

    // Sort all spans strictly by start position
    spans.sort((a, b) => a.start.compareTo(b.start));
    return spans;
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

    final theme = isDark ? MarkdownSyntaxTheme.dark() : MarkdownSyntaxTheme.light();
    final spans = parseSpans(
      text: text,
      theme: theme,
      baseStyle: baseStyle,
    );

    final children = <TextSpan>[];
    int cursor = 0;

    void appendPiece(int start, int end, TextStyle style) {
      if (start >= end) return;
      final piece = text.substring(start, end);

      // Handle IME composing underline
      if (composingRange != null && composingRange.isValid && !composingRange.isCollapsed) {
        final compStart = composingRange.start.clamp(0, text.length);
        final compEnd = composingRange.end.clamp(0, text.length);

        if (start < compEnd && end > compStart) {
          final intersectStart = start.clamp(compStart, compEnd);
          final intersectEnd = end.clamp(compStart, compEnd);

          if (intersectStart > start) {
            children.add(TextSpan(
              text: text.substring(start, intersectStart),
              style: style,
            ));
          }

          children.add(TextSpan(
            text: text.substring(intersectStart, intersectEnd),
            style: style.copyWith(decoration: TextDecoration.underline),
          ));

          if (end > intersectEnd) {
            children.add(TextSpan(
              text: text.substring(intersectEnd, end),
              style: style,
            ));
          }
          return;
        }
      }

      children.add(TextSpan(text: piece, style: style));
    }

    for (final span in spans) {
      if (span.start > cursor) {
        appendPiece(cursor, span.start, baseStyle);
      }
      appendPiece(span.start, span.end, span.style);
      cursor = span.end;
    }

    if (cursor < text.length) {
      appendPiece(cursor, text.length, baseStyle);
    }

    return TextSpan(style: baseStyle, children: children);
  }
}

/// A specialized TextEditingController that renders real-time syntax highlighting
/// for Markdown formatting (bold, italics, headers, links, citations, and LaTeX math).
class MarkdownSyntaxEditingController extends TextEditingController {
  MarkdownSyntaxEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseStyle = style ?? const TextStyle();

    final composingRange = (withComposing && value.isComposingRangeValid)
        ? value.composing
        : null;

    return MarkdownSyntaxHighlighter.buildTextSpan(
      text: value.text,
      baseStyle: baseStyle,
      isDark: isDark,
      composingRange: composingRange,
    );
  }
}
