import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import '../../controllers/editor_controller.dart';
import '../../models/citation_item.dart';
import '../theme/app_theme.dart';

// =============================================================================
// Math Markdown Syntaxes & Builders (KaTeX-compatible)
// =============================================================================

/// Matches block/display formulas: $$...$$ or \[...\]
class DisplayMathSyntax extends md.InlineSyntax {
  DisplayMathSyntax()
      : super(r'(?:\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\])');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final formula = match[1] ?? match[2] ?? '';
    final el = md.Element('displaymath', [md.Text(formula.trim())]);
    parser.addNode(el);
    return true;
  }
}

/// Matches inline math formulas: $...$ or \(...\)
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

/// Element builder rendering LaTeX formulas using Math.tex from flutter_math_fork
class MathElementBuilder extends MarkdownElementBuilder {
  final bool isDisplay;
  final Color textColor;
  final String codeFont;

  MathElementBuilder({
    required this.isDisplay,
    required this.textColor,
    required this.codeFont,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final tex = element.textContent.trim();
    if (tex.isEmpty) return const SizedBox.shrink();

    if (isDisplay) {
      return Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            tex,
            mathStyle: MathStyle.display,
            textStyle: (preferredStyle ?? const TextStyle()).copyWith(
              color: textColor,
              fontSize: 16.5,
            ),
            onErrorFallback: (err) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '\$\$$tex\$\$',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontFamily: codeFont,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Math.tex(
      tex,
      mathStyle: MathStyle.text,
      textStyle: (preferredStyle ?? const TextStyle()).copyWith(
        color: textColor,
        fontSize: 14.5,
      ),
      onErrorFallback: (err) => Text(
        '\$$tex\$',
        style: TextStyle(
          color: Colors.redAccent,
          fontFamily: codeFont,
          fontSize: 12,
        ),
      ),
    );
  }
}

// =============================================================================
// Academic Citations Markdown Syntaxes & Builders
// =============================================================================

/// Matches bracketed citations: [@key], [@key, locator], [-@key], [@key1; @key2]
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

/// Matches in-text citations: @key or @key [p. 42]
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

/// Formatted citation model
class FormattedCitationSegment {
  final String rendered;
  final String citekey;
  final String tooltip;
  final CitationItem? item;

  const FormattedCitationSegment({
    required this.rendered,
    required this.citekey,
    required this.tooltip,
    this.item,
  });
}

/// Helper resolving citations against active controller and Zotero
class CitationHelper {
  final EditorController? controller;

  CitationHelper(this.controller);

  CitationItem? resolveItem(String rawKey) {
    final cleanKey = rawKey.trim().replaceAll(RegExp(r'^[@\-]'), '');
    if (cleanKey.isEmpty || controller == null) return null;

    // 1. Search in active loaded bibliography
    for (final item in controller!.citations) {
      if (item.key.toLowerCase() == cleanKey.toLowerCase()) {
        return item;
      }
    }

    // 2. Search in Zotero library
    for (final item in controller!.zoteroCitations) {
      if (item.key.toLowerCase() == cleanKey.toLowerCase()) {
        return item;
      }
    }

    return null;
  }

  /// Format an individual citation item
  FormattedCitationSegment formatSegment({
    required String segmentText,
    required bool bracketed,
  }) {
    var raw = segmentText.trim();
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

    final item = resolveItem(key);
    String authorsStr;
    String yearStr;

    if (item != null) {
      authorsStr = item.shortAuthorSummary;
      yearStr = item.effectiveYear;
    } else {
      authorsStr = CitationItem.inferAuthorFromKey(key);
      final yearMatch = RegExp(r'(19\d\d|20\d\d)').firstMatch(key);
      yearStr = yearMatch?.group(0) ?? 'n.d.';
    }

    final yearDisplay = yearStr.isNotEmpty ? yearStr : 'n.d.';
    final locatorDisplay =
        (locator != null && locator.isNotEmpty) ? ', $locator' : '';

    String rendered;
    if (bracketed) {
      if (suppressAuthor) {
        rendered = '$yearDisplay$locatorDisplay';
      } else {
        rendered = '$authorsStr, $yearDisplay$locatorDisplay';
      }
    } else {
      rendered = '$authorsStr ($yearDisplay$locatorDisplay)';
    }

    final tooltip = item != null
        ? '${item.title}\n${item.authorsSummary} (${item.year ?? "n.d."})\nCitekey: @${item.key}'
        : '$authorsStr ($yearDisplay)\nCitekey: @$key';

    return FormattedCitationSegment(
      rendered: rendered,
      citekey: key,
      tooltip: tooltip,
      item: item,
    );
  }
}

/// Element builder rendering interactive academic citations
class CitationElementBuilder extends MarkdownElementBuilder {
  final CitationHelper helper;
  final bool isDark;

  CitationElementBuilder({
    required this.helper,
    required this.isDark,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final raw = element.textContent;
    final isBracketed = element.attributes['bracketed'] != 'false';

    // Handle multiple citations in brackets e.g. [@smith2020; @doe2021]
    final segments = raw.split(';').map((s) => s.trim()).toList();
    final formattedSegments = segments
        .map((s) => helper.formatSegment(
              segmentText: s,
              bracketed: isBracketed,
            ))
        .toList();

    final linkColor =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    if (isBracketed) {
      final combined = formattedSegments.map((s) => s.rendered).join('; ');
      final tooltipCombined = formattedSegments.map((s) => s.tooltip).join('\n---\n');

      return Tooltip(
        message: tooltipCombined,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: linkColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '($combined)',
            style: (preferredStyle ?? const TextStyle()).copyWith(
              color: linkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else {
      final seg = formattedSegments.first;
      return Tooltip(
        message: seg.tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: linkColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            seg.rendered,
            style: (preferredStyle ?? const TextStyle()).copyWith(
              color: linkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }
}

/// Element builder handling code blocks, rendering ```math blocks with Math.tex
class MathCodeBlockBuilder extends MarkdownElementBuilder {
  final Color textColor;
  final String codeFont;

  MathCodeBlockBuilder({
    required this.textColor,
    required this.codeFont,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final language = element.attributes['class'];
    if (language == 'language-math' || language == 'language-latex') {
      final tex = element.textContent.trim();
      return Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            tex,
            mathStyle: MathStyle.display,
            textStyle: TextStyle(color: textColor, fontSize: 16),
            onErrorFallback: (err) => Text(
              tex,
              style: TextStyle(fontFamily: codeFont, color: Colors.redAccent),
            ),
          ),
        ),
      );
    }
    return null; // Fallback to standard code formatting
  }
}

// =============================================================================
// Image Markdown Element Builder
// =============================================================================

/// Element builder rendering images referenced in Markdown or HTML tags,
/// supporting local absolute paths, relative paths resolved against the document
/// or workspace directory, remote network URLs, data URIs, custom dimensions,
/// figure captions, and elegant error fallbacks.
class MarkdownImageElementBuilder extends MarkdownElementBuilder {
  final EditorController? controller;
  final String? imageDirectory;
  final bool isDark;
  final String codeFont;
  final Color textColor;
  final Color mutedColor;

  MarkdownImageElementBuilder({
    this.controller,
    this.imageDirectory,
    required this.isDark,
    required this.codeFont,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    var rawSrc = element.attributes['src'] ?? '';
    if (rawSrc.trim().isEmpty) return const SizedBox.shrink();

    // Decode percent-encoded URI components (e.g. %20 -> space, %5C -> \)
    try {
      rawSrc = Uri.decodeFull(rawSrc);
    } catch (_) {}

    final alt = element.attributes['alt'];
    final title = element.attributes['title'];

    // Parse dimensions if present
    double? width;
    double? height;

    if (element.attributes['width'] != null) {
      width = double.tryParse(element.attributes['width']!);
    }
    if (element.attributes['height'] != null) {
      height = double.tryParse(element.attributes['height']!);
    }

    // Check for fragment dimension syntax: #widthxheight or #width
    final hashIndex = rawSrc.lastIndexOf('#');
    if (hashIndex != -1) {
      final fragment = rawSrc.substring(hashIndex + 1);
      final dims = fragment.split('x');
      if (dims.length == 2) {
        width ??= double.tryParse(dims[0]);
        height ??= double.tryParse(dims[1]);
        rawSrc = rawSrc.substring(0, hashIndex);
      } else if (dims.length == 1) {
        final w = double.tryParse(dims[0]);
        if (w != null) {
          width ??= w;
          rawSrc = rawSrc.substring(0, hashIndex);
        }
      }
    }

    Widget imageWidget;

    // 1. Data URI (Base64)
    if (rawSrc.startsWith('data:image/')) {
      final commaIndex = rawSrc.indexOf(',');
      if (commaIndex != -1) {
        try {
          final base64Data = rawSrc.substring(commaIndex + 1).trim();
          final bytes = base64Decode(base64Data);
          imageWidget = Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => _buildErrorWidget(
                context, rawSrc, alt, 'Failed to decode image data'),
          );
        } catch (_) {
          imageWidget = _buildErrorWidget(
              context, rawSrc, alt, 'Invalid base64 image data');
        }
      } else {
        imageWidget =
            _buildErrorWidget(context, rawSrc, alt, 'Malformed data URI');
      }
    }
    // 2. Remote network image (http:// or https://)
    else if (rawSrc.startsWith('http://') || rawSrc.startsWith('https://')) {
      imageWidget = Image.network(
        rawSrc,
        width: width,
        height: height,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width ?? 200,
            height: height ?? 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.image_outlined,
              color: mutedColor,
              size: 24,
            ),
          );
        },
        errorBuilder: (ctx, err, stack) => _buildErrorWidget(
            context, rawSrc, alt, 'Unable to load network image'),
      );
    }
    // 3. Local filesystem image / Asset
    else {
      final file = _resolveLocalFile(rawSrc);
      if (file != null && file.existsSync()) {
        imageWidget = Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => _buildErrorWidget(
              context, rawSrc, alt, 'Unable to decode image file'),
        );
      } else if (rawSrc.startsWith('asset:') || rawSrc.startsWith('assets/')) {
        final assetPath =
            rawSrc.startsWith('asset:') ? rawSrc.substring(6) : rawSrc;
        imageWidget = Image.asset(
          assetPath,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => _buildErrorWidget(
              context, rawSrc, alt, 'Asset not found: $assetPath'),
        );
      } else {
        imageWidget = _buildErrorWidget(
          context,
          rawSrc,
          alt,
          file != null ? 'File not found: ${file.path}' : 'File not found',
        );
      }
    }

    return _wrapImage(
      context: context,
      imageWidget: imageWidget,
      rawSrc: rawSrc,
      title: title,
      alt: alt,
      width: width,
      height: height,
    );
  }

  File? _resolveLocalFile(String src) {
    var clean = src.trim();
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

    // Normalise path separators for checking
    final isWindowsAbs =
        RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(clean) || clean.startsWith(r'\\');
    final isPosixAbs = clean.startsWith('/');
    if (isWindowsAbs || isPosixAbs || p.isAbsolute(clean)) {
      return File(clean);
    }

    // 1. Try relative to document directory
    final currentDoc = controller?.currentFilePath;
    if (currentDoc != null && currentDoc.isNotEmpty) {
      final docDir = p.dirname(currentDoc);
      final candidate = File(p.normalize(p.join(docDir, clean)));
      if (candidate.existsSync()) {
        return candidate;
      }
    }

    // 2. Try relative to provided imageDirectory
    if (imageDirectory != null && imageDirectory!.isNotEmpty) {
      final candidate = File(p.normalize(p.join(imageDirectory!, clean)));
      if (candidate.existsSync()) {
        return candidate;
      }
    }

    // 3. Try relative to current working directory
    final cwdCandidate =
        File(p.normalize(p.join(Directory.current.path, clean)));
    if (cwdCandidate.existsSync()) {
      return cwdCandidate;
    }

    // Fallback: return candidate in document directory if known, else cwd
    if (currentDoc != null && currentDoc.isNotEmpty) {
      final docDir = p.dirname(currentDoc);
      return File(p.normalize(p.join(docDir, clean)));
    }
    if (imageDirectory != null && imageDirectory!.isNotEmpty) {
      return File(p.normalize(p.join(imageDirectory!, clean)));
    }
    return cwdCandidate;
  }

  Widget _wrapImage({
    required BuildContext context,
    required Widget imageWidget,
    required String rawSrc,
    required String? title,
    required String? alt,
    required double? width,
    required double? height,
  }) {
    final caption = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : (alt != null && alt.trim().isNotEmpty && !alt.startsWith('http')
            ? alt.trim()
            : null);

    Widget content = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: imageWidget,
    );

    if (width != null || height != null) {
      content = SizedBox(
        width: width,
        height: height,
        child: content,
      );
    }

    final tooltipMsg = title ?? alt ?? p.basename(rawSrc);
    if (tooltipMsg.isNotEmpty) {
      content = Tooltip(
        message: tooltipMsg,
        child: content,
      );
    }

    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          content,
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Segoe UI',
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: mutedColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorWidget(
    BuildContext context,
    String src,
    String? alt,
    String reason,
  ) {
    final displayName = (alt != null && alt.trim().isNotEmpty)
        ? alt.trim()
        : p.basename(src);

    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Tooltip(
      message: '$reason\nPath: $src',
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 20,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Image: $displayName',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    src,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: codeFont,
                      color: mutedColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Live Markdown Preview Widget
// =============================================================================

/// Live Markdown preview widget using flutter_markdown with customised
/// GitHub-Flavoured styling, immediate KaTeX formula rendering,
/// immediate in-place reference formatting, and auto-generated bibliography.
class MarkdownPreviewView extends StatelessWidget {
  final String markdown;
  final String bodyFont;
  final String headerFont;
  final String codeFont;
  final EditorController? controller;
  final bool? isFullView;
  final String? imageDirectory;

  const MarkdownPreviewView({
    super.key,
    required this.markdown,
    this.bodyFont = 'Segoe UI',
    this.headerFont = 'Segoe UI',
    this.codeFont = 'Consolas',
    this.controller,
    this.isFullView,
    this.imageDirectory,
  });

  /// Base directory for resolving relative image paths
  String? get effectiveImageDirectory {
    if (imageDirectory != null && imageDirectory!.isNotEmpty) {
      return imageDirectory;
    }
    final currentDoc = controller?.currentFilePath;
    if (currentDoc != null && currentDoc.isNotEmpty) {
      return p.dirname(currentDoc);
    }
    return Directory.current.path;
  }

  /// Generate augmented Markdown text with auto-generated references if cited
  String _prepareMarkdownWithReferences(CitationHelper helper) {
    if (markdown.trim().isEmpty) return '_Document is empty._';

    // 1. Convert HTML <img> tags outside fenced code blocks into Markdown image syntax
    final codeTokens = <String>[];
    var processed = markdown.replaceAllMapped(
      RegExp(r'(```[\s\S]*?```|`[^`\n]+`)'),
      (m) {
        codeTokens.add(m.group(0)!);
        return '%%CODE_BLOCK_${codeTokens.length - 1}%%';
      },
    );

    processed = processed.replaceAllMapped(
      RegExp(r'<img\s+([^>]*?)\/?>', caseSensitive: false),
      (match) {
        final attrs = match[1] ?? '';
        final src = RegExp(r'''src=["']([^"']+)["']''', caseSensitive: false)
            .firstMatch(attrs)
            ?.group(1);
        if (src == null || src.isEmpty) return match.group(0)!;

        final alt = RegExp(r'''alt=["']([^"']*)["']''', caseSensitive: false)
                .firstMatch(attrs)
                ?.group(1) ??
            '';
        final title = RegExp(r'''title=["']([^"']*)["']''', caseSensitive: false)
            .firstMatch(attrs)
            ?.group(1);
        final width = RegExp(r'''width=["']?([0-9]+)["']?''', caseSensitive: false)
            .firstMatch(attrs)
            ?.group(1);
        final height =
            RegExp(r'''height=["']?([0-9]+)["']?''', caseSensitive: false)
                .firstMatch(attrs)
                ?.group(1);

        String dim = '';
        if (width != null && height != null) {
          dim = '#${width}x$height';
        } else if (width != null) {
          dim = '#$width';
        }

        final titlePart =
            (title != null && title.isNotEmpty) ? ' "$title"' : '';
        return '![$alt]($src$dim$titlePart)';
      },
    );

    for (var i = 0; i < codeTokens.length; i++) {
      processed = processed.replaceAll('%%CODE_BLOCK_$i%%', codeTokens[i]);
    }

    // 2. Scan for all cited keys in document
    final citeRegex = RegExp(
      r'(?:\[(?:-?@[a-zA-Z0-9_\-:#\/]+(?:[^\n\]]*))\]|(?<![\w@])@([a-zA-Z0-9_\-:#\/]+))',
    );
    final matches = citeRegex.allMatches(processed);
    if (matches.isEmpty) return processed;

    // Do not append references if user already created a References or Bibliography heading
    final hasExistingReferences = RegExp(
      r'^(?:#{1,6}\s*(?:References|Bibliography)|<a\s+name="references">)',
      caseSensitive: false,
      multiLine: true,
    ).hasMatch(processed);

    if (hasExistingReferences) return processed;

    // Collect unique cited keys
    final citedKeys = <String>{};
    for (final match in matches) {
      final fullMatch = match.group(0)!;
      // Extract keys from full match
      final keyMatches =
          RegExp(r'@([a-zA-Z0-9_\-:#\/]+)').allMatches(fullMatch);
      for (final km in keyMatches) {
        final k = km.group(1);
        if (k != null && k.isNotEmpty) citedKeys.add(k);
      }
    }

    if (citedKeys.isEmpty) return processed;

    // Build references bibliography
    final buffer = StringBuffer(processed);
    buffer.writeln('\n\n---\n\n### References\n');

    final sortedKeys = citedKeys.toList()..sort();
    for (final key in sortedKeys) {
      final item = helper.resolveItem(key);
      if (item != null) {
        final authors = item.authorsSummary;
        final yearStr = item.effectiveYear != 'n.d.'
            ? item.effectiveYear
            : (item.year != null && item.year!.isNotEmpty ? item.year! : '');
        final yearDisplay = yearStr.isNotEmpty ? ' ($yearStr)' : '';
        final title = item.title;
        final venue = (item.venue != null && item.venue!.trim().isNotEmpty)
            ? ' *${item.venue}*.'
            : '';
        final doi = (item.doi != null && item.doi!.trim().isNotEmpty)
            ? ' DOI: ${item.doi}.'
            : '';
        final url = (item.url != null && item.url!.trim().isNotEmpty && item.doi == null)
            ? ' Available at: ${item.url}.'
            : '';
        buffer.writeln('- **$authors**$yearDisplay. *$title*.$venue$doi$url');
      } else {
        // Fallback reference listing
        final seg = helper.formatSegment(segmentText: '@$key', bracketed: false);
        buffer.writeln('- **${seg.rendered}**. Citekey: `@$key`');
      }
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final mutedColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final codeBg =
        isDark ? const Color(0xFF131D2E) : const Color(0xFFF1F5F9);
    final blockquoteBorder =
        isDark ? AppTheme.darkAccent : AppTheme.lightAccent;

    final helper = CitationHelper(controller);
    final effectiveMarkdown = _prepareMarkdownWithReferences(helper);

    final customStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14.5,
        height: 1.6,
        color: textColor,
      ),
      h1: TextStyle(
        fontFamily: headerFont,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textColor,
        height: 1.5,
      ),
      h2: TextStyle(
        fontFamily: headerFont,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textColor,
        height: 1.4,
      ),
      h3: TextStyle(
        fontFamily: headerFont,
        fontSize: 16.5,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.4,
      ),
      h4: TextStyle(
        fontFamily: headerFont,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.4,
      ),
      h5: TextStyle(
        fontFamily: headerFont,
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
        color: textColor,
        height: 1.4,
      ),
      h6: TextStyle(
        fontFamily: headerFont,
        fontSize: 12.5,
        fontWeight: FontWeight.bold,
        color: mutedColor,
        height: 1.4,
      ),
      blockquote: TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontStyle: FontStyle.italic,
        color: mutedColor,
      ),
      blockquoteDecoration: BoxDecoration(
        color: codeBg.withValues(alpha: 0.5),
        border: Border(left: BorderSide(color: blockquoteBorder, width: 4)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      code: TextStyle(
        fontFamily: codeFont,
        fontFamilyFallback: AppTheme.editorFontFamilyFallback,
        fontSize: 12.5,
        backgroundColor: codeBg,
        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      tableBody: TextStyle(
        fontFamily: bodyFont,
        fontSize: 13,
        color: textColor,
      ),
      tableHead: TextStyle(
        fontFamily: headerFont,
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      tableBorder: TableBorder.all(
        color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        width: 1,
      ),
      tableCellsPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );

    final bool effectiveIsFullView =
        isFullView ?? (controller?.viewMode == EditorViewMode.preview);

    final canvasBg =
        isDark ? AppTheme.darkPreviewCanvas : AppTheme.lightPreviewCanvas;
    final pageBg =
        isDark ? AppTheme.darkPreviewPage : AppTheme.lightPreviewPage;
    final pageBorder =
        isDark ? AppTheme.darkPreviewBorder : AppTheme.lightPreviewBorder;

    final double deskHorizontalPadding = effectiveIsFullView ? 32.0 : 16.0;
    final double deskVerticalPadding = effectiveIsFullView ? 28.0 : 16.0;
    final double innerHorizontalPadding = effectiveIsFullView ? 48.0 : 28.0;
    final double innerVerticalPadding = effectiveIsFullView ? 40.0 : 28.0;
    const double maxPageWidth = 850.0;

    return Container(
      color: canvasBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double minPageHeight =
              (constraints.maxHeight - (deskVerticalPadding * 2))
                  .clamp(120.0, double.infinity);

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: deskHorizontalPadding,
              vertical: deskVerticalPadding,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxPageWidth,
                  minHeight: minPageHeight,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: pageBg,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: pageBorder, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.40)
                            : const Color(0xFF0F172A).withValues(alpha: 0.08),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.20)
                            : const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: innerHorizontalPadding,
                    vertical: innerVerticalPadding,
                  ),
                  child: MarkdownBody(
                    data: effectiveMarkdown,
                    selectable: true,
                    imageDirectory: effectiveImageDirectory,
                    styleSheet: customStyle,
                    inlineSyntaxes: [
                      DisplayMathSyntax(),
                      InlineMathSyntax(),
                      BracketedCitationSyntax(),
                      InTextCitationSyntax(),
                    ],
                    builders: {
                      'displaymath': MathElementBuilder(
                        isDisplay: true,
                        textColor: textColor,
                        codeFont: codeFont,
                      ),
                      'inlinemath': MathElementBuilder(
                        isDisplay: false,
                        textColor: textColor,
                        codeFont: codeFont,
                      ),
                      'academiccitation': CitationElementBuilder(
                        helper: helper,
                        isDark: isDark,
                      ),
                      'code': MathCodeBlockBuilder(
                        textColor: textColor,
                        codeFont: codeFont,
                      ),
                      'img': MarkdownImageElementBuilder(
                        controller: controller,
                        imageDirectory: effectiveImageDirectory,
                        isDark: isDark,
                        codeFont: codeFont,
                        textColor: textColor,
                        mutedColor: mutedColor,
                      ),
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
