import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../controllers/editor_controller.dart';
import '../models/citation_item.dart';
import '../utils/yaml_frontmatter_helper.dart';
import 'markdown_render_service.dart';
import 'pandoc_service.dart';

/// Service generating publication-quality HTML and PDF documents directly
/// from Markdown, matching the editor preview's typography, deep green code styling,
/// and unaccented academic citations without requiring Pandoc or LaTeX.
class _ExportDisplayMathSyntax extends md.InlineSyntax {
  _ExportDisplayMathSyntax()
    : super(r'(?:\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\])');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final formula = (match[1] ?? match[2] ?? '').trim();
    final el = md.Element('div', [md.Text('\$\$$formula\$\$')]);
    el.attributes['class'] = 'math-display';
    parser.addNode(el);
    return true;
  }
}

class _ExportInlineMathSyntax extends md.InlineSyntax {
  _ExportInlineMathSyntax()
    : super(r'(?:(?<!\\)\$(?!\$)(.+?)(?<!\\)\$|\\\((.+?)\\\))');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final formula = (match[1] ?? match[2] ?? '').trim();
    final el = md.Element('span', [md.Text('\\($formula\\)')]);
    el.attributes['class'] = 'math-inline';
    parser.addNode(el);
    return true;
  }
}

class DirectExportService {
  /// Deep green colour specified for code blocks and inline code
  static const String codeGreenColor = '#166534';

  static final RegExp _cleanKeyRegex = RegExp(r'^[@\-]+');
  static final RegExp _yearRegex = RegExp(r'(19\d\d|20\d\d)');
  static final RegExp _bracketRegex = RegExp(
    r'\[(-?@[a-zA-Z0-9_\-:#\/]+(?:[^\n\]]*))\]',
  );
  static final RegExp _inTextRegex = RegExp(
    r'(?<![\w@])@([a-zA-Z0-9_\-:#\/]+)(?:\[([^\]]+)\])?',
  );
  static final RegExp _winAbsRegex = RegExp(r'^[a-zA-Z]:[\\/]');
  static final RegExp _codeMaskRegex = RegExp(
    r'<pre\b[^>]*>[\s\S]*?</pre>|<code\b[^>]*>[\s\S]*?</code>',
    caseSensitive: false,
  );
  static final RegExp _codeUnmaskRegex = RegExp(r'%%CODE_BLOCK_(\d+)%%');
  static final RegExp _imgTagRegex = RegExp(
    r'<img\b([^>]*)/?>',
    caseSensitive: false,
  );
  static final RegExp _srcAttrRegex = RegExp(
    r'''\bsrc\s*=\s*(?:"([^"]*)"|'([^']*)')''',
    caseSensitive: false,
  );
  static final RegExp _widthAttrRegex = RegExp(
    r'''\bwidth\s*=\s*(?:"([^"]*)"|'([^']*)'|(\S+))''',
    caseSensitive: false,
  );
  static final RegExp _heightAttrRegex = RegExp(
    r'''\bheight\s*=\s*(?:"([^"]*)"|'([^']*)'|(\S+))''',
    caseSensitive: false,
  );
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
  static final RegExp _mathCodeBlockRegex = RegExp(
    r'<pre><code class="language-(?:math|latex)">([\s\S]*?)</code></pre>',
    caseSensitive: false,
  );
  static final RegExp _fencedCodeRegex = RegExp(
    r'^(?:```|~~~)[\s\S]*?^(?:```|~~~)[ \t]*\r?$',
    multiLine: true,
  );
  static final RegExp _hrPageBreakRegex = RegExp(
    r'(?:^|\r?\n[ \t]*\r?\n)[ \t]*-{3,}[ \t]*(?=\r?\n|$)',
  );

  String? _cachedBrowserExecutable;

  /// Resolve page margin stylesheet definition based on selected margin mode
  static String resolvePageMargin(String marginSize) {
    switch (marginSize.toLowerCase()) {
      case 'thin':
        // 50% thinner than medium (1in * 0.5 = 0.5in)
        return '0.5in';
      case 'thick':
        // 25% thicker than medium only on the sides (top/bottom: 1in, sides: 1.25in)
        return '1in 1.25in';
      case 'medium':
      default:
        // 30% thinner than 1in
        return '0.7in';
    }
  }

