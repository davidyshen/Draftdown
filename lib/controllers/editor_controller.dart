import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/citation_item.dart';
import '../models/export_format.dart';
import '../models/history_entry.dart';
import '../services/bibliography_service.dart';
import '../services/direct_export_service.dart';
import '../services/file_service.dart';
import '../services/history_service.dart';
import '../services/pandoc_service.dart';
import '../services/zotero_service.dart';
import '../ui/theme/app_theme.dart';
import 'markdown_syntax_controller.dart';

enum EditorViewMode {
  edit,
  split,
  preview,
}

enum CitationSource {
  bibtex,
  zotero,
}

/// Main application state controller for MDWriter.
class EditorController extends ChangeNotifier {
  final FileService fileService;
  final HistoryService historyService;
  final BibliographyService bibliographyService;
  final PandocService pandocService;
  final ZoteroService zoteroService;
  final DirectExportService directExportService;

  // Document state
  String? _currentFilePath;
  String _currentFileName = 'Untitled.md';
  bool _isModified = false;
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
  bool _isSidebarOpen = true;

  // Bibliography & Zotero state
  String? _bibliographyPath;
  bool _isZoteroConnected = false;
  String _bibliographyStatus = 'Initialised with sample bibliography';
  CitationSource _citationSource = CitationSource.bibtex;

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
  String _previewMarkdown = '';
  Timer? _debounceTimer;
  bool? _isProgrammaticUpdate;
  String? _lastObservedText;

  // Getters
  Duration get renderDebounceDuration =>
      _customRenderDebounce ?? defaultRenderDebounce;
  String? get currentFilePath => _currentFilePath;
  String get currentFileName => _currentFileName;
  bool get isModified => _isModified;
  bool get isRenderPending => _debounceTimer?.isActive ?? false;
  EditorViewMode get viewMode => _viewMode;
  bool get isSidebarOpen => _isSidebarOpen;
  int get wordCount => _wordCount;
  int get charCount => _charCount;
  int get lineCount => _lineCount;
  int get readingTimeMinutes => _readingTimeMinutes;
  List<HistoryEntry> get history => historyService.history;
  List<CitationItem> get citations => bibliographyService.items;
  CitationSource get citationSource => _citationSource;
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

  EditorController({
    FileService? fileService,
    HistoryService? historyService,
    BibliographyService? bibliographyService,
    PandocService? pandocService,
    ZoteroService? zoteroService,
    DirectExportService? directExportService,
    Duration? renderDebounceDuration,
  })  : fileService = fileService ?? FileService(),
        historyService = historyService ?? HistoryService(),
        bibliographyService = bibliographyService ?? BibliographyService(),
        pandocService = pandocService ?? PandocService(),
        zoteroService = zoteroService ?? ZoteroService(),
        directExportService = directExportService ?? DirectExportService(),
        _customRenderDebounce = renderDebounceDuration {
    _lastObservedText = textController.text;
    textController.addListener(_onTextChanged);
  }

  /// Initialise controller, check Pandoc & Zotero, load history and preferences
  Future<void> initialise() async {
    await historyService.loadHistory();
    await _loadPreferences();
    await checkPandocAvailability();
    await checkZoteroConnection();

    // Check if there is an active history entry or load welcome document
    if (history.isNotEmpty && File(history.first.path).existsSync()) {
      await openFile(history.first.path);
    } else {
      _loadWelcomeDocument();
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _bibliographyPath = prefs.getString('mdwriter_bibliography_path');
      final customPandoc = prefs.getString('mdwriter_custom_pandoc_path');
      if (customPandoc != null && customPandoc.isNotEmpty) {
        pandocService.setCustomPath(customPandoc);
      }

      if (_bibliographyPath != null && File(_bibliographyPath!).existsSync()) {
        await loadBibliographyFile(_bibliographyPath!);
      }

      _editorFontFamily =
          prefs.getString('mdwriter_editor_font') ?? 'Consolas';
      _isDualRenderFont =
          prefs.getBool('mdwriter_is_dual_render_font') ?? false;
      _renderBodyFont =
          prefs.getString('mdwriter_render_body_font') ?? 'Segoe UI';
      _renderHeaderFont =
          prefs.getString('mdwriter_render_header_font') ?? 'Georgia';

      _darkSchemeId =
          prefs.getString('mdwriter_dark_scheme') ?? AppTheme.slateDarkScheme.id;
      _lightSchemeId = prefs.getString('mdwriter_light_scheme') ??
          AppTheme.slateLightScheme.id;
      _isDarkMode = prefs.getBool('mdwriter_dark_mode') ?? false;

      AppTheme.setActiveScheme(AppTheme.schemeById(darkSchemeId));
      AppTheme.setActiveScheme(AppTheme.schemeById(lightSchemeId));

      final savedSource = prefs.getString('mdwriter_citation_source');
      if (savedSource == 'zotero') {
        _citationSource = CitationSource.zotero;
      }
    } catch (_) {}
  }

