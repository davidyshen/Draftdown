import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../controllers/editor_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/citation_dialog.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/editor_view.dart';
import '../widgets/export_dialog.dart';
import '../widgets/markdown_preview.dart';
import '../widgets/paste_image_dialog.dart';
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
  bool _showFloatingSidebar = false;
  bool _isHoveringHamburger = false;
  bool _isHoveringFloatingSidebar = false;
  bool _isConflictDialogOpen = false;
  Timer? _startupPeekTimer;
  Timer? _floatingCloseTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    if (!widget.controller.isSidebarOpen) {
      _showFloatingSidebar = true;
      _startupPeekTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        if (!_isHoveringHamburger && !_isHoveringFloatingSidebar) {
          setState(() => _showFloatingSidebar = false);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _startupPeekTimer?.cancel();
    _floatingCloseTimer?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted || _isConflictDialogOpen) return;
    if (widget.controller.shouldPromptConflict) {
      _isConflictDialogOpen = true;
      widget.controller.markConflictPrompted();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showConflictDialog();
        } else {
          _isConflictDialogOpen = false;
        }
      });
    }
  }

  Future<void> _showConflictDialog() async {
    try {
      final fileName = widget.controller.currentFileName;
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('File Conflict'),
            ],
          ),
          content: Text(
            'There are unsaved changes in $fileName, but the file on disk has been modified.\n\n'
            'Do you want to discard your changes or save as a new file?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Discard Changes'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save_as'),
              child: const Text('Save as New File'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (action == 'discard') {
        await widget.controller.discardChangesAndReloadFromDisk();
      } else if (action == 'save_as') {
        await widget.controller.saveFileAs();
      }
    } finally {
      _isConflictDialogOpen = false;
    }
  }

  void _onHamburgerHoverChanged(bool isHovering) {
    _isHoveringHamburger = isHovering;
    if (widget.controller.isSidebarOpen) return;

    if (isHovering) {
      _floatingCloseTimer?.cancel();
      _floatingCloseTimer = null;
      if (!_showFloatingSidebar) {
        setState(() => _showFloatingSidebar = true);
      }
    } else {
      _scheduleFloatingSidebarClose();
    }
  }

  void _onFloatingSidebarHoverChanged(bool isHovering) {
    _isHoveringFloatingSidebar = isHovering;
    if (isHovering) {
      _floatingCloseTimer?.cancel();
      _floatingCloseTimer = null;
    } else {
      _scheduleFloatingSidebarClose();
    }
  }

  void _scheduleFloatingSidebarClose() {
    _floatingCloseTimer?.cancel();
    _floatingCloseTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      if (!_isHoveringHamburger && !_isHoveringFloatingSidebar) {
        setState(() => _showFloatingSidebar = false);
      }
    });
  }

  void _openCitationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CitationDialog(controller: widget.controller),
    );
  }

  Future<void> _insertImage() async {
    final pickedPath = await widget.controller.fileService.pickImageFile();
    if (pickedPath == null || !mounted) return;

    final file = File(pickedPath);
    if (!await file.exists() || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final rawExt = p.extension(pickedPath).toLowerCase().replaceFirst('.', '');
    final ext = rawExt.isEmpty ? 'png' : rawExt;

    await PasteImageDialog.promptAndSaveImage(
      context: context,
      controller: widget.controller,
      imageBytes: bytes,
      defaultExtension: ext,
      initialFilename: p.basename(pickedPath),
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
    widget.controller.newFile();
  }

  Future<void> _handleOpenFile() async {
    await widget.controller.openFile();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final viewMode = widget.controller.viewMode;
        final isSidebarOpen = widget.controller.isSidebarOpen;
        final showFloating = !isSidebarOpen && _showFloatingSidebar;

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
              widget.controller.requestSearchFocus();
            },
          },
          child: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomTitleBar(
                  controller: widget.controller,
                  onHamburgerHoverChanged: _onHamburgerHoverChanged,
                  isDarkMode: widget.isDarkMode,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Collapsible Docked Sidebar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            width: isSidebarOpen ? 290 : 0,
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                minWidth: 290,
                                maxWidth: 290,
                                child: isSidebarOpen
                                    ? RepaintBoundary(
                                        child: AppSidebar(
                                          controller: widget.controller,
                                          onOpenFile: _handleOpenFile,
                                          onNewFile: _handleNewFile,
                                          onOpenSettingsDialog:
                                              _openSettingsDialog,
                                          onToggleTheme: widget.onToggleTheme,
                                          onResolveConflict:
                                              _showConflictDialog,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),

                          // Main Editor Area
                          Expanded(
                            child: Column(
                              children: [
                                // Top App Toolbar
                                RepaintBoundary(
                                  child: AppToolbar(
                                    controller: widget.controller,
                                    onInsertImage: _insertImage,
                                    onOpenCitationDialog: _openCitationDialog,
                                    onOpenExportDialog: _openExportDialog,
                                    isDarkMode: widget.isDarkMode,
                                  ),
                                ),

                                // Editor / Preview Split or Single View
                                Expanded(
                                  child: _buildEditorWorkspace(
                                    viewMode,
                                    borderColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Floating Hover Sidebar (also peeks for 1s on startup)
                      if (!isSidebarOpen)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          left: showFloating ? 10 : -310,
                          top: 10,
                          bottom: 10,
                          width: 290,
                          child: MouseRegion(
                            onEnter: (_) =>
                                _onFloatingSidebarHoverChanged(true),
                            onExit: (_) =>
                                _onFloatingSidebarHoverChanged(false),
                            child: RepaintBoundary(
                              child: AppSidebar(
                                key: const ValueKey('floating-sidebar'),
                                controller: widget.controller,
                                onOpenFile: _handleOpenFile,
                                onNewFile: _handleNewFile,
                                onOpenSettingsDialog: _openSettingsDialog,
                                onToggleTheme: widget.onToggleTheme,
                                onResolveConflict: _showConflictDialog,
                                isFloating: true,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  final GlobalKey _editorViewKey = GlobalKey();
  Widget? _cachedEditorView;

  Widget _getEditorView() {
    return _cachedEditorView ??= RepaintBoundary(
      key: _editorViewKey,
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
            scrollController: widget.controller.previewScrollController,
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
          scrollController: widget.controller.previewScrollController,
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
