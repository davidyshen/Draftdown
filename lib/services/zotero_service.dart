import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/citation_item.dart';

/// Service interfacing with local Zotero (via Better BibTeX JSON-RPC)
/// or the Zotero Web API.
class ZoteroService {
  /// Default local Better BibTeX JSON-RPC endpoint
  static const String defaultBbtEndpoint =
      'http://127.0.0.1:23119/better-bibtex/json-rpc';

  static final RegExp _yearBoundaryRegex = RegExp(r'\b(19\d\d|20\d\d)\b');
  static final RegExp _yearRegex = RegExp(r'(19\d\d|20\d\d)');
  static final RegExp _andSplitRegex = RegExp(
    r'\s+and\s+',
    caseSensitive: false,
  );
  static final RegExp _whitespaceRegex = RegExp(r'\s+');
  static const String _pingPayload =
      '{"jsonrpc":"2.0","method":"user.ping","id":1}';

  final String bbtEndpoint;
  late final Uri _bbtUri = Uri.parse(bbtEndpoint);
  final http.Client _httpClient = http.Client();
  final List<CitationItem> _cachedItems = [];
  List<CitationItem>? _unmodifiableCachedItems;
  final Map<String, CitationItem> _cachedByKey = {};

  bool? _lastBbtRunning;
  DateTime? _lastBbtCheckTime;

  List<CitationItem> get cachedItems =>
      _unmodifiableCachedItems ??= List.unmodifiable(_cachedItems);

  ZoteroService({this.bbtEndpoint = defaultBbtEndpoint}) {
    for (final item in defaultSampleZoteroItems) {
      _cachedItems.add(item);
      _cachedByKey[item.normalizedKey] = item;
    }
  }

