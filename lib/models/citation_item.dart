/// Model representing a bibliographic citation item, compatible with
/// Zotero, Better BibTeX, and Pandoc citation keys.
class CitationItem {
  final String key;
  final String title;
  final List<String> authors;
  final String? year;
  final String? venue; // Journal, book title, or conference
  final String? itemType; // article, book, inproceedings, etc.
  final String? doi;
  final String? url;
  final String? abstractText;
  final String? rawBibtex;

  const CitationItem({
    required this.key,
    required this.title,
    this.authors = const [],
    this.year,
    this.venue,
    this.itemType,
    this.doi,
    this.url,
    this.abstractText,
    this.rawBibtex,
  });

  /// Extract the surname from a full author string (e.g. "David Moreno-Mateos" -> "Moreno-Mateos", "Turing, Alan" -> "Turing")
  static String extractSurname(String fullName) {
    var trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains(',')) {
      return trimmed.split(',').first.trim();
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.last.trim();
  }

  /// Infer author surname(s) from a citekey string e.g. "moreno-mateosLongtermRestorationEcosystem2020" -> "Moreno-Mateos et al."
  static String inferAuthorFromKey(String rawKey) {
    var clean = rawKey.trim().replaceAll(RegExp(r'^[@\-]'), '');
    final yearMatch = RegExp(r'(19\d\d|20\d\d)').firstMatch(clean);
    if (yearMatch != null) {
      final prefix = clean.substring(0, yearMatch.start);
      String rawAuthor;
      final boundaryMatch = RegExp(r'[a-z](?=[A-Z]|_)').firstMatch(prefix);
      if (boundaryMatch != null) {
        rawAuthor = prefix.substring(0, boundaryMatch.end);
      } else {
        rawAuthor = prefix;
      }
      if (rawAuthor.isNotEmpty) {
        final formattedAuthor = rawAuthor
            .split('-')
            .map((part) => part.isNotEmpty
                ? '${part[0].toUpperCase()}${part.substring(1)}'
                : '')
            .join('-');
        if (prefix.length > rawAuthor.length) {
          return '$formattedAuthor et al.';
        }
        return formattedAuthor;
      }
    }

    final cleanAlpha = clean.split(RegExp(r'[^a-zA-Z\-]')).firstWhere(
          (s) => s.isNotEmpty,
          orElse: () => clean,
        );
    if (cleanAlpha.isNotEmpty) {
      return cleanAlpha
          .split('-')
          .map((part) => part.isNotEmpty
              ? '${part[0].toUpperCase()}${part.substring(1)}'
              : '')
          .join('-');
    }
    return clean;
  }

  /// Short author representation for in-text citations (e.g. "Turing", "Russell & Norvig", "Moreno-Mateos et al.")
  String get shortAuthorSummary {
    if (authors.isNotEmpty) {
      if (authors.length == 1) {
        return extractSurname(authors.first);
      } else if (authors.length == 2) {
        return '${extractSurname(authors[0])} & ${extractSurname(authors[1])}';
      } else {
        return '${extractSurname(authors.first)} et al.';
      }
    }
    return inferAuthorFromKey(key);
  }

  /// Effective year from item metadata or inferred from the citekey
  String get effectiveYear {
    if (year != null && year!.trim().isNotEmpty && year != 'n.d.') {
      return year!.trim();
    }
    final yearMatch = RegExp(r'(19\d\d|20\d\d)').firstMatch(key);
    if (yearMatch != null) {
      return yearMatch.group(0)!;
    }
    return 'n.d.';
  }

  /// Formatted author and year string, e.g. "Moreno-Mateos et al., 2020" or "Turing, 1950"
  String get formattedAuthorYear {
    final author = shortAuthorSummary;
    final y = effectiveYear;
    return '$author, $y';
  }

  /// Single-line summary of authors, e.g. "Smith, J., Doe, A." or inferred from citekey
  String get authorsSummary {
    if (authors.isNotEmpty) {
      if (authors.length <= 3) return authors.join(', ');
      return '${authors.take(2).join(', ')} et al.';
    }
    final inferred = inferAuthorFromKey(key);
    return inferred.isNotEmpty ? inferred : 'Unknown author';
  }

