import 'dart:convert';
import 'dart:io';
import '../models/citation_item.dart';

/// Service responsible for loading, parsing, and caching bibliography databases
/// (BibTeX, BibLaTeX, and CSL JSON formats).
class BibliographyService {
  /// In-memory cache of currently parsed citation items
  List<CitationItem> _items = [];

  List<CitationItem> get items => List.unmodifiable(_items);

  /// Initialise the service with default sample references so the user can
  /// experiment with citations immediately out of the box.
  BibliographyService() {
    _items = List.from(defaultSampleCitations);
  }

  /// Manually replace or initialise items in active bibliography
  void setItems(List<CitationItem> items) {
    _items = List.from(items);
  }

  /// Find a citation item by its citekey (case-insensitive, ignoring leading `@`)
  CitationItem? findByKey(String rawKey) {
    final clean = rawKey.trim().replaceAll('@', '').toLowerCase();
    for (final item in _items) {
      if (item.key.trim().replaceAll('@', '').toLowerCase() == clean) {
        return item;
      }
    }
    return null;
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
      _items = parsedItems;
    }
    return _items;
  }

  /// Parse BibTeX / BibLaTeX formatted string
  List<CitationItem> parseBibTeX(String bibtexContent) {
    final List<CitationItem> results = [];
    final normalized = bibtexContent.replaceAll('\r\n', '\n');

    // Match @type{key, ...}
    final entryRegex = RegExp(
      r'@([a-zA-Z]+)\s*\{\s*([a-zA-Z0-9_:.+-]+)\s*,\s*([\s\S]*?)(?=(?:\n\s*@|$))',
    );

    final matches = entryRegex.allMatches(normalized);

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

      results.add(CitationItem(
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
      ));
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
    if (raw.trim().isEmpty) return [];

    final parts = raw.split(RegExp(r'\s+and\s+', caseSensitive: false));
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
    var out = text;
    // Replace \{ and \}
    out = out.replaceAll(RegExp(r'[{}]'), '');
    // Replace \textit, \textbf, etc.
    out = out.replaceAll(RegExp(r'\\[a-zA-Z]+'), '');
    // Normalize extra whitespace
    out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
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
        final venue = raw['container-title']?.toString() ??
            raw['publisher']?.toString();
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
              final family = a['family']?.toString() ?? a['lastName']?.toString() ?? '';
              final given = a['given']?.toString() ?? a['firstName']?.toString() ?? '';
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
          final parts = authorList.split(RegExp(r'\s+and\s+', caseSensitive: false));
          for (final p in parts) {
            final t = p.trim();
            if (t.isNotEmpty) authors.add(t);
          }
        }

        items.add(CitationItem(
          key: key,
          title: title,
          authors: authors,
          year: year,
          venue: venue,
          itemType: type,
          doi: doi,
          url: url,
          abstractText: abstractText,
        ));
      }
    } catch (_) {
      // Return whatever could be parsed
    }
    return items;
  }

  /// Search literature in active bibliography with diacritic-insensitive matching
  List<CitationItem> search(String query) {
    if (query.trim().isEmpty) return _items;
    final normalized = CitationItem.normalizeForSearch(query.trim());
    final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return _items;

    return _items.where((item) {
      final text = item.searchableText;
      return tokens.every((token) => text.contains(token));
    }).toList();
  }

  /// Preloaded foundational sample citations
  static const List<CitationItem> defaultSampleCitations = [
    CitationItem(
      key: 'turing1950computing',
      title: 'Computing Machinery and Intelligence',
      authors: ['Alan M. Turing'],
      year: '1950',
      venue: 'Mind, 59(236), 433-460',
      itemType: 'article',
      doi: '10.1093/mind/LIX.236.433',
      abstractText:
          'Proposes the imitation game (the Turing test) to address the question: "Can machines think?" and considers nine common objections.',
    ),
    CitationItem(
      key: 'shannon1948mathematical',
      title: 'A Mathematical Theory of Communication',
      authors: ['Claude E. Shannon'],
      year: '1948',
      venue: 'Bell System Technical Journal, 27(3), 379-423',
      itemType: 'article',
      doi: '10.1002/j.1538-7305.1948.tb01338.x',
      abstractText:
          'Foundational paper establishing information theory, introducing the bit, channel capacity, and information entropy.',
    ),
    CitationItem(
      key: 'knuth1984literate',
      title: 'Literate Programming',
      authors: ['Donald E. Knuth'],
      year: '1984',
      venue: 'The Computer Journal, 27(2), 97-111',
      itemType: 'article',
      doi: '10.1093/comjnl/27.2.97',
      abstractText:
          'Advocates that computer programs should be written primarily as literary works for human reading rather than merely for machines.',
    ),
    CitationItem(
      key: 'vaswani2017attention',
      title: 'Attention Is All You Need',
      authors: [
        'Ashish Vaswani',
        'Noam Shazeer',
        'Niki Parmar',
        'Jakob Uszkoreit',
        'Llion Jones',
        'Aidan N. Gomez',
        'Lukasz Kaiser',
        'Illia Polosukhin'
      ],
      year: '2017',
      venue: 'Advances in Neural Information Processing Systems (NeurIPS 30)',
      itemType: 'inproceedings',
      abstractText:
          'Introduces the Transformer network architecture based entirely on self-attention mechanisms without recurrence or convolutions.',
    ),
    CitationItem(
      key: 'goodfellow2014generative',
      title: 'Generative Adversarial Nets',
      authors: [
        'Ian Goodfellow',
        'Jean Pouget-Abadie',
        'Mehdi Mirza',
        'Bing Xu',
        'David Warde-Farley',
        'Sherjil Ozair',
        'Aaron Courville',
        'Yoshua Bengio'
      ],
      year: '2014',
      venue: 'Advances in Neural Information Processing Systems (NeurIPS 27)',
      itemType: 'inproceedings',
      abstractText:
          'Proposes a new framework for estimating generative models via an adversarial process with generator and discriminator networks.',
    ),
    CitationItem(
      key: 'mcfarlane2020pandoc',
      title: 'Pandoc: A Universal Document Converter',
      authors: ['John MacFarlane'],
      year: '2020',
      venue: 'GitHub repository & documentation',
      itemType: 'manual',
      url: 'https://pandoc.org',
      abstractText:
          'The definitive reference for Pandoc document conversion, readers, writers, and markdown extensions.',
    ),
  ];
}
