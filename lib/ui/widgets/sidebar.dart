import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/editor_controller.dart';
import '../theme/app_theme.dart';

/// Collapsible left navigation bar displaying the active document
/// (with light path) and file history for seamless switching.
class AppSidebar extends StatefulWidget {
  final EditorController controller;
  final VoidCallback onOpenFile;
  final VoidCallback onNewFile;
  final VoidCallback onOpenSettingsDialog;
  final VoidCallback onToggleTheme;
  final VoidCallback? onResolveConflict;
  final bool isFloating;

  const AppSidebar({
    super.key,
    required this.controller,
    required this.onOpenFile,
    required this.onNewFile,
    required this.onOpenSettingsDialog,
    required this.onToggleTheme,
    this.onResolveConflict,
    this.isFloating = false,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  String _searchFilter = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isEditingFileName = false;
  bool _isCancellingRename = false;
  final TextEditingController _renameController = TextEditingController();
  final FocusNode _renameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _renameFocusNode.addListener(_onRenameFocusChange);
  }

  @override
  void dispose() {
    _renameFocusNode.removeListener(_onRenameFocusChange);
    _renameFocusNode.dispose();
    _renameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _startRenamingFile(String currentFileName) {
    final parts = EditorController.splitFileName(currentFileName);
    _isCancellingRename = false;
    _renameController.text = parts.stem;
    _renameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: parts.stem.length,
    );
    setState(() {
      _isEditingFileName = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isEditingFileName) {
        _renameFocusNode.requestFocus();
      }
    });
  }

  void _cancelRenamingFile() {
    if (!_isEditingFileName) return;
    _isCancellingRename = true;
    setState(() {
      _isEditingFileName = false;
    });
  }