  /// Mapping of accented / diacritic characters and ligatures to their plain ASCII equivalents.
  static final Map<String, String> _diacriticsMap = {
    // A
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
    'ă': 'a', 'ą': 'a', 'ǎ': 'a', 'ǟ': 'a', 'ǡ': 'a', 'ǻ': 'a', 'ȁ': 'a',
    'ȃ': 'a', 'ȧ': 'a', 'ḁ': 'a', 'ạ': 'a', 'ả': 'a', 'ấ': 'a', 'ầ': 'a',
    'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a', 'ắ': 'a', 'ằ': 'a', 'ẳ': 'a', 'ẵ': 'a',
    'ặ': 'a', 'ª': 'a',
    // AE
    'æ': 'ae', 'ǽ': 'ae', 'ǣ': 'ae',
    // B
    'ḃ': 'b', 'ḅ': 'b', 'ḇ': 'b',
    // C
    'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c', 'č': 'c', 'ḉ': 'c',
    // D
    'ð': 'd', 'ď': 'd', 'đ': 'd', 'ḋ': 'd', 'ḍ': 'd', 'ḏ': 'd', 'ḑ': 'd', 'ḓ': 'd',
    // E
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e',
    'ę': 'e', 'ě': 'e', 'ȅ': 'e', 'ȇ': 'e', 'ȩ': 'e', 'ḙ': 'e', 'ḛ': 'e',
    'ḝ': 'e', 'ẹ': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ế': 'e', 'ề': 'e', 'ể': 'e',
    'ễ': 'e', 'ệ': 'e',
    // F
    'ḟ': 'f',
    // G
    'ĝ': 'g', 'ğ': 'g', 'ġ': 'g', 'ģ': 'g', 'ǥ': 'g', 'ǧ': 'g', 'ǵ': 'g', 'ḡ': 'g',
    // H
    'ĥ': 'h', 'ħ': 'h', 'ḣ': 'h', 'ḥ': 'h', 'ḧ': 'h', 'ḩ': 'h', 'ḫ': 'h',
    // I
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i', 'ĭ': 'i',
    'į': 'i', 'ı': 'i', 'ǐ': 'i', 'ḭ': 'i', 'ỉ': 'i', 'ị': 'i',
    // J
    'ĵ': 'j', 'ǰ': 'j',
    // K
    'ķ': 'k', 'ǩ': 'k', 'ḱ': 'k', 'ḳ': 'k', 'ḵ': 'k',
    // L
    'ĺ': 'l', 'ļ': 'l', 'ľ': 'l', 'ŀ': 'l', 'ł': 'l', 'ḷ': 'l', 'ḹ': 'l',
    'ḻ': 'l', 'ḽ': 'l',
    // M
    'ḿ': 'm', 'ṁ': 'm', 'ṃ': 'm',
    // N
    'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n', 'ŉ': 'n', 'ŋ': 'n', 'ǹ': 'n',
    'ṅ': 'n', 'ṇ': 'n', 'ṉ': 'n', 'ṋ': 'n',
    // O
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
    'ŏ': 'o', 'ő': 'o', 'ơ': 'o', 'ǒ': 'o', 'ǫ': 'o', 'ǭ': 'o', 'ȍ': 'o',
    'ȏ': 'o', 'ȯ': 'o', 'ȱ': 'o', 'ṍ': 'o', 'ṏ': 'o', 'ṑ': 'o', 'ṓ': 'o',
    'ọ': 'o', 'ỏ': 'o', 'ố': 'o', 'ồ': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ớ': 'o', 'ờ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o', 'º': 'o', 'ǿ': 'o',
    // OE
    'œ': 'oe',
    // P
    'ṕ': 'p', 'ṗ': 'p',
    // R
    'ŕ': 'r', 'ŗ': 'r', 'ř': 'r', 'ȑ': 'r', 'ȓ': 'r', 'ṙ': 'r', 'ṛ': 'r',
    'ṝ': 'r', 'ṟ': 'r',
    // S
    'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's', 'ș': 's', 'ṡ': 's', 'ṣ': 's',
    'ṥ': 's', 'ṧ': 's', 'ṩ': 's', 'ß': 'ss',
    // T
    'ţ': 't', 'ť': 't', 'ŧ': 't', 'ț': 't', 'ṫ': 't', 'ṭ': 't', 'ṯ': 't', 'ṱ': 't',
    // TH
    'þ': 'th',
    // U
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u', 'ŭ': 'u',
    'ů': 'u', 'ű': 'u', 'ų': 'u', 'ǔ': 'u', 'ǖ': 'u', 'ǘ': 'u', 'ǚ': 'u',
    'ǜ': 'u', 'ȕ': 'u', 'ȗ': 'u', 'ṳ': 'u', 'ṵ': 'u', 'ṷ': 'u', 'ṹ': 'u',
    'ṻ': 'u', 'ụ': 'u', 'ủ': 'u', 'ứ': 'u', 'ừ': 'u', 'ử': 'u', 'ữ': 'u',
    'ự': 'u',
    // V
    'ṽ': 'v', 'ṿ': 'v',
    // W
    'ŵ': 'w', 'ẁ': 'w', 'ẃ': 'w', 'ẅ': 'w', 'ẇ': 'w', 'ẉ': 'w',
    // X
    'ẋ': 'x', 'ẍ': 'x',
    // Y
    'ý': 'y', 'ÿ': 'y', 'ŷ': 'y', 'ȳ': 'y', 'ẏ': 'y', 'ẙ': 'y', 'ỳ': 'y',
    'ỵ': 'y', 'ỷ': 'y', 'ỹ': 'y',
    // Z
    'ź': 'z', 'ż': 'z', 'ž': 'z', 'ẑ': 'z', 'ẓ': 'z', 'ẕ': 'z',
  };

