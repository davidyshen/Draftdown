import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/editor_controller.dart';
import '../theme/app_theme.dart';

/// Top application toolbar with document metadata, responsive view mode switcher,
/// formatting tools, citation trigger, and Pandoc export.
class AppToolbar extends StatelessWidget {
  final EditorController controller;
  final VoidCallback onInsertImage;
  final VoidCallback onOpenCitationDialog;
  final VoidCallback onOpenExportDialog;
  final bool isDarkMode;

  const AppToolbar({
    super.key,
    required this.controller,
    required this.onInsertImage,
    required this.onOpenCitationDialog,
    required this.onOpenExportDialog,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDarkMode ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surfaceColor = isDarkMode
        ? AppTheme.darkSurface
        : AppTheme.lightSurface;
    final mutedText = isDarkMode
        ? AppTheme.darkTextMuted
        : AppTheme.lightTextMuted;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          // Main Top App Bar - Responsive with LayoutBuilder
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 800;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    // Left area: document title, word count
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Document title & modified status
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    controller.currentFileName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (controller.hasConflict) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'Conflict: file modified on disk',
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ] else if (controller.isModified) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'Unsaved changes',
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Colors.amber,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Word count & Read time chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isCompact
                                  ? '${controller.wordCount}w'
                                  : '${controller.wordCount} words • ~${controller.readingTimeMinutes}m',
                              style: TextStyle(
                                fontSize: 11,
                                color: mutedText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Centred View Mode Switcher: Edit, Split, Preview
                    _buildViewModeSegmented(isCompact),

                    // Right area: Search & Export button
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ToolbarSearchPill(
                            controller: controller,
                            isDarkMode: isDarkMode,
                            borderColor: borderColor,
                          ),
                          const SizedBox(width: 8),
                          // Export Button
                          if (isCompact)
                            IconButton(
                              icon: const Icon(Icons.output, size: 18),
                              tooltip: 'Export Document (Ctrl+E)',
                              splashRadius: 18,
                              onPressed: onOpenExportDialog,
                            )
                          else
                            SizedBox(
                              height: 32,
                              child: FilledButton.icon(
                                key: const ValueKey('toolbar-export-btn'),
                                icon: const Icon(Icons.output, size: 16),
                                label: const Text(
                                  'Export',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 0,
                                  ),
                                ),
                                onPressed: onOpenExportDialog,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Secondary Markdown Quick-Formatting Bar (horizontally scrollable, centred)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: borderColor.withValues(alpha: 0.5)),
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFormatBtn(
                      icon: Icons.format_bold,
                      tooltip: 'Bold (**text**)',
                      onTap: () => controller.formatSelection('**', '**'),
                    ),
                    _buildFormatBtn(
                      icon: Icons.format_italic,
                      tooltip: 'Italic (*text*)',
                      onTap: () => controller.formatSelection('*', '*'),
                    ),
                    _buildFormatBtn(
                      icon: Icons.format_strikethrough,
                      tooltip: 'Strikethrough (~~text~~)',
                      onTap: () => controller.formatSelection('~~', '~~'),
                    ),
                    _buildFormatBtn(
                      icon: Icons.superscript,
                      tooltip: 'Superscript (^text^)',
                      onTap: () => controller.formatSelection('^', '^'),
                    ),
                    _buildFormatBtn(
                      icon: Icons.subscript,
                      tooltip: 'Subscript (~text~)',
                      onTap: () => controller.formatSelection('~', '~'),
                    ),
                    _buildDivider(borderColor),
                    _buildFormatBtn(
                      icon: Icons.title,
                      tooltip: 'Heading 1 (# Heading)',
                      onTap: () => controller.formatSelection('# ', ''),
                    ),
                    _buildFormatBtn(
                      icon: Icons.format_size,
                      tooltip: 'Heading 2 (## Heading)',
                      onTap: () => controller.formatSelection('## ', ''),
                    ),
                    _buildDivider(borderColor),
                    _buildFormatBtn(
                      icon: Icons.format_quote_outlined,
                      tooltip: 'Blockquote (> quote)',
                      onTap: () => controller.formatSelection('> ', ''),
                    ),
                    _buildFormatBtn(
                      icon: Icons.code,
                      tooltip: 'Inline Code (`code`)',
                      onTap: () => controller.formatSelection('`', '`'),
                    ),
                    _buildFormatBtn(
                      icon: Icons.data_object,
                      tooltip: 'Code Block (```)',
                      onTap: () => controller.formatSelection('```\n', '\n```'),
                    ),
                    _buildDivider(borderColor),
                    _buildFormatBtn(
                      icon: Icons.format_list_bulleted,
                      tooltip: 'Bullet List (- item)',
                      onTap: () => controller.formatSelection('- ', ''),
                    ),
                    _buildFormatBtn(
                      icon: Icons.format_list_numbered,
                      tooltip: 'Numbered List (1. item)',
                      onTap: () => controller.formatSelection('1. ', ''),
                    ),
                    _buildFormatBtn(
                      icon: Icons.check_box_outlined,
                      tooltip: 'Task List (- [ ] task)',
                      onTap: () => controller.formatSelection('- [ ] ', ''),
                    ),
                    _buildDivider(borderColor),
                    _buildFormatBtn(
                      icon: Icons.link,
                      tooltip: 'Link ([text](url))',
                      onTap: () =>
                          controller.formatSelection('[', '](https://)'),
                    ),
                    _buildFormatBtn(
                      icon: Icons.table_chart_outlined,
                      tooltip: 'Table Template',
                      onTap: () => controller.insertText(
                        '\n| Header 1 | Header 2 |\n| :--- | :--- |\n| Value 1 | Value 2 |\n',
                      ),
                    ),
                    _buildDivider(borderColor),
                    _buildFormatBtn(
                      icon: Icons.image_outlined,
                      tooltip: 'Insert Image',
                      onTap: onInsertImage,
                    ),
                    _buildDivider(borderColor),
                    _buildCitationBtn(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeSegmented(bool isCompact) {
    return SegmentedButton<EditorViewMode>(
      segments: [
        ButtonSegment(
          value: EditorViewMode.edit,
          icon: const Icon(Icons.edit, size: 14),
          label: isCompact
              ? null
              : const Text('Edit', style: TextStyle(fontSize: 11)),
        ),
        ButtonSegment(
          value: EditorViewMode.split,
          icon: const Icon(Icons.vertical_split, size: 14),
          label: isCompact
              ? null
              : const Text('Split', style: TextStyle(fontSize: 11)),
        ),
        ButtonSegment(
          value: EditorViewMode.preview,
          icon: const Icon(Icons.visibility, size: 14),
          label: isCompact
              ? null
              : const Text('Preview', style: TextStyle(fontSize: 11)),
        ),
      ],
      selected: {controller.viewMode},
      onSelectionChanged: (Set<EditorViewMode> newSelection) {
        controller.setViewMode(newSelection.first);
      },
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildFormatBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }

  Widget _buildCitationBtn() {
    return Tooltip(
      message: 'Insert Academic Citation (Ctrl+Shift+C or @)',
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onOpenCitationDialog,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            'Cite',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(Color borderColor) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: borderColor.withValues(alpha: 0.6),
    );
  }
}

class _ToolbarSearchPill extends StatefulWidget {
  final EditorController controller;
  final bool isDarkMode;
  final Color borderColor;

  const _ToolbarSearchPill({
    required this.controller,
    required this.isDarkMode,
    required this.borderColor,
  });

  @override
  State<_ToolbarSearchPill> createState() => _ToolbarSearchPillState();
}

class _ToolbarSearchPillState extends State<_ToolbarSearchPill> {
  bool _isExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.controller.searchFocusRequests.addListener(_onSearchFocusRequested);
  }

  @override
  void didUpdateWidget(covariant _ToolbarSearchPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.searchFocusRequests.removeListener(
        _onSearchFocusRequested,
      );
      widget.controller.searchFocusRequests.addListener(
        _onSearchFocusRequested,
      );
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.searchFocusRequests.removeListener(
      _onSearchFocusRequested,
    );
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus &&
        _isExpanded &&
        _searchController.text.trim().isEmpty) {
      _collapse();
    }
  }

  void _onSearchFocusRequested() {
    if (!_isExpanded) {
      _expand();
    } else {
      _focusNode.requestFocus();
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    }
  }

  void _expand() {
    if (_isExpanded) return;
    setState(() => _isExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isExpanded) {
        _focusNode.requestFocus();
      }
    });
  }

