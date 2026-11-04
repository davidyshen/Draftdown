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

  // Typography state
  String _editorFontFamily = 'Consolas';
  bool _isDualRenderFont = false;
  String _renderBodyFont = 'Segoe UI';
  String _renderHeaderFont = 'Georgia';

  // Getters
  String? get currentFilePath => _currentFilePath;
  String get currentFileName => _currentFileName;
  bool get isModified => _isModified;
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
  String get content => textController.text;

  EditorController({
    FileService? fileService,
    HistoryService? historyService,
    BibliographyService? bibliographyService,
    PandocService? pandocService,
    ZoteroService? zoteroService,
    DirectExportService? directExportService,
  })  : fileService = fileService ?? FileService(),
        historyService = historyService ?? HistoryService(),
        bibliographyService = bibliographyService ?? BibliographyService(),
        pandocService = pandocService ?? PandocService(),
        zoteroService = zoteroService ?? ZoteroService(),
        directExportService = directExportService ?? DirectExportService() {
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

  void _onTextChanged() {
    final text = textController.text;
    _charCount = text.length;

    // Word count calculation
    final words = text.trim().split(RegExp(r'\s+'));
    _wordCount = (text.trim().isEmpty) ? 0 : words.length;

    // Line count
    _lineCount = '\n'.allMatches(text).length + 1;

    // Reading time: standard ~200 words per minute
    _readingTimeMinutes = (_wordCount / 200).ceil().clamp(1, 9999);

    if (!_isModified) {
      _isModified = true;
    }
    notifyListeners();
  }

  /// Create a new blank Markdown document
  void newFile() {
    _currentFilePath = null;
    _currentFileName = 'Untitled.md';
    textController.clear();
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
      _currentFilePath = path;
      _currentFileName = File(path).uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      textController.text = content;
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
    notifyListeners();
  }

  /// Insert text at current cursor position
  void insertText(String textToInsert) {
    final currentText = textController.text;
    final selection = textController.selection;

    final start = selection.isValid ? selection.start : currentText.length;
    final end = selection.isValid ? selection.end : currentText.length;

    final newText = currentText.replaceRange(start, end, textToInsert);
    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + textToInsert.length),
    );
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
    insertText(citationStr);
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
    insertText(citationStr);
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
    textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + newCitationText.length),
    );
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
    _currentFilePath = null;
    _currentFileName = 'Welcome.md';
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
    _isModified = false;
    notifyListeners();
  }

  @override
  void dispose() {
    textController.removeListener(_onTextChanged);
    textController.dispose();
    focusNode.dispose();
    scrollController.dispose();
    super.dispose();
  }
}