  static final RegExp _combiningDiacritics = RegExp(r'[\u0300-\u036f]');

  /// Normalises a string for character-fuzzy / diacritic-insensitive search.
  /// Accents, umlauts, cedillas, ligatures, and combining diacritics are removed
  /// or converted to their base ASCII equivalents in lowercase.
  /// (e.g. "Pärtel" -> "partel", "Schrödinger" -> "schrodinger", "García" -> "garcia").
  static String normalizeForSearch(String input) {
    if (input.isEmpty) return '';
    final lower = input.toLowerCase().replaceAll(_combiningDiacritics, '');
    final buffer = StringBuffer();
    for (int i = 0; i < lower.length; i++) {
      final char = lower[i];
      final replacement = _diacriticsMap[char];
      if (replacement != null) {
        buffer.write(replacement);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Searchable text index in lowercase with diacritics and accents normalised
  String get searchableText {
    final raw = '$key $title ${authors.join(' ')} ${year ?? ''} ${venue ?? ''} ${itemType ?? ''}';
    return normalizeForSearch(raw);
  }

  /// Format citation for Pandoc Markdown
  String toPandocCitation({
    bool inText = false,
    bool suppressAuthor = false,
    String? locator,
  }) {
    final cleanKey = key.trim().replaceAll('@', '');
    if (inText) {
      // In-text citation: @smith2020 or @smith2020 [p. 23]
      if (locator != null && locator.trim().isNotEmpty) {
        return '@$cleanKey [${locator.trim()}]';
      }
      return '@$cleanKey';
    }

    // Bracketed citation: [@smith2020] or [-@smith2020] or [@smith2020, p. 23]
    final prefix = suppressAuthor ? '-@$cleanKey' : '@$cleanKey';
    if (locator != null && locator.trim().isNotEmpty) {
      return '[$prefix, ${locator.trim()}]';
    }
    return '[$prefix]';
  }

  /// Format this citation item as a valid BibTeX entry string
  String toBibtex() {
    if (rawBibtex != null && rawBibtex!.trim().isNotEmpty) {
      return rawBibtex!.trim();
    }

    final cleanKey = key.trim().replaceAll('@', '');
    String type = (itemType != null && itemType!.trim().isNotEmpty)
        ? itemType!.trim().toLowerCase()
        : 'misc';

    // Map common CSL / Zotero types to standard BibTeX entry types
    switch (type) {
      case 'journalarticle':
      case 'journal_article':
      case 'article-journal':
        type = 'article';
        break;
      case 'conferencepaper':
      case 'conference_paper':
      case 'paper-conference':
      case 'proceedings':
        type = 'inproceedings';
        break;
      case 'booksection':
      case 'chapter':
        type = 'incollection';
        break;
      case 'report':
      case 'techreport':
        type = 'techreport';
        break;
      case 'thesis':
      case 'phdthesis':
        type = 'phdthesis';
        break;
      case 'webpage':
      case 'website':
      case 'online':
        type = 'online';
        break;
      default:
        break;
    }

    final buffer = StringBuffer();
    buffer.writeln('@$type{$cleanKey,');
    buffer.writeln('  title = {${title.replaceAll('{', '').replaceAll('}', '')}},');

    if (authors.isNotEmpty) {
      buffer.writeln('  author = {${authors.join(' and ')}},');
    }

    final y = effectiveYear;
    if (y.isNotEmpty && y != 'n.d.') {
      buffer.writeln('  year = {$y},');
    }

    if (venue != null && venue!.trim().isNotEmpty) {
      final v = venue!.trim().replaceAll('{', '').replaceAll('}', '');
      if (type == 'article') {
        buffer.writeln('  journal = {$v},');
      } else if (type == 'inproceedings' || type == 'incollection') {
        buffer.writeln('  booktitle = {$v},');
      } else {
        buffer.writeln('  howpublished = {$v},');
      }
    }

    if (doi != null && doi!.trim().isNotEmpty) {
      buffer.writeln('  doi = {${doi!.trim()}},');
    }

    if (url != null && url!.trim().isNotEmpty) {
      buffer.writeln('  url = {${url!.trim()}},');
    }

    if (abstractText != null && abstractText!.trim().isNotEmpty) {
      final cleanAbstract =
          abstractText!.trim().replaceAll('{', '').replaceAll('}', '');
      buffer.writeln('  abstract = {$cleanAbstract},');
    }

    buffer.write('}');
    return buffer.toString();
  }

  /// Format multiple citations for Pandoc Markdown
  static String formatMultiple(
    List<CitationItem> items, {
    bool inText = false,
    bool suppressAuthor = false,
    String? locator,
  }) {
    if (items.isEmpty) return '';
    if (items.length == 1) {
      return items.first.toPandocCitation(
        inText: inText,
        suppressAuthor: suppressAuthor,
        locator: locator,
      );
    }

    if (inText) {
      final parts = items.map((item) {
        final cleanKey = item.key.trim().replaceAll('@', '');
        return '@$cleanKey';
      }).toList();

      final loc = (locator != null && locator.trim().isNotEmpty)
          ? ' [${locator.trim()}]'
          : '';

      if (parts.length == 2) {
        return '${parts[0]} and ${parts[1]}$loc';
      } else {
        final last = parts.removeLast();
        return '${parts.join(', ')}, and $last$loc';
      }
    }

    final parts = <String>[];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final cleanKey = item.key.trim().replaceAll('@', '');
      final prefix = suppressAuthor ? '-@$cleanKey' : '@$cleanKey';
      if (i == items.length - 1 &&
          locator != null &&
          locator.trim().isNotEmpty) {
        parts.add('$prefix, ${locator.trim()}');
      } else {
        parts.add(prefix);
      }
    }
    return '[${parts.join('; ')}]';
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'title': title,
      'authors': authors,
      'year': year,
      'venue': venue,
      'itemType': itemType,
      'doi': doi,
      'url': url,
      'abstractText': abstractText,
      'rawBibtex': rawBibtex,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CitationItem &&
          runtimeType == other.runtimeType &&
          key.trim().toLowerCase() == other.key.trim().toLowerCase();

  @override
  int get hashCode => key.trim().toLowerCase().hashCode;

  factory CitationItem.fromJson(Map<String, dynamic> json) {
    return CitationItem(
      key: json['key'] as String? ?? 'citation',
      title: json['title'] as String? ?? 'Untitled',
      authors: (json['authors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      year: json['year'] as String?,
      venue: json['venue'] as String?,
      itemType: json['itemType'] as String?,
      doi: json['doi'] as String?,
      url: json['url'] as String?,
      abstractText: json['abstractText'] as String?,
      rawBibtex: json['rawBibtex'] as String?,
    );
  }

  /// Extract all unique citation keys cited within [markdown] text.
  static List<String> extractCitedKeys(String markdown) =>
      DetectedCitation.extractCitedKeys(markdown);
}

/// Represents a recognized citation occurrence in the editor text.
class DetectedCitation {
  /// Start index of the citation in the document (inclusive, e.g. at '[')
  final int startOffset;

  /// End index of the citation in the document (exclusive, e.g. after ']')
  final int endOffset;

  /// The raw matched string in the text, e.g. "[@asdf, @ghj]"
  final String rawText;

  /// List of citation keys extracted from the citation
  final List<String> keys;

  /// Whether author suppression was detected (e.g. -@key)
  final bool suppressAuthor;

  /// Whether this was an in-text citation (e.g. @key without surrounding brackets)
  final bool inText;

  /// Any locator string detected (e.g. "p. 42")
  final String? locator;

  const DetectedCitation({
    required this.startOffset,
    required this.endOffset,
    required this.rawText,
    required this.keys,
    this.suppressAuthor = false,
    this.inText = false,
    this.locator,
  });

  /// Scan the text around [cursor] to detect if it sits within a citation.
  static DetectedCitation? findAt(String text, int cursor) {
    if (text.isEmpty || cursor < 0 || cursor > text.length) return null;

    // 1. Check if cursor is inside or adjacent to a bracketed citation [...]
    int openBracket = -1;
    for (int i = (cursor < text.length ? cursor : text.length - 1);
        i >= 0 && i >= cursor - 500;
        i--) {
      if (text[i] == '\n') break;
      if (text[i] == ']') {
        if (i == cursor - 1) {
          continue;
        } else {
          break;
        }
      }
      if (text[i] == '[') {
        openBracket = i;
        break;
      }
    }

    if (openBracket != -1) {
      int closeBracket = -1;
      for (int i = openBracket; i < text.length && i <= openBracket + 500; i++) {
        if (text[i] == '\n') break;
        if (text[i] == ']') {
          closeBracket = i;
          break;
        }
      }

      if (closeBracket != -1 &&
          cursor >= openBracket &&
          cursor <= closeBracket + 1) {
        final isLink =
            closeBracket + 1 < text.length && text[closeBracket + 1] == '(';
        if (!isLink) {
          final content = text.substring(openBracket + 1, closeBracket);
          final keyMatches =
              RegExp(r'(-?@[a-zA-Z0-9_\-:#\/]+)').allMatches(content);
          if (keyMatches.isNotEmpty) {
            final keys = <String>[];
            bool hasSuppress = false;
            for (final m in keyMatches) {
              final raw = m.group(0)!;
              if (raw.startsWith('-@')) {
                hasSuppress = true;
                keys.add(raw.substring(2));
              } else if (raw.startsWith('@')) {
                keys.add(raw.substring(1));
              }
            }

            // Extract locator if present e.g. [@key, p. 42] or [@key1; @key2, p. 42]
            String? locator;
            final locMatch =
                RegExp(r',\s*([^;@\]]+)(?:;|$)').firstMatch(content);
            if (locMatch != null) {
              final candidate = locMatch.group(1)?.trim();
              if (candidate != null &&
                  !candidate.startsWith('@') &&
                  candidate.isNotEmpty) {
                locator = candidate;
              }
            }

            return DetectedCitation(
              startOffset: openBracket,
              endOffset: closeBracket + 1,
              rawText: text.substring(openBracket, closeBracket + 1),
              keys: keys,
              suppressAuthor: hasSuppress,
              inText: false,
              locator: locator,
            );
          }
        }
      }
    }

    // 2. Check if cursor is on an in-text citation: @key or @key [locator]
    int lineStart = cursor;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }
    int lineEnd = cursor;
    while (lineEnd < text.length && text[lineEnd] != '\n') {
      lineEnd++;
    }
    final line = text.substring(lineStart, lineEnd);
    final inTextMatches = RegExp(
            r'(?<![\w@])@([a-zA-Z0-9_\-:#\/]+)(?:\s*\[([^\]]+)\])?')
        .allMatches(line);
    for (final m in inTextMatches) {
      final matchStart = lineStart + m.start;
      final matchEnd = lineStart + m.end;
      if (cursor >= matchStart && cursor <= matchEnd) {
        return DetectedCitation(
          startOffset: matchStart,
          endOffset: matchEnd,
          rawText: text.substring(matchStart, matchEnd),
          keys: [m.group(1)!],
          suppressAuthor: false,
          inText: true,
          locator: m.group(2)?.trim(),
        );
      }
    }

    return null;
  }

  /// Extract all unique citation keys cited within [markdown] text.
  /// Detects bracketed citations (e.g. `[@key]`, `[@k1; @k2, p. 5]`, `[-@k3]`)
  /// and in-text citations (e.g. `@key`, `@key [p. 10]`).
  static List<String> extractCitedKeys(String markdown) {
    if (markdown.isEmpty) return const [];
    final keys = <String>{};

    // 1. Match bracketed citations: [...@key...]
    final bracketRegex = RegExp(r'\[([^\]]*@[^\]]+)\]');
    for (final match in bracketRegex.allMatches(markdown)) {
      final inner = match.group(1)!;
      final keyRegex = RegExp(r'(-?@([a-zA-Z0-9_\-:#\/]+))');
      for (final km in keyRegex.allMatches(inner)) {
        final k = km.group(2);
        if (k != null && k.isNotEmpty) {
          keys.add(k);
        }
      }
    }

    // 2. Match in-text citations: (?<![\w@])@([a-zA-Z0-9_\-:#\/]+)
    final inTextRegex = RegExp(r'(?<![\w@])@([a-zA-Z0-9_\-:#\/]+)');
    for (final match in inTextRegex.allMatches(markdown)) {
      final k = match.group(1);
      if (k != null && k.isNotEmpty) {
        keys.add(k);
      }
    }

    return keys.toList();
  }
}
