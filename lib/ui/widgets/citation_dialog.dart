import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/editor_controller.dart';
import '../../models/citation_item.dart';
import '../theme/app_theme.dart';

/// Modal dialogue to search, preview, and insert literature citations
/// from either a local BibTeX database (.bib) or directly from Zotero
/// (via Better BibTeX JSON-RPC) into the Markdown editor.
class CitationDialog extends StatefulWidget {
  final EditorController controller;
  final DetectedCitation? initialCitation;

  const CitationDialog({
    super.key,
    required this.controller,
    this.initialCitation,
  });

  @override
  State<CitationDialog> createState() => _CitationDialogState();
}

class _CitationDialogState extends State<CitationDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locatorController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _listScrollController = ScrollController();

  late CitationSource _activeSource;
  List<CitationItem> _filteredItems = [];
  final List<CitationItem> _selectedCitations = [];
  int _highlightedIndex = -1;
  DetectedCitation? _editingCitation;

  List<CitationItem> get _availableItems {
    return _filteredItems
        .where((item) => !_selectedCitations.contains(item))
        .toList();
  }

  CitationItem? get _selectedItem =>
      (_availableItems.isNotEmpty &&
              _highlightedIndex >= 0 &&
              _highlightedIndex < _availableItems.length)
          ? _availableItems[_highlightedIndex]
          : null;

  bool _inTextCitation = false;
  bool _suppressAuthor = false;
  bool _isLoadingZotero = false;
  bool _isCheckingConnection = false;

  @override
  void initState() {
    super.initState();
    _activeSource = widget.controller.citationSource;
    _searchFocusNode.onKeyEvent = _handleKeyEvent;
    _editingCitation = widget.initialCitation ??
        widget.controller.getCitationAtCursor();
    if (_editingCitation != null) {
      _inTextCitation = _editingCitation!.inText;
      _suppressAuthor = _editingCitation!.suppressAuthor;
      if (_editingCitation!.locator != null) {
        _locatorController.text = _editingCitation!.locator!;
      }
    }
    _initialiseItems();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _listScrollController.dispose();
    _searchController.dispose();
    _locatorController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _onEnterPressed();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _searchController.text.isEmpty &&
        _selectedCitations.isNotEmpty) {
      _removeLastSelectedCitation();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _moveHighlight(int delta) {
    if (_availableItems.isEmpty) return;
    setState(() {
      if (_highlightedIndex == -1) {
        _highlightedIndex = delta > 0 ? 0 : _availableItems.length - 1;
      } else {
        final next = _highlightedIndex + delta;
        if (next < 0) {
          _highlightedIndex = -1;
        } else if (next >= _availableItems.length) {
          _highlightedIndex = _availableItems.length - 1;
        } else {
          _highlightedIndex = next;
        }
      }
    });
    _scrollToHighlighted();
  }

  void _scrollToHighlighted() {
    if (!_listScrollController.hasClients || _highlightedIndex < 0) return;
    const itemHeight = 68.0;
    final targetOffset = _highlightedIndex * itemHeight;
    final viewportHeight = _listScrollController.position.viewportDimension;
    final currentOffset = _listScrollController.offset;

    if (targetOffset < currentOffset) {
      _listScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
      );
    } else if (targetOffset + itemHeight > currentOffset + viewportHeight) {
      _listScrollController.animateTo(
        (targetOffset + itemHeight - viewportHeight)
            .clamp(0.0, _listScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
      );
    }
  }

  void _onEnterPressed() {
    final query = _searchController.text.trim();
    final item = _selectedItem;

    if (item != null) {
      // User explicitly highlighted an available citation: add it to selected basket
      setState(() {
        if (!_selectedCitations.contains(item)) {
          _selectedCitations.add(item);
        }
        _searchController.clear();
        _highlightedIndex = -1; // Clear selection so next Enter confirms
      });
      _onSearch('');
      _searchFocusNode.requestFocus();
      return;
    }

    if (query.isNotEmpty && _availableItems.isNotEmpty) {
      // User typed a search query and pressed Enter directly: select the first match
      final firstMatch = _availableItems.first;
      setState(() {
        if (!_selectedCitations.contains(firstMatch)) {
          _selectedCitations.add(firstMatch);
        }
        _searchController.clear();
        _highlightedIndex = -1; // Clear selection so next Enter confirms
      });
      _onSearch('');
      _searchFocusNode.requestFocus();
      return;
    }

    // Search query is empty and no entry is highlighted in the list:
    if (_selectedCitations.isNotEmpty) {
      // Selection was cleared: hitting Enter confirms the selected citations and inserts them!
      _apply();
      return;
    }
  }

  void _toggleCitation(CitationItem item) {
    setState(() {
      if (_selectedCitations.contains(item)) {
        _selectedCitations.remove(item);
      } else {
        _selectedCitations.add(item);
      }
      _searchController.clear();
      _highlightedIndex = -1;
    });
    _onSearch('');
    _searchFocusNode.requestFocus();
  }

  void _removeLastSelectedCitation() {
    if (_selectedCitations.isNotEmpty) {
      setState(() {
        _selectedCitations.removeLast();
        _highlightedIndex = -1;
      });
    }
  }

  Future<void> _initialiseItems() async {
    if (_activeSource == CitationSource.bibtex) {
      setState(() {
        _filteredItems = widget.controller.citations;
        _highlightedIndex = -1;
      });
    } else {
      await _loadZoteroItems();
    }
    _populateInitialCitations();
  }

  void _populateInitialCitations() {
    if (_editingCitation == null) return;
    for (final key in _editingCitation!.keys) {
      final cleanKey = key.trim().toLowerCase();
      CitationItem? found;
      for (final item in widget.controller.citations) {
        if (item.key.trim().toLowerCase() == cleanKey) {
          found = item;
          break;
        }
      }
      if (found == null) {
        for (final item in widget.controller.zoteroCitations) {
          if (item.key.trim().toLowerCase() == cleanKey) {
            found = item;
            break;
          }
        }
      }
      found ??= CitationItem(
        key: key.trim(),
        title: 'Citation: @${key.trim()}',
      );

      if (!_selectedCitations.contains(found)) {
        _selectedCitations.add(found);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadZoteroItems({String query = ''}) async {
    setState(() => _isLoadingZotero = true);
    final results = await widget.controller.zoteroService.getOrSearch(query);
    if (!mounted) return;
    setState(() {
      _isLoadingZotero = false;
      _filteredItems = results;
      _highlightedIndex = -1;
    });
  }

  void _onSourceChanged(CitationSource newSource) {
    if (_activeSource == newSource) return;
    setState(() {
      _activeSource = newSource;
      _highlightedIndex = -1;
    });
    widget.controller.setCitationSource(newSource);
    _onSearch(_searchController.text);
    _searchFocusNode.requestFocus();
  }

  Future<void> _onSearch(String query) async {
    if (_activeSource == CitationSource.bibtex) {
      setState(() {
        _filteredItems = widget.controller.bibliographyService.search(query);
        _highlightedIndex = -1;
      });
      if (_listScrollController.hasClients) {
        _listScrollController.jumpTo(0);
      }
    } else {
      await _loadZoteroItems(query: query);
      if (_listScrollController.hasClients) {
        _listScrollController.jumpTo(0);
      }
    }
  }

  Future<void> _retryZoteroConnection() async {
    setState(() => _isCheckingConnection = true);
    await widget.controller.checkZoteroConnection();
    await _loadZoteroItems(query: _searchController.text);
    if (mounted) {
      setState(() => _isCheckingConnection = false);
    }
  }

  void _apply() {
    final itemsToInsert = _selectedCitations.isNotEmpty
        ? List<CitationItem>.from(_selectedCitations)
        : (_selectedItem != null ? [_selectedItem!] : <CitationItem>[]);

    if (itemsToInsert.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final citationStr = CitationItem.formatMultiple(
      itemsToInsert,
      inText: _inTextCitation,
      suppressAuthor: _suppressAuthor,
      locator: _locatorController.text.trim().isNotEmpty
          ? _locatorController.text.trim()
          : null,
    );

    if (_editingCitation != null) {
      widget.controller.replaceCitation(_editingCitation!, citationStr);
    } else {
      widget.controller.insertText(citationStr);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surfaceColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final mutedColor =
        isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final isZoteroConnected = widget.controller.isZoteroConnected;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: surfaceColor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 820,
          maxHeight: 620,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header row
              Row(
                children: [
                  Icon(Icons.format_quote,
                      color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _editingCitation != null
                        ? 'Edit Literature Citation'
                        : 'Insert Literature Citation',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Source Selector Row: .bib vs Zotero
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    // BibTeX button
                    _buildSourceTabButton(
                      source: CitationSource.bibtex,
                      title: 'BibTeX (.bib)',
                      icon: Icons.description_outlined,
                      isActive: _activeSource == CitationSource.bibtex,
                      theme: theme,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 4),
                    // Zotero button
                    _buildSourceTabButton(
                      source: CitationSource.zotero,
                      title: 'Zotero',
                      icon: Icons.school_outlined,
                      isActive: _activeSource == CitationSource.zotero,
                      theme: theme,
                      isDark: isDark,
                      statusWidget: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isZoteroConnected ? Colors.green : Colors.amber,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Contextual Action depending on source
                    if (_activeSource == CitationSource.bibtex)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: theme.colorScheme.primary,
                        ),
                        icon: const Icon(Icons.folder_open, size: 14),
                        label: Text(
                          widget.controller.bibliographyPath != null
                              ? File(widget.controller.bibliographyPath!)
                                  .uri
                                  .pathSegments
                                  .last
                              : 'Change .bib',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        onPressed: () async {
                          final path = await widget.controller.fileService
                              .pickBibliographyFile();
                          if (path != null) {
                            await widget.controller.loadBibliographyFile(path);
                            _onSearch(_searchController.text);
                          }
                        },
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isZoteroConnected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Connected',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: _isCheckingConnection
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh, size: 14),
                            label: const Text('Refresh',
                                style: TextStyle(fontSize: 11.5)),
                            onPressed: _isCheckingConnection
                                ? null
                                : _retryZoteroConnection,
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Offline notice banner if Zotero is selected and disconnected
              if (_activeSource == CitationSource.zotero && !isZoteroConnected) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Zotero desktop is not responding on 127.0.0.1:23119. Showing cached references with Zotero citekeys. Start Zotero with Better BibTeX to search live.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.amber[200] : Colors.brown[800],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: _retryZoteroConnection,
                        child: const Text('Check Connection',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Selected Citations Basket (if any citations have been added)
              if (_selectedCitations.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.collections_bookmark_outlined,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Selected (${_selectedCitations.length}):',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _selectedCitations.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Chip(
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                  labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  backgroundColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.15),
                                  side: BorderSide(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.3),
                                  ),
                                  label: Text(
                                    '@${item.key}',
                                    style: TextStyle(
                                      fontFamily: AppTheme.editorFontFamily,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  deleteIcon: const Icon(Icons.close, size: 13),
                                  deleteIconColor: theme.colorScheme.primary,
                                  onDeleted: () {
                                    setState(() {
                                      _selectedCitations.remove(item);
                                    });
                                    _searchFocusNode.requestFocus();
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedCitations.clear();
                          });
                          _searchFocusNode.requestFocus();
                        },
                        child: const Text('Clear all',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Search Box
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: _selectedCitations.isEmpty
                      ? (_activeSource == CitationSource.bibtex
                          ? 'Search .bib database (↑/↓ to navigate, Enter to select)...'
                          : 'Search Zotero library (↑/↓ to navigate, Enter to select)...')
                      : 'Type to search another citation, or press Enter to insert (${_selectedCitations.length} selected)...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                            _searchFocusNode.requestFocus();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.darkSidebar
                      : AppTheme.lightSidebar,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: _onSearch,
                onSubmitted: (_) => _onEnterPressed(),
              ),

              if (_isLoadingZotero) ...[
                const SizedBox(height: 4),
                const LinearProgressIndicator(minHeight: 2),
              ],

              const SizedBox(height: 12),

              // Main content: Items List + Details Pane
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Citation Results List
                    Expanded(
                      flex: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _availableItems.isEmpty
                            ? Center(
                                child: Text(
                                  _selectedCitations.isNotEmpty &&
                                          _filteredItems.isNotEmpty
                                      ? 'All matching references are in Selected Citations.\nPress Enter to insert into text.'
                                      : (_activeSource == CitationSource.bibtex
                                          ? 'No references found in .bib database.\nTry a different search or load a .bib file.'
                                          : 'No references found in Zotero.\nTry a different query or check your connection.'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: mutedColor,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: _listScrollController,
                                itemCount: _availableItems.length,
                                itemBuilder: (context, index) {
                                  final item = _availableItems[index];
                                  final isHighlighted =
                                      index == _highlightedIndex;

                                  return InkWell(
                                    splashFactory: NoSplash.splashFactory,
                                    focusColor: Colors.transparent,
                                    hoverColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.05),
                                    onTap: () {
                                      setState(() => _highlightedIndex = index);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isHighlighted
                                            ? theme.colorScheme.primary
                                                .withValues(alpha: 0.12)
                                            : Colors.transparent,
                                        border: Border(
                                          left: isHighlighted
                                              ? BorderSide(
                                                  color:
                                                      theme.colorScheme.primary,
                                                  width: 3,
                                                )
                                              : BorderSide.none,
                                          bottom: BorderSide(
                                            color: borderColor
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Container(
                                                        padding: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 6,
                                                            vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: theme
                                                              .colorScheme.primary
                                                              .withValues(
                                                                  alpha: 0.15),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                  4),
                                                        ),
                                                        child: Text(
                                                          '@${item.key}',
                                                          style: TextStyle(
                                                            fontFamily: AppTheme
                                                                .editorFontFamily,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: theme
                                                                .colorScheme
                                                                .primary,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    if (item.year != null) ...[
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        item.year!,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: mutedColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item.title,
                                                  style: const TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.authorsSummary,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: mutedColor,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: Icon(
                                              Icons.add_circle_outline,
                                              size: 16,
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.7),
                                            ),
                                            splashRadius: 14,
                                            tooltip: 'Add to selected citations',
                                            onPressed: () =>
                                                _toggleCitation(item),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Details Pane for Selected Citation
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                          color: isDark
                              ? const Color(0xFF131D2E)
                              : const Color(0xFFF8FAFC),
                        ),
                        child: _selectedItem == null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_selectedCitations.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_outline,
                                                  size: 14,
                                                  color: theme
                                                      .colorScheme.primary),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${_selectedCitations.length} citation${_selectedCitations.length > 1 ? "s" : ""} selected',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Press Enter to confirm and insert into text,\nor use ↓ to select another reference.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: mutedColor,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.black
                                                    .withValues(alpha: 0.3)
                                                : Colors.white,
                                            border:
                                                Border.all(color: borderColor),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            CitationItem.formatMultiple(
                                              _selectedCitations,
                                              inText: _inTextCitation,
                                              suppressAuthor: _suppressAuthor,
                                              locator: _locatorController
                                                      .text
                                                      .trim()
                                                      .isNotEmpty
                                                  ? _locatorController.text
                                                      .trim()
                                                  : null,
                                            ),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontFamily:
                                                  AppTheme.editorFontFamily,
                                              fontSize: 11.5,
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        Icon(Icons.touch_app_outlined,
                                            size: 28,
                                            color: mutedColor
                                                .withValues(alpha: 0.6)),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Use ↓ arrow or type to search and select a reference',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 12, color: mutedColor),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _activeSource == CitationSource.zotero
                                                ? Colors.purple.withValues(alpha: 0.15)
                                                : Colors.blue.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _activeSource == CitationSource.zotero
                                                ? 'Zotero Item'
                                                : 'BibTeX (.bib)',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _activeSource == CitationSource.zotero
                                                  ? Colors.purple
                                                  : Colors.blue,
                                            ),
                                          ),
                                        ),
                                        if (_selectedItem!.itemType != null) ...[
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              _selectedItem!.itemType!,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: mutedColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _selectedItem!.title,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _selectedItem!.authors.isNotEmpty
                                          ? _selectedItem!.authors.join(', ')
                                          : 'Unknown Authors',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_selectedItem!.venue != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedItem!.venue!,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: mutedColor,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                    if (_selectedItem!.doi != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'DOI: ${_selectedItem!.doi}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: mutedColor,
                                        ),
                                      ),
                                    ],
                                    const Divider(height: 18),
                                    if (_selectedItem!.abstractText != null) ...[
                                      const Text(
                                        'Abstract',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedItem!.abstractText!,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.4,
                                          color: mutedColor,
                                        ),
                                        maxLines: 7,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                    // Live Pandoc Preview
                                    Text(
                                      _selectedCitations.isNotEmpty
                                          ? 'Pandoc Syntax Preview (${_selectedCitations.length} selected)'
                                          : 'Pandoc Syntax Preview',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.black.withValues(alpha: 0.3)
                                            : Colors.white,
                                        border: Border.all(color: borderColor),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _selectedCitations.isNotEmpty
                                            ? CitationItem.formatMultiple(
                                                _selectedCitations,
                                                inText: _inTextCitation,
                                                suppressAuthor: _suppressAuthor,
                                                locator: _locatorController.text
                                                        .trim()
                                                        .isNotEmpty
                                                    ? _locatorController.text.trim()
                                                    : null,
                                              )
                                            : (_selectedItem?.toPandocCitation(
                                                    inText: _inTextCitation,
                                                    suppressAuthor: _suppressAuthor,
                                                    locator: _locatorController.text
                                                            .trim()
                                                            .isNotEmpty
                                                        ? _locatorController.text.trim()
                                                        : null,
                                                  ) ??
                                                ''),
                                        style: TextStyle(
                                          fontFamily: AppTheme.editorFontFamily,
                                          fontSize: 12,
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Citation Formatting Options (In-text, Suppress Author, Locator)
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('In-text (@key)',
                                style: TextStyle(fontSize: 11)),
                            selected: _inTextCitation,
                            onSelected: (val) {
                              setState(() {
                                _inTextCitation = val;
                                if (val) _suppressAuthor = false;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Suppress Author ([-@key])',
                                style: TextStyle(fontSize: 11)),
                            selected: _suppressAuthor,
                            onSelected: (val) {
                              setState(() {
                                _suppressAuthor = val;
                                if (val) _inTextCitation = false;
                              });
                            },
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 130,
                            height: 32,
                            child: TextField(
                              controller: _locatorController,
                              style: const TextStyle(fontSize: 11.5),
                              decoration: InputDecoration(
                                hintText: 'Page (e.g. p. 42)',
                                hintStyle: const TextStyle(fontSize: 11),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                  borderSide: BorderSide(color: borderColor),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _apply(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Cancel & Insert buttons
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(
                      _editingCitation != null
                          ? (_selectedCitations.length > 1
                              ? 'Update Citations (${_selectedCitations.length})'
                              : 'Update Citation')
                          : (_selectedCitations.length > 1
                              ? 'Insert Citations (${_selectedCitations.length})'
                              : 'Insert Citation'),
                    ),
                    onPressed: (_selectedCitations.isNotEmpty ||
                            _selectedItem != null)
                        ? _apply
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceTabButton({
    required CitationSource source,
    required String title,
    required IconData icon,
    required bool isActive,
    required ThemeData theme,
    required bool isDark,
    Widget? statusWidget,
  }) {
    final activeBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        splashFactory: NoSplash.splashFactory,
        focusColor: Colors.transparent,
        onTap: () => _onSourceChanged(source),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? theme.colorScheme.primary : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                ),
              ),
              if (statusWidget != null) ...[
                const SizedBox(width: 6),
                statusWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