  void _collapse() {
    if (!_isExpanded) return;
    _searchController.clear();
    widget.controller.clearSearch();
    setState(() => _isExpanded = false);
  }

  void _submitSearch() {
    final query = _searchController.text;
    if (query.isEmpty) {
      widget.controller.clearSearch();
      return;
    }
    widget.controller.searchNext(query);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final activeIconColor = accent.computeLuminance() > 0.55
        ? Colors.black87
        : Colors.white;
    final pillBg = widget.isDarkMode
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final mutedText = widget.isDarkMode
        ? AppTheme.darkTextMuted
        : AppTheme.lightTextMuted;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _collapse,
      },
      child: AnimatedContainer(
        key: const ValueKey('toolbar-search-pill'),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: _isExpanded ? 210 : 32,
        height: 32,
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: widget.borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: _isExpanded
            ? OverflowBox(
                alignment: Alignment.centerRight,
                minWidth: 210,
                maxWidth: 210,
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('toolbar-search-input'),
                        controller: _searchController,
                        focusNode: _focusNode,
                        style: const TextStyle(fontSize: 12),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(fontSize: 12, color: mutedText),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _submitSearch(),
                        onChanged: (val) {
                          if (val.isEmpty) {
                            widget.controller.clearSearch();
                          }
                        },
                      ),
                    ),
                    Tooltip(
                      message: 'Close search (Esc)',
                      child: InkWell(
                        key: const ValueKey('toolbar-search-close-btn'),
                        borderRadius: BorderRadius.circular(999),
                        onTap: _collapse,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close, size: 14, color: mutedText),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Tooltip(
                      message: 'Find next (Enter)',
                      child: Material(
                        color: accent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          key: const ValueKey('toolbar-search-action-btn'),
                          customBorder: const CircleBorder(),
                          onTap: _submitSearch,
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: Icon(
                              Icons.search,
                              size: 15,
                              color: activeIconColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                  ],
                ),
              )
            : Tooltip(
                message: 'Search in document (Ctrl+F)',
                child: InkWell(
                  key: const ValueKey('toolbar-search-toggle-btn'),
                  customBorder: const CircleBorder(),
                  onTap: _expand,
                  child: Center(
                    child: Icon(Icons.search, size: 16, color: mutedText),
                  ),
                ),
              ),
      ),
    );
  }
}
