import 'package:flutter/material.dart';

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

                    // Right area: Export button
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Export Button
                          if (isCompact)
                            IconButton(
                              icon: const Icon(Icons.output, size: 18),
                              tooltip: 'Export Document (Ctrl+E)',
                              splashRadius: 18,
                              onPressed: onOpenExportDialog,
                            )
                          else
                            FilledButton.icon(
                              icon: const Icon(Icons.output, size: 16),
                              label: const Text(
                                'Export',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: onOpenExportDialog,
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
