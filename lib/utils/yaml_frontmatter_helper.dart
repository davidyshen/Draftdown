/// Utilities for reading, updating, and stripping YAML frontmatter (`--- ... ---`)
/// at the top of Markdown documents.
class YamlFrontmatterHelper {
  static final RegExp _frontmatterRegex = RegExp(
    r'^(?:\uFEFF)?---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)',
  );

  static final RegExp _cslLineRegex = RegExp(
    r'^[ \t]*csl[ \t]*:[ \t]*(.+?)[ \t]*$',
    multiLine: true,
  );

  /// Split a full Markdown file into its leading YAML frontmatter block
  /// (including `---` delimiters and trailing newline) and the Markdown body.
  static ({String frontmatter, String body}) splitFrontmatter(String markdown) {
    final match = _frontmatterRegex.firstMatch(markdown);
    if (match == null) {
      return (frontmatter: '', body: markdown);
    }
    return (
      frontmatter: markdown.substring(0, match.end),
      body: markdown.substring(match.end),
    );
  }

  /// Extract the inner YAML content (without the `---` delimiter lines)
  /// from a frontmatter block for editing in the Frontmatter dialog.
  static String extractInnerYaml(String frontmatter) {
    final match = _frontmatterRegex.firstMatch(frontmatter);
    if (match != null) {
      return (match.group(1) ?? '').trim();
    }
    return frontmatter.trim();
  }

  /// Wrap inner YAML lines in `---\n...\n---\n`, stripping any stray `---`
  /// delimiter lines so all content stays strictly inside the YAML block.
  static String wrapInnerYaml(String innerYaml) {
    final lines = innerYaml.replaceAll('\r\n', '\n').split('\n');
    // Strip leading/trailing `---` lines if pasted
    while (lines.isNotEmpty && lines.first.trim() == '---') {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && lines.last.trim() == '---') {
      lines.removeLast();
    }
    final cleaned = lines.join('\n').trim();
    if (cleaned.isEmpty) return '';
    return '---\n$cleaned\n---\n';
  }

  /// Recombine a stored YAML frontmatter block and Markdown body for saving/exporting.
  static String joinFrontmatter(String frontmatter, String body) {
    if (frontmatter.trim().isEmpty) return body;
    final newline = frontmatter.contains('\r\n') || body.contains('\r\n')
        ? '\r\n'
        : '\n';
    final fm = frontmatter.endsWith('\n')
        ? frontmatter
        : '$frontmatter$newline';
    return '$fm$body';
  }

  /// Extract the `csl:` value from leading YAML frontmatter, or `null` if absent.
  static String? readCslFromFrontmatter(String markdown) {
    final match = _frontmatterRegex.firstMatch(markdown);
    if (match == null) return null;
    final body = match.group(1) ?? '';
    final cslMatch = _cslLineRegex.firstMatch(body);
    if (cslMatch == null) return null;

    var value = (cslMatch.group(1) ?? '').trim();
    // Strip optional matching quotes
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      if (value.length >= 2) {
        value = value.substring(1, value.length - 1).trim();
      }
    }
    if (value.isEmpty) return null;
    // Normalise if a path/filename with .csl extension was given
    if (value.toLowerCase().endsWith('.csl')) {
      final base = value.split(RegExp(r'[/\\]')).last;
      return base.substring(0, base.length - 4);
    }
    return value;
  }

  /// Extract `draftdown.media` from leading YAML frontmatter, or `null` if absent.
  static String? readMediaPathFromFrontmatter(String markdown) {
    final match = _frontmatterRegex.firstMatch(markdown);
    if (match == null) return null;
    final body = match.group(1) ?? '';
    final lines = body.replaceAll('\r\n', '\n').split('\n');

    final draftdownKeyRegex = RegExp(r'^([ \t]*)draftdown[ \t]*:[ \t]*(?:#.*)?$');
    final mediaKeyRegex = RegExp(r'^([ \t]*)media[ \t]*:[ \t]*(.*?)[ \t]*$');

    int? blockIndent;
    for (final line in lines) {
      if (blockIndent == null) {
        final ddMatch = draftdownKeyRegex.firstMatch(line);
        if (ddMatch != null) {
          blockIndent = ddMatch.group(1)!.length;
        }
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      final indent = line.length - line.trimLeft().length;
      if (indent <= blockIndent) {
        // Left the `draftdown:` block.
        break;
      }

      final mediaMatch = mediaKeyRegex.firstMatch(line);
      if (mediaMatch != null) {
        var value = (mediaMatch.group(2) ?? '').trim();
        if (value.isEmpty) return null;

        final doubleQuoted = RegExp(r'^"([^"]*)"[ \t]*(?:#.*)?$').firstMatch(value);
        final singleQuoted = RegExp(r"^'([^']*)'[ \t]*(?:#.*)?$").firstMatch(value);
        if (doubleQuoted != null) {
          value = doubleQuoted.group(1)!.trim();
        } else if (singleQuoted != null) {
          value = singleQuoted.group(1)!.trim();
        } else {
          // Strip unquoted inline YAML comment.
          final commentIdx = value.indexOf(' #');
          if (commentIdx != -1) {
            value = value.substring(0, commentIdx).trim();
          } else if (value.startsWith('#')) {
            return null;
          }
        }

        return value.isEmpty ? null : value;
      }
    }

    return null;
  }

  /// Update or insert `csl: <styleId>` in the document's leading YAML frontmatter.
  /// Preserves existing frontmatter keys and line-ending style.
  static String upsertCslInFrontmatter(String markdown, String styleId) {
    final newline = markdown.contains('\r\n') ? '\r\n' : '\n';
    final match = _frontmatterRegex.firstMatch(markdown);

    if (match == null) {
      final hasBom = markdown.startsWith('\uFEFF');
      final content = hasBom ? markdown.substring(1) : markdown;
      final prefix = hasBom ? '\uFEFF' : '';
      final sep = content.isEmpty ? '' : newline;
      return '$prefix---${newline}csl: $styleId$newline---$newline$sep$content';
    }

    final body = match.group(1) ?? '';
    final updatedBody = _cslLineRegex.hasMatch(body)
        ? body.replaceFirst(_cslLineRegex, 'csl: $styleId')
        : (body.trim().isEmpty
              ? 'csl: $styleId'
              : '$body${newline}csl: $styleId');

    final rest = markdown.substring(match.end);
    final hasBom = markdown.startsWith('\uFEFF');
    final prefix = hasBom ? '\uFEFF' : '';
    return '$prefix---$newline$updatedBody$newline---$newline$rest';
  }

  /// Remove leading YAML frontmatter so it is not rendered as body text in preview
  /// or direct plain-text/HTML/RTF exports.
  static String stripYamlFrontmatter(String markdown) {
    final match = _frontmatterRegex.firstMatch(markdown);
    if (match == null) return markdown;
    var rest = markdown.substring(match.end);
    if (rest.startsWith('\r\n')) {
      rest = rest.substring(2);
    } else if (rest.startsWith('\n')) {
      rest = rest.substring(1);
    }
    return rest;
  }
}
