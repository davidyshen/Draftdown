import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/citation_item.dart';
import '../models/export_format.dart';
import '../models/history_entry.dart';
import '../services/bibliography_service.dart';
import '../services/direct_export_service.dart';
import '../services/file_service.dart';
import '../services/history_service.dart';
import '../services/markdown_render_service.dart';
import '../services/pandoc_service.dart';
import '../services/spell_check_service.dart';
import '../services/zotero_service.dart';
import '../ui/theme/app_theme.dart';
import 'markdown_syntax_controller.dart';

enum EditorViewMode { edit, split, preview }

enum CitationSource { bibtex, zotero }

/// Represents information about a task list checkbox in markdown source.
class MarkdownCheckboxInfo {
  final int charOffset;
  final bool isChecked;

  const MarkdownCheckboxInfo({
    required this.charOffset,
    required this.isChecked,
  });
}

/// Represents an open document tab held in memory by [EditorController].
class OpenDocument {
  String id;
  String? filePath;
  String fileName;
  String content;
  TextSelection selection;
  double scrollOffset;
  bool isModified;
  bool hasConflict;
  bool hasPromptedConflict;
  String? lastKnownDiskContent;
  DateTime? lastDiskModified;
  int? lastDiskSize;
  String previewMarkdown;
  Map<String, int> numericIndices;
  List<md.Node>? astNodes;
  int wordCount;
  int charCount;
  int lineCount;
  int readingTimeMinutes;
  CitationStyle citationStyle;

  OpenDocument({
    required this.id,
    this.filePath,
    required this.fileName,
    this.content = '',
    this.selection = const TextSelection.collapsed(offset: 0),
    this.scrollOffset = 0.0,
    this.isModified = false,
    this.hasConflict = false,
    this.hasPromptedConflict = false,
    this.lastKnownDiskContent,
    this.lastDiskModified,
    this.lastDiskSize,
    this.previewMarkdown = '',
    this.numericIndices = const {},
    this.astNodes,
    this.wordCount = 0,
    this.charCount = 0,
    this.lineCount = 1,
    this.readingTimeMinutes = 1,
    this.citationStyle = CitationStyle.authorYear,
  });
}

/// Main application state controller for Draftdown.
class EditorController extends ChangeNotifier {
  static final RegExp _bibEntryKeyRegex = RegExp(
    r'@([a-zA-Z]+)\s*\{\s*([a-zA-Z0-9_:.+-]+)\s*,',
  );

  final FileService fileService;
  final HistoryService historyService;
  final BibliographyService bibliographyService;
  final PandocService pandocService;
  final ZoteroService zoteroService;
  final DirectExportService directExportService;
  final SpellCheckService spellCheckService;

  SharedPreferences? _prefs;
  Future<SharedPreferences> _getPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  // Document state
  final List<OpenDocument> _openDocuments = [];
  int _activeDocumentIndex = -1;
  int _nextUntitledId = 0;
  String? _currentFilePath;
  String _currentFileName = 'Untitled.md';
  bool _isModified = false;
  bool _hasConflict = false;
  bool _hasPromptedConflict = false;
  bool _isWatchingFiles = false;
  bool _isCheckingFiles = false;
  final Map<String, StreamSubscription<FileSystemEvent>> _directoryWatchers =
      {};
  final Map<String, Timer> _fileChangeDebounceTimers = {};
  static const Duration fileWatchDebounce = Duration(milliseconds: 150);
  final MarkdownSyntaxEditingController textController =
      MarkdownSyntaxEditingController();
  final FocusNode focusNode = FocusNode();
  final ScrollController scrollController = ScrollController();

  // Metrics
  int _wordCount = 0;
  int _charCount = 0;
  int _lineCount = 1;
  int _readingTimeMinutes = 1;

  // View state
  EditorViewMode _viewMode = EditorViewMode.split;
  bool _isSidebarOpen = false;

  // Bibliography & Zotero state
  String? _bibliographyPath;
  bool _isZoteroConnected = false;
  String _bibliographyStatus = 'Initialised with sample bibliography';
  CitationSource _citationSource = CitationSource.bibtex;
  CitationStyle _citationStyle = CitationStyle.authorYear;

  // Pandoc state
  bool _isPandocAvailable = false;
  String? _pandocVersion;

  // Typography & Appearance state
  String _editorFontFamily = 'Consolas';
  bool _isDualRenderFont = false;
  String _renderBodyFont = 'Segoe UI';
  String _renderHeaderFont = 'Georgia';
  String? _darkSchemeId;
  String? _lightSchemeId;
  bool? _isDarkMode;

  // Preview state & Debouncing (1.5s idle window after typing stops)
  static const Duration defaultRenderDebounce = Duration(milliseconds: 1500);
  final Duration? _customRenderDebounce;
  final MarkdownRenderService _renderService;
  final ValueNotifier<String> previewNotifier = ValueNotifier<String>('');
  String _previewMarkdown = '';
  Map<String, int> _numericIndices = const {};
  List<md.Node>? _astNodes;
  Timer? _debounceTimer;
  int _activeRenderSequence = 0;
  int _completedRenderSequence = 0;
  int _documentEpoch = 0;
  bool _isBackgroundRendering = false;
  bool? _isProgrammaticUpdate;
  String? _lastObservedText;

  // Getters
  Duration get renderDebounceDuration =>
      _customRenderDebounce ?? defaultRenderDebounce;
  String? get currentFilePath => _currentFilePath;
  String get currentFileName => _currentFileName;
  bool get isModified => _isModified;
  bool get hasConflict => _hasConflict;
  bool get shouldPromptConflict => _hasConflict && !_hasPromptedConflict;
  bool get isFileWatchingActive => _isWatchingFiles;
  List<OpenDocument> get openDocuments => List.unmodifiable(_openDocuments);
  OpenDocument? get activeDocument =>
      (_activeDocumentIndex >= 0 &&
          _activeDocumentIndex < _openDocuments.length)
      ? _openDocuments[_activeDocumentIndex]
      : null;
  bool isFileOpen(String path) =>
      _openDocuments.any((d) => _pathsEqual(d.filePath, path));
  OpenDocument? openDocumentForPath(String path) {
    for (final doc in _openDocuments) {
      if (_pathsEqual(doc.filePath, path)) return doc;
    }
    return null;
  }

  bool isFileModified(String path) {
    if (_pathsEqual(_currentFilePath, path)) return _isModified;
    return openDocumentForPath(path)?.isModified ?? false;
  }

  bool isFileConflicted(String path) {
    if (_pathsEqual(_currentFilePath, path)) return _hasConflict;
    return openDocumentForPath(path)?.hasConflict ?? false;
  }

  void markConflictPrompted() {
    if (!_hasPromptedConflict) {
      _hasPromptedConflict = true;
      activeDocument?.hasPromptedConflict = true;
    }
  }

  bool get isBackgroundRendering => _isBackgroundRendering;
  bool get isRenderPending =>
      (_debounceTimer?.isActive ?? false) || _isBackgroundRendering;
  Map<String, int> get numericIndices => _numericIndices;
  List<md.Node>? get astNodes => _astNodes;
  EditorViewMode get viewMode => _viewMode;
  bool get isSidebarOpen => _isSidebarOpen;
  int get wordCount => _wordCount;
  int get charCount => _charCount;
  int get lineCount => _lineCount;
  int get readingTimeMinutes => _readingTimeMinutes;
  List<HistoryEntry> get history => historyService.history;
  List<CitationItem> get citations => bibliographyService.items;
  CitationSource get citationSource => _citationSource;
  CitationStyle get citationStyle => _citationStyle;
  List<CitationItem> get zoteroCitations => zoteroService.cachedItems;
  String? get bibliographyPath => _bibliographyPath;
  bool get isZoteroConnected => _isZoteroConnected;
  String get bibliographyStatus => _bibliographyStatus;
  bool get isPandocAvailable => _isPandocAvailable;
  String? get pandocVersion => _pandocVersion;
  bool get isUsingBundledPandoc => pandocService.isBundled;
  String? get resolvedPandocPath => pandocService.resolvedExecutablePath;
  String get editorFontFamily => _editorFontFamily;
  bool get isDualRenderFont => _isDualRenderFont;
  String get renderBodyFont => _renderBodyFont;
  String get renderHeaderFont => _renderHeaderFont;
  String get effectiveRenderHeaderFont =>
      _isDualRenderFont ? _renderHeaderFont : _renderBodyFont;
  String get darkSchemeId => _darkSchemeId ?? AppTheme.slateDarkScheme.id;
  String get lightSchemeId => _lightSchemeId ?? AppTheme.slateLightScheme.id;
  bool get isDarkMode => _isDarkMode ?? false;
  String get activeColorSchemeId => isDarkMode ? darkSchemeId : lightSchemeId;
  AppColorScheme get activeColorScheme =>
      AppTheme.schemeById(activeColorSchemeId);
  String get content => textController.text;
  String get previewMarkdown => _previewMarkdown;
  bool get isSpellCheckEnabled => spellCheckService.isEnabled;
  String get spellCheckLanguage => spellCheckService.languageTag;
  Set<String> get customDictionaryWords => spellCheckService.customWords;
  List<SpellErrorRange> get spellErrors => textController.spellErrors;

