import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:markdown/markdown.dart' as md;

import '../models/citation_item.dart';
import '../utils/yaml_frontmatter_helper.dart';

// =============================================================================
// Markdown Syntaxes for Off-Thread AST Generation
// =============================================================================

class DisplayMathSyntax extends md.InlineSyntax {
  DisplayMathSyntax() : super(r'(?:\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\])');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final formula = match[1] ?? match[2] ?? '';
    final el = md.Element('displaymath', [md.Text(formula.trim())]);
    parser.addNode(el);
    return true;
  }
}

class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax()
    : super(r'(?:(?<!\\)\$(?!\$)(.+?)(?<!\\)\$|\\\((.+?)\\\))');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final formula = match[1] ?? match[2] ?? '';
    final el = md.Element('inlinemath', [md.Text(formula.trim())]);
    parser.addNode(el);
    return true;
  }
}

class SuperscriptSyntax extends md.InlineSyntax {
  SuperscriptSyntax()
    : super(
        r'(?:<sup\b[^>]*>(.*?)<\/sup>|(?<!\^)\^([^\^\s]+)\^(?!\^))',
        caseSensitive: false,
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match[1] ?? match[2] ?? '';
    final el = md.Element('sup', [md.Text(content)]);
    parser.addNode(el);
    return true;
  }
}

class SubscriptSyntax extends md.InlineSyntax {
  SubscriptSyntax()
    : super(
        r'(?:<sub\b[^>]*>(.*?)<\/sub>|(?<!~)~([^~\s]+)~(?!~))',
        caseSensitive: false,
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match[1] ?? match[2] ?? '';
    final el = md.Element('sub', [md.Text(content)]);
    parser.addNode(el);
    return true;
  }
}

class BracketedCitationSyntax extends md.InlineSyntax {
  BracketedCitationSyntax()
    : super(r'\[(-?@[a-zA-Z0-9_\-:#\/]+(?:[^\n\]]*))\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final raw = match[1]!;
    final el = md.Element('academiccitation', [md.Text(raw)]);
    el.attributes['bracketed'] = 'true';
    parser.addNode(el);
    return true;
  }
}

class InTextCitationSyntax extends md.InlineSyntax {
  InTextCitationSyntax()
    : super(r'(?<![\w@])@([a-zA-Z0-9_\-:#\/]+)(?:\[([^\]]+)\])?');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final key = match[1]!;
    final locator = match[2];
    final text = locator != null ? '@$key, $locator' : '@$key';
    final el = md.Element('academiccitation', [md.Text(text)]);
    el.attributes['bracketed'] = 'false';
    parser.addNode(el);
    return true;
  }
}

/// Payload delivered to the background Markdown render thread / Isolate.
class MarkdownRenderPayload {
  final int renderId;
  final String rawMarkdown;
  final List<CitationItem> citations;
  final bool isNumericCitation;

  const MarkdownRenderPayload({
    required this.renderId,
    required this.rawMarkdown,
    required this.citations,
    this.isNumericCitation = false,
  });
}

/// Result produced by the background Markdown render thread / Isolate.
class MarkdownRenderResult {
  final int renderId;
  final String rawMarkdown;
  final String processedMarkdown;
  final Map<String, int> numericIndices;
  final List<md.Node>? astNodes;
  final int wordCount;
  final int lineCount;
  final int readingTimeMinutes;

  const MarkdownRenderResult({
    required this.renderId,
    required this.rawMarkdown,
    required this.processedMarkdown,
    required this.numericIndices,
    this.astNodes,
    this.wordCount = 0,
    this.lineCount = 1,
    this.readingTimeMinutes = 1,
  });
}

/// Signature for executing a Markdown render job asynchronously.
typedef MarkdownIsolateRunner = Future<MarkdownRenderResult> Function(
  MarkdownRenderPayload payload,
);

