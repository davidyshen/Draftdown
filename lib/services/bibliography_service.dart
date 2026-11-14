import 'dart:convert';
import 'dart:io';

import '../models/citation_item.dart';

/// Service responsible for loading, parsing, and caching bibliography databases
/// (BibTeX, BibLaTeX, and CSL JSON formats).
class BibliographyService {
  static final RegExp _entryRegex = RegExp(
    r'@([a-zA-Z]+)\s*\{\s*([a-zA-Z0-9_:.+-]+)\s*,\s*([\s\S]*?)(?=(?:\n\s*@|$))',
  );
  static final RegExp _andSplitRegex = RegExp(
    r'\s+and\s+',
    caseSensitive: false,
  );
  static final RegExp _bracesRegex = RegExp(r'[{}]');
  static final RegExp _latexCmdRegex = RegExp(r'\\[a-zA-Z]+');
  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  /// In-memory cache of currently parsed citation items
  List<CitationItem> _items = [];
  List<CitationItem>? _unmodifiableItems;
  final Map<String, CitationItem> _itemsByKey = {};

  List<CitationItem> get items =>
      _unmodifiableItems ??= List.unmodifiable(_items);

  /// Initialise the service with default sample references so the user can
  /// experiment with citations immediately out of the box.
  BibliographyService() {
    _rebuildIndex(defaultSampleCitations);
  }

  void _rebuildIndex(List<CitationItem> source) {
    _items = List<CitationItem>.from(source, growable: false);
    _unmodifiableItems = null;
    _itemsByKey.clear();
    for (final item in _items) {
      _itemsByKey[item.normalizedKey] = item;
    }
  }

  /// Manually replace or initialise items in active bibliography
  void setItems(List<CitationItem> items) {
    _rebuildIndex(items);
  }

  /// Find a citation item by its citekey in O(1) time (case-insensitive, ignoring leading `@`)
  CitationItem? findByKey(String rawKey) {
    final clean = rawKey.trim().replaceAll('@', '').toLowerCase();
    return _itemsByKey[clean];
  }

