import 'package:flutter/material.dart';
import '../../controllers/editor_controller.dart';
import '../../models/history_entry.dart';
import '../theme/app_theme.dart';

/// Collapsible left navigation bar displaying the active document
/// (with light path) and file history for seamless switching.
class AppSidebar extends StatefulWidget {
  final EditorController controller;
  final VoidCallback onOpenFile;
  final VoidCallback onNewFile;

  const AppSidebar({
    super.key,
    required this.controller,
    required this.onOpenFile,
    required this.onNewFile,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  String _searchFilter = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sidebarBg = isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final lightTextColor =
        isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar top header
          _buildHeader(theme, borderColor),

          // Currently open file card
          _buildActiveFileCard(theme, isDark, lightTextColor, borderColor),

          const SizedBox(height: 12),

          // Search bar for history
          _buildHistorySearchBar(theme, isDark, borderColor),

          // History header with clear action
          _buildHistorySectionHeader(theme, lightTextColor),

          // History list
          Expanded(
            child: _buildHistoryList(theme, isDark, lightTextColor, borderColor),
          ),

          // Bibliography & Zotero status bar
          _buildBibliographyStatusBar(theme, isDark, lightTextColor, borderColor),

          // Bottom quick action buttons
          _buildBottomActions(theme, borderColor),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          const Text(
            'Draftdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            tooltip: 'Collapse Sidebar (Ctrl+\\)',
            splashRadius: 18,
            onPressed: widget.controller.toggleSidebar,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isModified
                ? theme.colorScheme.primary.withValues(alpha: 0.5)
                : borderColor,
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
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      Text(
                        'CURRENT FILE',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isModified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1.5),
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
            // File Name
            Text(
              fileName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                        child: Icon(Icons.folder_open,
                            size: 15, color: lightTextColor),
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
    final history = widget.controller.history;
    final filtered = _searchFilter.isEmpty
        ? history
        : history.where((entry) {
            return entry.fileName.toLowerCase().contains(_searchFilter) ||
                entry.path.toLowerCase().contains(_searchFilter);
          }).toList();

    if (filtered.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        final isCurrent = entry.path == widget.controller.currentFilePath;

        return _buildHistoryItem(
          entry: entry,
          isCurrent: isCurrent,
          theme: theme,
          isDark: isDark,
          lightTextColor: lightTextColor,
          borderColor: borderColor,
        );
      },
    );
  }

  Widget _buildHistoryItem({
    required HistoryEntry entry,
    required bool isCurrent,
    required ThemeData theme,
    required bool isDark,
    required Color lightTextColor,
    required Color borderColor,
  }) {
    final itemBg = isCurrent
        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.08)
        : Colors.transparent;

    return Container(
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        visualDensity: VisualDensity.compact,
        dense: true,
        leading: Icon(
          Icons.description_outlined,
          size: 18,
          color: isCurrent ? theme.colorScheme.primary : lightTextColor,
        ),
        title: Text(
          entry.fileName,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
            color: isCurrent ? theme.colorScheme.primary : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            // Path in light text
            Text(
              entry.path,
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
              entry.relativeTime,
              style: TextStyle(
                fontSize: 9.5,
                color: lightTextColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 14),
          tooltip: 'Remove from history',
          splashRadius: 14,
          onPressed: () async {
            await widget.controller.historyService.removeEntry(entry.path);
            setState(() {});
          },
        ),
        onTap: () async {
          // If currently editing and modified, ask to save or switch
          if (widget.controller.isModified) {
            final discardOrSave = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Unsaved Changes'),
                content: Text(
                  'Save changes to ${widget.controller.currentFileName} before opening ${entry.fileName}?',
                ),
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
                    child: const Text('Save & Open'),
                  ),
                ],
              ),
            );

            if (discardOrSave == 'cancel' || discardOrSave == null) return;
            if (discardOrSave == 'save') {
              await widget.controller.saveFile();
            }
          }

          await widget.controller.openFile(entry.path);
        },
      ),
    ),
  );
  }

  Widget _buildBibliographyStatusBar(
    ThemeData theme,
    bool isDark,
    Color lightTextColor,
    Color borderColor,
  ) {
    final status = widget.controller.bibliographyStatus;
    final isZotero = widget.controller.isZoteroConnected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        border: Border(
          top: BorderSide(color: borderColor.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isZotero ? Icons.sync : Icons.book_outlined,
            size: 14,
            color: isZotero ? Colors.green : lightTextColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10.5,
                color: lightTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 14),
            tooltip: 'Check Zotero & Bibliography',
            splashRadius: 14,
            onPressed: () async {
              await widget.controller.checkZoteroConnection();
            },
          ),
        ],
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