/// Service managing off-thread Markdown preview processing and AST preparation
/// so that the main UI and Markdown entry stay responsive at 60/120 FPS at all times.
class MarkdownRenderService {
  static final RegExp _emptyTaskRegex = RegExp(
    r'^([ \t]*(?:>\s*)*(?:[-*+]|\d+\.)[ \t]+\[[ xX]\])[ \t]*$',
    multiLine: true,
  );
  static final RegExp _emptyBulletRegex = RegExp(
    r'^([ \t]*)([-*+])([ \t]+)$',
    multiLine: true,
  );
  static final RegExp _multiSpaceBulletRegex = RegExp(
    r'^([ \t]*[-*+])[ \t]{2,}',
    multiLine: true,
  );
  static final RegExp _codeMaskRegex = RegExp(r'(```[\s\S]*?```|`[^`\n]+`)');
  static final RegExp _codeUnmaskRegex = RegExp(r'%%CODE_BLOCK_(\d+)%%');
  static final RegExp _imgTagRegex = RegExp(
    r'<img\s+([^>]*?)\/?>',
    caseSensitive: false,
  );
  static final RegExp _srcAttrRegex = RegExp(
    r'''src=["']([^"']+)["']''',
    caseSensitive: false,
  );
  static final RegExp _altAttrRegex = RegExp(
    r'''alt=["']([^"']*)["']''',
    caseSensitive: false,
  );
  static final RegExp _titleAttrRegex = RegExp(
    r'''title=["']([^"']*)["']''',
    caseSensitive: false,
  );
  static final RegExp _widthAttrRegex = RegExp(
    r'''width=["']?([0-9]+)["']?''',
    caseSensitive: false,
  );
  static final RegExp _heightAttrRegex = RegExp(
    r'''height=["']?([0-9]+)["']?''',
    caseSensitive: false,
  );
  static final RegExp _citeRegex = RegExp(
    r'(?:\[(?:-?@[a-zA-Z0-9_\-:#\/]+(?:[^\n\]]*))\]|(?<![\w@])@([a-zA-Z0-9_\-:#\/]+))',
  );
  static final RegExp _fencedCodeBlockRegex = RegExp(
    r'^(?:```|~~~)[\s\S]*?^(?:```|~~~)[ \t]*\r?$',
    multiLine: true,
  );
  static final RegExp _existingRefHeadingRegex = RegExp(
    r'^(?:#{1,6}\s*(?:References|Bibliography)[ \t]*\r?$|<a\s+name="references">)',
    caseSensitive: false,
    multiLine: true,
  );

  /// Returns true if [markdown] already contains a standalone References or
  /// Bibliography heading outside fenced code blocks.
  static bool hasExistingReferencesHeading(String markdown) {
    final withoutCodeBlocks = markdown.replaceAll(_fencedCodeBlockRegex, '');
    return _existingRefHeadingRegex.hasMatch(withoutCodeBlocks);
  }

  static final RegExp _citeKeyExtractRegex = RegExp(r'@([a-zA-Z0-9_\-:#\/]+)');
  static final RegExp _leadingAtOrHyphenRegex = RegExp(r'^[@\-]+');
  static final RegExp _yearFallbackRegex = RegExp(r'(19\d\d|20\d\d)');

  final MarkdownIsolateRunner _runner;

  MarkdownRenderService({MarkdownIsolateRunner? runner})
    : _runner = runner ?? _defaultIsolateRunner;

