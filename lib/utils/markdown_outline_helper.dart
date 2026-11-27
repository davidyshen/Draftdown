import 'dart:convert';

/// Represents a Markdown heading extracted from the editor source text.
class MarkdownHeading {
  /// Heading level from 1 (`#`) to 6 (`######`).
  final int level;

  /// Clean plain-text heading title for display in the Navigation panel.
  final String title;

  /// 0-based line index in the editor's body text.
  final int lineIndex;

  /// 0-based character offset of the heading line start in the editor's body text.
  final int charOffset;

  /// 0-based index of this heading among all headings in the document body.
  final int headingIndex;

  /// 0-based top-level block index corresponding to the AST node list.
  final int blockIndex;

  const MarkdownHeading({
    required this.level,
    required this.title,
    required this.lineIndex,
    required this.charOffset,
    required this.headingIndex,
    required this.blockIndex,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownHeading &&
          runtimeType == other.runtimeType &&
          level == other.level &&
          title == other.title &&
          lineIndex == other.lineIndex &&
          charOffset == other.charOffset &&
          headingIndex == other.headingIndex &&
          blockIndex == other.blockIndex;

  @override
  int get hashCode => Object.hash(
    level,
    title,
    lineIndex,
    charOffset,
    headingIndex,
    blockIndex,
  );
}

/// Maps a top-level rendered Markdown block to its source line range.
class MarkdownBlockRange {
  final int blockIndex;
  final int startLine;
  final int endLine;

  const MarkdownBlockRange({
    required this.blockIndex,
    required this.startLine,
    required this.endLine,
  });
}

/// Combined outline and block-range result for a Markdown document.
class MarkdownOutline {
  final List<MarkdownHeading> headings;
  final List<MarkdownBlockRange> blockRanges;

  const MarkdownOutline({required this.headings, required this.blockRanges});

  static const MarkdownOutline empty = MarkdownOutline(
    headings: <MarkdownHeading>[],
    blockRanges: <MarkdownBlockRange>[],
  );
}

/// Parses Markdown source text into document headings and top-level block line
/// ranges for sidebar navigation and editor-driven scroll synchronisation.
class MarkdownOutlineHelper {
  static final RegExp _atxHeadingRegex = RegExp(
    r'^[ ]{0,3}(#{1,6})(?:[ \t]+(.*?))?[ \t]*$',
  );
  static final RegExp _closingHashesRegex = RegExp(r'[ \t]+#+$');
  static final RegExp _fenceOpenRegex = RegExp(r'^[ ]{0,3}(`{3,}|~{3,})');
  static final RegExp _thematicBreakRegex = RegExp(
    r'^[ ]{0,3}(?:(\*[ \t]*){3,}|(-[ \t]*){3,}|(_[ \t]*){3,})$',
  );
  static final RegExp _setextH1Regex = RegExp(r'^[ ]{0,3}=+[ \t]*$');
  static final RegExp _setextH2Regex = RegExp(r'^[ ]{0,3}-+[ \t]*$');
  static final RegExp _listItemRegex = RegExp(
    r'^[ ]{0,3}(?:[-*+]|\d{1,9}[.)])[ \t]+',
  );
  static final RegExp _blockquoteRegex = RegExp(r'^[ ]{0,3}>');
  static final RegExp _tableRowRegex = RegExp(r'^\s*\|');

  /// Extracts headings and top-level block line ranges from [markdown]
  /// (which should already have YAML frontmatter stripped, as in `textController.text`).
  static MarkdownOutline parse(String markdown) {
    if (markdown.isEmpty) return MarkdownOutline.empty;

    final lines = const LineSplitter().convert(markdown);
    if (lines.isEmpty) return MarkdownOutline.empty;

    // Precompute 0-based character offset for the start of each line.
    final lineOffsets = List<int>.filled(lines.length, 0);
    int runningOffset = 0;
    for (int i = 0; i < lines.length; i++) {
      lineOffsets[i] = runningOffset;
      runningOffset += lines[i].length + 1;
      // Handle \r\n if present in original text
      if (runningOffset - 1 < markdown.length &&
          runningOffset - 1 >= 0 &&
          markdown.codeUnitAt(runningOffset - 1) == 13) {
        runningOffset++;
      }
    }

    final headings = <MarkdownHeading>[];
    final blockRanges = <MarkdownBlockRange>[];

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // 1. Fenced code block (``` or ~~~)
      final fenceMatch = _fenceOpenRegex.firstMatch(line);
      if (fenceMatch != null) {
        final fence = fenceMatch.group(1)!;
        final fenceChar = fence[0];
        final fenceLen = fence.length;
        // Backtick fences cannot have backticks in info string
        final info = line.substring(fenceMatch.end);
        if (fenceChar != '`' || !info.contains('`')) {
          final startLine = i;
          i++;
          while (i < lines.length) {
            final closeLine = lines[i].trimLeft();
            if (closeLine.startsWith(fenceChar * fenceLen) &&
                closeLine.replaceAll(fenceChar, '').trim().isEmpty) {
              i++;
              break;
            }
            i++;
          }
          blockRanges.add(
            MarkdownBlockRange(
              blockIndex: blockRanges.length,
              startLine: startLine,
              endLine: i - 1,
            ),
          );
          continue;
        }
      }

      // 2. ATX Heading (# ... ######)
      final atxMatch = _atxHeadingRegex.firstMatch(line);
      if (atxMatch != null) {
        final level = atxMatch.group(1)!.length;
        var rawTitle = (atxMatch.group(2) ?? '').trim();
        rawTitle = rawTitle.replaceFirst(_closingHashesRegex, '').trim();
        if (rawTitle == '#' * rawTitle.length && rawTitle.isNotEmpty) {
          // Edge case: "# ###" -> empty heading or hashes
          rawTitle = '';
        }
        final cleanTitle = _stripInlineMarkdown(rawTitle);
        final blockIdx = blockRanges.length;
        headings.add(
          MarkdownHeading(
            level: level,
            title: cleanTitle.isEmpty ? 'Untitled Heading' : cleanTitle,
            lineIndex: i,
            charOffset: lineOffsets[i],
            headingIndex: headings.length,
            blockIndex: blockIdx,
          ),
        );
        blockRanges.add(
          MarkdownBlockRange(blockIndex: blockIdx, startLine: i, endLine: i),
        );
        i++;
        continue;
      }

      // 3. Thematic break (---, ***, ___)
      if (_thematicBreakRegex.hasMatch(line)) {
        blockRanges.add(
          MarkdownBlockRange(
            blockIndex: blockRanges.length,
            startLine: i,
            endLine: i,
          ),
        );
        i++;
        continue;
      }

      // 4. Blockquote (> ...)
      if (_blockquoteRegex.hasMatch(line)) {
        final startLine = i;
        i++;
        while (i < lines.length &&
            lines[i].trim().isNotEmpty &&
            !_fenceOpenRegex.hasMatch(lines[i]) &&
            !_atxHeadingRegex.hasMatch(lines[i])) {
          i++;
        }
        blockRanges.add(
          MarkdownBlockRange(
            blockIndex: blockRanges.length,
            startLine: startLine,
            endLine: i - 1,
          ),
        );
        continue;
      }

      // 5. List block (-, *, +, 1.)
      if (_listItemRegex.hasMatch(line)) {
        final startLine = i;
        i++;
        while (i < lines.length) {
          final next = lines[i];
          if (next.trim().isEmpty) {
            // Loose list check: if next non-empty line is another list item or indented, continue
            int lookahead = i + 1;
            while (lookahead < lines.length &&
                lines[lookahead].trim().isEmpty) {
              lookahead++;
            }
            if (lookahead < lines.length &&
                (_listItemRegex.hasMatch(lines[lookahead]) ||
                    lines[lookahead].startsWith('  ') ||
                    lines[lookahead].startsWith('\t'))) {
              i = lookahead;
              continue;
            }
            break;
          }
          if (_atxHeadingRegex.hasMatch(next) ||
              _fenceOpenRegex.hasMatch(next) ||
              _thematicBreakRegex.hasMatch(next)) {
            break;
          }
          i++;
        }
        blockRanges.add(
          MarkdownBlockRange(
            blockIndex: blockRanges.length,
            startLine: startLine,
            endLine: i - 1,
          ),
        );
        continue;
      }

      // 6. Table block (| ... |)
      if (_tableRowRegex.hasMatch(line)) {
        final startLine = i;
        i++;
        while (i < lines.length &&
            lines[i].trim().isNotEmpty &&
            _tableRowRegex.hasMatch(lines[i])) {
          i++;
        }
        blockRanges.add(
          MarkdownBlockRange(
            blockIndex: blockRanges.length,
            startLine: startLine,
            endLine: i - 1,
          ),
        );
        continue;
      }

      // 7. Paragraph (or Setext heading if followed by === / ---)
      final startLine = i;
      i++;
      bool isSetext = false;
      while (i < lines.length) {
        final next = lines[i];
        if (next.trim().isEmpty) break;
        if (i == startLine + 1 &&
            (_setextH1Regex.hasMatch(next) || _setextH2Regex.hasMatch(next))) {
          final level = _setextH1Regex.hasMatch(next) ? 1 : 2;
          final cleanTitle = _stripInlineMarkdown(lines[startLine].trim());
          final blockIdx = blockRanges.length;
          headings.add(
            MarkdownHeading(
              level: level,
              title: cleanTitle.isEmpty ? 'Untitled Heading' : cleanTitle,
              lineIndex: startLine,
              charOffset: lineOffsets[startLine],
              headingIndex: headings.length,
              blockIndex: blockIdx,
            ),
          );
          blockRanges.add(
            MarkdownBlockRange(
              blockIndex: blockIdx,
              startLine: startLine,
              endLine: i,
            ),
          );
          i++;
          isSetext = true;
          break;
        }
        if (_atxHeadingRegex.hasMatch(next) ||
            _fenceOpenRegex.hasMatch(next) ||
            _thematicBreakRegex.hasMatch(next) ||
            _blockquoteRegex.hasMatch(next) ||
            _listItemRegex.hasMatch(next)) {
          break;
        }
        i++;
      }

      if (!isSetext) {
        blockRanges.add(
          MarkdownBlockRange(
            blockIndex: blockRanges.length,
            startLine: startLine,
            endLine: i - 1,
          ),
        );
      }
    }

    return MarkdownOutline(
      headings: List.unmodifiable(headings),
      blockRanges: List.unmodifiable(blockRanges),
    );
  }

  /// Given a 0-based [lineIndex], returns the matching `(blockIndex, fraction)`
  /// where `fraction` is in `[0.0, 1.0]` representing progress within the block.
  static ({int blockIndex, double fraction}) blockPositionForLine(
    List<MarkdownBlockRange> ranges,
    int lineIndex,
  ) {
    if (ranges.isEmpty) return (blockIndex: 0, fraction: 0.0);
    if (lineIndex <= ranges.first.startLine) {
      return (blockIndex: ranges.first.blockIndex, fraction: 0.0);
    }
    if (lineIndex >= ranges.last.endLine) {
      return (blockIndex: ranges.last.blockIndex, fraction: 1.0);
    }

    int low = 0;
    int high = ranges.length - 1;
    int bestIdx = 0;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final range = ranges[mid];
      if (lineIndex >= range.startLine && lineIndex <= range.endLine) {
        final span = (range.endLine - range.startLine + 1).clamp(1, 100000);
        final fraction = ((lineIndex - range.startLine) / span).clamp(0.0, 1.0);
        return (blockIndex: range.blockIndex, fraction: fraction);
      }
      if (range.startLine < lineIndex) {
        bestIdx = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // Line falls on a blank line between blocks: map to the next block's start
    final nextIdx = (bestIdx + 1).clamp(0, ranges.length - 1);
    return (blockIndex: ranges[nextIdx].blockIndex, fraction: 0.0);
  }

  static String _stripInlineMarkdown(String text) {
    var result = text;
    // Images: ![alt](url) -> alt
    result = result.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
      (m) => m[1] ?? '',
    );
    // Links: [text](url) -> text
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]*\)'),
      (m) => m[1] ?? '',
    );
    // Reference links: [text][id] -> text
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\[[^\]]*\]'),
      (m) => m[1] ?? '',
    );
    // Inline code, bold, italic, strikethrough
    result = result.replaceAll(RegExp(r'(`{1,3}|\*{1,3}|_{1,3}|~~)'), '');
    return result.trim();
  }
}