  EditorController({
    FileService? fileService,
    HistoryService? historyService,
    BibliographyService? bibliographyService,
    PandocService? pandocService,
    ZoteroService? zoteroService,
    DirectExportService? directExportService,
    MarkdownRenderService? renderService,
    SpellCheckService? spellCheckService,
    Duration? renderDebounceDuration,
  }) : fileService = fileService ?? FileService(),
       historyService = historyService ?? HistoryService(),
       bibliographyService = bibliographyService ?? BibliographyService(),
       pandocService = pandocService ?? PandocService(),
       zoteroService = zoteroService ?? ZoteroService(),
       directExportService = directExportService ?? DirectExportService(),
       _renderService = renderService ?? MarkdownRenderService(),
       spellCheckService = spellCheckService ?? SpellCheckService(),
       _customRenderDebounce = renderDebounceDuration {
    textController.spellCheckService = this.spellCheckService;
    _lastObservedText = textController.text;
    textController.addListener(_onTextChanged);
    _openDocuments.add(
      OpenDocument(
        id: 'untitled_${++_nextUntitledId}',
        fileName: _currentFileName,
        content: textController.text,
      ),
    );
    _activeDocumentIndex = 0;
  }

  /// Initialise controller, check Pandoc & Zotero, load history and preferences
  Future<void> initialise() async {
    await Future.wait([historyService.loadHistory(), _loadPreferences()]);
    await Future.wait([checkPandocAvailability(), checkZoteroConnection()]);

    // Check if there is an active history entry or load welcome document
    if (history.isNotEmpty && File(history.first.path).existsSync()) {
      await openFile(history.first.path);
    } else {
      _loadWelcomeDocument();
    }

    startFileWatching();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await _getPrefs();
      _bibliographyPath = prefs.getString('draftdown_bibliography_path');
      final customPandoc = prefs.getString('draftdown_custom_pandoc_path');
      if (customPandoc != null && customPandoc.isNotEmpty) {
        pandocService.setCustomPath(customPandoc);
      }

      if (_bibliographyPath != null && File(_bibliographyPath!).existsSync()) {
        await loadBibliographyFile(_bibliographyPath!);
      }

      _editorFontFamily =
          prefs.getString('draftdown_editor_font') ?? 'Consolas';
      _isDualRenderFont =
          prefs.getBool('draftdown_is_dual_render_font') ?? false;
      _renderBodyFont =
          prefs.getString('draftdown_render_body_font') ?? 'Segoe UI';
      _renderHeaderFont =
          prefs.getString('draftdown_render_header_font') ?? 'Georgia';

      _darkSchemeId =
          prefs.getString('draftdown_dark_scheme') ??
          AppTheme.slateDarkScheme.id;
      _lightSchemeId =
          prefs.getString('draftdown_light_scheme') ??
          AppTheme.slateLightScheme.id;
      _isDarkMode = prefs.getBool('draftdown_dark_mode') ?? false;

      AppTheme.setActiveScheme(AppTheme.schemeById(darkSchemeId));
      AppTheme.setActiveScheme(AppTheme.schemeById(lightSchemeId));

      final savedSource = prefs.getString('draftdown_citation_source');
      if (savedSource == 'zotero') {
        _citationSource = CitationSource.zotero;
      }

      final spellEnabled = prefs.getBool('draftdown_spellcheck_enabled');
      if (spellEnabled != null) {
        spellCheckService.setEnabled(spellEnabled);
      }
      final spellLang = prefs.getString('draftdown_spellcheck_language');
      if (spellLang != null && spellLang.isNotEmpty) {
        spellCheckService.setLanguage(spellLang);
      }
      final customWords = prefs.getStringList(
        'draftdown_spellcheck_custom_words',
      );
      if (customWords != null) {
        spellCheckService.loadCustomWords(customWords);
      }
      textController.invalidateSpellCheck();
    } catch (_) {}
  }

  /// Toggles Markdown spellchecking on or off.
  Future<void> toggleSpellCheck() => setSpellCheckEnabled(!isSpellCheckEnabled);

  /// Enables or disables Markdown spellchecking and persists the preference.
  Future<void> setSpellCheckEnabled(bool enabled) async {
    spellCheckService.setEnabled(enabled);
    textController.invalidateSpellCheck();
    notifyListeners();
    try {
      final prefs = await _getPrefs();
      await prefs.setBool('draftdown_spellcheck_enabled', enabled);
    } catch (_) {}
  }

  /// Changes the active spellchecker dictionary locale (e.g. `en-GB`, `en-US`).
  Future<void> setSpellCheckLanguage(String languageTag) async {
    spellCheckService.setLanguage(languageTag);
    textController.invalidateSpellCheck();
    notifyListeners();
    try {
      final prefs = await _getPrefs();
      await prefs.setString('draftdown_spellcheck_language', languageTag);
    } catch (_) {}
  }

  /// Adds [word] to the user's persistent custom dictionary.
  Future<void> addWordToDictionary(String word) async {
    spellCheckService.addCustomWord(word);
    textController.invalidateSpellCheck();
    notifyListeners();
    try {
      final prefs = await _getPrefs();
      await prefs.setStringList(
        'draftdown_spellcheck_custom_words',
        spellCheckService.customWords.toList()..sort(),
      );
    } catch (_) {}
  }

  /// Removes [word] from the user's persistent custom dictionary.
  Future<void> removeWordFromDictionary(String word) async {
    spellCheckService.removeCustomWord(word);
    textController.invalidateSpellCheck();
    notifyListeners();
    try {
      final prefs = await _getPrefs();
      await prefs.setStringList(
        'draftdown_spellcheck_custom_words',
        spellCheckService.customWords.toList()..sort(),
      );
    } catch (_) {}
  }

  /// Ignores [word] for the current editing session.
  void ignoreSpellingWord(String word) {
    spellCheckService.ignoreWord(word);
    textController.invalidateSpellCheck();
    notifyListeners();
  }

  /// Returns spelling suggestions for [word].
  List<String> getSpellingSuggestions(String word, {int maxSuggestions = 5}) {
    return spellCheckService.suggest(word, maxSuggestions: maxSuggestions);
  }

  /// Replaces a misspelled [error] range with [replacement] in the editor.
  void replaceSpellingError(SpellErrorRange error, String replacement) {
    final text = textController.text;
    if (error.start < 0 || error.end > text.length || error.start > error.end) {
      return;
    }
    final updated = text.replaceRange(error.start, error.end, replacement);
    textController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(
        offset: error.start + replacement.length,
      ),
    );
  }

  /// Change active citation source (BibTeX file vs. Zotero)
  Future<void> setCitationSource(CitationSource source) async {
    _citationSource = source;
    notifyListeners();
    try {
      final prefs = await _getPrefs();
      await prefs.setString('draftdown_citation_source', source.name);
    } catch (_) {}
  }

  static const String _fileCitationStylesKey = 'draftdown_file_citation_styles';

  String _normalizePathKey(String path) =>
      Platform.isWindows ? path.toLowerCase() : path;

  Future<Map<String, String>> _readFileCitationStylesMap() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_fileCitationStylesKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  Future<CitationStyle> _loadFileCitationStyle(String path) async {
    final map = await _readFileCitationStylesMap();
    final saved = map[_normalizePathKey(path)];
    if (saved == CitationStyle.numeric.name) {
      return CitationStyle.numeric;
    }
    return CitationStyle.authorYear;
  }

  Future<void> _saveFileCitationStyle(String path, CitationStyle style) async {
    try {
      final prefs = await _getPrefs();
      final map = await _readFileCitationStylesMap();
      map[_normalizePathKey(path)] = style.name;
      await prefs.setString(_fileCitationStylesKey, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _removeFileCitationStyle(String path) async {
    try {
      final prefs = await _getPrefs();
      final map = await _readFileCitationStylesMap();
      if (map.remove(_normalizePathKey(path)) != null) {
        await prefs.setString(_fileCitationStylesKey, jsonEncode(map));
      }
    } catch (_) {}
  }

  /// Change active document citation style (Author-Year vs Numeric)
  Future<void> setCitationStyle(CitationStyle style) async {
    if (_citationStyle == style) return;
    _citationStyle = style;
    activeDocument?.citationStyle = style;
    flushPendingRenderUpdate();
    notifyListeners();
    final path = _currentFilePath;
    if (path != null) {
      await _saveFileCitationStyle(path, style);
    }
  }

  /// Update editor and render typography settings
  Future<void> updateTypography({
    String? editorFontFamily,
    bool? isDualRenderFont,
    String? renderBodyFont,
    String? renderHeaderFont,
  }) async {
    if (editorFontFamily != null) _editorFontFamily = editorFontFamily;
    if (isDualRenderFont != null) _isDualRenderFont = isDualRenderFont;
    if (renderBodyFont != null) _renderBodyFont = renderBodyFont;
    if (renderHeaderFont != null) _renderHeaderFont = renderHeaderFont;

    notifyListeners();

    try {
      final prefs = await _getPrefs();
      await prefs.setString('draftdown_editor_font', _editorFontFamily);
      await prefs.setBool('draftdown_is_dual_render_font', _isDualRenderFont);
      await prefs.setString('draftdown_render_body_font', _renderBodyFont);
      await prefs.setString('draftdown_render_header_font', _renderHeaderFont);
    } catch (_) {}
  }

  /// Synchronises initial dark mode state without firing redundant writes.
  void syncDarkMode(bool isDark) {
    _isDarkMode = isDark;
    AppTheme.setActiveScheme(AppTheme.schemeById(darkSchemeId));
    AppTheme.setActiveScheme(AppTheme.schemeById(lightSchemeId));
  }

  /// Toggles between the active Light and Dark colour schemes.
  Future<void> toggleDarkMode() async {
    _isDarkMode = !isDarkMode;
    AppTheme.setActiveScheme(AppTheme.schemeById(darkSchemeId));
    AppTheme.setActiveScheme(AppTheme.schemeById(lightSchemeId));
    notifyListeners();
    try {
      final prefs = await _getPrefs();
      await prefs.setBool('draftdown_dark_mode', isDarkMode);
    } catch (_) {}
  }

  /// Selects a specific colour scheme (Dark or Light) and applies its palette immediately.
  Future<void> setColorScheme(String schemeId) async {
    final scheme = AppTheme.schemeById(schemeId);
    AppTheme.setActiveScheme(scheme);
    if (scheme.isDark) {
      _darkSchemeId = scheme.id;
      _isDarkMode = true;
    } else {
      _lightSchemeId = scheme.id;
      _isDarkMode = false;
    }

    // Notify syntax controller and main app listeners so editor & preview update immediately
    textController.refreshThemeHighlighting();
    notifyListeners();

    try {
      final prefs = await _getPrefs();
      await prefs.setString('draftdown_color_scheme', scheme.id);
      await prefs.setString('draftdown_dark_scheme', darkSchemeId);
      await prefs.setString('draftdown_light_scheme', lightSchemeId);
      await prefs.setBool('draftdown_dark_mode', isDarkMode);
    } catch (_) {}
  }

  void _onTextChanged() {
    if (_isProgrammaticUpdate == true) return;

    final currentText = textController.text;
    // Ignore selection-only, focus, or composing notifications where text did not change
    if (currentText == _lastObservedText) return;
    _lastObservedText = currentText;

    _charCount = currentText.length;

    // When text is set programmatically before the editor widget is mounted,
    // synchronise metrics and preview immediately without leaving a pending timer.
    if (focusNode.context == null) {
      _isModified = true;
      _computeMetrics();
      _previewMarkdown = currentText;
      activeDocument?.isModified = true;
      activeDocument?.content = currentText;
      return;
    }

    // Decouple Markdown entry from expensive rendering on large files:
    // Wait until a 1.5-second period of typing inactivity before taking a snapshot
    // and rendering in a separate thread.
    textController.isActivelyTyping = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(renderDebounceDuration, _onDebounceTimerFired);

    if (!_isModified) {
      _isModified = true;
      activeDocument?.isModified = true;
      notifyListeners();
    }
  }

  /// Triggered after the 1.5-second debounce window has elapsed with no new typing.
  /// Takes a snapshot of the Markdown code and runs rendering in a separate thread.
  void _onDebounceTimerFired() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _lastObservedText = textController.text;

    final snapshotText = textController.text;
    final renderSeq = ++_activeRenderSequence;
    final renderEpoch = _documentEpoch;
    _isBackgroundRendering = true;

    final allCitations = [...citations, ...zoteroCitations];
    final payload = MarkdownRenderPayload(
      renderId: renderSeq,
      rawMarkdown: snapshotText,
      citations: allCitations,
      citationStyle: _citationStyle,
    );

    _renderService
        .render(payload)
        .then((result) {
          // Discard if a newer render has already completed or tab changed
          if (renderEpoch != _documentEpoch ||
              result.renderId < _completedRenderSequence) {
            return;
          }

          void applyResult() {
            if (renderEpoch == _documentEpoch &&
                result.renderId >= _completedRenderSequence) {
              _completedRenderSequence = result.renderId;
              _numericIndices = result.numericIndices;
              _astNodes = result.astNodes;
              _previewMarkdown = result.processedMarkdown;
              _wordCount = result.wordCount;
              _lineCount = result.lineCount;
              _readingTimeMinutes = result.readingTimeMinutes;
              _isBackgroundRendering = false;
              previewNotifier.value = result.processedMarkdown;
              notifyListeners();
            }
          }

          // If user typed new text while background render was running,
          // silently record cached values without interrupting active typing.
          if (_debounceTimer?.isActive == true) {
            _completedRenderSequence = result.renderId;
            _numericIndices = result.numericIndices;
            _astNodes = result.astNodes;
            _previewMarkdown = result.processedMarkdown;
            _wordCount = result.wordCount;
            _lineCount = result.lineCount;
            _readingTimeMinutes = result.readingTimeMinutes;
            _isBackgroundRendering = false;
          } else if (scrollController.hasClients &&
              scrollController.position.isScrollingNotifier.value) {
            // If user is actively scrolling the editor, defer applying until scroll gesture finishes
            void onScrollEnd() {
              if (!scrollController.position.isScrollingNotifier.value) {
                scrollController.position.isScrollingNotifier.removeListener(
                  onScrollEnd,
                );
                applyResult();
              }
            }

            scrollController.position.isScrollingNotifier.addListener(
              onScrollEnd,
            );
          } else {
            applyResult();
          }
        })
        .catchError((_) {
          if (renderSeq >= _completedRenderSequence) {
            _completedRenderSequence = renderSeq;
            _previewMarkdown = snapshotText;
            _isBackgroundRendering = false;
            previewNotifier.value = snapshotText;
            notifyListeners();
          }
        });
  }

  /// Manually or automatically flushes any pending debounced render and metrics update.
  void updateRender() {
    flushPendingRenderUpdate();
  }

  /// Flushes any pending debounced render and metrics update immediately.
  void flushPendingRenderUpdate() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _lastObservedText = textController.text;

    final snapshotText = textController.text;
    final renderSeq = ++_activeRenderSequence;
    _completedRenderSequence = renderSeq;
    _isBackgroundRendering = false;

    final allCitations = [...citations, ...zoteroCitations];
    final payload = MarkdownRenderPayload(
      renderId: renderSeq,
      rawMarkdown: snapshotText,
      citations: allCitations,
      citationStyle: _citationStyle,
    );

    final result = MarkdownRenderService.executeMarkdownRender(payload);
    _numericIndices = result.numericIndices;
    _astNodes = result.astNodes;
    _previewMarkdown = result.processedMarkdown;
    _wordCount = result.wordCount;
    _lineCount = result.lineCount;
    _readingTimeMinutes = result.readingTimeMinutes;
    previewNotifier.value = result.processedMarkdown;
    notifyListeners();
  }

  void _computeMetrics() {
    final text = textController.text;
    _charCount = text.length;

    // Single-pass high-performance word and line counter without heap allocations
    int words = 0;
    int lines = 1;
    bool inWord = false;
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code == 10) {
        lines++;
      }
      final isSpace = code <= 32;
      if (isSpace) {
        inWord = false;
      } else if (!inWord) {
        inWord = true;
        words++;
      }
    }
    _wordCount = words;
    _lineCount = lines;

    // Reading time: standard ~200 words per minute
    _readingTimeMinutes = (_wordCount / 200).ceil().clamp(1, 9999);
  }

  bool _pathsEqual(String? a, String? b) {
    if (a == null || b == null) return false;
    if (Platform.isWindows) {
      return a.toLowerCase() == b.toLowerCase();
    }
    return a == b;
  }

  void _syncActiveDocumentToStore() {
    final doc = activeDocument;
    if (doc == null) return;
    doc.filePath = _currentFilePath;
    doc.fileName = _currentFileName;
    doc.content = textController.text;
    doc.selection = textController.selection;
    doc.scrollOffset = scrollController.hasClients
        ? scrollController.offset
        : 0.0;
    doc.isModified = _isModified;
    doc.hasConflict = _hasConflict;
    doc.hasPromptedConflict = _hasPromptedConflict;
    doc.previewMarkdown = _previewMarkdown;
    doc.numericIndices = _numericIndices;
    doc.astNodes = _astNodes;
    doc.wordCount = _wordCount;
    doc.charCount = _charCount;
    doc.lineCount = _lineCount;
    doc.readingTimeMinutes = _readingTimeMinutes;
    doc.citationStyle = _citationStyle;
  }

  void _loadDocumentFromStore(int index) {
    _activeDocumentIndex = index;
    final doc = _openDocuments[index];
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _documentEpoch++;
    _isBackgroundRendering = false;

    _currentFilePath = doc.filePath;
    _currentFileName = doc.fileName;
    _isProgrammaticUpdate = true;
    textController.isActivelyTyping = false;
    final safeBase = doc.selection.baseOffset.clamp(0, doc.content.length);
    final safeExtent = doc.selection.extentOffset.clamp(0, doc.content.length);
    textController.value = TextEditingValue(
      text: doc.content,
      selection: TextSelection(baseOffset: safeBase, extentOffset: safeExtent),
    );
    _isProgrammaticUpdate = false;
    _lastObservedText = doc.content;
    _previewMarkdown = doc.previewMarkdown;
    _numericIndices = doc.numericIndices;
    _astNodes = doc.astNodes;
    _wordCount = doc.wordCount;
    _charCount = doc.charCount;
    _lineCount = doc.lineCount;
    _readingTimeMinutes = doc.readingTimeMinutes;
    _citationStyle = doc.citationStyle;
    _isModified = doc.isModified;
    _hasConflict = doc.hasConflict;
    _hasPromptedConflict = doc.hasPromptedConflict;
    previewNotifier.value = doc.previewMarkdown;
    textController.invalidateSpellCheck();

    if (scrollController.hasClients) {
      final maxExtent = scrollController.position.maxScrollExtent;
      scrollController.jumpTo(doc.scrollOffset.clamp(0.0, maxExtent));
    }
  }

  /// Switch to an already-open document tab by its [index].
  void switchToDocument(int index) {
    if (index < 0 || index >= _openDocuments.length) return;
    if (index == _activeDocumentIndex) return;

    if (_debounceTimer?.isActive ?? false) {
      flushPendingRenderUpdate();
    }
    _syncActiveDocumentToStore();
    _loadDocumentFromStore(index);
    notifyListeners();
  }

  /// Switch to an already-open document tab by its [id].
  void switchToDocumentById(String id) {
    final index = _openDocuments.indexWhere((d) => d.id == id);
    if (index != -1) {
      switchToDocument(index);
    }
  }

  /// Close an open document tab by its [id].
  /// If it is the last open tab, replaces it with a fresh blank document.
  void closeDocument(String id) {
    final index = _openDocuments.indexWhere((d) => d.id == id);
    if (index == -1) return;

    if (_openDocuments.length == 1) {
      _openDocuments.clear();
      _activeDocumentIndex = -1;
      newFile();
      _syncDirectoryWatchers();
      return;
    }

    if (index == _activeDocumentIndex) {
      _openDocuments.removeAt(index);
      final nextIndex = index >= _openDocuments.length
          ? _openDocuments.length - 1
          : index;
      _loadDocumentFromStore(nextIndex);
    } else {
      _openDocuments.removeAt(index);
      if (index < _activeDocumentIndex) {
        _activeDocumentIndex--;
      }
    }
    _syncDirectoryWatchers();
    notifyListeners();
  }

  /// Create a new blank Markdown document tab
  void newFile() {
    if (_debounceTimer?.isActive ?? false) {
      flushPendingRenderUpdate();
    }
    _syncActiveDocumentToStore();

    _debounceTimer?.cancel();
    _debounceTimer = null;
    _documentEpoch++;
    _currentFilePath = null;
    _currentFileName = 'Untitled.md';
    _isProgrammaticUpdate = true;
    textController.isActivelyTyping = false;
    textController.clear();
    _isProgrammaticUpdate = false;
    _lastObservedText = '';
    _previewMarkdown = '';
    _numericIndices = const {};
    _astNodes = null;
    _isBackgroundRendering = false;
    previewNotifier.value = '';
    _computeMetrics();
    _isModified = false;
    _hasConflict = false;
    _hasPromptedConflict = false;
    _citationStyle = CitationStyle.authorYear;
    if (scrollController.hasClients) {
      scrollController.jumpTo(0.0);
    }

    final doc = OpenDocument(
      id: 'untitled_${++_nextUntitledId}',
      fileName: _currentFileName,
      content: '',
      wordCount: _wordCount,
      charCount: _charCount,
      lineCount: _lineCount,
      readingTimeMinutes: _readingTimeMinutes,
      citationStyle: _citationStyle,
    );
    _openDocuments.add(doc);
    _activeDocumentIndex = _openDocuments.length - 1;
    notifyListeners();
  }

  /// Open a Markdown document from disk (or switch to its existing tab if already open)
  Future<bool> openFile([String? targetPath]) async {
    final path = targetPath ?? await fileService.pickMarkdownFile();

    if (path == null) return false;

    final existingIndex = _openDocuments.indexWhere(
      (d) => _pathsEqual(d.filePath, path),
    );
    if (existingIndex != -1) {
      switchToDocument(existingIndex);
      return true;
    }

    try {
      final content = await fileService.readFile(path);
      final stat = await fileService.statFile(path);
      final fileCitationStyle = await _loadFileCitationStyle(path);

      if (_debounceTimer?.isActive ?? false) {
        flushPendingRenderUpdate();
      }
      _syncActiveDocumentToStore();

      // Replace a single untouched blank Untitled.md tab on initial open
      if (_openDocuments.length == 1 &&
          _openDocuments[0].filePath == null &&
          !_openDocuments[0].isModified &&
          _openDocuments[0].content.isEmpty) {
        _openDocuments.clear();
        _activeDocumentIndex = -1;
      }

      _debounceTimer?.cancel();
      _debounceTimer = null;
      _documentEpoch++;
      _currentFilePath = path;
      _currentFileName = File(path).uri.pathSegments
          .lastWhere((s) => s.isNotEmpty);
      _isProgrammaticUpdate = true;
      textController.isActivelyTyping = false;
      textController.text = content;
      _isProgrammaticUpdate = false;
      _lastObservedText = content;
      _computeMetrics();
      _isModified = false;
      _hasConflict = false;
      _hasPromptedConflict = false;
      _citationStyle = fileCitationStyle;

      final doc = OpenDocument(
        id: path,
        filePath: path,
        fileName: _currentFileName,
        content: content,
        isModified: false,
        hasConflict: false,
        hasPromptedConflict: false,
        lastKnownDiskContent: content,
        lastDiskModified: stat?.modified,
        lastDiskSize: stat?.size,
        wordCount: _wordCount,
        charCount: _charCount,
        lineCount: _lineCount,
        readingTimeMinutes: _readingTimeMinutes,
        citationStyle: _citationStyle,
      );
      _openDocuments.add(doc);
      _activeDocumentIndex = _openDocuments.length - 1;

      // Add to history
      await historyService.recordFileOpen(path);

      // Auto-detect adjacent bibliography if present in the same directory
      _autoDetectAdjacentBibliography(File(path).parent.path);

      flushPendingRenderUpdate();
      _syncActiveDocumentToStore();
      _syncDirectoryWatchers();

      if (scrollController.hasClients) {
        scrollController.jumpTo(0.0);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[EditorController] Error opening file: $e');
      return false;
    }
  }

  /// If a .bib or references.bib exists in the directory of the opened file, auto-load it
  Future<void> _autoDetectAdjacentBibliography(String directoryPath) async {
    if (_bibliographyPath != null && File(_bibliographyPath!).existsSync()) {
      return; // Already configured
    }

    try {
      final dir = Directory(directoryPath);
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          final lower = entity.path.toLowerCase();
          if (lower.endsWith('.bib')) {
            await loadBibliographyFile(entity.path);
            break;
          }
        }
      }
    } catch (_) {}
  }

  /// Save the current document
  Future<bool> saveFile() async {
    if (_currentFilePath == null) {
      return await saveFileAs();
    }

    try {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      textController.reconcileFullHighlight();
      _computeMetrics();
      _previewMarkdown = textController.text;
      await fileService.writeFile(_currentFilePath!, textController.text);
      final stat = await fileService.statFile(_currentFilePath!);
      _isModified = false;
      _hasConflict = false;
      _hasPromptedConflict = false;
      activeDocument?.lastKnownDiskContent = textController.text;
      activeDocument?.lastDiskModified = stat?.modified;
      activeDocument?.lastDiskSize = stat?.size;
      _syncActiveDocumentToStore();
      _syncDirectoryWatchers();
      await historyService.recordFileOpen(_currentFilePath!);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[EditorController] Error saving file: $e');
      return false;
    }
  }

  /// Save current document to a chosen destination
  Future<bool> saveFileAs() async {
    final destination = await fileService.pickSaveMarkdownLocation(
      defaultName: _currentFileName,
    );

    if (destination == null) return false;

    try {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      textController.reconcileFullHighlight();
      _computeMetrics();
      _previewMarkdown = textController.text;
      await fileService.writeFile(destination, textController.text);
      final stat = await fileService.statFile(destination);
      _currentFilePath = destination;
      _currentFileName = File(destination).uri.pathSegments
          .lastWhere((s) => s.isNotEmpty);
      _isModified = false;
      _hasConflict = false;
      _hasPromptedConflict = false;
      // Remove any other open tab that already pointed to this destination
      for (int i = _openDocuments.length - 1; i >= 0; i--) {
        if (i != _activeDocumentIndex &&
            _pathsEqual(_openDocuments[i].filePath, destination)) {
          _openDocuments.removeAt(i);
          if (i < _activeDocumentIndex) {
            _activeDocumentIndex--;
          }
        }
      }
      activeDocument?.id = destination;
      activeDocument?.lastKnownDiskContent = textController.text;
      activeDocument?.lastDiskModified = stat?.modified;
      activeDocument?.lastDiskSize = stat?.size;
      _syncActiveDocumentToStore();
      _syncDirectoryWatchers();
      await _saveFileCitationStyle(destination, _citationStyle);
      await historyService.recordFileOpen(destination);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[EditorController] Error saving file as: $e');
      return false;
    }
  }

  /// Close current document
  void closeFile() {
    final doc = activeDocument;
    if (doc != null) {
      closeDocument(doc.id);
    } else {
      newFile();
    }
  }

  /// Split a file name into its editable stem and fixed extension (`.md`).
  static ({String stem, String extension}) splitFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.md') && fileName.length > 3) {
      return (
        stem: fileName.substring(0, fileName.length - 3),
        extension: fileName.substring(fileName.length - 3),
      );
    }
    if (lower.endsWith('.markdown') && fileName.length > 9) {
      return (
        stem: fileName.substring(0, fileName.length - 9),
        extension: fileName.substring(fileName.length - 9),
      );
    }
    return (stem: fileName, extension: '.md');
  }

  /// Rename the current document's file name without changing its extension.
  /// Returns `null` on success, or an error message if renaming failed.
  Future<String?> renameCurrentFile(String newStem) async {
    final trimmedStem = newStem.trim();
    if (trimmedStem.isEmpty) {
      return 'File name cannot be empty.';
    }

    final sanitizedStem = trimmedStem
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .trim();
    if (sanitizedStem.isEmpty) {
      return 'File name contains only invalid characters.';
    }

    final parts = splitFileName(_currentFileName);
    final newFileName = '$sanitizedStem${parts.extension}';
    if (newFileName == _currentFileName) {
      return null;
    }

    if (_currentFilePath == null) {
      _currentFileName = newFileName;
      activeDocument?.fileName = newFileName;
      notifyListeners();
      return null;
    }

    try {
      final oldPath = _currentFilePath!;
      final oldFile = File(oldPath);
      final newPath =
          '${oldFile.parent.path}${Platform.pathSeparator}$newFileName';

      final isCaseOnlyRename = oldPath.toLowerCase() == newPath.toLowerCase();
      if (!isCaseOnlyRename && File(newPath).existsSync()) {
        return 'A file named "$newFileName" already exists.';
      }

      if (oldFile.existsSync()) {
        await oldFile.rename(newPath);
      }

      final stat = await fileService.statFile(newPath);
      _currentFilePath = newPath;
      _currentFileName = newFileName;
      activeDocument?.id = newPath;
      activeDocument?.filePath = newPath;
      activeDocument?.fileName = newFileName;
      activeDocument?.lastDiskModified = stat?.modified;
      activeDocument?.lastDiskSize = stat?.size;
      await _removeFileCitationStyle(oldPath);
      await _saveFileCitationStyle(newPath, _citationStyle);
      await historyService.removeEntry(oldPath);
      await historyService.recordFileOpen(newPath);
      _syncDirectoryWatchers();
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[EditorController] Error renaming file: $e');
      return 'Failed to rename file: $e';
    }
  }

  /// Toggle sidebar visibility
  void toggleSidebar() {
    _isSidebarOpen = !_isSidebarOpen;
    notifyListeners();
  }

  /// Switch editor view mode (edit, split, preview)
  void setViewMode(EditorViewMode mode) {
    _viewMode = mode;
    if (mode != EditorViewMode.edit) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      textController.reconcileFullHighlight();
      _computeMetrics();
      _previewMarkdown = textController.text;
    }
    notifyListeners();
  }

  /// Insert text at current cursor position
  void insertText(String textToInsert, {bool flushImmediately = false}) {
    final currentText = textController.text;
    final selection = textController.selection;

    final start = selection.isValid ? selection.start : currentText.length;
    final end = selection.isValid ? selection.end : currentText.length;

    final newText = currentText.replaceRange(start, end, textToInsert);
    if (flushImmediately) {
      _isProgrammaticUpdate = true;
    }
    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + textToInsert.length),
    );
    if (focusNode.canRequestFocus) {
      focusNode.requestFocus();
    }
    if (flushImmediately) {
      _isProgrammaticUpdate = false;
      _isModified = true;
      flushPendingRenderUpdate();
    }
  }

  /// Indent at the cursor by [spaces] spaces, or indent all lines in the
  /// current selection by [spaces] spaces when a block of text is highlighted.
  void indentSelection({int spaces = 2}) {
    final indent = ' ' * spaces;
    final currentText = textController.text;
    final selection = textController.selection;

    if (!selection.isValid) {
      insertText(indent);
      return;
    }

    if (selection.isCollapsed) {
      final offset = selection.start;
      final newText = currentText.replaceRange(offset, offset, indent);
      textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + spaces),
      );
      return;
    }

    final selStart = selection.start;
    final selEnd = selection.end;
    final isReversed = selection.baseOffset > selection.extentOffset;

    final lineStart = selStart == 0
        ? 0
        : currentText.lastIndexOf('\n', selStart - 1) + 1;
    final effectiveEnd = (selEnd > lineStart && currentText[selEnd - 1] == '\n')
        ? selEnd - 1
        : selEnd;
    final nextNewline = currentText.indexOf('\n', effectiveEnd);
    final blockEnd = nextNewline == -1 ? currentText.length : nextNewline;

    final lines = currentText.substring(lineStart, blockEnd).split('\n');
    final indentedBlock = lines.map((line) => '$indent$line').join('\n');
    final newText = currentText.replaceRange(
      lineStart,
      blockEnd,
      indentedBlock,
    );

    final newStart = selStart + spaces;
    final newEnd = selEnd + (lines.length * spaces);
    textController.value = TextEditingValue(
      text: newText,
      selection: isReversed
          ? TextSelection(baseOffset: newEnd, extentOffset: newStart)
          : TextSelection(baseOffset: newStart, extentOffset: newEnd),
    );
  }

  /// Outdent (unindent) the current line or all lines in the selection by up to
  /// [spaces] leading spaces.
  void outdentSelection({int spaces = 2}) {
    final currentText = textController.text;
    final selection = textController.selection;
    if (!selection.isValid) return;

    final selStart = selection.start;
    final selEnd = selection.end;
    final isReversed = selection.baseOffset > selection.extentOffset;

    final lineStart = selStart == 0
        ? 0
        : currentText.lastIndexOf('\n', selStart - 1) + 1;
    final effectiveEnd =
        (!selection.isCollapsed &&
            selEnd > lineStart &&
            currentText[selEnd - 1] == '\n')
        ? selEnd - 1
        : selEnd;
    final nextNewline = currentText.indexOf('\n', effectiveEnd);
    final blockEnd = nextNewline == -1 ? currentText.length : nextNewline;

    final lines = currentText.substring(lineStart, blockEnd).split('\n');
    int firstLineRemoved = 0;
    int totalRemoved = 0;
    final outdentedLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      int removed = 0;
      if (line.startsWith('\t')) {
        removed = 1;
      } else {
        while (removed < spaces &&
            removed < line.length &&
            line[removed] == ' ') {
          removed++;
        }
      }
      if (i == 0) {
        firstLineRemoved = removed;
      }
      totalRemoved += removed;
      outdentedLines.add(line.substring(removed));
    }

    if (totalRemoved == 0) return;

    final outdentedBlock = outdentedLines.join('\n');
    final newText = currentText.replaceRange(
      lineStart,
      blockEnd,
      outdentedBlock,
    );

    final newStart = (selStart - firstLineRemoved).clamp(
      lineStart,
      newText.length,
    );
    final newEnd = (selEnd - totalRemoved).clamp(newStart, newText.length);
    textController.value = TextEditingValue(
      text: newText,
      selection: selection.isCollapsed
          ? TextSelection.collapsed(offset: newStart)
          : (isReversed
                ? TextSelection(baseOffset: newEnd, extentOffset: newStart)
                : TextSelection(baseOffset: newStart, extentOffset: newEnd)),
    );
  }

  /// Format currently selected text with markdown prefix and optional suffix
  void formatSelection(String prefix, [String? suffix]) {
    final post = suffix ?? (prefix.endsWith(' ') ? '' : prefix);
    final currentText = textController.text;
    final selection = textController.selection;

    final start = selection.isValid ? selection.start : currentText.length;
    final end = selection.isValid ? selection.end : currentText.length;

    if (!selection.isValid || selection.isCollapsed) {
      // Nothing selected: insert template and align typing cursor at entrypoint
      final template = '$prefix$post';
      final newText = currentText.replaceRange(start, end, template);
      textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + prefix.length),
      );
      if (focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
      return;
    }

    final selectedText = currentText.substring(start, end);
    final formatted = '$prefix$selectedText$post';
    final newText = currentText.replaceRange(start, end, formatted);

    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + selectedText.length,
      ),
    );
    if (focusNode.canRequestFocus) {
      focusNode.requestFocus();
    }
  }

  /// Regex to identify GFM task list items (e.g. "- [ ]", "* [x]", "1. [ ]")
  static final RegExp _taskCheckboxRegex = RegExp(
    r'^[ \t]*(?:>+[ \t]*)*(?:[-*+]|\d+[.)])[ \t]+\[([ xX])\](?=[ \t]|$)',
    multiLine: true,
  );

  /// Fenced code blocks to ignore when scanning for task list checkboxes
  static final RegExp _fencedCodeBlockRegex = RegExp(
    r'(```+|~~~+)[\s\S]*?(?:\1|$)',
  );

  /// Scans markdown text and returns all task list checkboxes in document order.
  static List<MarkdownCheckboxInfo> findTaskCheckboxes(String text) {
    if (!text.contains('[')) return const [];

    final codeRanges = <(int, int)>[];
    for (final cm in _fencedCodeBlockRegex.allMatches(text)) {
      codeRanges.add((cm.start, cm.end));
    }

    final result = <MarkdownCheckboxInfo>[];
    for (final m in _taskCheckboxRegex.allMatches(text)) {
      final isInsideCode = codeRanges.any(
        (range) => m.start >= range.$1 && m.start < range.$2,
      );
      if (isInsideCode) continue;

      final fullMatch = m.group(0)!;
      final bracketOffset = fullMatch.lastIndexOf('[');
      if (bracketOffset == -1 || bracketOffset + 2 >= fullMatch.length) {
        continue;
      }
      if (fullMatch[bracketOffset] != '[' ||
          fullMatch[bracketOffset + 2] != ']') {
        continue;
      }

      final charOffset = m.start + bracketOffset + 1;
      if (charOffset >= text.length) continue;

      final char = text[charOffset];
      final isChecked = char == 'x' || char == 'X';

      result.add(
        MarkdownCheckboxInfo(charOffset: charOffset, isChecked: isChecked),
      );
    }

    return result;
  }

  /// Toggles the task list checkbox at [index] (0-based document order).
  ///
  /// Swaps '[ ]' to '[x]' or '[x]'/'[X]' to '[ ]', synchronises the editor text
  /// controller, and immediately updates the preview.
  bool toggleCheckbox(int index) {
    final currentText = textController.text;
    final checkboxes = findTaskCheckboxes(currentText);
    if (index < 0 || index >= checkboxes.length) return false;

    final target = checkboxes[index];
    final newChar = target.isChecked ? ' ' : 'x';

    final newText = currentText.replaceRange(
      target.charOffset,
      target.charOffset + 1,
      newChar,
    );

    _debounceTimer?.cancel();
    _debounceTimer = null;

    _isProgrammaticUpdate = true;
    textController.value = TextEditingValue(
      text: newText,
      selection: textController.selection,
    );
    _isProgrammaticUpdate = false;
    _lastObservedText = newText;
    _isModified = true;
    _computeMetrics();
    flushPendingRenderUpdate();
    return true;
  }

  /// Insert citation item formatted for Pandoc
  void insertCitation(
    CitationItem item, {
    bool inText = false,
    bool suppressAuthor = false,
    String? locator,
  }) {
    final citationStr = item.toPandocCitation(
      inText: inText,
      suppressAuthor: suppressAuthor,
      locator: locator,
    );
    insertText(citationStr, flushImmediately: true);
  }

  /// Insert one or more citation items formatted for Pandoc
  void insertCitations(
    List<CitationItem> items, {
    bool inText = false,
    bool suppressAuthor = false,
    String? locator,
  }) {
    if (items.isEmpty) return;
    if (items.length == 1) {
      insertCitation(
        items.first,
        inText: inText,
        suppressAuthor: suppressAuthor,
        locator: locator,
      );
      return;
    }
    final citationStr = CitationItem.formatMultiple(
      items,
      inText: inText,
      suppressAuthor: suppressAuthor,
      locator: locator,
    );
    insertText(citationStr, flushImmediately: true);
  }

  /// Detect whether the editor cursor is currently situated within a citation string.
  DetectedCitation? getCitationAtCursor([int? cursorOffset]) {
    final offset =
        cursorOffset ??
        (textController.selection.isValid
            ? textController.selection.baseOffset
            : -1);
    if (offset < 0) return null;
    return DetectedCitation.findAt(textController.text, offset);
  }

  /// Replace an existing citation range with updated citation text formatted for Pandoc
  void replaceCitation(DetectedCitation existing, String newCitationText) {
    final currentText = textController.text;
    final start = existing.startOffset.clamp(0, currentText.length);
    final end = existing.endOffset.clamp(start, currentText.length);

    final newText = currentText.replaceRange(start, end, newCitationText);
    _isProgrammaticUpdate = true;
    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + newCitationText.length,
      ),
    );
    _isProgrammaticUpdate = false;
    _isModified = true;
    flushPendingRenderUpdate();
  }

  /// Load a chosen bibliography file (.bib / .json)
  Future<bool> loadBibliographyFile(String filePath) async {
    try {
      final items = await bibliographyService.loadFromFile(filePath);
      _bibliographyPath = filePath;
      _bibliographyStatus =
          'Loaded ${items.length} references from ${File(filePath).uri.pathSegments.last}';

      final prefs = await _getPrefs();
      await prefs.setString('draftdown_bibliography_path', filePath);

      notifyListeners();
      return true;
    } catch (e) {
      _bibliographyStatus = 'Failed to load bibliography: $e';
      notifyListeners();
      return false;
    }
  }

  /// Check Pandoc availability and fetch version
  Future<void> checkPandocAvailability() async {
    _isPandocAvailable = await pandocService.isAvailable();
    if (_isPandocAvailable) {
      final baseVersion = await pandocService.getVersion();
      final tag = pandocService.isBundled ? ' (Bundled)' : '';
      _pandocVersion = '${baseVersion ?? "Pandoc"}$tag';
    } else {
      _pandocVersion = null;
    }
    notifyListeners();
  }

  /// Check if Zotero Better BibTeX is running
  Future<void> checkZoteroConnection({bool forceRefresh = false}) async {
    _isZoteroConnected = await zoteroService.isBbtRunning(
      forceRefresh: forceRefresh,
    );
    if (_isZoteroConnected) {
      _bibliographyStatus = 'Connected to Zotero (Better BibTeX)';
    }
    notifyListeners();
  }

  /// Prepares a consolidated bibliography file containing all cited references
  /// (merging active Zotero items, in-memory bibliography entries, and any user .bib file).
  ///
  /// Returns a temporary [File] containing the consolidated BibTeX if citations were found
  /// or a user bibliography was specified, or null if no bibliography is needed.
  Future<File?> prepareExportBibliography({
    required String markdownText,
    String? userBibliographyPath,
  }) async {
    final citedKeys = CitationItem.extractCitedKeys(markdownText);

    // If there are no citations in the document and no user bibliography is specified,
    // citeproc does not require a bibliography file.
    final hasUserBib =
        userBibliographyPath != null &&
        userBibliographyPath.trim().isNotEmpty &&
        await File(userBibliographyPath.trim()).exists();

    if (citedKeys.isEmpty && !hasUserBib) {
      return null;
    }

    final buffer = StringBuffer();
    final includedKeys = <String>{};

    // 1. If the user loaded or specified a bibliography file, prepend its contents
    if (hasUserBib) {
      try {
        final userContent = await File(userBibliographyPath.trim())
            .readAsString();
        buffer.writeln(userContent);
        buffer.writeln();

        // Extract citekeys already present in the user bibliography
        for (final m in _bibEntryKeyRegex.allMatches(userContent)) {
          final k = m.group(2)?.trim().toLowerCase();
          if (k != null && k.isNotEmpty) {
            includedKeys.add(k);
          }
        }
      } catch (e) {
        debugPrint(
          '[EditorController] Warning: Could not read user bibliography: $e',
        );
      }
    }

    // 2. For every cited key, check if it's already included. If not, resolve it.
    for (final key in citedKeys) {
      final cleanKey = key.trim().replaceAll('@', '').toLowerCase();
      if (includedKeys.contains(cleanKey)) {
        continue;
      }

      // Check Zotero service (cached items or live BBT)
      CitationItem? resolved = await zoteroService.resolveItem(cleanKey);

      // Check Bibliography service if not found in Zotero
      resolved ??= bibliographyService.findByKey(cleanKey);

      if (resolved != null) {
        buffer.writeln(resolved.toBibtex());
        buffer.writeln();
        includedKeys.add(cleanKey);
      } else {
        // Fallback: create a placeholder @misc entry so citeproc can resolve it
        buffer.writeln('@misc{$cleanKey,');
        buffer.writeln('  title = {$cleanKey}');
        buffer.writeln('}');
        buffer.writeln();
        includedKeys.add(cleanKey);
      }
    }

    // If no entries were added, return null
    final bibString = buffer.toString().trim();
    if (bibString.isEmpty) {
      return null;
    }

    return await fileService.createTemporaryFile(
      bibString,
      prefix: 'draftdown_bib_',
      extension: 'bib',
    );
  }

  /// Execute document export (direct high-fidelity export for HTML and PDF, Pandoc for other formats)
  Future<PandocResult> exportDocument(ExportOptions options) async {
    // 1. Direct preview-faithful HTML export
    if (options.format.type == ExportFormatType.html5) {
      return await directExportService.exportHtml(
        markdown: textController.text,
        targetPath: options.targetPath,
        controller: this,
        title: _currentFileName.replaceAll('.md', ''),
        pageSize: options.pageSize,
      );
    }

    // 2. Direct preview-faithful PDF export via system headless browser engine
    if (options.format.type == ExportFormatType.pdf) {
      return await directExportService.exportPdf(
        markdown: textController.text,
        targetPath: options.targetPath,
        controller: this,
        title: _currentFileName.replaceAll('.md', ''),
        pageSize: options.pageSize,
        marginSize: options.marginSize,
      );
    }

    // 3. Pandoc export for Word (.docx), LaTeX, EPUB, ODT, RTF
    String sourcePath = _currentFilePath ?? '';
    File? tempSourceFile;
    File? tempBibFile;

    try {
      if (_currentFilePath == null || _isModified) {
        tempSourceFile = await fileService.createTemporaryFile(
          textController.text,
        );
        sourcePath = tempSourceFile.path;
      }

      ExportOptions effectiveOptions = options;

      // Automatically consolidate cited references if citeproc is enabled
      if (options.useCiteproc) {
        final userBibPath = options.bibliographyPath ?? _bibliographyPath;
        tempBibFile = await prepareExportBibliography(
          markdownText: textController.text,
          userBibliographyPath: userBibPath,
        );
        if (tempBibFile != null) {
          effectiveOptions = options.copyWith(
            bibliographyPath: tempBibFile.path,
          );
        }
      }

      final result = await pandocService.exportDocument(
        sourceMarkdownPath: sourcePath,
        options: effectiveOptions,
        workingDirectory: _currentFilePath != null
            ? File(_currentFilePath!).parent.path
            : null,
      );

      return result;
    } finally {
      // Clean up temporary files
      if (tempSourceFile != null && await tempSourceFile.exists()) {
        try {
          await tempSourceFile.delete();
        } catch (_) {}
      }
      if (tempBibFile != null && await tempBibFile.exists()) {
        try {
          await tempBibFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Fallback HTML export matching preview styling
  Future<PandocResult> fallbackExportHtml(String targetPath) async {
    return await directExportService.exportHtml(
      markdown: textController.text,
      targetPath: targetPath,
      controller: this,
      title: _currentFileName.replaceAll('.md', ''),
    );
  }

  /// Welcome sample document shown on first run
  void _loadWelcomeDocument() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _currentFilePath = null;
    _currentFileName = 'Welcome.md';
    _isProgrammaticUpdate = true;
    textController.isActivelyTyping = false;
    textController.text = '''# Welcome to Draftdown

A minimalist, high-productivity Markdown editor with native academic citations and Pandoc document export.

## Key Features

1. **Academic Citations**:
   - Seamlessly insert citations formatted for Pandoc, such as [@holling1973resilience] or in-text citations like @hutchinson1957concluding.
   - Press **Ctrl+Shift+C** or click the **@** icon to search and insert citations.
   - Integrated with **Zotero** (via Better BibTeX) and local `.bib` or `.json` bibliography files.

2. **Multi-Format Pandoc Export**:
   - Convert your document into **PDF**, **Microsoft Word (.docx)**, **HTML 5**, **LaTeX**, **EPUB**, **ODT**, or **RTF**.
   - Automatic `--citeproc` bibliography compilation.
   - Click the **Export** button in the header toolbar to begin.

3. **Collapsible Navigation & File History**:
   - Toggle the left navigation panel using **Ctrl+\\** or the menu icon.
   - The top card displays the active document and its directory path in light text.
   - The **File History** lists previously opened files for instant access.

## Writing Sample

Food web complexity and species diversity, as demonstrated by @paine1966food, shape how communities respond to environmental change. Foundational models of island biogeography [@macarthur1967theory] and long-term restoration of ecosystem complexity [@moreno-mateosLongtermRestorationEcosystem2020] highlight the importance of habitat connectivity and ecological resilience.

### Formatted Table Example

| Format | Pandoc Writer | Supported Citations |
| :--- | :--- | :--- |
| PDF | `pdf` / `xelatex` | Yes (`--citeproc`) |
| Word | `docx` | Yes (`--citeproc`) |
| HTML | `html5` | Yes (`--citeproc`) |
| LaTeX | `latex` | Native or BibLaTeX |

Try writing your thoughts, inserting literature references, and exporting to Word or PDF!
''';
    _isProgrammaticUpdate = false;
    _lastObservedText = textController.text;
    _previewMarkdown = textController.text;
    _computeMetrics();
    _isModified = false;
    _hasConflict = false;
    _hasPromptedConflict = false;
    _syncActiveDocumentToStore();
    notifyListeners();
  }

  /// Start event-driven directory watching for open disk-backed files.
  void startFileWatching() {
    if (_isWatchingFiles) return;
    _isWatchingFiles = true;
    _syncDirectoryWatchers();
  }

  /// Stop all directory watchers and cancel any pending debounce timers.
  void stopFileWatching() {
    _isWatchingFiles = false;
    for (final sub in _directoryWatchers.values) {
      sub.cancel();
    }
    _directoryWatchers.clear();
    for (final timer in _fileChangeDebounceTimers.values) {
      timer.cancel();
    }
    _fileChangeDebounceTimers.clear();
  }

  void _syncDirectoryWatchers() {
    if (!_isWatchingFiles) return;

    final neededDirs = <String, String>{};
    for (final doc in _openDocuments) {
      final path = doc.filePath;
      if (path == null) continue;
      final dirPath = File(path).parent.path;
      neededDirs[_normalizePathKey(dirPath)] = dirPath;
    }

    // Remove watchers for directories that no longer have open files
    final staleKeys = _directoryWatchers.keys
        .where((key) => !neededDirs.containsKey(key))
        .toList();
    for (final key in staleKeys) {
      _directoryWatchers.remove(key)?.cancel();
    }

    // Add watchers for newly opened directories
    for (final entry in neededDirs.entries) {
      if (_directoryWatchers.containsKey(entry.key)) continue;
      final dir = Directory(entry.value);
      if (!dir.existsSync()) continue;
      try {
        final sub = dir
            .watch(events: FileSystemEvent.all)
            .listen(
              _onDirectoryFileEvent,
              onError: (Object error) {
                debugPrint(
                  '[EditorController] Directory watcher error for ${entry.value}: $error',
                );
                _directoryWatchers.remove(entry.key);
              },
              cancelOnError: true,
            );
        _directoryWatchers[entry.key] = sub;
      } catch (e) {
        debugPrint(
          '[EditorController] Failed to watch directory ${entry.value}: $e',
        );
      }
    }
  }

  void _onDirectoryFileEvent(FileSystemEvent event) {
    final candidatePaths = <String>[
      event.path,
      if (event is FileSystemMoveEvent && event.destination != null)
        event.destination!,
    ];

    for (final doc in _openDocuments) {
      final docPath = doc.filePath;
      if (docPath == null) continue;
      if (candidatePaths.any((p) => _pathsEqual(p, docPath))) {
        _scheduleFileChangeCheck(docPath);
      }
    }
  }

  void _scheduleFileChangeCheck(String filePath) {
    final key = _normalizePathKey(filePath);
    _fileChangeDebounceTimers[key]?.cancel();
    _fileChangeDebounceTimers[key] = Timer(fileWatchDebounce, () {
      _fileChangeDebounceTimers.remove(key);
      checkFileForChanges(filePath);
    });
  }

  /// Check a single open disk-backed document for external changes on disk.
  Future<void> checkFileForChanges(String filePath) async {
    final doc = openDocumentForPath(filePath);
    if (doc == null) return;
    await _checkDocumentForChanges(doc, forceRead: true);
  }

  /// Check all open disk-backed documents for external modifications on disk.
  Future<void> checkOpenFilesForChanges({bool forceRead = false}) async {
    if (_isCheckingFiles) return;
    _isCheckingFiles = true;
    try {
      final docsSnapshot = List<OpenDocument>.from(_openDocuments);
      for (final doc in docsSnapshot) {
        await _checkDocumentForChanges(doc, forceRead: forceRead);
      }
    } catch (e) {
      debugPrint('[EditorController] Error checking files for changes: $e');
    } finally {
      _isCheckingFiles = false;
    }
  }

  Future<void> _checkDocumentForChanges(
    OpenDocument doc, {
    bool forceRead = false,
  }) async {
    final path = doc.filePath;
    if (path == null) return;
    if (!_openDocuments.contains(doc) || doc.filePath != path) return;

    final stat = await fileService.statFile(path);
    if (stat == null) return;

    if (!forceRead) {
      final metaChanged =
          doc.lastDiskModified == null ||
          doc.lastDiskSize == null ||
          stat.modified != doc.lastDiskModified ||
          stat.size != doc.lastDiskSize;
      if (!metaChanged) return;
    }

    final diskContent = await fileService.readFile(path);
    if (!_openDocuments.contains(doc) || doc.filePath != path) return;

    doc.lastDiskModified = stat.modified;
    doc.lastDiskSize = stat.size;

    if (diskContent == doc.lastKnownDiskContent) {
      return;
    }

    doc.lastKnownDiskContent = diskContent;

    final isActive = identical(doc, activeDocument);
    final isDocModified = isActive ? _isModified : doc.isModified;

    if (!isDocModified) {
      if (isActive) {
        _applyDiskContentToActiveDocument(diskContent);
      } else {
        _applyDiskContentToBackgroundDocument(doc, diskContent);
      }
    } else {
      if (isActive) {
        final changed = !_hasConflict;
        _hasConflict = true;
        doc.hasConflict = true;
        if (changed || !_hasPromptedConflict) {
          notifyListeners();
        }
      } else if (!doc.hasConflict) {
        doc.hasConflict = true;
        doc.hasPromptedConflict = false;
        notifyListeners();
      }
    }
  }

  void _applyDiskContentToActiveDocument(String diskContent) {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _documentEpoch++;
    _isBackgroundRendering = false;

    final previousSelection = textController.selection;
    final safeBase = previousSelection.baseOffset.clamp(0, diskContent.length);
    final safeExtent = previousSelection.extentOffset.clamp(
      0,
      diskContent.length,
    );

    _isProgrammaticUpdate = true;
    textController.isActivelyTyping = false;
    textController.value = TextEditingValue(
      text: diskContent,
      selection: TextSelection(baseOffset: safeBase, extentOffset: safeExtent),
    );
    _isProgrammaticUpdate = false;
    _lastObservedText = diskContent;
    _isModified = false;
    _hasConflict = false;
    _hasPromptedConflict = false;
    activeDocument?.hasConflict = false;
    activeDocument?.hasPromptedConflict = false;

    textController.reconcileFullHighlight();
    textController.invalidateSpellCheck();
    flushPendingRenderUpdate();
    _syncActiveDocumentToStore();
  }

  void _applyDiskContentToBackgroundDocument(
    OpenDocument doc,
    String diskContent,
  ) {
    final safeBase = doc.selection.baseOffset.clamp(0, diskContent.length);
    final safeExtent = doc.selection.extentOffset.clamp(0, diskContent.length);
    doc.content = diskContent;
    doc.selection = TextSelection(
      baseOffset: safeBase,
      extentOffset: safeExtent,
    );
    doc.isModified = false;
    doc.hasConflict = false;
    doc.hasPromptedConflict = false;

    final result = MarkdownRenderService.executeMarkdownRender(
      MarkdownRenderPayload(
        renderId: 0,
        rawMarkdown: diskContent,
        citations: [...citations, ...zoteroCitations],
        citationStyle: doc.citationStyle,
      ),
    );
    doc.previewMarkdown = result.processedMarkdown;
    doc.numericIndices = result.numericIndices;
    doc.astNodes = result.astNodes;
    doc.wordCount = result.wordCount;
    doc.charCount = diskContent.length;
    doc.lineCount = result.lineCount;
    doc.readingTimeMinutes = result.readingTimeMinutes;
    notifyListeners();
  }

  /// Discard in-app unsaved changes and reload the active file from disk.
  Future<bool> discardChangesAndReloadFromDisk() async {
    final path = _currentFilePath;
    if (path == null) return false;

    try {
      final diskContent = await fileService.readFile(path);
      final stat = await fileService.statFile(path);
      activeDocument?.lastKnownDiskContent = diskContent;
      activeDocument?.lastDiskModified = stat?.modified;
      activeDocument?.lastDiskSize = stat?.size;
      _applyDiskContentToActiveDocument(diskContent);
      return true;
    } catch (e) {
      debugPrint('[EditorController] Error discarding changes: $e');
      return false;
    }
  }

  @override
  void dispose() {
    stopFileWatching();
    _debounceTimer?.cancel();
    previewNotifier.dispose();
    textController.removeListener(_onTextChanged);
    textController.dispose();
    focusNode.dispose();
    scrollController.dispose();
    zoteroService.dispose();
    spellCheckService.dispose();
    super.dispose();
  }
}
