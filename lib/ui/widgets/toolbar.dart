import 'package:flutter/material.dart';
import '../../controllers/editor_controller.dart';
import '../theme/app_theme.dart';

/// Top application toolbar with document metadata, responsive view mode switcher,
/// formatting tools, citation trigger, and Pandoc export.
class AppToolbar extends StatelessWidget {
  final EditorController controller;
  final VoidCallback onOpenCitationDialog;
  final VoidCallback onOpenExportDialog;
  final VoidCallback onOpenSettingsDialog;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const AppToolbar({
    super.key,
    required this.controller,
    required this.onOpenCitationDialog,
    required this.onOpenExportDialog,
    required this.onOpenSettingsDialog,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isDarkMode ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surfaceColor =
        isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface;
    final mutedText =
        isDarkMode ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

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
              final isCompact = constraints.maxWidth < 850;

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    // Sidebar toggle
                    if (!controller.isSidebarOpen)
                      IconButton(
                        icon: const Icon(Icons.menu, size: 20),
                        tooltip: 'Open Navigation (Ctrl+\\)',
                        splashRadius: 18,
                        onPressed: controller.toggleSidebar,
                      ),

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
                          if (controller.isModified) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
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
                          horizontal: 8, vertical: 3),
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

                    const Spacer(),

                    // View Mode Switcher: Edit, Split, Preview
                    _buildViewModeSegmented(isCompact),

                    const SizedBox(width: 8),

                    // Insert Citation Button (@)
                    if (isCompact)
                      IconButton(
                        icon: const Icon(Icons.format_quote, size: 18),
                        tooltip: 'Insert Citation (Ctrl+Shift+C)',
                        splashRadius: 18,
                        onPressed: onOpenCitationDialog,
                      )
                    else
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.format_quote, size: 16),
                        label: const Text('Citation',
                            style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        ),
                        onPressed: onOpenCitationDialog,
                      ),

                    const SizedBox(width: 6),

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
                        label: const Text('Export',
                            style: TextStyle(fontSize: 12)),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        ),
                        onPressed: onOpenExportDialog,
                      ),

                    const SizedBox(width: 4),

                    // Settings
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      tooltip: 'Settings (Pandoc & Zotero)',
                      splashRadius: 18,
                      onPressed: onOpenSettingsDialog,
                    ),

                    // Theme toggle
                    IconButton(
                      icon: Icon(
                        isDarkMode
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        size: 18,
                      ),
                      tooltip:
                          isDarkMode ? 'Switch to Light' : 'Switch to Dark',
                      splashRadius: 18,
                      onPressed: onToggleTheme,
                    ),
                  ],
                ),
              );
            },
          ),

          // Secondary Markdown Quick-Formatting Bar (horizontally scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: borderColor.withValues(alpha: 0.5)),
                ),
              ),
              child: Row(
                children: [
                  _buildFormatBtn(
                    icon: Icons.format_bold,
                    tooltip: 'Bold (**text**)',
                    onTap: () => controller.formatSelection('**'),
                  ),
                  _buildFormatBtn(
                    icon: Icons.format_italic,
                    tooltip: 'Italic (*text*)',
                    onTap: () => controller.formatSelection('*'),
                  ),
                  _buildFormatBtn(
                    icon: Icons.format_strikethrough,
                    tooltip: 'Strikethrough (~~text~~)',
                    onTap: () => controller.formatSelection('~~'),
                  ),
                  _buildDivider(borderColor),
                  _buildFormatBtn(
                    icon: Icons.title,
                    tooltip: 'Heading 1 (# Heading)',
                    onTap: () => controller.formatSelection('# '),
                  ),
                  _buildFormatBtn(
                    icon: Icons.format_size,
                    tooltip: 'Heading 2 (## Heading)',
                    onTap: () => controller.formatSelection('## '),
                  ),
                  _buildDivider(borderColor),
                  _buildFormatBtn(
                    icon: Icons.format_quote_outlined,
                    tooltip: 'Blockquote (> quote)',
                    onTap: () => controller.formatSelection('> '),
                  ),
                  _buildFormatBtn(
                    icon: Icons.code,
                    tooltip: 'Inline Code (`code`)',
                    onTap: () => controller.formatSelection('`'),
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
                    onTap: () => controller.formatSelection('- '),
                  ),
                  _buildFormatBtn(
                    icon: Icons.format_list_numbered,
                    tooltip: 'Numbered List (1. item)',
                    onTap: () => controller.formatSelection('1. '),
                  ),
                  _buildFormatBtn(
                    icon: Icons.check_box_outlined,
                    tooltip: 'Task List (- [ ] task)',
                    onTap: () => controller.formatSelection('- [ ] '),
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
                  _buildFormatBtn(
                    icon: Icons.alternate_email,
                    tooltip: 'Insert Citation (@)',
                    onTap: onOpenCitationDialog,
                  ),
                ],
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
          label: isCompact ? null : const Text('Edit', style: TextStyle(fontSize: 11)),
        ),
        ButtonSegment(
          value: EditorViewMode.split,
          icon: const Icon(Icons.vertical_split, size: 14),
          label: isCompact ? null : const Text('Split', style: TextStyle(fontSize: 11)),
        ),
        ButtonSegment(
          value: EditorViewMode.preview,
          icon: const Icon(Icons.visibility, size: 14),
          label: isCompact ? null : const Text('Preview', style: TextStyle(fontSize: 11)),
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

  Widget _buildDivider(Color borderColor) {
    return Container(
      width: 1,
      height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: borderColor.withValues(alpha: 0.6),
    );
  }
}
