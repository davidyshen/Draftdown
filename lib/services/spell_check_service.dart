import 'dart:collection';

import '../controllers/markdown_syntax_controller.dart';
import 'windows_spell_checker.dart';

/// Represents a misspelled word range in the Markdown editor source.
class SpellErrorRange {
  final int start;
  final int end;
  final String word;

  const SpellErrorRange({
    required this.start,
    required this.end,
    required this.word,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpellErrorRange &&
          start == other.start &&
          end == other.end &&
          word == other.word;

  @override
  int get hashCode => Object.hash(start, end, word);
}

/// Supported spellchecker dictionary locales.
class SpellCheckLanguage {
  final String tag;
  final String label;

  const SpellCheckLanguage(this.tag, this.label);

  static const List<SpellCheckLanguage> supported = [
    SpellCheckLanguage('en-GB', 'English (UK)'),
    SpellCheckLanguage('en-US', 'English (US)'),
  ];
}

/// Markdown-aware spellcheck service.
///
/// Uses the native Windows `ISpellChecker` COM API when available, with a
/// pure-Dart fallback dictionary for non-Windows platforms or headless test
/// environments where COM spellchecking is unavailable.
class SpellCheckService {
  static final RegExp _wordRegex = RegExp(
    r"[A-Za-z]+(?:['’][A-Za-z]+)*(?:-[A-Za-z]+(?:['’][A-Za-z]+)*)*",
  );
  static final RegExp _urlOrEmailRegex = RegExp(
    r'(?:https?://|www\.)\S+|\S+@\S+\.\S+',
    caseSensitive: false,
  );
  static final RegExp _htmlTagOrEntityRegex = RegExp(
    r'<[A-Za-z/!][^>]*>|&[A-Za-z0-9#]+;',
  );

  static const Set<MarkdownTokenType> _skippedTokenTypes = {
    MarkdownTokenType.codeBlock,
    MarkdownTokenType.codeFence,
    MarkdownTokenType.inlineCode,
    MarkdownTokenType.latexInline,
    MarkdownTokenType.latexDisplay,
    MarkdownTokenType.latexDelimiter,
    MarkdownTokenType.linkUrl,
    MarkdownTokenType.citationKey,
    MarkdownTokenType.citationLocator,
    MarkdownTokenType.citationBracket,
    MarkdownTokenType.footnoteKey,
    MarkdownTokenType.footnoteBracket,
    MarkdownTokenType.headerMarker,
    MarkdownTokenType.blockquoteMarker,
    MarkdownTokenType.listMarker,
    MarkdownTokenType.horizontalRule,
    MarkdownTokenType.delimiter,
    MarkdownTokenType.imageMarker,
  };

  /// Domain-specific terms used throughout Draftdown and academic Markdown
  /// that should not be flagged as spelling errors.
  static const Set<String> _builtInAllowlist = {
    'draftdown',
    'markdown',
    'pandoc',
    'bibtex',
    'zotero',
    'latex',
    'katex',
    'mathjax',
    'yaml',
    'json',
    'docx',
    'pdf',
    'epub',
  };

  WindowsSpellChecker? _windowsChecker;
  bool _windowsInitialised = false;
  String _languageTag = 'en-GB';
  bool _isEnabled = true;

  final Set<String> _customWords = <String>{};
  final Set<String> _ignoredWords = <String>{};
  final Map<String, bool> _wordCache = HashMap<String, bool>();
  final bool useNativeBackend;

  SpellCheckService({
    String languageTag = 'en-GB',
    bool isEnabled = true,
    this.useNativeBackend = true,
  }) {
    _languageTag = languageTag;
    _isEnabled = isEnabled;
  }

  bool get isEnabled => _isEnabled;
  String get languageTag => _languageTag;
  Set<String> get customWords => Set.unmodifiable(_customWords);
  Set<String> get ignoredWords => Set.unmodifiable(_ignoredWords);
  bool get isUsingNativeBackend {
    _ensureBackend();
    return _windowsChecker?.isAvailable ?? false;
  }

  void _ensureBackend() {
    if (_windowsInitialised || !useNativeBackend) return;
    _windowsInitialised = true;
    _windowsChecker = WindowsSpellChecker.create(languageTag: _languageTag);
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  void setLanguage(String languageTag) {
    if (_languageTag == languageTag) return;
    _languageTag = languageTag;
    _wordCache.clear();
    if (_windowsInitialised && _windowsChecker != null) {
      _windowsChecker!.setLanguage(languageTag);
    }
  }

  void loadCustomWords(Iterable<String> words) {
    _customWords
      ..clear()
      ..addAll(
        words.map((w) => w.trim().toLowerCase()).where((w) => w.isNotEmpty),
      );
    _wordCache.clear();
  }

  void addCustomWord(String word) {
    final normalized = _normalizeWord(word);
    if (normalized.isEmpty) return;
    _customWords.add(normalized);
    _wordCache[normalized] = true;
  }

  void removeCustomWord(String word) {
    final normalized = _normalizeWord(word);
    _customWords.remove(normalized);
    _wordCache.remove(normalized);
  }

  void ignoreWord(String word) {
    final normalized = _normalizeWord(word);
    if (normalized.isEmpty) return;
    _ignoredWords.add(normalized);
    _wordCache[normalized] = true;
  }

  void clearIgnoredWords() {
    _ignoredWords.clear();
    _wordCache.clear();
  }

  void dispose() {
    _windowsChecker?.dispose();
    _windowsChecker = null;
  }

  String _normalizeWord(String word) =>
      word.replaceAll('’', "'").trim().toLowerCase();

  /// Returns `true` if [word] is considered valid (spelled correctly,
  /// allowlisted, ignored, or an acronym/identifier).
  bool isWordCorrect(String word) {
    if (word.length <= 1) return true;
    if (_isAllCapsAcronym(word)) return true;
    if (_hasInternalUpperCase(word)) return true;

    final normalized = _normalizeWord(word);
    if (normalized.isEmpty) return true;
    if (_builtInAllowlist.contains(normalized) ||
        _customWords.contains(normalized) ||
        _ignoredWords.contains(normalized)) {
      return true;
    }

    final cached = _wordCache[normalized];
    if (cached != null) return cached;

    // Handle hyphenated compound words: valid if the full form OR every part is valid.
    if (word.contains('-')) {
      final fullOk = _checkSingleToken(word.replaceAll('’', "'"));
      if (fullOk) {
        _wordCache[normalized] = true;
        return true;
      }
      final parts = word.split('-');
      final allPartsOk = parts.every(
        (part) => part.isEmpty || isWordCorrect(part),
      );
      _wordCache[normalized] = allPartsOk;
      return allPartsOk;
    }

    final ok = _checkSingleToken(word.replaceAll('’', "'"));
    _wordCache[normalized] = ok;
    return ok;
  }

  bool _checkSingleToken(String token) {
    _ensureBackend();
    final checker = _windowsChecker;
    if (checker != null && checker.isAvailable) {
      return checker.checkWord(token);
    }
    return _FallbackDictionary.isWordValid(token);
  }

  /// Returns up to [maxSuggestions] spelling suggestions for [word].
  List<String> suggest(String word, {int maxSuggestions = 5}) {
    if (word.trim().isEmpty) return const [];
    final normalizedInput = word.replaceAll('’', "'");
    _ensureBackend();
    final checker = _windowsChecker;
    if (checker != null && checker.isAvailable) {
      final native = checker.suggest(
        normalizedInput,
        maxSuggestions: maxSuggestions,
      );
      if (native.isNotEmpty) return native;
    }
    return _FallbackDictionary.suggest(
      normalizedInput,
      maxSuggestions: maxSuggestions,
    );
  }

  /// Scans [text] using pre-parsed Markdown [tokens] and returns all
  /// misspelled word ranges outside code, math, URLs, citations, and syntax markers.
  List<SpellErrorRange> findSpellingErrors({
    required String text,
    required List<ParsedToken> tokens,
  }) {
    if (!_isEnabled || text.isEmpty) return const [];

    // Build sorted list of excluded intervals from Markdown tokens + inline URLs/HTML.
    final excluded = _buildExcludedIntervals(text, tokens);
    final errors = <SpellErrorRange>[];

    int exIdx = 0;
    for (final match in _wordRegex.allMatches(text)) {
      final start = match.start;
      final end = match.end;

      // Skip words glued to digits or underscores (e.g. v2, H2O, snake_case).
      if (start > 0 && _isIdentifierNeighbor(text.codeUnitAt(start - 1))) {
        continue;
      }
      if (end < text.length && _isIdentifierNeighbor(text.codeUnitAt(end))) {
        continue;
      }

      // Advance exclusion pointer.
      while (exIdx < excluded.length && excluded[exIdx].$2 <= start) {
        exIdx++;
      }
      if (exIdx < excluded.length && excluded[exIdx].$1 < end) {
        continue;
      }

      final word = match.group(0)!;
      if (!isWordCorrect(word)) {
        errors.add(SpellErrorRange(start: start, end: end, word: word));
      }
    }

    return errors;
  }

  List<(int, int)> _buildExcludedIntervals(
    String text,
    List<ParsedToken> tokens,
  ) {
    final intervals = <(int, int)>[];

    for (final token in tokens) {
      if (_skippedTokenTypes.contains(token.type)) {
        intervals.add((token.start, token.end));
      }
    }

    for (final m in _urlOrEmailRegex.allMatches(text)) {
      intervals.add((m.start, m.end));
    }
    for (final m in _htmlTagOrEntityRegex.allMatches(text)) {
      intervals.add((m.start, m.end));
    }

    if (intervals.length <= 1) return intervals;
    intervals.sort((a, b) {
      final cmp = a.$1.compareTo(b.$1);
      return cmp != 0 ? cmp : a.$2.compareTo(b.$2);
    });

    // Merge overlapping intervals for fast single-pass scanning.
    final merged = <(int, int)>[intervals.first];
    for (int i = 1; i < intervals.length; i++) {
      final prev = merged.last;
      final curr = intervals[i];
      if (curr.$1 <= prev.$2) {
        if (curr.$2 > prev.$2) {
          merged[merged.length - 1] = (prev.$1, curr.$2);
        }
      } else {
        merged.add(curr);
      }
    }
    return merged;
  }

  static bool _isIdentifierNeighbor(int codeUnit) {
    // Digits 0-9 or underscore '_'
    return (codeUnit >= 48 && codeUnit <= 57) || codeUnit == 95;
  }

  static bool _isAllCapsAcronym(String word) {
    if (word.length < 2) return false;
    bool hasLetter = false;
    for (int i = 0; i < word.length; i++) {
      final c = word.codeUnitAt(i);
      if (c >= 97 && c <= 122) return false; // lowercase a-z
      if (c >= 65 && c <= 90) hasLetter = true;
    }
    return hasLetter;
  }

  /// Detects camelCase / PascalCase identifiers (e.g. `camelCase`, `TextField`)
  /// by checking if an uppercase letter appears after a lowercase letter.
  static bool _hasInternalUpperCase(String word) {
    bool seenLower = false;
    for (int i = 0; i < word.length; i++) {
      final c = word.codeUnitAt(i);
      if (c >= 97 && c <= 122) {
        seenLower = true;
      } else if (c >= 65 && c <= 90 && seenLower) {
        return true;
      }
    }
    return false;
  }
}

/// Pure-Dart fallback dictionary and edit-distance suggester used when the
/// native Windows spellchecker is unavailable (e.g. non-Windows platforms).
class _FallbackDictionary {
  static const Set<String> _coreWords = {
    'a',
    'about',
    'above',
    'academic',
    'accept',
    'access',
    'according',
    'account',
    'acronym',
    'across',
    'act',
    'action',
    'active',
    'actual',
    'actually',
    'add',
    'added',
    'addition',
    'address',
    'after',
    'again',
    'against',
    'age',
    'ago',
    'agree',
    'air',
    'all',
    'allow',
    'almost',
    'alone',
    'along',
    'already',
    'also',
    'although',
    'always',
    'am',
    'among',
    'amount',
    'an',
    'analysis',
    'and',
    'another',
    'answer',
    'any',
    'anyone',
    'anything',
    'appear',
    'app',
    'application',
    'apply',
    'approach',
    'are',
    'area',
    'argument',
    'around',
    'art',
    'article',
    'as',
    'ask',
    'at',
    'author',
    'authors',
    'available',
    'away',
    'back',
    'bad',
    'base',
    'based',
    'basic',
    'be',
    'because',
    'become',
    'been',
    'before',
    'begin',
    'behind',
    'being',
    'believe',
    'below',
    'best',
    'better',
    'between',
    'beyond',
    'bibliography',
    'big',
    'bit',
    'black',
    'block',
    'blue',
    'body',
    'bold',
    'book',
    'both',
    'box',
    'break',
    'brief',
    'bring',
    'build',
    'built',
    'but',
    'button',
    'by',
    'call',
    'called',
    'came',
    'can',
    'cannot',
    'capital',
    'case',
    'cause',
    'centre',
    'center',
    'certain',
    'change',
    'chapter',
    'character',
    'check',
    'child',
    'children',
    'choice',
    'choose',
    'citation',
    'citations',
    'cite',
    'city',
    'class',
    'clear',
    'click',
    'close',
    'code',
    'colour',
    'color',
    'column',
    'come',
    'command',
    'comment',
    'common',
    'compare',
    'complete',
    'complex',
    'component',
    'computer',
    'concept',
    'conclusion',
    'condition',
    'config',
    'configuration',
    'consider',
    'consistent',
    'contain',
    'content',
    'context',
    'continue',
    'control',
    'controller',
    'copy',
    'core',
    'correct',
    'could',
    'count',
    'country',
    'course',
    'cover',
    'create',
    'current',
    'cursor',
    'custom',
    'cut',
    'dark',
    'data',
    'date',
    'day',
    'deal',
    'decide',
    'default',
    'define',
    'definition',
    'delete',
    'describe',
    'design',
    'desktop',
    'detail',
    'details',
    'determine',
    'develop',
    'development',
    'device',
    'dialog',
    'dictionary',
    'did',
    'different',
    'direct',
    'directory',
    'display',
    'do',
    'doc',
    'document',
    'documentation',
    'does',
    'done',
    'down',
    'draft',
    'draw',
    'during',
    'each',
    'early',
    'easy',
    'edit',
    'editing',
    'editor',
    'effect',
    'either',
    'element',
    'else',
    'email',
    'empty',
    'enable',
    'enabled',
    'end',
    'english',
    'enough',
    'ensure',
    'enter',
    'entry',
    'environment',
    'equal',
    'error',
    'errors',
    'especially',
    'even',
    'event',
    'ever',
    'every',
    'everyone',
    'everything',
    'evidence',
    'exact',
    'example',
    'examples',
    'except',
    'exist',
    'expand',
    'expect',
    'experience',
    'explain',
    'export',
    'express',
    'extend',
    'external',
    'extra',
    'eye',
    'face',
    'fact',
    'fail',
    'fall',
    'false',
    'family',
    'far',
    'fast',
    'feature',
    'features',
    'feel',
    'few',
    'field',
    'figure',
    'file',
    'files',
    'fill',
    'filter',
    'final',
    'find',
    'fine',
    'finish',
    'first',
    'fit',
    'fix',
    'focus',
    'folder',
    'follow',
    'font',
    'fonts',
    'footnote',
    'for',
    'force',
    'form',
    'format',
    'formatting',
    'formula',
    'forward',
    'found',
    'four',
    'frame',
    'free',
    'from',
    'front',
    'full',
    'function',
    'further',
    'future',
    'game',
    'general',
    'generate',
    'get',
    'give',
    'given',
    'global',
    'go',
    'good',
    'got',
    'government',
    'great',
    'green',
    'group',
    'grow',
    'guide',
    'had',
    'half',
    'hand',
    'handle',
    'happen',
    'hard',
    'has',
    'have',
    'he',
    'head',
    'header',
    'heading',
    'health',
    'hear',
    'held',
    'hello',
    'help',
    'her',
    'here',
    'herself',
    'high',
    'highlight',
    'him',
    'himself',
    'his',
    'history',
    'hold',
    'home',
    'hope',
    'hour',
    'house',
    'how',
    'however',
    'human',
    'idea',
    'identifier',
    'identify',
    'if',
    'ignore',
    'image',
    'images',
    'implement',
    'important',
    'improve',
    'in',
    'include',
    'increase',
    'indeed',
    'index',
    'indicate',
    'individual',
    'industry',
    'information',
    'initial',
    'inline',
    'input',
    'insert',
    'inside',
    'install',
    'instance',
    'instead',
    'into',
    'introduce',
    'is',
    'issue',
    'it',
    'italic',
    'item',
    'items',
    'its',
    'itself',
    'job',
    'join',
    'just',
    'keep',
    'key',
    'keyboard',
    'kind',
    'knew',
    'know',
    'known',
    'label',
    'language',
    'large',
    'last',
    'late',
    'later',
    'latest',
    'law',
    'layout',
    'lead',
    'learn',
    'least',
    'leave',
    'left',
    'length',
    'less',
    'let',
    'letter',
    'level',
    'library',
    'life',
    'light',
    'like',
    'likely',
    'line',
    'lines',
    'link',
    'links',
    'list',
    'listen',
    'little',
    'live',
    'load',
    'local',
    'locate',
    'location',
    'long',
    'look',
    'lose',
    'loss',
    'lot',
    'love',
    'low',
    'machine',
    'made',
    'main',
    'make',
    'man',
    'manage',
    'management',
    'manager',
    'many',
    'map',
    'mark',
    'marker',
    'market',
    'match',
    'material',
    'math',
    'matter',
    'may',
    'maybe',
    'me',
    'mean',
    'meaning',
    'measure',
    'media',
    'meet',
    'member',
    'memory',
    'mention',
    'menu',
    'message',
    'method',
    'middle',
    'might',
    'mind',
    'minute',
    'minutes',
    'miss',
    'mode',
    'model',
    'modern',
    'modify',
    'moment',
    'money',
    'month',
    'more',
    'morning',
    'most',
    'mother',
    'move',
    'much',
    'multiple',
    'must',
    'my',
    'myself',
    'name',
    'nation',
    'national',
    'natural',
    'nature',
    'near',
    'necessary',
    'need',
    'network',
    'never',
    'new',
    'news',
    'next',
    'nice',
    'night',
    'no',
    'none',
    'nor',
    'normal',
    'north',
    'not',
    'note',
    'notes',
    'nothing',
    'notice',
    'now',
    'number',
    'numbers',
    'object',
    'obtain',
    'obvious',
    'occur',
    'of',
    'off',
    'offer',
    'office',
    'often',
    'oh',
    'old',
    'on',
    'once',
    'one',
    'only',
    'open',
    'operate',
    'operation',
    'option',
    'options',
    'or',
    'order',
    'organisation',
    'organization',
    'other',
    'others',
    'our',
    'out',
    'output',
    'outside',
    'over',
    'own',
    'page',
    'paper',
    'paragraph',
    'part',
    'particular',
    'party',
    'pass',
    'past',
    'path',
    'pattern',
    'pay',
    'people',
    'per',
    'percent',
    'perform',
    'perhaps',
    'period',
    'person',
    'personal',
    'phone',
    'pick',
    'picture',
    'piece',
    'place',
    'plan',
    'plane',
    'plant',
    'platform',
    'play',
    'please',
    'point',
    'policy',
    'political',
    'poor',
    'popular',
    'position',
    'positive',
    'possible',
    'post',
    'power',
    'practice',
    'prepare',
    'present',
    'preserve',
    'press',
    'pressure',
    'pretty',
    'prevent',
    'preview',
    'previous',
    'price',
    'primary',
    'print',
    'private',
    'probably',
    'problem',
    'process',
    'produce',
    'product',
    'production',
    'program',
    'project',
    'proper',
    'property',
    'prose',
    'protect',
    'prove',
    'provide',
    'public',
    'pull',
    'purpose',
    'push',
    'put',
    'quality',
    'question',
    'quick',
    'quickly',
    'quite',
    'quote',
    'race',
    'raise',
    'range',
    'rate',
    'rather',
    'reach',
    'read',
    'reading',
    'ready',
    'real',
    'really',
    'reason',
    'receive',
    'recent',
    'recognise',
    'recognize',
    'record',
    'red',
    'reduce',
    'refer',
    'reference',
    'references',
    'reflect',
    'region',
    'relate',
    'release',
    'relevant',
    'remain',
    'remember',
    'remove',
    'render',
    'replace',
    'report',
    'represent',
    'require',
    'research',
    'resolve',
    'resource',
    'respect',
    'respond',
    'response',
    'rest',
    'result',
    'return',
    'reveal',
    'review',
    'rich',
    'right',
    'rise',
    'risk',
    'road',
    'role',
    'room',
    'rule',
    'run',
    'safe',
    'said',
    'same',
    'sample',
    'save',
    'saw',
    'say',
    'scale',
    'scene',
    'scheme',
    'school',
    'science',
    'scientific',
    'screen',
    'script',
    'scroll',
    'search',
    'season',
    'seat',
    'second',
    'section',
    'security',
    'see',
    'seek',
    'seem',
    'select',
    'selection',
    'self',
    'sell',
    'send',
    'sense',
    'sentence',
    'separate',
    'series',
    'serious',
    'serve',
    'service',
    'session',
    'set',
    'setting',
    'settings',
    'several',
    'shall',
    'shape',
    'share',
    'she',
    'sheet',
    'short',
    'should',
    'show',
    'side',
    'sidebar',
    'sign',
    'significant',
    'similar',
    'simple',
    'simply',
    'since',
    'single',
    'site',
    'situation',
    'size',
    'skill',
    'small',
    'so',
    'social',
    'society',
    'software',
    'solution',
    'some',
    'someone',
    'something',
    'sometimes',
    'son',
    'soon',
    'sort',
    'sound',
    'source',
    'south',
    'space',
    'speak',
    'special',
    'specific',
    'spell',
    'spellcheck',
    'spellchecker',
    'spelling',
    'spend',
    'split',
    'spoke',
    'stage',
    'stand',
    'standard',
    'star',
    'start',
    'state',
    'statement',
    'station',
    'status',
    'stay',
    'step',
    'still',
    'stock',
    'stop',
    'store',
    'story',
    'strategy',
    'street',
    'strong',
    'structure',
    'student',
    'study',
    'stuff',
    'style',
    'subject',
    'submit',
    'success',
    'such',
    'suddenly',
    'suffer',
    'suggest',
    'suggestion',
    'suggestions',
    'summary',
    'summer',
    'supply',
    'support',
    'sure',
    'surface',
    'switch',
    'symbol',
    'syntax',
    'system',
    'table',
    'take',
    'talk',
    'target',
    'task',
    'tax',
    'teach',
    'teacher',
    'team',
    'technology',
    'tell',
    'template',
    'ten',
    'tend',
    'term',
    'terms',
    'test',
    'text',
    'than',
    'thank',
    'that',
    'the',
    'their',
    'them',
    'theme',
    'themselves',
    'then',
    'theory',
    'there',
    'these',
    'they',
    'thing',
    'think',
    'third',
    'this',
    'those',
    'though',
    'thought',
    'thousand',
    'three',
    'through',
    'throughout',
    'throw',
    'thus',
    'time',
    'title',
    'to',
    'today',
    'together',
    'told',
    'tomorrow',
    'too',
    'took',
    'tool',
    'toolbar',
    'tools',
    'top',
    'topic',
    'total',
    'touch',
    'toward',
    'towards',
    'town',
    'track',
    'trade',
    'traditional',
    'train',
    'training',
    'travel',
    'treat',
    'tree',
    'trial',
    'trip',
    'trouble',
    'true',
    'truth',
    'try',
    'turn',
    'two',
    'type',
    'typical',
    'under',
    'understand',
    'unit',
    'united',
    'university',
    'unless',
    'until',
    'up',
    'update',
    'upon',
    'us',
    'use',
    'used',
    'user',
    'using',
    'usually',
    'valid',
    'value',
    'values',
    'various',
    'version',
    'very',
    'view',
    'visit',
    'visual',
    'voice',
    'wait',
    'walk',
    'wall',
    'want',
    'war',
    'watch',
    'water',
    'way',
    'we',
    'wear',
    'week',
    'weight',
    'welcome',
    'well',
    'went',
    'were',
    'west',
    'what',
    'whatever',
    'when',
    'where',
    'whether',
    'which',
    'while',
    'white',
    'who',
    'whole',
    'whom',
    'whose',
    'why',
    'wide',
    'wife',
    'will',
    'win',
    'wind',
    'window',
    'windows',
    'wish',
    'with',
    'within',
    'without',
    'woman',
    'women',
    'wonder',
    'word',
    'words',
    'work',
    'worker',
    'working',
    'world',
    'worry',
    'worse',
    'worst',
    'worth',
    'would',
    'write',
    'writer',
    'writing',
    'written',
    'wrong',
    'wrote',
    'year',
    'yes',
    'yesterday',
    'yet',
    'you',
    'young',
    'your',
    'yourself',
    'zero',
  };

  static bool isWordValid(String word) {
    final lower = word.toLowerCase();
    if (_coreWords.contains(lower)) return true;

    // Basic possessive handling
    if (lower.endsWith("'s") && lower.length > 2) {
      return isWordValid(lower.substring(0, lower.length - 2));
    }

    // Basic morphological suffix stripping
    if (lower.endsWith('s') && lower.length > 3) {
      if (_coreWords.contains(lower.substring(0, lower.length - 1)))
        return true;
    }
    if (lower.endsWith('es') && lower.length > 4) {
      if (_coreWords.contains(lower.substring(0, lower.length - 2)))
        return true;
    }
    if (lower.endsWith('ed') && lower.length > 4) {
      final stem = lower.substring(0, lower.length - 2);
      if (_coreWords.contains(stem) || _coreWords.contains('${stem}e')) {
        return true;
      }
    }
    if (lower.endsWith('ing') && lower.length > 5) {
      final stem = lower.substring(0, lower.length - 3);
      if (_coreWords.contains(stem) || _coreWords.contains('${stem}e')) {
        return true;
      }
    }
    if (lower.endsWith('ly') && lower.length > 4) {
      if (_coreWords.contains(lower.substring(0, lower.length - 2)))
        return true;
    }
    return false;
  }

  static List<String> suggest(String word, {int maxSuggestions = 5}) {
    final lower = word.toLowerCase();
    final scored = <(String, int)>[];
    for (final candidate in _coreWords) {
      if ((candidate.length - lower.length).abs() > 2) continue;
      final dist = _levenshtein(lower, candidate);
      if (dist <= 2) {
        scored.add((candidate, dist));
      }
    }
    scored.sort((a, b) {
      final cmp = a.$2.compareTo(b.$2);
      return cmp != 0 ? cmp : a.$1.compareTo(b.$1);
    });
    final isTitleCase =
        word.isNotEmpty &&
        word[0].toUpperCase() == word[0] &&
        word[0].toLowerCase() != word[0];
    return scored.take(maxSuggestions).map((e) {
      final w = e.$1;
      if (isTitleCase && w.isNotEmpty) {
        return w[0].toUpperCase() + w.substring(1);
      }
      return w;
    }).toList();
  }

  static int _levenshtein(String a, String b) {
    final m = a.length;
    final n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;
    var prev = List<int>.generate(n + 1, (j) => j);
    var curr = List<int>.filled(n + 1, 0);
    for (int i = 1; i <= m; i++) {
      curr[0] = i;
      for (int j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        curr[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }
}
