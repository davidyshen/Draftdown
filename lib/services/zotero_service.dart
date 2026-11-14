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
  static final RegExp _andSplitRegex =
      RegExp(r'\s+and\s+', caseSensitive: false);
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
        'Illia Polosukhin',
      ],
      year: '2017',
      venue: 'Advances in Neural Information Processing Systems (NeurIPS 2017)',
      itemType: 'inproceedings',
      doi: '10.48550/arXiv.1706.03762',
      url: 'https://arxiv.org/abs/1706.03762',
      abstractText:
          'The dominant sequence transduction models are based on complex recurrent or convolutional neural networks that include an encoder and a decoder. We propose a new simple network architecture, the Transformer, based solely on attention mechanisms.',
    ),
    CitationItem(
      key: 'chinchilla2022optimal',
      title: 'Training Compute-Optimal Large Language Models',
      authors: [
        'Jordan Hoffmann',
        'Sebastian Borgeaud',
        'Arthur Mensch',
        'Elena Buchatskaya',
        'Trevor Cai',
        'Eliza Rutherford',
      ],
      year: '2022',
      venue: 'Advances in Neural Information Processing Systems (NeurIPS 2022)',
      itemType: 'article',
      doi: '10.48550/arXiv.2203.15556',
      url: 'https://arxiv.org/abs/2203.15556',
      abstractText:
          'We investigate the optimal model size and number of tokens for training a transformer language model under a given compute budget. We find that current large models are significantly undertrained.',
    ),
    CitationItem(
      key: 'kaplan2020scaling',
      title: 'Scaling Laws for Neural Language Models',
      authors: [
        'Jared Kaplan',
        'Sam McCandlish',
        'Tom Henighan',
        'Tom B. Brown',
        'Benjamin Chess',
        'Rewon Child',
      ],
      year: '2020',
      venue: 'arXiv preprint arXiv:2001.08361',
      itemType: 'article',
      doi: '10.48550/arXiv.2001.08361',
      url: 'https://arxiv.org/abs/2001.08361',
      abstractText:
          'We study empirical scaling laws for language model performance on cross-entropy loss. The loss scales as a power-law with model size, dataset size, and the amount of compute used for training.',
    ),
    CitationItem(
      key: 'brown2020language',
      title: 'Language Models are Few-Shot Learners',
      authors: [
        'Tom B. Brown',
        'Benjamin Mann',
        'Nick Ryder',
        'Melanie Subbiah',
        'Jared Kaplan',
        'Prafulla Dhariwal',
      ],
      year: '2020',
      venue: 'Advances in Neural Information Processing Systems (NeurIPS 2020)',
      itemType: 'inproceedings',
      doi: '10.48550/arXiv.2005.14165',
      url: 'https://arxiv.org/abs/2005.14165',
      abstractText:
          'Recent work has demonstrated substantial gains on many NLP tasks and benchmarks by pre-training on a large corpus of text followed by fine-tuning on a specific task. Here we show that scaling up language models greatly improves task-agnostic, few-shot performance.',
    ),
    CitationItem(
      key: 'devlin2019bert',
      title: 'BERT: Pre-training of Deep Bidirectional Transformers for Language Understanding',
      authors: [
        'Jacob Devlin',
        'Ming-Wei Chang',
        'Kenton Lee',
        'Kristina Toutanova',
      ],
      year: '2019',
      venue: 'Proceedings of NAACL-HLT 2019',
      itemType: 'inproceedings',
      doi: '10.18653/v1/N19-1423',
      url: 'https://aclanthology.org/N19-1423',
      abstractText:
          'We introduce a new language representation model called BERT, which stands for Bidirectional Encoder Representations from Transformers. Unlike recent language representation models, BERT is designed to pre-train deep bidirectional representations.',
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

      final parsed = results.map((item) {
        final rawMap = (item is Map) ? item : <dynamic, dynamic>{};
        final map = (rawMap['data'] is Map) ? (rawMap['data'] as Map) : rawMap;

        final citekey = map['citekey']?.toString() ??
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

        final venue = map['publicationTitle']?.toString() ??
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
              final last = c['lastName']?.toString() ??
                  c['family']?.toString() ??
                  c['last']?.toString() ??
                  '';
              final first = c['firstName']?.toString() ??
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
      }).toList(growable: false);

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

    return _cachedItems.where((item) {
      final text = item.searchableText;
      for (int i = 0; i < tokens.length; i++) {
        if (!text.contains(tokens[i])) return false;
      }
      return true;
    }).toList(growable: false);
  }

  /// Query items from Zotero Web API using user/group credentials
  Future<List<CitationItem>> fetchFromZoteroWeb({
    required String userId,
    required String apiKey,
    int limit = 50,
  }) async {
    try {
      final url = Uri.parse(
          'https://api.zotero.org/users/$userId/items?format=csljson&limit=$limit');
      final response = await _httpClient.get(
        url,
        headers: {
          'Zotero-API-Version': '3',
          'Zotero-API-Key': apiKey,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Zotero Web API returned status ${response.statusCode}');
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