  static Future<MarkdownRenderResult> _defaultIsolateRunner(
    MarkdownRenderPayload payload,
  ) {
    // When executing under flutter_test, dispatch via microtask to cooperate
    // with FakeAsync event loops while maintaining asynchronous behaviour.
    // In production (desktop / mobile), execute in a dedicated OS thread via Isolate.run.
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      return Isolate.run(() => executeMarkdownRender(payload));
    }
    return Future<MarkdownRenderResult>.microtask(
      () => executeMarkdownRender(payload),
    );
  }

  /// Dispatches the render payload to the configured isolate runner.
  Future<MarkdownRenderResult> render(MarkdownRenderPayload payload) {
    return _runner(payload);
  }

  /// Pure computation executing Markdown preprocessing, regex substitutions,
  /// academic citation resolution, and bibliography generation.
  static MarkdownRenderResult executeMarkdownRender(
    MarkdownRenderPayload payload,
  ) {
    final raw = payload.rawMarkdown;
    if (raw.trim().isEmpty) {
      return MarkdownRenderResult(
        renderId: payload.renderId,
        rawMarkdown: raw,
        processedMarkdown: '_Document is empty._',
        numericIndices: const {},
        astNodes: parseAst('_Document is empty._'),
        wordCount: 0,
        lineCount: 1,
        readingTimeMinutes: 1,
      );
    }

    // Strip leading YAML frontmatter (e.g. `csl: apa`) before metrics and preview
    final body = YamlFrontmatterHelper.stripYamlFrontmatter(raw);

    // High-performance single-pass metrics computation off the main UI thread
    int words = 0;
    int lines = 1;
    bool inWord = false;
    for (int i = 0; i < body.length; i++) {
      final code = body.codeUnitAt(i);
      if (code == 10) {
        lines++;
      }
      if (code <= 32) {
        inWord = false;
      } else if (!inWord) {
        inWord = true;
        words++;
      }
    }
    final readingTime = (words / 200).ceil().clamp(1, 9999);

    // 0. Handle empty task list checkboxes (e.g. "- [ ] " or "- [x] ")
    var processed = body.replaceAllMapped(
      _emptyTaskRegex,
      (m) => '${m[1]} \u00A0',
    );

    // Handle incomplete list markers (e.g. line with only "* " or "*   ")
    processed = processed.replaceAllMapped(_emptyBulletRegex, (m) {
      final indent = m[1] ?? '';
      final marker = m[2] ?? '*';
      final spaces = m[3] ?? '';
      final visibleSpaces = '\u00A0' * spaces.length;
      return '$indent\\$marker$visibleSpaces';
    });

    // Preserve multiple spaces after list markers on lines with content
    processed = processed.replaceAllMapped(_multiSpaceBulletRegex, (m) {
      final marker = m[1]!;
      final totalMatch = m.group(0)!;
      final spaceCount = totalMatch.length - marker.length;
      final extraSpaces = '\u00A0' * (spaceCount - 1);
      return '$marker $extraSpaces';
    });

    // 1. Convert HTML <img> tags outside fenced code blocks into Markdown image syntax
    if (processed.contains('<img') ||
        processed.contains('<IMG') ||
        processed.contains('<Img')) {
      final codeTokens = <String>[];
      processed = processed.replaceAllMapped(_codeMaskRegex, (m) {
        codeTokens.add(m.group(0)!);
        return '%%CODE_BLOCK_${codeTokens.length - 1}%%';
      });

      processed = processed.replaceAllMapped(_imgTagRegex, (match) {
        final attrs = match[1] ?? '';
        final src = _srcAttrRegex.firstMatch(attrs)?.group(1);
        if (src == null || src.isEmpty) return match.group(0)!;

        final alt = _altAttrRegex.firstMatch(attrs)?.group(1) ?? '';
        final title = _titleAttrRegex.firstMatch(attrs)?.group(1);
        final width = _widthAttrRegex.firstMatch(attrs)?.group(1);
        final height = _heightAttrRegex.firstMatch(attrs)?.group(1);

        String dim = '';
        if (width != null && height != null) {
          dim = '#${width}x$height';
        } else if (width != null) {
          dim = '#$width';
        }

        final titlePart = (title != null && title.isNotEmpty)
            ? ' "$title"'
            : '';
        return '![$alt]($src$dim$titlePart)';
      });

      if (codeTokens.isNotEmpty) {
        processed = processed.replaceAllMapped(
          _codeUnmaskRegex,
          (m) => codeTokens[int.parse(m.group(1)!)],
        );
      }
    }

    // 2. Scan for cited keys in document
    if (!processed.contains('@')) {
      return MarkdownRenderResult(
        renderId: payload.renderId,
        rawMarkdown: raw,
        processedMarkdown: processed,
        numericIndices: const {},
        astNodes: parseAst(processed),
        wordCount: words,
        lineCount: lines,
        readingTimeMinutes: readingTime,
      );
    }

    final matches = _citeRegex.allMatches(processed);
    if (matches.isEmpty || hasExistingReferencesHeading(processed)) {
      return MarkdownRenderResult(
        renderId: payload.renderId,
        rawMarkdown: raw,
        processedMarkdown: processed,
        numericIndices: const {},
        astNodes: parseAst(processed),
        wordCount: words,
        lineCount: lines,
        readingTimeMinutes: readingTime,
      );
    }

    // Index citations by clean lowercase key for fast O(1) resolution
    final Map<String, CitationItem> citationLookup = {};
    for (final item in payload.citations) {
      citationLookup[item.key.toLowerCase()] = item;
    }

    // Collect unique cited keys in order of appearance
    final citedKeysInOrder = <String>[];
    final citedKeysSet = <String>{};
    for (final match in matches) {
      final fullMatch = match.group(0)!;
      for (final km in _citeKeyExtractRegex.allMatches(fullMatch)) {
        final k = km.group(1);
        if (k != null && k.isNotEmpty) {
          final clean = k.toLowerCase();
          if (citedKeysSet.add(clean)) {
            citedKeysInOrder.add(k);
          }
        }
      }
    }

    if (citedKeysInOrder.isEmpty) {
      return MarkdownRenderResult(
        renderId: payload.renderId,
        rawMarkdown: raw,
        processedMarkdown: processed,
        numericIndices: const {},
        astNodes: parseAst(processed),
        wordCount: words,
        lineCount: lines,
        readingTimeMinutes: readingTime,
      );
    }

    // Build numeric index mapping
    final Map<String, int> keyToNumber = {};
    for (int i = 0; i < citedKeysInOrder.length; i++) {
      keyToNumber[citedKeysInOrder[i].toLowerCase()] = i + 1;
    }

    // Build references bibliography
    final buffer = StringBuffer(processed);
    buffer.writeln('\n\n---\n\n### References\n');

    final isNumeric = payload.isNumericCitation;

    if (isNumeric) {
      for (int i = 0; i < citedKeysInOrder.length; i++) {
        final key = citedKeysInOrder[i];
        final num = i + 1;
        final clean = key
            .trim()
            .replaceFirst(_leadingAtOrHyphenRegex, '')
            .toLowerCase();
        final item = citationLookup[clean];
        if (item != null) {
          buffer.writeln(item.formatBibliographyEntry(numericIndex: num));
        } else {
          final authorsStr = CitationItem.inferAuthorFromKey(key);
          final yearMatch = _yearFallbackRegex.firstMatch(key);
          final yearStr = yearMatch?.group(0) ?? 'n.d.';
          buffer.writeln('$num. $authorsStr ($yearStr). `@$key`');
        }
      }
    } else {
      // In Author-Year mode: sort alphabetically by first author surname
      final sortedKeys = List<String>.from(citedKeysInOrder);
      sortedKeys.sort((keyA, keyB) {
        final cleanA = keyA
            .trim()
            .replaceFirst(_leadingAtOrHyphenRegex, '')
            .toLowerCase();
        final cleanB = keyB
            .trim()
            .replaceFirst(_leadingAtOrHyphenRegex, '')
            .toLowerCase();
        final itemA = citationLookup[cleanA];
        final itemB = citationLookup[cleanB];
        final surnameA = itemA?.authors.isNotEmpty == true
            ? CitationItem.extractSurname(itemA!.authors.first)
            : CitationItem.inferAuthorFromKey(keyA);
        final surnameB = itemB?.authors.isNotEmpty == true
            ? CitationItem.extractSurname(itemB!.authors.first)
            : CitationItem.inferAuthorFromKey(keyB);
        final cmp = surnameA.toLowerCase().compareTo(surnameB.toLowerCase());
        if (cmp != 0) return cmp;
        return (itemA?.effectiveYear ?? '').compareTo(
          itemB?.effectiveYear ?? '',
        );
      });

      for (final key in sortedKeys) {
        final clean = key
            .trim()
            .replaceFirst(_leadingAtOrHyphenRegex, '')
            .toLowerCase();
        final item = citationLookup[clean];
        if (item != null) {
          buffer.writeln(item.formatBibliographyEntry());
        } else {
          final authorsStr = CitationItem.inferAuthorFromKey(key);
          final yearMatch = _yearFallbackRegex.firstMatch(key);
          final yearStr = yearMatch?.group(0) ?? 'n.d.';
          buffer.writeln('- $authorsStr ($yearStr). `@$key`');
        }
      }
    }

    final finalMarkdown = buffer.toString();
    return MarkdownRenderResult(
      renderId: payload.renderId,
      rawMarkdown: raw,
      processedMarkdown: finalMarkdown,
      numericIndices: keyToNumber,
      astNodes: parseAst(finalMarkdown),
      wordCount: words,
      lineCount: lines,
      readingTimeMinutes: readingTime,
    );
  }

  /// Parses Markdown into Abstract Syntax Tree (AST) nodes with all inline syntaxes.
  /// Runs off-thread within the Isolate so that no Markdown parsing work is done on the UI thread.
  static List<md.Node> parseAst(String markdown) {
    final doc = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: <md.InlineSyntax>[
        DisplayMathSyntax(),
        InlineMathSyntax(),
        BracketedCitationSyntax(),
        InTextCitationSyntax(),
        SuperscriptSyntax(),
        SubscriptSyntax(),
      ],
      encodeHtml: false,
    );
    final List<String> lines = const LineSplitter().convert(markdown);
    return doc.parseLines(lines);
  }
}