  /// Locate the pre-installed system browser executable (Edge / Chrome) for headless PDF printing
  Future<String?> findBrowserExecutable() async {
    if (_cachedBrowserExecutable != null &&
        File(_cachedBrowserExecutable!).existsSync()) {
      return _cachedBrowserExecutable;
    }

    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      final candidates = [
        r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
        r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
        r'C:\Program Files\Google\Chrome\Application\chrome.exe',
        r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
        if (localAppData != null)
          '$localAppData\\Microsoft\\Edge\\Application\\msedge.exe',
        if (localAppData != null)
          '$localAppData\\Google\\Chrome\\Application\\chrome.exe',
      ];
      for (final candidate in candidates) {
        if (File(candidate).existsSync()) {
          _cachedBrowserExecutable = candidate;
          return candidate;
        }
      }
    } else if (Platform.isMacOS) {
      const candidates = [
        '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge',
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        '/Applications/Chromium.app/Contents/MacOS/Chromium',
      ];
      for (final candidate in candidates) {
        if (File(candidate).existsSync()) {
          _cachedBrowserExecutable = candidate;
          return candidate;
        }
      }
    } else if (Platform.isLinux) {
      const candidates = [
        '/usr/bin/google-chrome',
        '/usr/bin/chromium-browser',
        '/usr/bin/chromium',
        '/usr/bin/microsoft-edge',
      ];
      for (final candidate in candidates) {
        if (File(candidate).existsSync()) {
          _cachedBrowserExecutable = candidate;
          return candidate;
        }
      }
    }
    return null;
  }

  /// Resolve citation item from controller bibliographies
  CitationItem? _resolveCitation(String key, EditorController controller) {
    final clean = key.trim().replaceFirst(_cleanKeyRegex, '');
    if (clean.isEmpty) return null;
    return controller.bibliographyService.findByKey(clean) ??
        controller.zoteroService.findByKey(clean);
  }

  /// Format an individual citation segment in normal weight and colour
  String _formatCitationSegment(
    String segment, {
    required bool bracketed,
    required EditorController controller,
    Map<String, int>? keyToNumber,
  }) {
    var raw = segment.trim();
    bool suppressAuthor = raw.startsWith('-');
    if (suppressAuthor) raw = raw.substring(1).trim();
    if (raw.startsWith('@')) raw = raw.substring(1).trim();

    String key;
    String? locator;
    final commaIdx = raw.indexOf(',');
    if (commaIdx != -1) {
      key = raw.substring(0, commaIdx).trim();
      locator = raw.substring(commaIdx + 1).trim();
    } else {
      key = raw.trim();
    }

    final item = _resolveCitation(key, controller);
    String authorsStr;
    String yearStr;

    if (item != null) {
      authorsStr = item.shortAuthorSummary;
      yearStr = item.effectiveYear;
    } else {
      authorsStr = CitationItem.inferAuthorFromKey(key);
      final yearMatch = _yearRegex.firstMatch(key);
      yearStr = yearMatch?.group(0) ?? 'n.d.';
    }

    final isNumeric = controller.activeCslStyle.isNumeric;
    final num = isNumeric ? (keyToNumber?[key.toLowerCase()] ?? 1) : null;
    final yearDisplay = yearStr.isNotEmpty ? yearStr : 'n.d.';
    final locatorDisplay = (locator != null && locator.isNotEmpty)
        ? ', $locator'
        : '';

    if (isNumeric) {
      if (bracketed) {
        return '$num$locatorDisplay';
      } else {
        if (suppressAuthor) {
          return '[$num$locatorDisplay]';
        } else {
          return '$authorsStr [$num$locatorDisplay]';
        }
      }
    } else {
      if (bracketed) {
        if (suppressAuthor) {
          return '$yearDisplay$locatorDisplay';
        } else {
          return '$authorsStr, $yearDisplay$locatorDisplay';
        }
      } else {
        return '$authorsStr ($yearDisplay$locatorDisplay)';
      }
    }
  }

  /// Replace citation keys with formatted plain-text citations and append references
  String _processMarkdownForExport({
    required String markdown,
    required EditorController controller,
  }) {
    if (markdown.trim().isEmpty) {
      return '_Document is empty._';
    }

    var stripped = YamlFrontmatterHelper.stripYamlFrontmatter(markdown);

    // Match in-app preview preprocessing for task checkboxes and bullet spacing
    stripped = stripped.replaceAllMapped(
      _emptyTaskRegex,
      (m) => '${m[1]} \u00A0',
    );
    stripped = stripped.replaceAllMapped(_emptyBulletRegex, (m) {
      final indent = m[1] ?? '';
      final marker = m[2] ?? '*';
      final spaces = m[3] ?? '';
      final visibleSpaces = '\u00A0' * spaces.length;
      return '$indent\\$marker$visibleSpaces';
    });
    stripped = stripped.replaceAllMapped(_multiSpaceBulletRegex, (m) {
      final marker = m[1]!;
      final totalMatch = m.group(0)!;
      final spaceCount = totalMatch.length - marker.length;
      final extraSpaces = '\u00A0' * (spaceCount - 1);
      return '$marker $extraSpaces';
    });

    if (!stripped.contains('@')) return stripped;

    final isNumeric = controller.activeCslStyle.isNumeric;
    final citedKeysInOrder = <String>[];
    final citedKeysSet = <String>{};
    final Map<String, int> keyToNumber = {};

    // 1. Collect cited keys in order of appearance
    for (final match in _bracketRegex.allMatches(stripped)) {
      final inner = match.group(1)!;
      for (final s in inner.split(';')) {
        var clean = s.trim();
        if (clean.startsWith('-')) clean = clean.substring(1).trim();
        if (clean.startsWith('@')) clean = clean.substring(1).trim();
        final comma = clean.indexOf(',');
        final k = comma != -1 ? clean.substring(0, comma).trim() : clean;
        if (k.isNotEmpty && citedKeysSet.add(k.toLowerCase())) {
          citedKeysInOrder.add(k);
          keyToNumber[k.toLowerCase()] = citedKeysInOrder.length;
        }
      }
    }
    for (final match in _inTextRegex.allMatches(stripped)) {
      final k = match.group(1)!;
      if (k.isNotEmpty && citedKeysSet.add(k.toLowerCase())) {
        citedKeysInOrder.add(k);
        keyToNumber[k.toLowerCase()] = citedKeysInOrder.length;
      }
    }

    var processed = stripped;

    // 2. Replace bracketed citations: [@key1; @key2, p. 5]
    processed = processed.replaceAllMapped(_bracketRegex, (match) {
      final inner = match.group(1)!;
      final segments = inner.split(';').map((s) => s.trim()).toList();
      final formatted = segments
          .map(
            (s) => _formatCitationSegment(
              s,
              bracketed: true,
              controller: controller,
              keyToNumber: keyToNumber,
            ),
          )
          .join(isNumeric ? ', ' : '; ');
      final display = isNumeric ? '[$formatted]' : '($formatted)';
      return '<span class="citation">$display</span>';
    });

    // 3. Replace in-text citations: @key or @key [p. 10]
    processed = processed.replaceAllMapped(_inTextRegex, (match) {
      final key = match.group(1)!;
      final loc = match.group(2);
      final segmentText = loc != null ? '@$key, $loc' : '@$key';
      final formatted = _formatCitationSegment(
        segmentText,
        bracketed: false,
        controller: controller,
        keyToNumber: keyToNumber,
      );
      return '<span class="citation">$formatted</span>';
    });

    // 4. Append References section if citations were present and no heading exists
    if (citedKeysInOrder.isNotEmpty) {
      final hasExistingReferences =
          MarkdownRenderService.hasExistingReferencesHeading(markdown);

      if (!hasExistingReferences) {
        final buffer = StringBuffer(processed);
        buffer.writeln('\n\n---\n\n## References\n');

        if (isNumeric) {
          for (int i = 0; i < citedKeysInOrder.length; i++) {
            final key = citedKeysInOrder[i];
            final num = i + 1;
            final item = _resolveCitation(key, controller);
            if (item != null) {
              buffer.writeln(item.formatBibliographyEntry(numericIndex: num));
            } else {
              final seg = _formatCitationSegment(
                '@$key',
                bracketed: false,
                controller: controller,
              );
              buffer.writeln('$num. $seg. `@$key`');
            }
          }
        } else {
          final sortedKeys = List<String>.from(citedKeysInOrder);
          sortedKeys.sort((keyA, keyB) {
            final itemA = _resolveCitation(keyA, controller);
            final itemB = _resolveCitation(keyB, controller);
            final surnameA = itemA?.authors.isNotEmpty == true
                ? CitationItem.extractSurname(itemA!.authors.first)
                : CitationItem.inferAuthorFromKey(keyA);
            final surnameB = itemB?.authors.isNotEmpty == true
                ? CitationItem.extractSurname(itemB!.authors.first)
                : CitationItem.inferAuthorFromKey(keyB);
            final cmp = surnameA.toLowerCase().compareTo(
              surnameB.toLowerCase(),
            );
            if (cmp != 0) return cmp;
            return (itemA?.effectiveYear ?? '').compareTo(
              itemB?.effectiveYear ?? '',
            );
          });

          for (final key in sortedKeys) {
            final item = _resolveCitation(key, controller);
            if (item != null) {
              buffer.writeln(item.formatBibliographyEntry());
            } else {
              final seg = _formatCitationSegment(
                '@$key',
                bracketed: false,
                controller: controller,
              );
              buffer.writeln('- $seg. `@$key`');
            }
          }
        }

        processed = buffer.toString();
      }
    }

    return processed;
  }

  static String _imageMimeType(String filePath) {
    switch (p.extension(filePath).toLowerCase()) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.svg':
        return 'image/svg+xml';
      case '.bmp':
        return 'image/bmp';
      case '.ico':
        return 'image/x-icon';
      case '.tif':
      case '.tiff':
        return 'image/tiff';
      case '.avif':
        return 'image/avif';
      default:
        return 'image/png';
    }
  }

  static String _unescapeHtmlAttr(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  static String _escapeHtmlAttr(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  File? _resolveLocalImageFile(String src, EditorController controller) {
    var clean = src.trim();
    if (clean.isEmpty) return null;

    if (clean.startsWith('file://')) {
      final uri = Uri.tryParse(clean);
      if (uri != null) {
        try {
          return File(uri.toFilePath());
        } catch (_) {}
      }
      clean = clean.substring(7);
      if (Platform.isWindows && clean.startsWith('/')) {
        clean = clean.substring(1);
      }
    }

    if (clean.contains('%')) {
      try {
        final decoded = Uri.decodeFull(clean);
        clean = decoded;
      } catch (_) {}
    }

    final isWindowsAbs =
        _winAbsRegex.hasMatch(clean) || clean.startsWith(r'\\');
    final isPosixAbs = clean.startsWith('/');
    if (isWindowsAbs || isPosixAbs || p.isAbsolute(clean)) {
      return File(clean);
    }

    // 1. Try relative to current document directory
    final currentDoc = controller.currentFilePath;
    if (currentDoc != null && currentDoc.isNotEmpty) {
      final docDir = p.dirname(currentDoc);
      final candidate = File(p.normalize(p.join(docDir, clean)));
      if (candidate.existsSync()) {
        return candidate;
      }
    }

    // 2. Try relative to current working directory
    final cwdCandidate = File(
      p.normalize(p.join(Directory.current.path, clean)),
    );
    if (cwdCandidate.existsSync()) {
      return cwdCandidate;
    }

    // Fallback to document directory candidate if known
    if (currentDoc != null && currentDoc.isNotEmpty) {
      final docDir = p.dirname(currentDoc);
      return File(p.normalize(p.join(docDir, clean)));
    }
    return cwdCandidate;
  }

  /// Resolve local image sources to embedded data URIs (or file URIs for very large files)
  /// and convert `#widthxheight` dimension fragments into HTML `width`/`height` attributes.
  String _resolveImagesInHtml(String htmlBody, EditorController controller) {
    if (!htmlBody.contains('<img') &&
        !htmlBody.contains('<IMG') &&
        !htmlBody.contains('<Img')) {
      return htmlBody;
    }

    final codeTokens = <String>[];
    var processed = htmlBody.replaceAllMapped(_codeMaskRegex, (m) {
      codeTokens.add(m.group(0)!);
      return '%%CODE_BLOCK_${codeTokens.length - 1}%%';
    });

    processed = processed.replaceAllMapped(_imgTagRegex, (match) {
      final fullTag = match.group(0)!;
      final attrs = match.group(1) ?? '';
      final srcMatch = _srcAttrRegex.firstMatch(attrs);
      if (srcMatch == null) return fullTag;

      final rawAttrVal = srcMatch.group(1) ?? srcMatch.group(2) ?? '';
      var cleanSrc = _unescapeHtmlAttr(rawAttrVal).trim();
      if (cleanSrc.isEmpty) return fullTag;

      String? fragWidth;
      String? fragHeight;
      if (!cleanSrc.startsWith('data:')) {
        final hashIndex = cleanSrc.lastIndexOf('#');
        if (hashIndex != -1) {
          final fragment = cleanSrc.substring(hashIndex + 1);
          final dims = fragment.split('x');
          if (dims.length == 2 &&
              double.tryParse(dims[0]) != null &&
              double.tryParse(dims[1]) != null) {
            fragWidth = dims[0];
            fragHeight = dims[1];
            cleanSrc = cleanSrc.substring(0, hashIndex);
          } else if (dims.length == 1 && double.tryParse(dims[0]) != null) {
            fragWidth = dims[0];
            cleanSrc = cleanSrc.substring(0, hashIndex);
          }
        }
      }

      String resolvedSrc = cleanSrc;
      final lowerSrc = cleanSrc.toLowerCase();
      final isRemoteOrData =
          lowerSrc.startsWith('data:') ||
          lowerSrc.startsWith('http://') ||
          lowerSrc.startsWith('https://');

      if (!isRemoteOrData) {
        final file = _resolveLocalImageFile(cleanSrc, controller);
        if (file != null && file.existsSync()) {
          try {
            // Embed files up to 25 MB as data URIs for reliable headless PDF rendering
            if (file.lengthSync() <= 25 * 1024 * 1024) {
              final mime = _imageMimeType(file.path);
              final b64 = base64Encode(file.readAsBytesSync());
              resolvedSrc = 'data:$mime;base64,$b64';
            } else {
              resolvedSrc = file.uri.toString();
            }
          } catch (_) {
            resolvedSrc = file.uri.toString();
          }
        }
      }

      final escapedSrc = _escapeHtmlAttr(resolvedSrc);
      var newAttrs = attrs.replaceFirst(
        srcMatch.group(0)!,
        'src="$escapedSrc"',
      );

      if (fragWidth != null && !_widthAttrRegex.hasMatch(newAttrs)) {
        newAttrs = '$newAttrs width="${_escapeHtmlAttr(fragWidth)}"';
      }
      if (fragHeight != null && !_heightAttrRegex.hasMatch(newAttrs)) {
        newAttrs = '$newAttrs height="${_escapeHtmlAttr(fragHeight)}"';
      }

      final selfClosing = fullTag.trimRight().endsWith('/>') ? ' /' : '';
      return '<img$newAttrs$selfClosing>';
    });

    if (codeTokens.isNotEmpty) {
      processed = processed.replaceAllMapped(
        _codeUnmaskRegex,
        (m) => codeTokens[int.parse(m.group(1)!)],
      );
    }

    return processed;
  }

  /// Replace standalone `---` horizontal rules (outside fenced code blocks)
  /// with [pageBreakMarkup] so no horizontal line is rendered.
  static String replaceHrWithPageBreaks(
    String markdown, {
    String pageBreakMarkup = '<div class="page-break"></div>',
  }) {
    final codeTokens = <String>[];
    var masked = markdown.replaceAllMapped(_fencedCodeRegex, (m) {
      codeTokens.add(m.group(0)!);
      return '%%CODE_BLOCK_${codeTokens.length - 1}%%';
    });

    masked = masked.replaceAllMapped(_hrPageBreakRegex, (m) {
      return '\n\n$pageBreakMarkup\n\n';
    });

    if (codeTokens.isNotEmpty) {
      masked = masked.replaceAllMapped(
        _codeUnmaskRegex,
        (m) => codeTokens[int.parse(m.group(1)!)],
      );
    }
    return masked;
  }

  /// Generate a complete, standalone HTML document mimicking the preview styles
  String generateHtmlDocument({
    required String markdown,
    required EditorController controller,
    String? title,
    String pageSize = 'a4',
    String marginSize = 'medium',
    double fontScale = 1.0,
    bool useHrAsPageBreak = false,
  }) {
    final docTitle = title ?? controller.currentFileName.replaceAll('.md', '');
    var processedMarkdown = _processMarkdownForExport(
      markdown: markdown,
      controller: controller,
    );
    if (useHrAsPageBreak) {
      processedMarkdown = replaceHrWithPageBreaks(processedMarkdown);
    }

    // Convert markdown to HTML using GitHub Flavored Markdown + preview inline syntaxes
    var rawHtmlBody = md.markdownToHtml(
      processedMarkdown,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      inlineSyntaxes: [
        _ExportDisplayMathSyntax(),
        _ExportInlineMathSyntax(),
        SuperscriptSyntax(),
        SubscriptSyntax(),
      ],
    );

    // Convert fenced ```math and ```latex code blocks into display math containers
    if (rawHtmlBody.contains('language-math') ||
        rawHtmlBody.contains('language-latex')) {
      rawHtmlBody = rawHtmlBody.replaceAllMapped(
        _mathCodeBlockRegex,
        (m) => '<div class="math-display">\$\$\n${m[1]!.trim()}\n\$\$</div>',
      );
    }

    final htmlBody = _resolveImagesInHtml(rawHtmlBody, controller);

    final bodyFont = controller.renderBodyFont;
    final headerFont = controller.effectiveRenderHeaderFont;
    final codeFont = controller.editorFontFamily;
    final effectivePageSize = pageSize.toLowerCase() == 'letter'
        ? 'letter'
        : 'A4';
    final effectiveMargin = resolvePageMargin(marginSize);
    final effectiveScale = fontScale.clamp(0.5, 2.0);
    final effectiveFontSizePt = (8.8 * effectiveScale).toStringAsFixed(2);

    return '''<!DOCTYPE html>
<html lang="en-GB">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$docTitle</title>

  <!-- KaTeX for high-fidelity formula rendering -->
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css">
  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.js"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/contrib/auto-render.min.js"
          onload="renderMathInElement(document.body, {delimiters: [{left: '\$\$', right: '\$\$', display: true}, {left: '\\\\[', right: '\\\\]', display: true}, {left: '\$', right: '\$', display: false}, {left: '\\\\(', right: '\\\\)', display: false}]});"></script>

  <style>
    :root {
      --body-font: '$bodyFont', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      --header-font: '$headerFont', Georgia, serif;
      --code-font: '$codeFont', Consolas, "Cascadia Code", "Courier New", monospace;
      --code-green: $codeGreenColor;
    }

    @page {
      size: $effectivePageSize portrait;
      margin: $effectiveMargin;
    }

    *, *::before, *::after {
      box-sizing: border-box;
    }

    body {
      font-family: var(--body-font);
      font-size: ${effectiveFontSizePt}pt;
      line-height: 1.6;
      color: #0f172a;
      background: #f8fafc;
      margin: 0;
      padding: 40px 20px;
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
    }

    .page-container {
      max-width: 850px;
      margin: 0 auto;
      background: #ffffff;
      padding: 56px 64px;
      border: 1px solid #cbd5e1;
      border-radius: 2px;
      box-shadow: 0 4px 16px rgba(15, 23, 42, 0.08), 0 1px 4px rgba(15, 23, 42, 0.04);
    }

    /* Headings */
    h1, h2, h3, h4, h5, h6 {
      font-family: var(--header-font);
      color: #0f172a;
      font-weight: 700;
      line-height: 1.35;
      margin-top: 1.5em;
      margin-bottom: 0.5em;
    }

    h1 {
      font-size: 2.1em;
      border-bottom: 1px solid #e2e8f0;
      padding-bottom: 0.3em;
      margin-top: 0;
    }

    h2 {
      font-size: 1.55em;
      border-bottom: 1px solid #f1f5f9;
      padding-bottom: 0.25em;
    }

    h3 { font-size: 1.25em; }
    h4 { font-size: 1.1em; }
    h5 { font-size: 1.0em; }
    h6 { font-size: 0.9em; color: #64748b; }

    p {
      margin-top: 0;
      margin-bottom: 1.15em;
    }

    /* Code Blocks & Inline Code: Monospace font, no background, deep green text */
    code, pre {
      font-family: var(--code-font);
    }

    pre {
      background: transparent !important;
      background-color: transparent !important;
      color: var(--code-green) !important;
      font-size: 0.95em;
      line-height: 1.5;
      padding: 10px 0;
      margin: 16px 0;
      border: none;
      overflow-x: auto;
      white-space: pre-wrap;
      word-wrap: break-word;
    }

    pre code {
      background: transparent !important;
      background-color: transparent !important;
      color: var(--code-green) !important;
      font-size: inherit;
      padding: 0;
      border: none;
    }

    p code, li code, td code, th code {
      background: transparent !important;
      background-color: transparent !important;
      color: var(--code-green) !important;
      font-size: 0.92em;
      padding: 0 2px;
      font-weight: 500;
    }

    /* References and Citations: Normal weight, normal body colour, no coloured badges */
    .citation {
      font-weight: normal !important;
      color: inherit !important;
      background: transparent !important;
      padding: 0 !important;
      border: none !important;
    }

    /* Blockquotes */
    blockquote {
      border-left: 3.5px solid #2563eb;
      margin: 18px 0;
      padding: 8px 18px;
      color: #475569;
      font-style: italic;
      background: #f8fafc;
      border-radius: 0 4px 4px 0;
    }

    /* Tables */
    table {
      border-collapse: collapse;
      width: 100%;
      margin: 20px 0;
      font-size: 0.95em;
    }

    th, td {
      border: 1px solid #cbd5e1;
      padding: 8px 14px;
      text-align: left;
    }

    th {
      font-family: var(--header-font);
      background: #f1f5f9;
      font-weight: 700;
      color: #0f172a;
    }

    tr:nth-child(even) td {
      background: #f8fafc;
    }

    /* Lists */
    ul, ol {
      padding-left: 24px;
      margin-bottom: 1.15em;
    }

    li {
      margin-bottom: 0.4em;
    }

    hr {
      border: none;
      border-top: 1px solid #e2e8f0;
      margin: 32px 0;
    }

    /* Images */
    img {
      max-width: 100%;
      height: auto;
      display: inline-block;
    }

    /* Superscripts & Subscripts (matching in-app preview) */
    sup, sub {
      font-size: 0.75em;
      line-height: 0;
      position: relative;
      vertical-align: baseline;
    }

    sup {
      top: -0.45em;
    }

    sub {
      bottom: -0.25em;
    }

    /* Display Math */
    .math-display {
      text-align: center;
      margin: 14px 0;
      overflow-x: auto;
    }

    /* Task List Checkboxes */
    input[type="checkbox"] {
      margin-right: 0.45em;
      accent-color: #2563eb;
      vertical-align: middle;
    }

    /* Page Breaks (when using --- as page breaks) */
    .page-break {
      break-after: page;
      page-break-after: always;
      height: 0;
      margin: 0;
      padding: 0;
      border: none;
    }

    /* Print Stylesheet for exact Word Processor fidelity */
    @media print {
      body {
        background: transparent !important;
        padding: 0 !important;
      }
      .page-container {
        border: none !important;
        box-shadow: none !important;
        padding: 0 !important;
        max-width: none !important;
        margin: 0 !important;
      }
      img {
        max-width: 100%;
        height: auto;
        page-break-inside: avoid;
        break-inside: avoid;
      }
      pre, pre code, p code, li code, td code {
        background: transparent !important;
        color: var(--code-green) !important;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
      }
      .citation {
        font-weight: normal !important;
        color: inherit !important;
      }
    }
  </style>
</head>
<body>
  <div class="page-container">
    $htmlBody
  </div>
</body>
</html>
''';
  }

  /// Export directly to a standalone HTML file
  Future<PandocResult> exportHtml({
    required String markdown,
    required String targetPath,
    required EditorController controller,
    String? title,
    String pageSize = 'a4',
    double fontScale = 1.0,
    bool useHrAsPageBreak = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final targetFile = File(targetPath);
      if (!await targetFile.parent.exists()) {
        await targetFile.parent.create(recursive: true);
      }

      final html = generateHtmlDocument(
        markdown: markdown,
        controller: controller,
        title: title,
        pageSize: pageSize,
        fontScale: fontScale,
        useHrAsPageBreak: useHrAsPageBreak,
      );

      await targetFile.writeAsString(html);
      stopwatch.stop();

      return PandocResult(
        success: true,
        exitCode: 0,
        targetFile: targetPath,
        stdout:
            'HTML document exported successfully matching preview typography',
        stderr: '',
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return PandocResult(
        success: false,
        exitCode: -1,
        targetFile: targetPath,
        stdout: '',
        stderr: e.toString(),
        duration: stopwatch.elapsed,
        errorMessage: 'Direct HTML export failed: $e',
      );
    }
  }

  /// Export directly to a publication-grade PDF file using the pre-installed system browser engine
  Future<PandocResult> exportPdf({
    required String markdown,
    required String targetPath,
    required EditorController controller,
    String? title,
    String pageSize = 'a4',
    String marginSize = 'medium',
    double fontScale = 1.0,
    bool useHrAsPageBreak = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    final browserExe = await findBrowserExecutable();

    if (browserExe == null) {
      stopwatch.stop();
      return PandocResult(
        success: false,
        exitCode: -1,
        targetFile: targetPath,
        stdout: '',
        stderr: 'No compatible browser executable found for direct PDF export.',
        duration: stopwatch.elapsed,
        errorMessage: 'A compatible browser (Microsoft Edge or Google Chrome) was not detected. Please install Microsoft Edge or Google Chrome to enable direct PDF export.',
      );
    }

    File? tempHtmlFile;
    Directory? tempProfileDir;

    try {
      // 1. Generate preview-matched HTML
      final html = generateHtmlDocument(
        markdown: markdown,
        controller: controller,
        title: title,
        pageSize: pageSize,
        marginSize: marginSize,
        fontScale: fontScale,
        useHrAsPageBreak: useHrAsPageBreak,
      );

      final tempDir = await getTemporaryDirectory();
      final tempTimestamp = DateTime.now().millisecondsSinceEpoch;
      tempHtmlFile = File(
        '${tempDir.path}${Platform.pathSeparator}draftdown_pdf_$tempTimestamp.html',
      );
      await tempHtmlFile.writeAsString(html);

      tempProfileDir = Directory(
        '${tempDir.path}${Platform.pathSeparator}draftdown_pdf_profile_$tempTimestamp',
      );
      if (!await tempProfileDir.exists()) {
        await tempProfileDir.create(recursive: true);
      }

      final targetFile = File(targetPath);
      if (!await targetFile.parent.exists()) {
        await targetFile.parent.create(recursive: true);
      }

      // Convert local file path to file:/// URL with escaped spaces
      final fileUri = tempHtmlFile.uri.toString();

      final args = [
        '--headless=new',
        '--disable-gpu',
        '--allow-file-access-from-files',
        '--no-pdf-header-footer',
        '--log-level=3',
        '--silent-debugger-extension-api',
        '--user-data-dir=${tempProfileDir.path}',
        '--print-to-pdf=${targetFile.path}',
        fileUri,
      ];

      debugPrint(
        '[DirectExportService] Running $browserExe to print PDF: ${args.join(" ")}',
      );

      final processResult = await Process.run(browserExe, args);
      stopwatch.stop();

      final pdfCreated = await targetFile.exists();
      final isSuccess = processResult.exitCode == 0 && pdfCreated;

      // Filter mundane browser engine diagnostic noise from stderr
      var cleanStderr = processResult.stderr.toString();
      var cleanStdout = processResult.stdout.toString();

      final stderrLines = cleanStderr.split('\n');
      final filteredStderr = <String>[];
      for (final line in stderrLines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        // Suppress benign Chromium task manager and crbug diagnostic noise
        if (trimmed.contains('fallback_task_provider.cc') ||
            trimmed.contains('crbug.com')) {
          continue;
        }
        // If Chromium outputs written bytes info to stderr, route to stdout instead
        if (trimmed.contains('bytes written to file')) {
          if (cleanStdout.isNotEmpty) cleanStdout += '\n';
          cleanStdout += trimmed;
          continue;
        }
        filteredStderr.add(line);
      }
      cleanStderr = filteredStderr.join('\n').trim();

      return PandocResult(
        success: isSuccess,
        exitCode: processResult.exitCode,
        targetFile: targetPath,
        stdout: cleanStdout,
        stderr: cleanStderr,
        duration: stopwatch.elapsed,
        errorMessage: isSuccess
            ? null
            : 'PDF conversion failed with exit code ${processResult.exitCode}: $cleanStderr',
      );
    } catch (e) {
      stopwatch.stop();
      return PandocResult(
        success: false,
        exitCode: -1,
        targetFile: targetPath,
        stdout: '',
        stderr: e.toString(),
        duration: stopwatch.elapsed,
        errorMessage: 'Direct PDF export failed: $e',
      );
    } finally {
      // Clean up temporary files
      if (tempHtmlFile != null && await tempHtmlFile.exists()) {
        try {
          await tempHtmlFile.delete();
        } catch (_) {}
      }
      if (tempProfileDir != null && await tempProfileDir.exists()) {
        try {
          await tempProfileDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }
}
