import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/csl_style.dart';

/// Exception thrown when a CSL style operation cannot be completed
/// (e.g. attempting to remove a built-in style or a parent still in use).
class CslStyleException implements Exception {
  final String message;
  const CslStyleException(this.message);

  @override
  String toString() => message;
}

/// Manages bundled and user-installed CSL (`.csl`) citation styles,
/// dependent-parent resolution, and the online Zotero Styles Library.
class CslStyleService {
  static const String defaultStyleId = 'apa';

  static const List<String> bundledStyleIds = [
    'apa',
    'ieee',
    'nature',
    'vancouver',
    'chicago-author-date',
    'modern-language-association',
  ];

  static const String zoteroStylesIndexUrl =
      'https://www.zotero.org/styles-files/styles.json';
  static const String zoteroStyleBaseUrl = 'https://www.zotero.org/styles/';
  static const Duration _indexCacheTtl = Duration(days: 7);

  static final RegExp _titleRegex = RegExp(
    r'<title>([\s\S]*?)</title>',
    caseSensitive: false,
  );
  static final RegExp _citationFormatRegex = RegExp(
    r'<category\b[^>]*\bcitation-format\s*=\s*["\x27]([^"\x27]+)["\x27]',
    caseSensitive: false,
  );
  static final RegExp _linkTagRegex = RegExp(
    r'<link\b([^>]*)/?>',
    caseSensitive: false,
  );
  static final RegExp _relIndependentParentRegex = RegExp(
    r'\brel\s*=\s*["\x27]independent-parent["\x27]',
    caseSensitive: false,
  );
  static final RegExp _hrefAttrRegex = RegExp(
    r'\bhref\s*=\s*["\x27]([^"\x27]+)["\x27]',
    caseSensitive: false,
  );

  final http.Client _httpClient;
  final Map<String, CslStyle> _stylesById = {};
  List<CslStyle>? _sortedCache;
  List<ZoteroStyleEntry>? _zoteroIndexCache;
  Directory? _cslRootDir;
  bool _initialized = false;

  CslStyleService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  bool get isInitialized => _initialized;