  Future<void> _commitRenamingFile() async {
    if (!_isEditingFileName || _isCancellingRename) return;
    final newStem = _renameController.text.trim();
    setState(() {
      _isEditingFileName = false;
    });
    if (newStem.isEmpty) return;

    final error = await widget.controller.renameCurrentFile(newStem);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  void _onRenameFocusChange() {
    if (!_renameFocusNode.hasFocus && _isEditingFileName) {
      if (_isCancellingRename) {
        _isCancellingRename = false;
        return;
      }
      _commitRenamingFile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sidebarBg = isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final lightTextColor = isDark
        ? AppTheme.darkTextMuted
        : AppTheme.lightTextMuted;

    final sidebarContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top settings & colour scheme actions
        _buildTopActions(theme, isDark, borderColor),

        // Currently open file card
        _buildActiveFileCard(theme, isDark, lightTextColor, borderColor),

        const SizedBox(height: 12),

        // Search bar for history
        _buildHistorySearchBar(theme, isDark, borderColor),

        // History header with clear action
        _buildHistorySectionHeader(theme, lightTextColor),

        // History + Resizable Navigation split area
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const handleHeight = 10.0;
              final availableHeight =
                  (constraints.maxHeight - handleHeight - 74.0).clamp(
                    96.0,
                    double.infinity,
                  );
              final navCardHeight =
                  (availableHeight *
                          widget.controller.sidebarNavigationFraction)
                      .clamp(48.0, availableHeight - 48.0);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildHistoryList(
                      theme,
                      isDark,
                      lightTextColor,
                      borderColor,
                    ),
                  ),

                  // Vertical resize handle between File History and Navigation
                  MouseRegion(
                    key: const ValueKey('sidebar-nav-resize-handle'),
                    cursor: SystemMouseCursors.resizeRow,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        if (availableHeight <= 0) return;
                        final newNavHeight = navCardHeight - details.delta.dy;
                        widget.controller.setSidebarNavigationFraction(
                          newNavHeight / availableHeight,
                        );
                      },
                      child: SizedBox(
                        height: handleHeight,
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 3,
                            decoration: BoxDecoration(
                              color: borderColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Navigation section header
                  _buildNavigationSectionHeader(theme, lightTextColor),

                  // Navigation headings card
                  SizedBox(
                    height: navCardHeight,
                    child: _buildNavigationCard(
                      theme,
                      isDark,
                      lightTextColor,
                      borderColor,
                    ),
                  ),

                  // Sync scroll checkbox below Navigation card
                  _buildSyncScrollToggle(theme, isDark, lightTextColor),
                ],
              );
            },
          ),
        ),

        // Bottom quick action buttons
        _buildBottomActions(theme, borderColor),
      ],
    );

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: sidebarBg,
        borderRadius: widget.isFloating ? BorderRadius.circular(12) : null,
        border: widget.isFloating
            ? Border.all(color: borderColor)
            : Border(right: BorderSide(color: borderColor)),
        boxShadow: widget.isFloating
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: widget.isFloating
          ? ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: sidebarContent,
            )
          : sidebarContent,
    );
  }

  Widget _buildTopActions(ThemeData theme, bool isDark, Color borderColor) {
    final spellCheckEnabled = widget.controller.isSpellCheckEnabled;
    final scheme = AppTheme.activeSchemeForBrightness(isDark);
    final accent = scheme.accent;
    final activeIconColor = accent.computeLuminance() > 0.55
        ? Colors.black87
        : Colors.white;
    const pillHeight = 32.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: pillHeight,
              child: Tooltip(
                message: 'Settings',
                child: OutlinedButton.icon(
                  key: const ValueKey('sidebar-settings-btn'),
                  icon: const Icon(Icons.settings_outlined, size: 15),
                  label: const Text(
                    'Settings',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, pillHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: borderColor),
                  ),
                  onPressed: widget.onOpenSettingsDialog,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: pillHeight,
              child: Tooltip(
                message: isDark ? 'Switch to Light' : 'Switch to Dark',
                child: OutlinedButton.icon(
                  key: const ValueKey('sidebar-theme-btn'),
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    size: 15,
                  ),
                  label: Text(
                    isDark ? 'Light' : 'Dark',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, pillHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: borderColor),
                  ),
                  onPressed: widget.onToggleTheme,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: pillHeight,
            child: Tooltip(
              message: spellCheckEnabled
                  ? 'Spellchecker Enabled (${widget.controller.spellCheckLanguage}) — Click to disable'
                  : 'Spellchecker Disabled — Click to enable',
              child: OutlinedButton(
                key: const ValueKey('spellcheck-toggle-btn'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, pillHeight),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 10,
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: spellCheckEnabled ? accent : null,
                  side: BorderSide(
                    color: spellCheckEnabled ? accent : borderColor,
                  ),
                ),
                onPressed: widget.controller.toggleSpellCheck,
                child: Icon(
                  Icons.spellcheck,
                  size: 16,
                  color: spellCheckEnabled ? activeIconColor : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFileCard(
    ThemeData theme,
    bool isDark,
    Color lightTextColor,
    Color borderColor,
  ) {
    final fileName = widget.controller.currentFileName;
    final filePath = widget.controller.currentFilePath;
    final isModified = widget.controller.isModified;
    final hasConflict = widget.controller.hasConflict;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasConflict
                ? Colors.red.withValues(alpha: 0.65)
                : (isModified
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : borderColor),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 11,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'CURRENT FILE',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (hasConflict)
                  InkWell(
                    onTap: widget.onResolveConflict,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 7, color: Colors.red),
                          SizedBox(width: 4),
                          Text(
                            'Conflict',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (isModified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Unsaved',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // File Name (click to rename, keeping .md extension fixed)
            if (_isEditingFileName)
              _buildInlineFileNameEditor(
                fileName,
                theme,
                isDark,
                lightTextColor,
              )
            else
              Tooltip(
                message: 'Click to rename',
                child: InkWell(
                  key: const ValueKey('sidebar-active-filename'),
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _startRenamingFile(fileName),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fileName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: lightTextColor.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 4),
            // File Path in light text
            Text(
              filePath ?? 'Not yet saved to disk',
              style: TextStyle(
                fontSize: 11,
                color: lightTextColor,
                fontFamily: 'Segoe UI',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            // Action buttons for currently open file
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.save_outlined, size: 14),
                    label: const Text('Save', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => widget.controller.saveFile(),
                  ),
                ),
                if (filePath != null) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Reveal in Explorer',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => widget.controller.fileService
                          .revealInExplorer(filePath),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.folder_open,
                          size: 15,
                          color: lightTextColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineFileNameEditor(
    String fileName,
    ThemeData theme,
    bool isDark,
    Color lightTextColor,
  ) {
    final parts = EditorController.splitFileName(fileName);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _cancelRenamingFile,
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            Flexible(
              child: IntrinsicWidth(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 24),
                  child: TextField(
                    key: const ValueKey('sidebar-rename-input'),
                    controller: _renameController,
                    focusNode: _renameFocusNode,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[\\/:*?"<>|]')),
                    ],
                    onSubmitted: (_) => _commitRenamingFile(),
                  ),
                ),
              ),
            ),
            Text(
              parts.extension,
              key: const ValueKey('sidebar-rename-extension'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: lightTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySearchBar(
    ThemeData theme,
    bool isDark,
    Color borderColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 32,
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Filter history...',
            hintStyle: const TextStyle(fontSize: 12),
            prefixIcon: const Icon(Icons.search, size: 16),
            prefixIconConstraints: const BoxConstraints(minWidth: 32),
            suffixIcon: _searchFilter.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 14),
                    splashRadius: 14,
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchFilter = '');
                    },
                  )
                : null,
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
          onChanged: (val) {
            setState(() => _searchFilter = val.trim().toLowerCase());
          },
        ),
      ),
    );
  }

  Widget _buildHistorySectionHeader(ThemeData theme, Color lightTextColor) {
    final historyCount = widget.controller.history.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
      child: Row(
        children: [
          Icon(Icons.history, size: 14, color: lightTextColor),
          const SizedBox(width: 6),
          Text(
            'FILE HISTORY ($historyCount)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: lightTextColor,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          if (historyCount > 0)
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear File History'),
                    content: const Text(
                      'Are you sure you wish to clear all previously opened file records? This will not delete your files from disk.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await widget.controller.historyService.clearHistory();
                  setState(() {});
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Clear',
                  style: TextStyle(fontSize: 10, color: lightTextColor),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(
    ThemeData theme,
    bool isDark,
    Color lightTextColor,
    Color borderColor,
  ) {
    final activeDoc = widget.controller.activeDocument;
    final currentPath = widget.controller.currentFilePath;
    final openUntitledDocs = widget.controller.openDocuments.where((doc) {
      if (doc.filePath != null) return false;
      final isSoleUntouched =
          widget.controller.openDocuments.length == 1 &&
          !widget.controller.isModified &&
          widget.controller.history.isEmpty;
      if (isSoleUntouched) return false;
      if (_searchFilter.isEmpty) return true;
      return doc.fileName.toLowerCase().contains(_searchFilter);
    }).toList();

    final history = widget.controller.history;
    final filtered = _searchFilter.isEmpty
        ? history
        : history.where((entry) {
            return entry.fileName.toLowerCase().contains(_searchFilter) ||
                entry.path.toLowerCase().contains(_searchFilter);
          }).toList();

    // Always place the active file at the top of the list.
    final activeUntitledIndex = openUntitledDocs.indexWhere(
      (doc) => activeDoc?.id == doc.id,
    );
    if (activeUntitledIndex > 0) {
      final activeUntitled = openUntitledDocs.removeAt(activeUntitledIndex);
      openUntitledDocs.insert(0, activeUntitled);
    }

    final activeHistoryIndex = currentPath == null
        ? -1
        : filtered.indexWhere((entry) => entry.path == currentPath);
    final activeHistoryEntry = activeHistoryIndex != -1
        ? filtered[activeHistoryIndex]
        : null;
    final remainingHistory = activeHistoryIndex != -1
        ? [
            ...filtered.sublist(0, activeHistoryIndex),
            ...filtered.sublist(activeHistoryIndex + 1),
          ]
        : filtered;

    if (openUntitledDocs.isEmpty &&
        activeHistoryEntry == null &&
        remainingHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_outlined, size: 32, color: lightTextColor),
              const SizedBox(height: 8),
              Text(
                _searchFilter.isEmpty
                    ? 'No file history yet'
                    : 'No matching files found',
                style: TextStyle(fontSize: 12, color: lightTextColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final hasActiveHistoryAtTop = activeHistoryEntry != null;
    final totalCount =
        (hasActiveHistoryAtTop ? 1 : 0) +
        openUntitledDocs.length +
        remainingHistory.length;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (hasActiveHistoryAtTop && index == 0) {
          final entry = activeHistoryEntry;
          final isModified = widget.controller.isFileModified(entry.path);
          final hasConflict = widget.controller.isFileConflicted(entry.path);
          final openDoc = widget.controller.openDocumentForPath(entry.path);
          return _buildSidebarFileItem(
            fileName: entry.fileName,
            subtitlePath: entry.path,
            subtitleTime: entry.relativeTime,
            isCurrent: true,
            isOpen: true,
            isModified: isModified,
            hasConflict: hasConflict,
            theme: theme,
            isDark: isDark,
            lightTextColor: lightTextColor,
            closeTooltip: 'Close tab',
            onTap: () async {
              await widget.controller.openFile(entry.path);
            },
            onCloseOrRemove: () async {
              if (openDoc != null) {
                await _handleCloseOpenTab(
                  openDoc.id,
                  entry.fileName,
                  isModified,
                );
              }
            },
          );
        }

        final adjustedIndex = hasActiveHistoryAtTop ? index - 1 : index;
        if (adjustedIndex < openUntitledDocs.length) {
          final doc = openUntitledDocs[adjustedIndex];
          final isCurrent = activeDoc?.id == doc.id;
          final isModified = isCurrent
              ? widget.controller.isModified
              : doc.isModified;
          return _buildSidebarFileItem(
            itemKey: ValueKey('sidebar-open-doc-${doc.id}'),
            fileName: doc.fileName,
            subtitlePath: 'Not yet saved to disk',
            subtitleTime: isCurrent ? 'Active tab' : 'Open tab',
            isCurrent: isCurrent,
            isOpen: true,
            isModified: isModified,
            theme: theme,
            isDark: isDark,
            lightTextColor: lightTextColor,
            closeTooltip: 'Close tab',
            onTap: () {
              widget.controller.switchToDocumentById(doc.id);
            },
            onCloseOrRemove: () =>
                _handleCloseOpenTab(doc.id, doc.fileName, isModified),
          );
        }

        final entry = remainingHistory[adjustedIndex - openUntitledDocs.length];
        final isCurrent = entry.path == widget.controller.currentFilePath;
        final isOpen = widget.controller.isFileOpen(entry.path);
        final isModified = widget.controller.isFileModified(entry.path);
        final hasConflict = widget.controller.isFileConflicted(entry.path);
        final openDoc = widget.controller.openDocumentForPath(entry.path);

        return _buildSidebarFileItem(
          fileName: entry.fileName,
          subtitlePath: entry.path,
          subtitleTime: entry.relativeTime,
          isCurrent: isCurrent,
          isOpen: isOpen,
          isModified: isModified,
          hasConflict: hasConflict,
          theme: theme,
          isDark: isDark,
          lightTextColor: lightTextColor,
          closeTooltip: isOpen ? 'Close tab' : 'Remove from history',
          onTap: () async {
            await widget.controller.openFile(entry.path);
          },
          onCloseOrRemove: () async {
            if (isOpen && openDoc != null) {
              await _handleCloseOpenTab(openDoc.id, entry.fileName, isModified);
            } else {
              await widget.controller.historyService.removeEntry(entry.path);
              setState(() {});
            }
          },
        );
      },
    );
  }

  Future<void> _handleCloseOpenTab(
    String docId,
    String fileName,
    bool isModified,
  ) async {
    if (isModified) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: Text('Save changes to $fileName before closing?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('Save & Close'),
            ),
          ],
        ),
      );

      if (action == 'cancel' || action == null) return;
      if (action == 'save') {
        if (widget.controller.activeDocument?.id != docId) {
          widget.controller.switchToDocumentById(docId);
        }
        final saved = await widget.controller.saveFile();
        if (!saved) return;
      }
    }

    widget.controller.closeDocument(docId);
  }

  Widget _buildSidebarFileItem({
    Key? itemKey,
    required String fileName,
    required String subtitlePath,
    required String subtitleTime,
    required bool isCurrent,
    required bool isOpen,
    required bool isModified,
    bool hasConflict = false,
    required ThemeData theme,
    required bool isDark,
    required Color lightTextColor,
    required String closeTooltip,
    required VoidCallback onTap,
    required VoidCallback onCloseOrRemove,
  }) {
    final itemBg = isCurrent
        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.08)
        : Colors.transparent;
    final secondaryTextColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final primaryTextColor = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final titleColor = isCurrent
        ? theme.colorScheme.primary
        : (isOpen ? primaryTextColor : secondaryTextColor);
    final iconColor = isCurrent
        ? theme.colorScheme.primary
        : (isOpen ? primaryTextColor : lightTextColor);

    return Container(
      key: itemKey,
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: isCurrent
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: Material(
        color: itemBg,
        borderRadius: BorderRadius.circular(6),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 2,
          ),
          visualDensity: VisualDensity.compact,
          dense: true,
          leading: Icon(Icons.description_outlined, size: 18, color: iconColor),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isOpen ? FontWeight.w700 : FontWeight.w400,
                    color: titleColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasConflict) ...[
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ] else if (isModified) ...[
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              // Path in light text
              Text(
                subtitlePath,
                style: TextStyle(
                  fontSize: 10,
                  color: lightTextColor,
                  fontFamily: 'Segoe UI',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitleTime,
                style: TextStyle(
                  fontSize: 9.5,
                  color: lightTextColor.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 14),
            tooltip: closeTooltip,
            splashRadius: 14,
            onPressed: onCloseOrRemove,
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildNavigationSectionHeader(ThemeData theme, Color lightTextColor) {
    return AnimatedBuilder(
      animation: widget.controller.textController,
      builder: (context, _) {
        final headingCount = widget.controller.headings.length;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
          child: Row(
            children: [
              Icon(Icons.format_list_bulleted, size: 14, color: lightTextColor),
              const SizedBox(width: 6),
              Text(
                'NAVIGATION ($headingCount)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: lightTextColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavigationCard(
    ThemeData theme,
    bool isDark,
    Color lightTextColor,
    Color borderColor,
  ) {
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final primaryTextColor = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;
    final secondaryTextColor = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        key: const ValueKey('sidebar-navigation-card'),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedBuilder(
          animation: widget.controller.textController,
          builder: (context, _) {
            final headings = widget.controller.headings;
            if (headings.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No headings in document',
                    style: TextStyle(fontSize: 11.5, color: lightTextColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              itemCount: headings.length,
              itemBuilder: (context, index) {
                final heading = headings[index];
                final indent = (heading.level - 1) * 12.0;
                final isPrimaryHeading = heading.level <= 2;

                return _NavigationHeadingItem(
                  key: ValueKey('sidebar-nav-heading-${heading.headingIndex}'),
                  title: heading.title,
                  level: heading.level,
                  indent: indent,
                  textColor: isPrimaryHeading
                      ? primaryTextColor
                      : secondaryTextColor,
                  accentColor: theme.colorScheme.primary,
                  isDark: isDark,
                  onTap: () => widget.controller.jumpToHeading(heading),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSyncScrollToggle(
    ThemeData theme,
    bool isDark,
    Color lightTextColor,
  ) {
    final isLinked = widget.controller.isLinkedScrolling;
    final textColor = isDark
        ? AppTheme.darkTextPrimary
        : AppTheme.lightTextPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: InkWell(
        key: const ValueKey('sidebar-sync-scroll-row'),
        borderRadius: BorderRadius.circular(6),
        onTap: () => widget.controller.setLinkedScrolling(!isLinked),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  key: const ValueKey('sidebar-sync-scroll-checkbox'),
                  value: isLinked,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (val) {
                    if (val != null) {
                      widget.controller.setLinkedScrolling(val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sync scroll',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(ThemeData theme, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 15),
              label: const Text('New', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: widget.onNewFile,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.file_open_outlined, size: 15),
              label: const Text('Open...', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: widget.onOpenFile,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationHeadingItem extends StatefulWidget {
  final String title;
  final int level;
  final double indent;
  final Color textColor;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _NavigationHeadingItem({
    super.key,
    required this.title,
    required this.level,
    required this.indent,
    required this.textColor,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_NavigationHeadingItem> createState() => _NavigationHeadingItemState();
}

class _NavigationHeadingItemState extends State<_NavigationHeadingItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = widget.accentColor.withValues(
      alpha: widget.isDark ? 0.18 : 0.10,
    );
    final hoverBorder = widget.accentColor.withValues(
      alpha: widget.isDark ? 0.45 : 0.35,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: EdgeInsets.fromLTRB(8.0 + widget.indent, 5, 8, 5),
          decoration: BoxDecoration(
            color: _isHovered ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: _isHovered ? hoverBorder : Colors.transparent,
            ),
          ),
          child: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: widget.level == 1
                  ? 12.5
                  : (widget.level == 2 ? 12.0 : 11.5),
              fontWeight: widget.level == 1
                  ? FontWeight.w700
                  : (widget.level == 2 ? FontWeight.w600 : FontWeight.w400),
              color: _isHovered ? widget.accentColor : widget.textColor,
            ),
          ),
        ),
      ),
    );
  }
}