  /// Default sample items representing Zotero library entries with Better BibTeX citekeys
  static const List<CitationItem> defaultSampleZoteroItems = [
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
      key: 'loreau2001biodiversity',
      title: 'Biodiversity and Ecosystem Functioning: Current Knowledge and Future Challenges',
      authors: [
        'Michel Loreau',
        'Shahid Naeem',
        'Pablo Inchausti',
        'Jan Bengtsson',
        'J. Philip Grime',
        'Andy Hector',
      ],
      year: '2001',
      venue: 'Science, 294(5543), 804-808',
      itemType: 'article',
      doi: '10.1126/science.1064088',
      abstractText: 'Synthesises experimental and theoretical evidence linking species diversity, functional traits, and ecosystem processes across terrestrial and aquatic biomes.',
    ),
    CitationItem(
      key: 'cardinale2012biodiversity',
      title: 'Biodiversity loss and its impact on humanity',
      authors: [
        'Bradley J. Cardinale',
        'J. Emmett Duffy',
        'Andrew Gonzalez',
        'David U. Hooper',
        'Charles Perrings',
        'Patrick Venail',
      ],
      year: '2012',
      venue: 'Nature, 486(7401), 59-67',
      itemType: 'article',
      doi: '10.1038/nature11148',
      abstractText: 'Reviews two decades of research demonstrating that biodiversity loss reduces the efficiency with which ecological communities capture biologically essential resources and produce biomass.',
    ),
    CitationItem(
      key: 'diaz2019pervasive',
      title: 'Pervasive human-driven decline of life on Earth points to the need for transformative change',
      authors: [
        'Sandra Díaz',
        'Josef Settele',
        'Eduardo S. Brondízio',
        'Hien T. Ngo',
        'John Agard',
        'Almut Arneth',
      ],
      year: '2019',
      venue: 'Science, 366(6471), eaax3100',
      itemType: 'article',
      doi: '10.1126/science.aax3100',
      abstractText: 'Global IPBES assessment documenting accelerating declines in biodiversity and ecosystem services driven by land-use change, exploitation, and climate change.',
    ),
  ];

  /// Check whether Zotero with Better BibTeX is running and responding
  Future<bool> isBbtRunning({
    Duration timeout = const Duration(milliseconds: 800),
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastBbtRunning != null &&
        _lastBbtCheckTime != null &&
        now.difference(_lastBbtCheckTime!) < const Duration(seconds: 3)) {
      return _lastBbtRunning!;
    }
    try {
      final response = await _httpClient
          .post(
            _bbtUri,
            headers: const {'Content-Type': 'application/json'},
            body: _pingPayload,
          )
          .timeout(timeout);

      final running = response.statusCode == 200;
      _lastBbtRunning = running;
      _lastBbtCheckTime = DateTime.now();
      return running;
    } catch (_) {
      _lastBbtRunning = false;
      _lastBbtCheckTime = DateTime.now();
      return false;
    }
  }

  /// Query Zotero Better BibTeX for literature items matching a search query
  Future<List<CitationItem>> searchBbt(String query) async {
    try {
      final response = await _httpClient
          .post(
            _bbtUri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'item.search',
              'params': [query],
              'id': 2,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode != 200) {
        return const [];
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic>? results = data['result'] as List<dynamic>?;
      if (results == null) return const [];

      final parsed = results
          .map((item) {
            final rawMap = (item is Map) ? item : <dynamic, dynamic>{};
            final map = (rawMap['data'] is Map)
                ? (rawMap['data'] as Map)
                : rawMap;

            final citekey =
                map['citekey']?.toString() ??
                map['citationKey']?.toString() ??
                map['key']?.toString() ??
                rawMap['key']?.toString() ??
                'item';
            final title = map['title']?.toString() ?? 'Untitled';

            String? year = map['year']?.toString();
            if (year == null || year.isEmpty) {
              final dateStr = map['date']?.toString();
              if (dateStr != null) {
                final match = _yearBoundaryRegex.firstMatch(dateStr);
                year = match?.group(0) ?? dateStr;
              }
            }
            if (year == null || year.isEmpty) {
              final issued = map['issued'];
              if (issued is Map) {
                final dateParts = issued['date-parts'];
                if (dateParts is List && dateParts.isNotEmpty) {
                  final firstDate = dateParts.first;
                  if (firstDate is List && firstDate.isNotEmpty) {
                    year = firstDate.first.toString();
                  }
                }
              }
            }
            if (year == null || year.isEmpty) {
              final keyYear = _yearRegex.firstMatch(citekey);
              year = keyYear?.group(0);
            }

            final venue =
                map['publicationTitle']?.toString() ??
                map['journal']?.toString() ??
                map['container-title']?.toString() ??
                map['bookTitle']?.toString() ??
                map['publisher']?.toString();
            final itemType = map['itemType']?.toString();
            final doi = map['DOI']?.toString() ?? map['doi']?.toString();
            final url = map['url']?.toString();
            final abstractText =
                map['abstractNote']?.toString() ?? map['abstract']?.toString();

            List<String> authors = [];
            final rawCreators =
                map['creators'] ?? map['author'] ?? map['authors'];
            if (rawCreators is List) {
              for (final c in rawCreators) {
                if (c is Map) {
                  final last =
                      c['lastName']?.toString() ??
                      c['family']?.toString() ??
                      c['last']?.toString() ??
                      '';
                  final first =
                      c['firstName']?.toString() ??
                      c['given']?.toString() ??
                      c['first']?.toString() ??
                      '';
                  final name =
                      c['name']?.toString() ?? c['literal']?.toString() ?? '';
                  if (first.isNotEmpty && last.isNotEmpty) {
                    authors.add('$first $last');
                  } else if (last.isNotEmpty) {
                    authors.add(last);
                  } else if (name.isNotEmpty) {
                    authors.add(name);
                  }
                } else if (c is String && c.trim().isNotEmpty) {
                  authors.add(c.trim());
                }
              }
            } else if (rawCreators is String && rawCreators.trim().isNotEmpty) {
              final parts = rawCreators.split(_andSplitRegex);
              for (final p in parts) {
                final trimmed = p.trim();
                if (trimmed.isNotEmpty) authors.add(trimmed);
              }
            }

            return CitationItem(
              key: citekey,
              title: title,
              authors: authors,
              year: year,
              venue: venue,
              itemType: itemType,
              doi: doi,
              url: url,
              abstractText: abstractText,
            );
          })
          .toList(growable: false);

      if (parsed.isNotEmpty) {
        bool addedAny = false;
        for (final item in parsed) {
          final k = item.normalizedKey;
          if (!_cachedByKey.containsKey(k)) {
            _cachedItems.add(item);
            _cachedByKey[k] = item;
            addedAny = true;
          }
        }
        if (addedAny) {
          _unmodifiableCachedItems = null;
        }
      }
      return parsed;
    } catch (_) {
      return const [];
    }
  }

  /// Find a cached citation item by its citekey in O(1) time (case-insensitive, ignoring leading `@`)
  CitationItem? findByKey(String rawKey) {
    final clean = rawKey.trim().replaceAll('@', '').toLowerCase();
    return _cachedByKey[clean];
  }

  /// Resolve a citation item by its citekey, searching BBT if running and not currently in cache
  Future<CitationItem?> resolveItem(String rawKey) async {
    final existing = findByKey(rawKey);
    if (existing != null) return existing;

    final isRunning = await isBbtRunning();
    if (isRunning) {
      final clean = rawKey.trim().replaceAll('@', '');
      final results = await searchBbt(clean);
      final targetLower = clean.toLowerCase();
      for (final item in results) {
        if (item.normalizedKey == targetLower) {
          return item;
        }
      }
    }
    return findByKey(rawKey);
  }

  /// Get cached Zotero items or search live if connected
  Future<List<CitationItem>> getOrSearch(String query) async {
    final cleanQuery = query.trim();
    final isRunning = await isBbtRunning();

    if (isRunning) {
      final results = await searchBbt(cleanQuery.isEmpty ? '' : cleanQuery);
      if (results.isNotEmpty) {
        return results;
      }
    }

    // Filter cached items if offline or if empty result
    if (cleanQuery.isEmpty) {
      return cachedItems;
    }

    final normalized = CitationItem.normalizeForSearch(cleanQuery);
    final tokens = normalized
        .split(_whitespaceRegex)
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return cachedItems;

    return _cachedItems
        .where((item) {
          final text = item.searchableText;
          for (int i = 0; i < tokens.length; i++) {
            if (!text.contains(tokens[i])) return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Query items from Zotero Web API using user/group credentials
  Future<List<CitationItem>> fetchFromZoteroWeb({
    required String userId,
    required String apiKey,
    int limit = 50,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.zotero.org/users/$userId/items?format=csljson&limit=$limit',
      );
      final response = await _httpClient
          .get(
            url,
            headers: {'Zotero-API-Version': '3', 'Zotero-API-Key': apiKey},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception(
          'Zotero Web API returned status ${response.statusCode}',
        );
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return [];
      final items = decoded['items'];
      if (items is! List) return [];

      return items.map((item) {
        final map = item as Map<String, dynamic>;
        final key = map['id']?.toString() ?? 'unknown';
        final title = map['title']?.toString() ?? 'Untitled';
        final venue = map['container-title']?.toString();

        List<String> authors = [];
        if (map['author'] is List) {
          for (final a in map['author']) {
            if (a is Map<String, dynamic>) {
              final family = a['family'] ?? '';
              final given = a['given'] ?? '';
              if (family.isNotEmpty) {
                authors.add(given.isNotEmpty ? '$given $family' : family);
              }
            }
          }
        }

        String? year;
        final issued = map['issued'];
        if (issued is Map<String, dynamic>) {
          final parts = issued['date-parts'];
          if (parts is List && parts.isNotEmpty && parts.first is List) {
            year = parts.first.first?.toString();
          }
        }

        return CitationItem(
          key: key,
          title: title,
          authors: authors,
          year: year,
          venue: venue,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Closes the underlying persistent HTTP client.
  void dispose() {
    _httpClient.close();
  }
}