  /// All available styles (bundled first, then user-installed), sorted by title.
  List<CslStyle> get installedStyles {
    if (_sortedCache != null) return _sortedCache!;
    final list = _stylesById.values.toList();
    list.sort((a, b) {
      if (a.isBuiltIn != b.isBuiltIn) {
        return a.isBuiltIn ? -1 : 1;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return _sortedCache = List.unmodifiable(list);
  }

  /// Find an installed or bundled style by ID (case-insensitive).
  CslStyle? findById(String id) {
    final clean = id.trim().toLowerCase();
    return _stylesById[clean];
  }

  /// Return the active style for [id], falling back to `apa` if not installed.
  CslStyle resolveOrDefault(String id) {
    final clean = id.trim().toLowerCase();
    final found = findById(clean);
    if (found != null) return found;
    if (!_initialized &&
        (clean == 'ieee' || clean == 'nature' || clean == 'vancouver')) {
      return CslStyle(
        id: clean,
        title: clean.toUpperCase(),
        citationFormat: 'numeric',
        isBuiltIn: true,
      );
    }
    return findById(defaultStyleId) ??
        const CslStyle(
          id: defaultStyleId,
          title: 'American Psychological Association 7th edition',
          citationFormat: 'author-date',
          isBuiltIn: true,
        );
  }

  /// Return all installed styles that declare [parentId] as their `independent-parent`.
  List<CslStyle> dependentsOf(String parentId) {
    final cleanParent = parentId.trim().toLowerCase();
    return _stylesById.values
        .where(
          (s) =>
              s.independentParentId != null &&
              s.independentParentId!.toLowerCase() == cleanParent,
        )
        .toList(growable: false);
  }

  /// Resolve the on-disk `.csl` file path to pass to Pandoc `--csl=...`.
  /// For dependent styles, resolves to the independent parent's `.csl` path.
  String? resolveEffectiveCslPath(String styleId) {
    final visited = <String>{};
    var current = findById(styleId);
    while (current != null &&
        current.isDependent &&
        !visited.contains(current.id)) {
      visited.add(current.id);
      final parent = findById(current.independentParentId!);
      if (parent == null) break;
      current = parent;
    }
    if (current?.filePath != null && File(current!.filePath!).existsSync()) {
      return current.filePath;
    }
    final fallback = findById(defaultStyleId);
    if (fallback?.filePath != null && File(fallback!.filePath!).existsSync()) {
      return fallback.filePath;
    }
    return null;
  }

  /// Initialise bundled and user-installed CSL styles.
  /// [customStorageDir] and [skipAssetExtraction] are intended for unit tests.
  Future<void> initialize({
    Directory? customStorageDir,
    bool skipAssetExtraction = false,
  }) async {
    if (_initialized && customStorageDir == null) return;

    if (customStorageDir != null) {
      _cslRootDir = customStorageDir;
    } else {
      final appSupport = await getApplicationSupportDirectory();
      _cslRootDir = Directory(p.join(appSupport.path, 'csl'));
    }

    if (!await _cslRootDir!.exists()) {
      await _cslRootDir!.create(recursive: true);
    }

    _stylesById.clear();
    _sortedCache = null;

    final builtinDir = Directory(p.join(_cslRootDir!.path, '_builtin'));
    if (!skipAssetExtraction) {
      if (!await builtinDir.exists()) {
        await builtinDir.create(recursive: true);
      }
      for (final id in bundledStyleIds) {
        try {
          final xml = await rootBundle.loadString('assets/csl/$id.csl');
          final target = File(p.join(builtinDir.path, '$id.csl'));
          await target.writeAsString(xml, flush: true);
          _stylesById[id] = parseCslMetadata(
            xml,
            id: id,
            isBuiltIn: true,
            filePath: target.path,
          );
        } catch (e) {
          debugPrint('[CslStyleService] Failed to extract bundled $id.csl: $e');
        }
      }
    } else if (await builtinDir.exists()) {
      await _scanDirectory(builtinDir, isBuiltIn: true);
    }

    // Scan user-installed styles in the root csl directory
    await _scanDirectory(_cslRootDir!, isBuiltIn: false);
    _initialized = true;
  }

  Future<void> _scanDirectory(Directory dir, {required bool isBuiltIn}) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.csl')) continue;
      try {
        final id = p.basenameWithoutExtension(entity.path).toLowerCase();
        // Do not let user files overwrite built-in IDs in the lookup map
        if (!isBuiltIn &&
            _stylesById.containsKey(id) &&
            _stylesById[id]!.isBuiltIn) {
          continue;
        }
        final xml = await entity.readAsString();
        _stylesById[id] = parseCslMetadata(
          xml,
          id: id,
          isBuiltIn: isBuiltIn,
          filePath: entity.path,
        );
      } catch (e) {
        debugPrint('[CslStyleService] Failed to parse ${entity.path}: $e');
      }
    }
    _sortedCache = null;
  }

  /// Parse `<info>` metadata from a `.csl` XML string.
  static CslStyle parseCslMetadata(
    String xmlContent, {
    required String id,
    bool isBuiltIn = false,
    String? filePath,
  }) {
    final titleMatch = _titleRegex.firstMatch(xmlContent);
    final rawTitle = titleMatch?.group(1)?.trim();
    final title = (rawTitle != null && rawTitle.isNotEmpty)
        ? _unescapeXml(rawTitle)
        : id;

    final formatMatch = _citationFormatRegex.firstMatch(xmlContent);
    final citationFormat =
        formatMatch?.group(1)?.trim().toLowerCase() ?? 'author-date';

    String? independentParentId;
    for (final linkMatch in _linkTagRegex.allMatches(xmlContent)) {
      final attrs = linkMatch.group(1) ?? '';
      if (_relIndependentParentRegex.hasMatch(attrs)) {
        final hrefMatch = _hrefAttrRegex.firstMatch(attrs);
        final href = hrefMatch?.group(1)?.trim();
        if (href != null && href.isNotEmpty) {
          independentParentId = _extractSlugFromUrl(href);
          break;
        }
      }
    }

    return CslStyle(
      id: id.toLowerCase(),
      title: title,
      citationFormat: citationFormat,
      isBuiltIn: isBuiltIn,
      independentParentId: independentParentId,
      filePath: filePath,
    );
  }

  static String _extractSlugFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final segments = (uri?.pathSegments ?? url.split('/'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (segments.isEmpty) return url.toLowerCase();
    var slug = segments.last.trim().toLowerCase();
    if (slug.endsWith('.csl')) {
      slug = slug.substring(0, slug.length - 4);
    }
    return slug;
  }

  static String _unescapeXml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  /// Fetch the Zotero Style Repository index (`styles.json`), using a 7-day local cache.
  Future<List<ZoteroStyleEntry>> fetchZoteroStylesIndex({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _zoteroIndexCache != null) {
      return _zoteroIndexCache!;
    }

    final cacheFile = _cslRootDir != null
        ? File(p.join(_cslRootDir!.path, 'zotero_styles_cache.json'))
        : null;

    if (!forceRefresh && cacheFile != null && await cacheFile.exists()) {
      try {
        final stat = await cacheFile.stat();
        if (DateTime.now().difference(stat.modified) < _indexCacheTtl) {
          final cachedRaw = await cacheFile.readAsString();
          final parsed = _parseZoteroIndexJson(cachedRaw);
          if (parsed.isNotEmpty) {
            _zoteroIndexCache = parsed;
            return parsed;
          }
        }
      } catch (_) {
        // Fall through to network fetch
      }
    }

    final response = await _httpClient
        .get(Uri.parse(zoteroStylesIndexUrl))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw CslStyleException(
        'Failed to load Zotero styles library (HTTP ${response.statusCode}).',
      );
    }

    final parsed = _parseZoteroIndexJson(response.body);
    if (cacheFile != null) {
      try {
        await cacheFile.writeAsString(response.body, flush: true);
      } catch (_) {}
    }
    _zoteroIndexCache = parsed;
    return parsed;
  }

  static List<ZoteroStyleEntry> _parseZoteroIndexJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) return const [];
    final entries = <ZoteroStyleEntry>[];
    for (final item in decoded) {
      if (item is Map<String, dynamic>) {
        final entry = ZoteroStyleEntry.fromJson(item);
        if (entry.name.isNotEmpty) {
          entries.add(entry);
        }
      } else if (item is Map) {
        final entry = ZoteroStyleEntry.fromJson(
          item.map((k, v) => MapEntry(k.toString(), v)),
        );
        if (entry.name.isNotEmpty) {
          entries.add(entry);
        }
      }
    }
    return entries;
  }

  /// Download and install a style from the Zotero Style Repository by its [slug].
  /// Automatically installs any missing `independent-parent` style.
  Future<CslStyle> installFromZotero(
    String slug, {
    Set<String>? visited,
  }) async {
    if (_cslRootDir == null) {
      await initialize();
    }
    final cleanSlug = slug.trim().toLowerCase();
    final visitedSet = visited ?? <String>{};
    if (!visitedSet.add(cleanSlug)) {
      throw const CslStyleException(
        'Circular independent-parent reference detected in CSL style.',
      );
    }

    // If it is already built-in, just return it
    final existing = findById(cleanSlug);
    if (existing != null && existing.isBuiltIn) {
      return existing;
    }

    final url = Uri.parse('$zoteroStyleBaseUrl$cleanSlug');
    final response = await _httpClient
        .get(url)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw CslStyleException(
        'Could not download "$cleanSlug" from Zotero Styles (HTTP ${response.statusCode}).',
      );
    }

    final xml = response.body;
    if (!xml.contains('<style') || !xml.contains('purl.org/net/xbiblio/csl')) {
      throw CslStyleException(
        'Downloaded file for "$cleanSlug" is not a valid CSL stylesheet.',
      );
    }

    final targetFile = File(p.join(_cslRootDir!.path, '$cleanSlug.csl'));
    await targetFile.writeAsString(xml, flush: true);

    final style = parseCslMetadata(
      xml,
      id: cleanSlug,
      isBuiltIn: false,
      filePath: targetFile.path,
    );
    _stylesById[cleanSlug] = style;
    _sortedCache = null;

    // Auto-resolve independent parent if missing
    if (style.isDependent &&
        findById(style.independentParentId!) == null &&
        !visitedSet.contains(style.independentParentId!)) {
      await installFromZotero(style.independentParentId!, visited: visitedSet);
    }

    return style;
  }

  /// Import a local `.csl` file into the user styles directory.
  /// If it is a dependent style whose parent is not yet installed, attempts
  /// to download the parent from Zotero Styles.
  Future<CslStyle> importLocalCslFile(String sourcePath) async {
    if (_cslRootDir == null) {
      await initialize();
    }
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw CslStyleException('File not found: $sourcePath');
    }

    final xml = await sourceFile.readAsString();
    if (!xml.contains('<style')) {
      throw const CslStyleException(
        'The selected file does not appear to be a valid CSL (.csl) file.',
      );
    }

    final slug = p.basenameWithoutExtension(sourcePath).toLowerCase();
    final existing = findById(slug);
    if (existing != null && existing.isBuiltIn) {
      throw CslStyleException(
        '"${existing.title}" is already a built-in style.',
      );
    }

    final targetFile = File(p.join(_cslRootDir!.path, '$slug.csl'));
    await targetFile.writeAsString(xml, flush: true);

    final style = parseCslMetadata(
      xml,
      id: slug,
      isBuiltIn: false,
      filePath: targetFile.path,
    );
    _stylesById[slug] = style;
    _sortedCache = null;

    if (style.isDependent && findById(style.independentParentId!) == null) {
      try {
        await installFromZotero(style.independentParentId!);
      } catch (e) {
        debugPrint(
          '[CslStyleService] Could not auto-download parent "${style.independentParentId}": $e',
        );
      }
    }

    return style;
  }

  /// Remove a user-installed `.csl` style.
  /// Throws [CslStyleException] if the style is built-in or if another
  /// installed dependent style still relies on it.
  Future<void> removeStyle(String styleId) async {
    final cleanId = styleId.trim().toLowerCase();
    final style = _stylesById[cleanId];
    if (style == null) return;

    if (style.isBuiltIn) {
      throw CslStyleException(
        '"${style.title}" is a built-in style and cannot be removed.',
      );
    }

    final dependents = dependentsOf(cleanId);
    if (dependents.isNotEmpty) {
      final depNames = dependents.map((d) => d.title).join(', ');
      throw CslStyleException(
        'Cannot remove "${style.title}" because the following installed style(s) depend on it: $depNames.',
      );
    }

    if (style.filePath != null) {
      final file = File(style.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _stylesById.remove(cleanId);
    _sortedCache = null;
  }
}