  /// Load a bibliography from a file path (.bib, .bibtex, .json)
  Future<List<CitationItem>> loadFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Bibliography file does not exist', filePath);
    }

    final content = await file.readAsString();
    final lower = filePath.toLowerCase();

    List<CitationItem> parsedItems = [];
    if (lower.endsWith('.json')) {
      parsedItems = parseCslJson(content);
    } else {
      // Default to BibTeX/BibLaTeX parser
      parsedItems = parseBibTeX(content);
    }

    if (parsedItems.isNotEmpty) {
      _rebuildIndex(parsedItems);
    }
    return items;
  }

  /// Parse BibTeX / BibLaTeX formatted string
  List<CitationItem> parseBibTeX(String bibtexContent) {
    final List<CitationItem> results = [];
    final normalized = bibtexContent.contains('\r\n')
        ? bibtexContent.replaceAll('\r\n', '\n')
        : bibtexContent;

    final matches = _entryRegex.allMatches(normalized);

    for (final match in matches) {
      final type = match.group(1)?.toLowerCase().trim();
      final key = match.group(2)?.trim();
      var body = match.group(3) ?? '';
      body = body.trim();
      if (body.endsWith('}')) {
        body = body.substring(0, body.length - 1).trim();
      }

      if (key == null || key.isEmpty) continue;
      // Skip comments or preambles
      if (type == 'comment' || type == 'preamble' || type == 'string') continue;

      final fields = _parseBibFields(body);

      final title = _cleanLatex(fields['title'] ?? 'Untitled');
      final year = fields['year'] ?? fields['date']?.split('-').firstOrNull;
      final authorsRaw = fields['author'] ?? fields['editor'] ?? '';
      final authors = _parseAuthors(authorsRaw);
      final venue = _cleanLatex(
        fields['journal'] ??
            fields['journaltitle'] ??
            fields['booktitle'] ??
            fields['publisher'] ??
            fields['institution'] ??
            '',
      );
      final doi = fields['doi'];
      final url = fields['url'];
      final abstractText = _cleanLatex(fields['abstract'] ?? '');

      results.add(
        CitationItem(
          key: key,
          title: title.isNotEmpty ? title : key,
          authors: authors,
          year: year,
          venue: venue.isNotEmpty ? venue : null,
          itemType: type,
          doi: doi,
          url: url,
          abstractText: abstractText.isNotEmpty ? abstractText : null,
          rawBibtex: match.group(0),
        ),
      );
    }

    return results;
  }

  /// Parse key-value fields inside a BibTeX entry with support for nested braces and macros
  Map<String, String> _parseBibFields(String body) {
    final Map<String, String> fields = {};
    int i = 0;
    final len = body.length;

    while (i < len) {
      // Skip whitespace, commas, and newlines
      while (i < len &&
          (body[i] == ' ' ||
              body[i] == '\t' ||
              body[i] == '\n' ||
              body[i] == '\r' ||
              body[i] == ',')) {
        i++;
      }
      if (i >= len) break;

      final nameStart = i;
      while (i < len &&
          body[i] != '=' &&
          body[i] != ' ' &&
          body[i] != '\t' &&
          body[i] != '\n' &&
          body[i] != '\r') {
        i++;
      }
      final fieldName = body.substring(nameStart, i).toLowerCase().trim();

      // Skip whitespace to '='
      while (i < len && body[i] != '=') {
        i++;
      }
      if (i >= len) break;
      i++; // skip '='

      // Skip whitespace to value
      while (i < len &&
          (body[i] == ' ' ||
              body[i] == '\t' ||
              body[i] == '\n' ||
              body[i] == '\r')) {
        i++;
      }
      if (i >= len) break;

      String val = '';
      if (body[i] == '{') {
        int depth = 1;
        i++;
        final valStart = i;
        while (i < len && depth > 0) {
          if (body[i] == '{') {
            depth++;
          } else if (body[i] == '}') {
            depth--;
          }
          if (depth > 0) i++;
        }
        val = body.substring(valStart, i);
        if (i < len && body[i] == '}') i++;
      } else if (body[i] == '"') {
        i++;
        final valStart = i;
        while (i < len && body[i] != '"') {
          if (body[i] == '\\' && i + 1 < len) {
            i += 2;
          } else {
            i++;
          }
        }
        val = body.substring(valStart, i);
        if (i < len && body[i] == '"') i++;
      } else {
        final valStart = i;
        while (i < len &&
            body[i] != ',' &&
            body[i] != '\n' &&
            body[i] != '\r' &&
            body[i] != '}') {
          i++;
        }
        val = body.substring(valStart, i).trim();
      }

      if (fieldName.isNotEmpty) {
        fields[fieldName] = val.trim();
      }

      while (i < len && body[i] != ',') {
        if (body[i] == '\n') break;
        i++;
      }
      if (i < len && body[i] == ',') i++;
    }

    return fields;
  }

  /// Parse author string like "Alan M. Turing and Alonzo Church" or "Turing, Alan and Church, Alonzo"
  List<String> _parseAuthors(String raw) {
    if (raw.trim().isEmpty) return const [];

    final parts = raw.split(_andSplitRegex);
    final List<String> authors = [];

    for (final part in parts) {
      final cleaned = _cleanLatex(part).trim();
      if (cleaned.isEmpty) continue;

      if (cleaned.contains(',')) {
        // "Turing, Alan" -> "Alan Turing" or maintain surname
        final sub = cleaned.split(',');
        final surname = sub[0].trim();
        final forename = sub.length > 1 ? sub[1].trim() : '';
        authors.add(forename.isNotEmpty ? '$forename $surname' : surname);
      } else {
        authors.add(cleaned);
      }
    }

    return authors;
  }

  /// Clean LaTeX formatting artifacts from text
  String _cleanLatex(String text) {
    if (text.isEmpty) return '';
    var out = text;
    if (out.contains('{') || out.contains('}')) {
      out = out.replaceAll(_bracesRegex, '');
    }
    if (out.contains(r'\')) {
      out = out.replaceAll(_latexCmdRegex, '');
    }
    out = out.replaceAll(_whitespaceRegex, ' ').trim();
    return out;
  }

  /// Parse CSL JSON bibliography format (produced natively by Zotero and Better BibTeX)
  List<CitationItem> parseCslJson(String jsonString) {
    final List<CitationItem> items = [];
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! List) return items;

      for (final dynamic raw in decoded) {
        if (raw is! Map<String, dynamic>) continue;

        final key = raw['id']?.toString() ?? 'unknown';
        final title = raw['title']?.toString() ?? 'Untitled';
        final type = raw['type']?.toString();
        final venue =
            raw['container-title']?.toString() ?? raw['publisher']?.toString();
        final doi = raw['DOI']?.toString();
        final url = raw['URL']?.toString();
        final abstractText = raw['abstract']?.toString();

        // Extract year from issued date-parts [[2023, 5, 12]]
        String? year;
        final issued = raw['issued'];
        if (issued is Map<String, dynamic>) {
          final dateParts = issued['date-parts'];
          if (dateParts is List && dateParts.isNotEmpty) {
            final firstDate = dateParts.first;
            if (firstDate is List && firstDate.isNotEmpty) {
              year = firstDate.first.toString();
            }
          }
        }

        // Extract authors
        final List<String> authors = [];
        final authorList = raw['author'] ?? raw['authors'] ?? raw['creators'];
        if (authorList is List) {
          for (final a in authorList) {
            if (a is Map) {
              final family =
                  a['family']?.toString() ?? a['lastName']?.toString() ?? '';
              final given =
                  a['given']?.toString() ?? a['firstName']?.toString() ?? '';
              if (given.isNotEmpty && family.isNotEmpty) {
                authors.add('$given $family');
              } else if (family.isNotEmpty) {
                authors.add(family);
              } else if (a['literal'] != null) {
                authors.add(a['literal'].toString());
              } else if (a['name'] != null) {
                authors.add(a['name'].toString());
              }
            } else if (a is String && a.trim().isNotEmpty) {
              authors.add(a.trim());
            }
          }
        } else if (authorList is String && authorList.trim().isNotEmpty) {
          final parts = authorList.split(_andSplitRegex);
          for (final p in parts) {
            final t = p.trim();
            if (t.isNotEmpty) authors.add(t);
          }
        }

        items.add(
          CitationItem(
            key: key,
            title: title,
            authors: authors,
            year: year,
            venue: venue,
            itemType: type,
            doi: doi,
            url: url,
            abstractText: abstractText,
          ),
        );
      }
    } catch (_) {
      // Return whatever could be parsed
    }
    return items;
  }

  /// Search literature in active bibliography with diacritic-insensitive matching
  List<CitationItem> search(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return items;
    final normalized = CitationItem.normalizeForSearch(trimmed);
    final tokens = normalized
        .split(_whitespaceRegex)
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return items;

    return _items
        .where((item) {
          final text = item.searchableText;
          for (int i = 0; i < tokens.length; i++) {
            if (!text.contains(tokens[i])) return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Preloaded foundational sample citations
  static const List<CitationItem> defaultSampleCitations = [
    CitationItem(
      key: 'hutchinson1957concluding',
      title: 'Concluding Remarks',
      authors: ['G. Evelyn Hutchinson'],
      year: '1957',
      venue: 'Cold Spring Harbor Symposia on Quantitative Biology, 22, 415-427',
      itemType: 'article',
      doi: '10.1101/SQB.1957.022.01.039',
      abstractText: 'Formalises the ecological niche as an n-dimensional hypervolume of environmental conditions and resources required for species persistence.',
    ),
    CitationItem(
      key: 'paine1966food',
      title: 'Food Web Complexity and Species Diversity',
      authors: ['Robert T. Paine'],
      year: '1966',
      venue: 'The American Naturalist, 100(910), 65-75',
      itemType: 'article',
      doi: '10.1086/282400',
      abstractText: 'Demonstrates how top predators regulate community diversity through trophic cascades and introduces the concept of keystone species.',
    ),
    CitationItem(
      key: 'macarthur1967theory',
      title: 'The Theory of Island Biogeography',
      authors: ['Robert H. MacArthur', 'Edward O. Wilson'],
      year: '1967',
      venue: 'Princeton University Press',
      itemType: 'book',
      abstractText: 'Establishes equilibrium models of species richness on islands and fragmented habitats based on immigration and extinction rates.',
    ),
    CitationItem(
      key: 'holling1973resilience',
      title: 'Resilience and Stability of Ecological Systems',
      authors: ['C. S. Holling'],
      year: '1973',
      venue: 'Annual Review of Ecology and Systematics, 4(1), 1-23',
      itemType: 'article',
      doi: '10.1146/annurev.es.04.110173.000245',
      abstractText: 'Distinguishes engineering stability from ecological resilience, defining resilience as the capacity of an ecosystem to absorb disturbance and persist.',
    ),
    CitationItem(
      key: 'tilman1994biodiversity',
      title: 'Biodiversity and stability in grasslands',
      authors: ['David Tilman', 'John A. Downing'],
      year: '1994',
      venue: 'Nature, 367(6461), 363-365',
      itemType: 'article',
      doi: '10.1038/367363a0',
      abstractText: 'Long-term grassland experiments showing that higher plant species richness buffers primary productivity against severe drought.',
    ),
    CitationItem(
      key: 'moreno-mateosLongtermRestorationEcosystem2020',
      title: 'The long-term restoration of ecosystem complexity',
      authors: ['David Moreno-Mateos', 'et al.'],
      year: '2020',
      venue: 'Nature Ecology & Evolution, 4(5), 676-685',
      itemType: 'article',
      doi: '10.1038/s41559-020-1154-1',
      abstractText: 'Ecosystem restoration often fails to recover pre-disturbance complexity, highlighting the need for long-term monitoring and ecological stewardship.',
    ),
  ];
}