  /// Change active citation source (BibTeX file vs. Zotero)
  Future<void> setCitationSource(CitationSource source) async {
    _citationSource = source;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mdwriter_citation_source', source.name);
    } catch (_) {}
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mdwriter_editor_font', _editorFontFamily);
      await prefs.setBool('mdwriter_is_dual_render_font', _isDualRenderFont);
      await prefs.setString('mdwriter_render_body_font', _renderBodyFont);
      await prefs.setString('mdwriter_render_header_font', _renderHeaderFont);
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('mdwriter_dark_mode', isDarkMode);
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mdwriter_color_scheme', scheme.id);
      await prefs.setString('mdwriter_dark_scheme', darkSchemeId);
      await prefs.setString('mdwriter_light_scheme', lightSchemeId);
      await prefs.setBool('mdwriter_dark_mode', isDarkMode);
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
      return;
    }

    // Decouple Markdown entry from expensive rendering on large files:
    // Wait until a 1.5-second period of typing inactivity before updating the render.
    textController.isActivelyTyping = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(renderDebounceDuration, flushPendingRenderUpdate);

    if (!_isModified) {
      _isModified = true;
      notifyListeners();
    }
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
    textController.reconcileFullHighlight();
    _computeMetrics();
    _previewMarkdown = textController.text;
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

  /// Create a new blank Markdown document
  void newFile() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _currentFilePath = null;
    _currentFileName = 'Untitled.md';
    _isProgrammaticUpdate = true;
    textController.isActivelyTyping = false;
    textController.clear();
    _isProgrammaticUpdate = false;
    _lastObservedText = '';
    _previewMarkdown = '';
    _computeMetrics();
    _isModified = false;
    if (scrollController.hasClients) {
      scrollController.jumpTo(0.0);
    }
    notifyListeners();
  }

  /// Open a Markdown document from disk
  Future<bool> openFile([String? targetPath]) async {
    final path = targetPath ?? await fileService.pickMarkdownFile();

    if (path == null) return false;

    try {
      final content = await fileService.readFile(path);
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _currentFilePath = path;
      _currentFileName = File(path).uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      _isProgrammaticUpdate = true;
      textController.isActivelyTyping = false;
      textController.text = content;
      _isProgrammaticUpdate = false;
      _lastObservedText = content;
      _previewMarkdown = content;
      _computeMetrics();
      _isModified = false;

      // Add to history
      await historyService.recordFileOpen(path);

      // Auto-detect adjacent bibliography if present in the same directory
      _autoDetectAdjacentBibliography(File(path).parent.path);

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
      final list = await dir.list().toList();
      for (final entity in list) {
        if (entity is File) {
          final lower = entity.path.toLowerCase();
          if (lower.endsWith('.bib') || lower.endsWith('references.bib')) {
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
      _isModified = false;
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
      _currentFilePath = destination;
      _currentFileName =
          File(destination).uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      _isModified = false;
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
    newFile();
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
    if (flushImmediately) {
      _isProgrammaticUpdate = false;
      _isModified = true;
      flushPendingRenderUpdate();
    }
  }

  /// Format currently selected text with markdown prefix and optional suffix
  void formatSelection(String prefix, [String? suffix]) {
    final post = suffix ?? prefix;
    final currentText = textController.text;
    final selection = textController.selection;

    if (!selection.isValid || selection.isCollapsed) {
      // Nothing selected: insert template
      insertText('$prefix$post');
      return;
    }

    final selectedText = currentText.substring(selection.start, selection.end);
    final formatted = '$prefix$selectedText$post';
    final newText = currentText.replaceRange(selection.start, selection.end, formatted);

    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: selection.start + prefix.length,
        extentOffset: selection.start + prefix.length + selectedText.length,
      ),
    );
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
    final offset = cursorOffset ??
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
      selection: TextSelection.collapsed(offset: start + newCitationText.length),
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mdwriter_bibliography_path', filePath);

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
  Future<void> checkZoteroConnection() async {
    _isZoteroConnected = await zoteroService.isBbtRunning();
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
    final hasUserBib = userBibliographyPath != null &&
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
        final userContent =
            await File(userBibliographyPath.trim()).readAsString();
        buffer.writeln(userContent);
        buffer.writeln();

        // Extract citekeys already present in the user bibliography
        final entryKeyRegex = RegExp(
          r'@([a-zA-Z]+)\s*\{\s*([a-zA-Z0-9_:.+-]+)\s*,',
        );
        for (final m in entryKeyRegex.allMatches(userContent)) {
          final k = m.group(2)?.trim().toLowerCase();
          if (k != null && k.isNotEmpty) {
            includedKeys.add(k);
          }
        }
      } catch (e) {
        debugPrint(
            '[EditorController] Warning: Could not read user bibliography: $e');
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
      prefix: 'mdwriter_bib_',
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
        tempSourceFile =
            await fileService.createTemporaryFile(textController.text);
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
    textController.text = '''# Welcome to MDWriter

A minimalist, high-productivity Markdown editor with native academic citations and Pandoc document export.

## Key Features

1. **Academic Citations**:
   - Seamlessly insert citations formatted for Pandoc, such as [@turing1950computing] or in-text citations like @shannon1948mathematical.
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

Literate programming, as introduced by @knuth1984literate, suggests that code and prose should harmonise. Deep learning architectures have similarly progressed from adversarial networks [@goodfellow2014generative] to attention-based Transformer models [@vaswani2017attention].

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
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    textController.removeListener(_onTextChanged);
    textController.dispose();
    focusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
