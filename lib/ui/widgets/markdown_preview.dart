import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;

import '../../controllers/editor_controller.dart';
import '../../models/citation_item.dart';
import '../../utils/yaml_frontmatter_helper.dart';
import '../../services/markdown_render_service.dart';
import '../theme/app_theme.dart';

// =============================================================================
// Math Markdown Syntaxes & Builders (KaTeX-compatible)
// =============================================================================

/// Matches block/display formulas: $$...$$ or \[...\]
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
  final double? baseFontSize;

  MathElementBuilder({
    required this.isDisplay,
    required this.textColor,
    required this.codeFont,
    this.baseFontSize,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final tex = element.textContent.trim();
    if (tex.isEmpty) return const SizedBox.shrink();

    final inlineSize = baseFontSize ?? 14.5;
    final displaySize = baseFontSize != null ? baseFontSize! * 1.15 : 16.5;

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
              fontSize: displaySize,
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
                  fontSize: inlineSize * 0.9,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              tex,
              mathStyle: MathStyle.text,
              textStyle: (preferredStyle ?? const TextStyle()).copyWith(
                color: textColor,
                fontSize: inlineSize,
              ),
              onErrorFallback: (err) => Text(
                '\$$tex\$',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontFamily: codeFont,
                  fontSize: inlineSize * 0.85,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Handles `<input>` tags (e.g. GFM task list checkboxes) so flutter_markdown_plus
/// properly clears inline elements even when a checkbox has no following text.
class InputElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return const SizedBox.shrink();
  }
}

/// Matches Pandoc `^content^` or HTML `<sup>content</sup>` inline tags
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

/// Matches Pandoc `~content~` or HTML `<sub>content</sub>` inline tags
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

/// Renders <sup> text elements as elevated, slightly smaller inline text
class SuperscriptElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent;
    final baseStyle = parentStyle ?? preferredStyle ?? const TextStyle();
    final double baseFontSize = baseStyle.fontSize ?? 14.5;
    final double targetFontSize = (baseFontSize * 0.75).clamp(8.0, 24.0);

    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Transform.translate(
              offset: Offset(0, -targetFontSize * 0.45),
              child: Text(
                text,
                style: baseStyle.copyWith(
                  fontSize: targetFontSize,
                  fontFeatures: const [FontFeature.enable('sups')],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders <sub> text elements as lowered, slightly smaller inline text
class SubscriptElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = element.textContent;
    final baseStyle = parentStyle ?? preferredStyle ?? const TextStyle();
    final double baseFontSize = baseStyle.fontSize ?? 14.5;
    final double targetFontSize = (baseFontSize * 0.75).clamp(8.0, 24.0);

    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Transform.translate(
              offset: Offset(0, targetFontSize * 0.35),
              child: Text(
                text,
                style: baseStyle.copyWith(
                  fontSize: targetFontSize,
                  fontFeatures: const [FontFeature.enable('subs')],
                ),
              ),
            ),
          ),
        ],
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
  static final RegExp _leadingAtOrHyphenRegex = RegExp(r'^[@\-]+');
  static final RegExp _yearFallbackRegex = RegExp(r'(19\d\d|20\d\d)');

  final EditorController? controller;
  Map<String, int> numericIndices;

  CitationHelper(this.controller, {this.numericIndices = const {}});

  CitationItem? resolveItem(String rawKey) {
    final cleanKey = rawKey.trim().replaceFirst(_leadingAtOrHyphenRegex, '');
    if (cleanKey.isEmpty || controller == null) return null;

    // 1. O(1) lookup in active loaded bibliography
    final bibMatch = controller!.bibliographyService.findByKey(cleanKey);
    if (bibMatch != null) return bibMatch;

    // 2. O(1) lookup in Zotero library cache
    final zoteroMatch = controller!.zoteroService.findByKey(cleanKey);
    if (zoteroMatch != null) return zoteroMatch;

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
      final yearMatch = _yearFallbackRegex.firstMatch(key);
      yearStr = yearMatch?.group(0) ?? 'n.d.';
    }

    final isNumeric = controller?.activeCslStyle.isNumeric ?? false;
    final num = isNumeric ? (numericIndices[key.toLowerCase()] ?? 1) : null;
    final yearDisplay = yearStr.isNotEmpty ? yearStr : 'n.d.';
    final locatorDisplay = (locator != null && locator.isNotEmpty)
        ? ', $locator'
        : '';

    String rendered;
    if (isNumeric) {
      if (bracketed) {
        rendered = '$num$locatorDisplay';
      } else {
        if (suppressAuthor) {
          rendered = '[$num$locatorDisplay]';
        } else {
          rendered = '$authorsStr [$num$locatorDisplay]';
        }
      }
    } else {
      if (bracketed) {
        if (suppressAuthor) {
          rendered = '$yearDisplay$locatorDisplay';
        } else {
          rendered = '$authorsStr, $yearDisplay$locatorDisplay';
        }
      } else {
        rendered = '$authorsStr ($yearDisplay$locatorDisplay)';
      }
    }

    final tooltip = item != null
        ? (isNumeric
              ? '[$num] ${item.title}\n${item.bibliographyAuthorsSummary} (${item.year ?? "n.d."})\nCitekey: @${item.key}'
              : '${item.title}\n${item.authorsSummary} (${item.year ?? "n.d."})\nCitekey: @${item.key}')
        : (isNumeric
              ? '[$num] $authorsStr ($yearDisplay)\nCitekey: @$key'
              : '$authorsStr ($yearDisplay)\nCitekey: @$key');

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

  CitationElementBuilder({required this.helper, required this.isDark});

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final raw = element.textContent;
    final isBracketed = element.attributes['bracketed'] != 'false';
    final effectiveStyle = parentStyle ?? preferredStyle ?? const TextStyle();

    // Handle multiple citations in brackets e.g. [@smith2020; @doe2021]
    final segments = raw.split(';').map((s) => s.trim()).toList();
    final formattedSegments = segments
        .map(
          (s) => helper.formatSegment(segmentText: s, bracketed: isBracketed),
        )
        .toList();

    final linkColor = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
    final isNumeric = helper.controller?.activeCslStyle.isNumeric ?? false;

    final Widget pill;
    if (isBracketed) {
      final combined = isNumeric
          ? formattedSegments.map((s) => s.rendered).join(', ')
          : formattedSegments.map((s) => s.rendered).join('; ');
      final tooltipCombined = formattedSegments
          .map((s) => s.tooltip)
          .join('\n---\n');
      final displayText = isNumeric ? '[$combined]' : '($combined)';

      pill = Tooltip(
        message: tooltipCombined,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: linkColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            displayText,
            style: effectiveStyle.copyWith(
              color: linkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else {
      final seg = formattedSegments.first;
      pill = Tooltip(
        message: seg.tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: linkColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            seg.rendered,
            style: effectiveStyle.copyWith(
              color: linkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: pill,
          ),
        ],
      ),
    );
  }
}

/// Element builder handling code blocks, rendering ```math blocks with Math.tex
class MathCodeBlockBuilder extends MarkdownElementBuilder {
  final Color textColor;
  final String codeFont;
  final double? baseFontSize;

  MathCodeBlockBuilder({
    required this.textColor,
    required this.codeFont,
    this.baseFontSize,
  });

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final language = element.attributes['class'];
    if (language == 'language-math' || language == 'language-latex') {
      final tex = element.textContent.trim();
      final displaySize = baseFontSize != null ? baseFontSize! * 1.15 : 16.0;
      return Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            tex,
            mathStyle: MathStyle.display,
            textStyle: TextStyle(color: textColor, fontSize: displaySize),
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
  static final RegExp _winAbsRegex = RegExp(r'^[a-zA-Z]:[/\\]');
  static final Map<String, Uint8List> _base64Cache = <String, Uint8List>{};
  static const int _maxBase64CacheEntries = 32;

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
    if (rawSrc.contains('%')) {
      try {
        rawSrc = Uri.decodeFull(rawSrc);
      } catch (_) {}
    }

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
          Uint8List? bytes = _base64Cache[base64Data];
          if (bytes == null) {
            bytes = base64Decode(base64Data);
            if (_base64Cache.length >= _maxBase64CacheEntries) {
              _base64Cache.remove(_base64Cache.keys.first);
            }
            _base64Cache[base64Data] = bytes;
          }
          imageWidget = Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => _buildErrorWidget(
              context,
              rawSrc,
              alt,
              'Failed to decode image data',
            ),
          );
        } catch (_) {
          imageWidget = _buildErrorWidget(
            context,
            rawSrc,
            alt,
            'Invalid base64 image data',
          );
        }
      } else {
        imageWidget = _buildErrorWidget(
          context,
          rawSrc,
          alt,
          'Malformed data URI',
        );
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
              color: isDark ? AppTheme.darkSurface : AppTheme.lightSidebar,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.image_outlined, color: mutedColor, size: 24),
          );
        },
        errorBuilder: (ctx, err, stack) => _buildErrorWidget(
          context,
          rawSrc,
          alt,
          'Unable to load network image',
        ),
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
            context,
            rawSrc,
            alt,
            'Unable to decode image file',
          ),
        );
      } else if (rawSrc.startsWith('asset:') || rawSrc.startsWith('assets/')) {
        final assetPath = rawSrc.startsWith('asset:')
            ? rawSrc.substring(6)
            : rawSrc;
        imageWidget = Image.asset(
          assetPath,
          width: width,
          height: height,
          fit: BoxFit.contain,
          errorBuilder: (ctx, err, stack) => _buildErrorWidget(
            context,
            rawSrc,
            alt,
            'Asset not found: $assetPath',
          ),
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
        _winAbsRegex.hasMatch(clean) || clean.startsWith(r'\\');
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
    final cwdCandidate = File(
      p.normalize(p.join(Directory.current.path, clean)),
    );
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
      content = SizedBox(width: width, height: height, child: content);
    }

    final tooltipMsg = title ?? alt ?? p.basename(rawSrc);
    if (tooltipMsg.isNotEmpty) {
      content = Tooltip(message: tooltipMsg, child: content);
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

    final bg = isDark ? AppTheme.darkSurface : AppTheme.lightBg;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

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
// Seamless AST Markdown Body (Pre-Parsed Off-Thread)
// =============================================================================

/// Non-blocking AST Markdown Body that builds Flutter widgets directly from pre-parsed
/// AST nodes computed in the background thread, avoiding line splitting and AST
/// generation on the main UI thread, preserving scroll momentum and interactive responsiveness.
class AstMarkdownBody extends StatefulWidget {
  final List<md.Node>? astNodes;
  final String data;
  final bool selectable;
  final MarkdownStyleSheet? styleSheet;
  final String? imageDirectory;
  final List<md.InlineSyntax> inlineSyntaxes;
  final Widget Function(bool isChecked)? checkboxBuilder;
  final Map<String, MarkdownElementBuilder> builders;
  final bool shrinkWrap;
  final bool fitContent;

  const AstMarkdownBody({
    super.key,
    this.astNodes,
    required this.data,
    this.selectable = false,
    this.styleSheet,
    this.imageDirectory,
    this.inlineSyntaxes = const [],
    this.checkboxBuilder,
    this.builders = const {},
    this.shrinkWrap = true,
    this.fitContent = true,
  });

  @override
  State<AstMarkdownBody> createState() => _AstMarkdownBodyState();
}

class _AstMarkdownBodyState extends State<AstMarkdownBody>
    implements MarkdownBuilderDelegate {
  List<Widget>? _children;
  final List<GestureRecognizer> _recognizers = <GestureRecognizer>[];

  @override
  void didChangeDependencies() {
    _buildNodes();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(AstMarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.astNodes != oldWidget.astNodes ||
        widget.data != oldWidget.data ||
        widget.styleSheet != oldWidget.styleSheet) {
      _buildNodes();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    if (_recognizers.isEmpty) return;
    final local = List<GestureRecognizer>.from(_recognizers);
    _recognizers.clear();
    for (final r in local) {
      r.dispose();
    }
  }

  @override
  GestureRecognizer createLink(String text, String? href, String title) {
    final recognizer = TapGestureRecognizer();
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) {
    code = code.replaceAll(RegExp(r'\n$'), '');
    return TextSpan(style: styleSheet.code, text: code);
  }

  void _buildNodes() {
    final theme = Theme.of(context);
    final fallbackStyleSheet = MarkdownStyleSheet.fromTheme(theme);
    final styleSheet = widget.styleSheet != null
        ? fallbackStyleSheet.merge(widget.styleSheet)
        : fallbackStyleSheet;

    _disposeRecognizers();

    List<md.Node> nodes;
    if (widget.astNodes != null) {
      nodes = widget.astNodes!;
    } else {
      final doc = md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
        inlineSyntaxes: widget.inlineSyntaxes,
        encodeHtml: false,
      );
      final lines = const LineSplitter().convert(widget.data);
      nodes = doc.parseLines(lines);
    }

    final builder = MarkdownBuilder(
      delegate: this,
      selectable: widget.selectable,
      styleSheet: styleSheet,
      imageDirectory: widget.imageDirectory,
      imageBuilder: null,
      checkboxBuilder: widget.checkboxBuilder,
      bulletBuilder: null,
      builders: widget.builders,
      paddingBuilders: const {},
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.baseline,
      fitContent: widget.fitContent,
    );

    _children = builder.build(nodes);
  }

  @override
  Widget build(BuildContext context) {
    if (_children == null || _children!.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_children!.length == 1 && widget.shrinkWrap) {
      return _children!.single;
    }
    return Column(
      mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: widget.fitContent
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.stretch,
      children: _children!,
    );
  }
}

/// Virtualised sliver Markdown renderer that parses/receives top-level AST
/// nodes once and lazily builds, lays out, and paints only blocks visible in
/// the viewport + cacheExtent.
class SliverAstMarkdownList extends StatefulWidget {
  final List<md.Node>? astNodes;
  final String data;
  final bool selectable;
  final MarkdownStyleSheet? styleSheet;
  final String? imageDirectory;
  final List<md.InlineSyntax> inlineSyntaxes;
  final Widget Function(bool isChecked, int checkboxIndex)? checkboxBuilder;
  final Map<String, MarkdownElementBuilder> builders;
  final bool fitContent;

  const SliverAstMarkdownList({
    super.key,
    this.astNodes,
    required this.data,
    this.selectable = false,
    this.styleSheet,
    this.imageDirectory,
    this.inlineSyntaxes = const [],
    this.checkboxBuilder,
    this.builders = const {},
    this.fitContent = true,
  });

  @override
  State<SliverAstMarkdownList> createState() => _SliverAstMarkdownListState();
}

class _SliverAstMarkdownListState extends State<SliverAstMarkdownList>
    implements MarkdownBuilderDelegate {
  List<md.Node> _nodes = const [];
  List<int> _checkboxOffsets = const [];
  final Map<int, Widget> _builtBlocks = {};
  final List<GestureRecognizer> _recognizers = <GestureRecognizer>[];
  MarkdownStyleSheet? _effectiveStyleSheet;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareNodes();
  }

  @override
  void didUpdateWidget(SliverAstMarkdownList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.astNodes != oldWidget.astNodes ||
        widget.data != oldWidget.data ||
        widget.styleSheet != oldWidget.styleSheet ||
        widget.imageDirectory != oldWidget.imageDirectory ||
        widget.builders != oldWidget.builders) {
      _prepareNodes();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _builtBlocks.clear();
    super.dispose();
  }

  void _disposeRecognizers() {
    if (_recognizers.isEmpty) return;
    final local = List<GestureRecognizer>.from(_recognizers);
    _recognizers.clear();
    for (final r in local) {
      r.dispose();
    }
  }

  @override
  GestureRecognizer createLink(String text, String? href, String title) {
    final recognizer = TapGestureRecognizer();
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) {
    code = code.replaceAll(RegExp(r'\n$'), '');
    return TextSpan(style: styleSheet.code, text: code);
  }

  static int _countCheckboxesInNode(md.Node node) {
    if (node is! md.Element) return 0;
    int count = 0;
    if (node.tag == 'input' && node.attributes['type'] == 'checkbox') {
      count = 1;
    }
    final children = node.children;
    if (children != null) {
      for (final child in children) {
        count += _countCheckboxesInNode(child);
      }
    }
    return count;
  }

  void _prepareNodes() {
    final theme = Theme.of(context);
    final fallbackStyleSheet = MarkdownStyleSheet.fromTheme(theme);
    _effectiveStyleSheet = widget.styleSheet != null
        ? fallbackStyleSheet.merge(widget.styleSheet)
        : fallbackStyleSheet;

    _disposeRecognizers();
    _builtBlocks.clear();

    if (widget.astNodes != null) {
      _nodes = widget.astNodes!;
    } else {
      final doc = md.Document(
        extensionSet: md.ExtensionSet.gitHubFlavored,
        inlineSyntaxes: widget.inlineSyntaxes,
        encodeHtml: false,
      );
      final lines = const LineSplitter().convert(widget.data);
      _nodes = doc.parseLines(lines);
    }

    final offsets = List<int>.filled(_nodes.length, 0);
    int running = 0;
    for (int i = 0; i < _nodes.length; i++) {
      offsets[i] = running;
      running += _countCheckboxesInNode(_nodes[i]);
    }
    _checkboxOffsets = offsets;
  }

  Widget _buildBlock(int index) {
    return _builtBlocks.putIfAbsent(index, () {
      int localCheckboxCounter = _checkboxOffsets[index];
      final builder = MarkdownBuilder(
        delegate: this,
        selectable: widget.selectable,
        styleSheet: _effectiveStyleSheet!,
        imageDirectory: widget.imageDirectory,
        imageBuilder: null,
        checkboxBuilder: widget.checkboxBuilder == null
            ? null
            : (bool isChecked) =>
                  widget.checkboxBuilder!(isChecked, localCheckboxCounter++),
        bulletBuilder: null,
        builders: widget.builders,
        paddingBuilders: const {},
        listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.baseline,
        fitContent: widget.fitContent,
      );

      final widgets = builder.build([_nodes[index]]);
      if (widgets.isEmpty) return const SizedBox.shrink();

      final Widget block = widgets.length == 1
          ? widgets.single
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: widget.fitContent
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.stretch,
              children: widgets,
            );

      final spacing = _effectiveStyleSheet!.blockSpacing ?? 8.0;
      if (index < _nodes.length - 1 && spacing > 0) {
        return Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: block,
        );
      }
      return block;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_nodes.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverList.builder(
      itemCount: _nodes.length,
      itemBuilder: (context, index) => _buildBlock(index),
    );
  }
}

// =============================================================================
// Live Markdown Preview Widget
// =============================================================================

/// Live Markdown preview widget using flutter_markdown_plus with customised
/// GitHub-Flavoured styling, immediate KaTeX formula rendering,
/// immediate in-place reference formatting, and auto-generated bibliography.
class MarkdownPreviewView extends StatefulWidget {
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

  @override
  State<MarkdownPreviewView> createState() => _MarkdownPreviewViewState();
}

class _MarkdownPreviewViewState extends State<MarkdownPreviewView> {
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
  static final RegExp _citeKeyExtractRegex = RegExp(r'@([a-zA-Z0-9_\-:#\/]+)');

  static final List<md.InlineSyntax> _inlineSyntaxes = <md.InlineSyntax>[
    DisplayMathSyntax(),
    InlineMathSyntax(),
    BracketedCitationSyntax(),
    InTextCitationSyntax(),
    SuperscriptSyntax(),
    SubscriptSyntax(),
  ];

  String? _memoRawMarkdown;
  int? _memoCitationCount;
  String? _memoCslStyleId;
  String? _memoResult;

  // Cached preview configuration to prevent re-parsing and rebuilding when inputs are unchanged
  String? _cachedBodyMarkdown;
  bool? _cachedBodyIsDark;
  String? _cachedBodySchemeId;
  String? _cachedBodyFont;
  String? _cachedHeaderFont;
  String? _cachedCodeFont;
  String? _cachedImageDir;
  int? _cachedBodyCitationCount;
  String? _cachedBodyCslStyleId;
  MarkdownStyleSheet? _cachedStyleSheet;
  Map<String, MarkdownElementBuilder>? _cachedBuilders;
  Widget Function(bool isChecked, int checkboxIndex)? _cachedCheckboxBuilder;

  @override
  void reassemble() {
    super.reassemble();
    _memoRawMarkdown = null;
    _memoResult = null;
    _cachedStyleSheet = null;
    _cachedBuilders = null;
    _cachedCheckboxBuilder = null;
    _cachedBodyMarkdown = null;
  }

  /// Generate augmented Markdown text with auto-generated references if cited (memoized for performance)
  String _prepareMarkdownWithReferences(CitationHelper helper) {
    if (widget.markdown.trim().isEmpty) return '_Document is empty._';

    // Fast path: if the Markdown code was already preprocessed by the background render thread
    if (widget.controller != null &&
        widget.controller!.previewMarkdown == widget.markdown) {
      if (widget.controller!.numericIndices.isNotEmpty) {
        helper.numericIndices = widget.controller!.numericIndices;
      }
      return widget.markdown;
    }

    final citationCount =
        (helper.controller?.citations.length ?? 0) +
        (helper.controller?.zoteroCitations.length ?? 0);
    final cslStyleId = helper.controller?.activeCslStyle.id ?? 'apa';
    if (_memoRawMarkdown == widget.markdown &&
        _memoCitationCount == citationCount &&
        _memoCslStyleId == cslStyleId &&
        _memoResult != null) {
      return _memoResult!;
    }

    final result = _computeMarkdownWithReferences(helper);
    _memoRawMarkdown = widget.markdown;
    _memoCitationCount = citationCount;
    _memoCslStyleId = cslStyleId;
    _memoResult = result;
    return result;
  }

  String _computeMarkdownWithReferences(CitationHelper helper) {
    // 0. Handle empty task list checkboxes (e.g. "- [ ] " or "- [x] ")
    // In flutter_markdown_plus, an empty task list item causes `_inlines.isEmpty` assertion to fail
    // because <input type="checkbox"> has no children and no text node is generated.
    // Appending a non-breaking space ensures a text child exists, safely clearing inlines.
    var processed = YamlFrontmatterHelper.stripYamlFrontmatter(widget.markdown)
        .replaceAllMapped(_emptyTaskRegex, (m) => '${m[1]} \u00A0');

    // Handle incomplete list markers (e.g. line with only "* " or "*   ")
    // In standard CommonMark, an empty bullet "*   " is parsed as an empty <li></li>,
    // which renders as a bullet with zero-width whitespace, hiding all spaces until text is entered.
    // By escaping the marker on lines with no text and converting spaces to non-breaking spaces,
    // spaces entered after "*" are always visibly rendered in the preview.
    processed = processed.replaceAllMapped(_emptyBulletRegex, (m) {
      final indent = m[1] ?? '';
      final marker = m[2] ?? '*';
      final spaces = m[3] ?? '';
      final visibleSpaces = '\u00A0' * spaces.length;
      return '$indent\\$marker$visibleSpaces';
    });

    // Also preserve multiple spaces after list markers on lines with content (e.g. "*   text")
    // so CommonMark does not collapse consecutive spaces into a single space
    processed = processed.replaceAllMapped(_multiSpaceBulletRegex, (m) {
      final marker = m[1]!;
      final totalMatch = m.group(0)!;
      final spaceCount = totalMatch.length - marker.length;
      final extraSpaces = '\u00A0' * (spaceCount - 1);
      return '$marker $extraSpaces';
    });

    // 1. Convert HTML <img> tags outside fenced code blocks into Markdown image syntax
    // Fast check: skip code-block masking and <img> replacement entirely if no '<img' is present.
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

    // 2. Scan for all cited keys in document
    if (!processed.contains('@')) return processed;

    final matches = _citeRegex.allMatches(processed);
    if (matches.isEmpty) return processed;

    // Do not append references if user already created a References or Bibliography heading
    if (MarkdownRenderService.hasExistingReferencesHeading(processed)) {
      return processed;
    }

    // Collect unique cited keys in order of appearance
    final citedKeysInOrder = <String>[];
    final citedKeysSet = <String>{};
    for (final match in matches) {
      final fullMatch = match.group(0)!;
      // Extract keys from full match
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

    if (citedKeysInOrder.isEmpty) return processed;

    // Build numeric index mapping (order of first appearance)
    final Map<String, int> keyToNumber = {};
    for (int i = 0; i < citedKeysInOrder.length; i++) {
      keyToNumber[citedKeysInOrder[i].toLowerCase()] = i + 1;
    }
    helper.numericIndices = keyToNumber;

    // Build references bibliography
    final buffer = StringBuffer(processed);
    buffer.writeln('\n\n---\n\n### References\n');

    final isNumeric = helper.controller?.activeCslStyle.isNumeric ?? false;

    if (isNumeric) {
      // In numeric mode: order by appearance (index 1, 2, 3...)
      for (int i = 0; i < citedKeysInOrder.length; i++) {
        final key = citedKeysInOrder[i];
        final num = i + 1;
        final item = helper.resolveItem(key);
        if (item != null) {
          buffer.writeln(item.formatBibliographyEntry(numericIndex: num));
        } else {
          // Fallback reference listing
          final seg = helper.formatSegment(
            segmentText: '@$key',
            bracketed: false,
          );
          buffer.writeln('$num. ${seg.rendered}. `@$key`');
        }
      }
    } else {
      // In Author-Year mode: sort alphabetically by first author surname
      final sortedKeys = List<String>.from(citedKeysInOrder);
      sortedKeys.sort((keyA, keyB) {
        final itemA = helper.resolveItem(keyA);
        final itemB = helper.resolveItem(keyB);
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
        final item = helper.resolveItem(key);
        if (item != null) {
          buffer.writeln(item.formatBibliographyEntry());
        } else {
          // Fallback reference listing
          final seg = helper.formatSegment(
            segmentText: '@$key',
            bracketed: false,
          );
          buffer.writeln('- ${seg.rendered}. `@$key`');
        }
      }
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final bodyFont = widget.bodyFont;
    final headerFont = widget.headerFont;
    final codeFont = widget.codeFont;
    final controller = widget.controller;
    final isFullView = widget.isFullView;
    final effectiveImageDirectory = widget.effectiveImageDirectory;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeScheme = AppTheme.activeSchemeForBrightness(isDark);
    final textColor = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final mutedColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final codeBg = isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar;
    final blockquoteBorder = isDark
        ? AppTheme.darkAccent
        : AppTheme.lightAccent;

    final helper = CitationHelper(controller);
    final String effectiveMarkdown;
    if (controller != null && controller.previewMarkdown == widget.markdown) {
      effectiveMarkdown = widget.markdown;
      if (controller.numericIndices.isNotEmpty) {
        helper.numericIndices = controller.numericIndices;
      }
    } else {
      effectiveMarkdown = _prepareMarkdownWithReferences(helper);
    }

    final bool effectiveIsFullView =
        isFullView ?? (controller?.viewMode == EditorViewMode.preview);

    final canvasBg = isDark
        ? AppTheme.darkPreviewCanvas
        : AppTheme.lightPreviewCanvas;
    final pageBg = isDark
        ? AppTheme.darkPreviewPage
        : AppTheme.lightPreviewPage;
    final pageBorder = isDark
        ? AppTheme.darkPreviewBorder
        : AppTheme.lightPreviewBorder;

    final double deskHorizontalPadding = effectiveIsFullView ? 32.0 : 16.0;
    final double deskVerticalPadding = effectiveIsFullView ? 28.0 : 16.0;
    final double innerHorizontalPadding = effectiveIsFullView ? 48.0 : 28.0;
    final double innerVerticalPadding = effectiveIsFullView ? 40.0 : 28.0;
    final double maxPageWidth = effectiveIsFullView ? 850.0 : double.infinity;

    final imgDir = effectiveImageDirectory;
    final citationCount =
        (controller?.citations.length ?? 0) +
        (controller?.zoteroCitations.length ?? 0);

    final MarkdownStyleSheet customStyle;
    final Map<String, MarkdownElementBuilder> builders;
    final Widget Function(bool isChecked, int checkboxIndex) checkboxBuilder;

    if (_cachedStyleSheet != null &&
        _cachedBuilders != null &&
        _cachedCheckboxBuilder != null &&
        _cachedBodyMarkdown == effectiveMarkdown &&
        _cachedBodyIsDark == isDark &&
        _cachedBodySchemeId == activeScheme.id &&
        _cachedBodyFont == bodyFont &&
        _cachedHeaderFont == headerFont &&
        _cachedCodeFont == codeFont &&
        _cachedImageDir == imgDir &&
        _cachedBodyCitationCount == citationCount &&
        _cachedBodyCslStyleId == controller?.activeCslStyle.id) {
      customStyle = _cachedStyleSheet!;
      builders = _cachedBuilders!;
      checkboxBuilder = _cachedCheckboxBuilder!;
    } else {
      customStyle = MarkdownStyleSheet.fromTheme(theme).copyWith(
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
          color: activeScheme.inlineCodeColor,
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
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        checkbox: TextStyle(
          color: isDark ? activeScheme.accent : theme.colorScheme.primary,
          fontSize: 17,
        ),
      );

      final totalCheckboxes = EditorController.findTaskCheckboxes(
        effectiveMarkdown,
      ).length;

      checkboxBuilder = (bool isChecked, int checkboxIndex) {
        final int targetIndex = totalCheckboxes > 0
            ? (checkboxIndex % totalCheckboxes)
            : checkboxIndex;

        final Color iconColor = isChecked
            ? (isDark ? activeScheme.accent : theme.colorScheme.primary)
            : (isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.lightTextSecondary);

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              controller?.toggleCheckbox(targetIndex);
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 6.0, top: 1.0, bottom: 1.0),
              child: Icon(
                isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 17,
                color: iconColor,
              ),
            ),
          ),
        );
      };

      builders = {
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
        'code': MathCodeBlockBuilder(textColor: textColor, codeFont: codeFont),
        'img': MarkdownImageElementBuilder(
          controller: controller,
          imageDirectory: imgDir,
          isDark: isDark,
          codeFont: codeFont,
          textColor: textColor,
          mutedColor: mutedColor,
        ),
        'input': InputElementBuilder(),
        'sup': SuperscriptElementBuilder(),
        'sub': SubscriptElementBuilder(),
      };

      _cachedBodyMarkdown = effectiveMarkdown;
      _cachedBodyIsDark = isDark;
      _cachedBodySchemeId = activeScheme.id;
      _cachedBodyFont = bodyFont;
      _cachedHeaderFont = headerFont;
      _cachedCodeFont = codeFont;
      _cachedImageDir = imgDir;
      _cachedBodyCitationCount = citationCount;
      _cachedBodyCslStyleId = controller?.activeCslStyle.id;
      _cachedStyleSheet = customStyle;
      _cachedBuilders = builders;
      _cachedCheckboxBuilder = checkboxBuilder;
    }

    final astNodes = (controller?.previewMarkdown == effectiveMarkdown)
        ? controller?.astNodes
        : null;

    return Container(
      color: canvasBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double availableWidth =
              (constraints.maxWidth - (deskHorizontalPadding * 2)).clamp(
                0.0,
                double.infinity,
              );
          final double pageWidth = maxPageWidth.isFinite
              ? availableWidth.clamp(0.0, maxPageWidth)
              : availableWidth;
          final double sideMargin = ((constraints.maxWidth - pageWidth) / 2)
              .clamp(deskHorizontalPadding, double.infinity);

          return SelectionArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sideMargin,
                    vertical: deskVerticalPadding,
                  ),
                  sliver: DecoratedSliver(
                    decoration: BoxDecoration(
                      color: pageBg,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: pageBorder, width: 1.0),
                    ),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: innerHorizontalPadding,
                            vertical: innerVerticalPadding,
                          ),
                          sliver: SliverAstMarkdownList(
                            key: ValueKey(
                              'preview_body_${isDark}_${activeScheme.id}',
                            ),
                            astNodes: astNodes,
                            data: effectiveMarkdown,
                            selectable: false,
                            imageDirectory: imgDir,
                            styleSheet: customStyle,
                            inlineSyntaxes: _inlineSyntaxes,
                            checkboxBuilder: checkboxBuilder,
                            builders: builders,
                            fitContent: true,
                          ),
                        ),
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
