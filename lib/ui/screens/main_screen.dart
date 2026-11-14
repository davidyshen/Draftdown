import 'package:flutter/material.dart';
import '../../controllers/editor_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/citation_dialog.dart';
import '../widgets/editor_view.dart';
import '../widgets/export_dialog.dart';
import '../widgets/markdown_preview.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/sidebar.dart';
import '../widgets/toolbar.dart';

/// The main application screen composed of the collapsible left navigation bar,
/// the top toolbar, and the Markdown editor/preview workspace.
class MainScreen extends StatefulWidget {
  final EditorController controller;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const MainScreen({
    super.key,
    required this.controller,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  void _openCitationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CitationDialog(controller: widget.controller),
    );
  }

  void _openExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => ExportDialog(
        controller: widget.controller,
        onOpenSettings: _openSettingsDialog,
      ),
    );
  }

  void _openSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SettingsDialog(controller: widget.controller),
    );
  }

  Future<void> _handleNewFile() async {
    if (widget.controller.isModified) {
      final shouldSave = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: Text(
            'Save changes to ${widget.controller.currentFileName} before creating a new document?',
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
              child: const Text('Save & New'),
            ),
          ],
        ),
      );

      if (shouldSave == 'cancel' || shouldSave == null) return;
      if (shouldSave == 'save') {
        await widget.controller.saveFile();
      }
    }

    widget.controller.newFile();
  }

  Future<void> _handleOpenFile() async {
    if (widget.controller.isModified) {
      final shouldSave = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: Text(
            'Save changes to ${widget.controller.currentFileName} before opening another document?',
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

      if (shouldSave == 'cancel' || shouldSave == null) return;
      if (shouldSave == 'save') {
        await widget.controller.saveFile();
      }
    }

    await widget.controller.openFile();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final viewMode = widget.controller.viewMode;
        final isSidebarOpen = widget.controller.isSidebarOpen;

        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Collapsible Sidebar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: isSidebarOpen ? 290 : 0,
                child: isSidebarOpen
                    ? RepaintBoundary(
                        child: AppSidebar(
                          controller: widget.controller,
                          onOpenFile: _handleOpenFile,
                          onNewFile: _handleNewFile,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Main Editor Area
              Expanded(
                child: Column(
                  children: [
                    // Top App Toolbar
                    RepaintBoundary(
                      child: AppToolbar(
                        controller: widget.controller,
                        onOpenCitationDialog: _openCitationDialog,
                        onOpenExportDialog: _openExportDialog,
                        onOpenSettingsDialog: _openSettingsDialog,
                        onToggleTheme: widget.onToggleTheme,
                        isDarkMode: widget.isDarkMode,
                      ),
                    ),

                    // Editor / Preview Split or Single View
                    Expanded(
                      child: _buildEditorWorkspace(viewMode, borderColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget? _cachedEditorView;

  Widget _getEditorView() {
    return _cachedEditorView ??= RepaintBoundary(
      child: EditorView(
        controller: widget.controller,
        onOpenCitation: _openCitationDialog,
        onOpenExport: _openExportDialog,
        onOpenFile: _handleOpenFile,
        onNewFile: _handleNewFile,
      ),
    );
  }

  Widget _buildEditorWorkspace(EditorViewMode mode, Color borderColor) {
    final editor = _getEditorView();

    if (mode == EditorViewMode.preview) {
      return ValueListenableBuilder<String>(
        valueListenable: widget.controller.previewNotifier,
        builder: (context, previewText, _) {
          return MarkdownPreviewView(
            markdown: previewText.isNotEmpty
                ? previewText
                : widget.controller.previewMarkdown,
            bodyFont: widget.controller.renderBodyFont,
            headerFont: widget.controller.effectiveRenderHeaderFont,
            codeFont: widget.controller.editorFontFamily,
            controller: widget.controller,
            isFullView: true,
          );
        },
      );
    }

    if (mode == EditorViewMode.edit) {
      return editor;
    }

    final preview = ValueListenableBuilder<String>(
      valueListenable: widget.controller.previewNotifier,
      builder: (context, previewText, _) {
        return MarkdownPreviewView(
          markdown: previewText.isNotEmpty
              ? previewText
              : widget.controller.previewMarkdown,
          bodyFont: widget.controller.renderBodyFont,
          headerFont: widget.controller.effectiveRenderHeaderFont,
          codeFont: widget.controller.editorFontFamily,
          controller: widget.controller,
          isFullView: false,
        );
      },
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: editor),
        Container(width: 1, color: borderColor),
        Expanded(flex: 5, child: preview),
      ],
    );
  }
}
