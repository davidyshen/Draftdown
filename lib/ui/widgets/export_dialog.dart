import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;

import '../../controllers/editor_controller.dart';
import '../../models/export_format.dart';
import '../../services/markdown_render_service.dart'
    show
        MarkdownRenderPayload,
        MarkdownRenderResult,
        MarkdownRenderService;
import '../../services/pandoc_service.dart';
import '../theme/app_theme.dart';
import 'markdown_preview.dart';

/// Modal dialog providing multi-format document export, citation processing,
/// options configuration, and execution log monitoring.
class ExportDialog extends StatefulWidget {
  final EditorController controller;
  final VoidCallback onOpenSettings;

  const ExportDialog({
    super.key,
    required this.controller,
    required this.onOpenSettings,
  });

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  ExportFormat _selectedFormat = ExportFormat.supportedFormats.first;
  final TextEditingController _targetPathController = TextEditingController();
  final TextEditingController _customArgsController = TextEditingController();

  bool _standalone = true;
  bool _tableOfContents = false;
  bool _useCiteproc = true;
  String _selectedPageSize = 'a4';
  String _selectedMarginSize = 'medium';
  double _fontScale = 1.0;
  bool _showAdvancedOptions = false;

  late final MarkdownRenderResult _previewRender;

  bool _isExporting = false;
  PandocResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _initialiseDefaultTargetPath();
    _previewRender = MarkdownRenderService.executeMarkdownRender(
      MarkdownRenderPayload(
        renderId: 0,
        rawMarkdown: widget.controller.content,
        citations: [
          ...widget.controller.bibliographyService.items,
          ...widget.controller.zoteroCitations,
        ],
        isNumericCitation: widget.controller.activeCslStyle.isNumeric,
      ),
    );
  }

  void _initialiseDefaultTargetPath() {
    final currentPath = widget.controller.currentFilePath;
    final baseName = widget.controller.currentFileName.replaceAll(
      RegExp(r'\.md$'),
      '',
    );

    if (currentPath != null) {
      final parentDir = File(currentPath).parent.path;
      _targetPathController.text =
          '$parentDir${Platform.pathSeparator}$baseName.${_selectedFormat.extension}';
    } else {
      _targetPathController.text = '$baseName.${_selectedFormat.extension}';
    }
  }

  void _onFormatChanged(ExportFormat format) {
    setState(() {
      _selectedFormat = format;
      final current = _targetPathController.text;
      if (current.isNotEmpty) {
        final lastDot = current.lastIndexOf('.');
        if (lastDot != -1) {
          _targetPathController.text =
              '${current.substring(0, lastDot)}.${format.extension}';
        } else {
          _targetPathController.text = '$current.${format.extension}';
        }
      }
    });
  }

  Future<void> _browseDestination() async {
    final defaultName =
        '${widget.controller.currentFileName.replaceAll(RegExp(r'\.md$'), '')}.${_selectedFormat.extension}';
    final picked = await widget.controller.fileService.pickExportLocation(
      defaultName: defaultName,
      extension: _selectedFormat.extension,
    );

    if (picked != null) {
      setState(() => _targetPathController.text = picked);
    }
  }

  Future<void> _startExport() async {
    final target = _targetPathController.text.trim();
    if (target.isEmpty) return;

    setState(() {
      _isExporting = true;
      _lastResult = null;
    });

    final options = ExportOptions(
      format: _selectedFormat,
      targetPath: target,
      standalone: _standalone,
      tableOfContents: _tableOfContents,
      useCiteproc: _useCiteproc,
      bibliographyPath: widget.controller.bibliographyPath,
      cslStylePath: widget.controller.activeEffectiveCslPath,
      customArguments: _customArgsController.text.trim(),
      pageSize: _selectedPageSize,
      marginSize: _selectedMarginSize,
      fontScale: _fontScale,
    );

    final result = await widget.controller.exportDocument(options);

    setState(() {
      _isExporting = false;
      _lastResult = result;
    });
  }

  @override
  void dispose() {
    _targetPathController.dispose();
    _customArgsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final mutedColor = isDark
        ? AppTheme.darkTextMuted
        : AppTheme.lightTextMuted;

    final showPreview =
        _selectedFormat.type == ExportFormatType.pdf ||
        _selectedFormat.type == ExportFormatType.html5;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: surfaceColor,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: showPreview ? 1000 : 820,
          maxHeight: 720,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.output,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Export Document',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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

              // Format Selection Grid
              const Text(
                'Select Output Format',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 105,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: ExportFormat.supportedFormats.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final fmt = ExportFormat.supportedFormats[index];
                    final isSelected = fmt == _selectedFormat;

                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _onFormatChanged(fmt),
                      child: Container(
                        width: 120,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                )
                              : (isDark
                                    ? AppTheme.darkSidebar
                                    : AppTheme.lightBg),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : borderColor,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              fmt.icon,
                              size: 26,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : mutedColor,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              fmt.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '.${fmt.extension}',
                              style: TextStyle(
                                fontSize: 10,
                                color: mutedColor,
                                fontFamily: 'Consolas, monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
              // Export destination field
              const Text(
                'Destination File',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _targetPathController,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Target output path...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: borderColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text(
                      'Browse...',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: _browseDestination,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Options: Citeproc, Standalone, TOC
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                  color: isDark ? AppTheme.darkSidebar : AppTheme.lightBg,
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _useCiteproc,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) =>
                              setState(() => _useCiteproc = val ?? true),
                        ),
                        const Text(
                          'Include Citations & References',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _standalone,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) =>
                              setState(() => _standalone = val ?? true),
                        ),
                        const Text(
                          'Standalone Document',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _tableOfContents,
                          visualDensity: VisualDensity.compact,
                          onChanged: (val) =>
                              setState(() => _tableOfContents = val ?? false),
                        ),
                        const Text(
                          'Table of Contents',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    if (_selectedFormat.type == ExportFormatType.pdf) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Page Size:',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(4),
                              color: isDark
                                  ? AppTheme.darkBg
                                  : AppTheme.lightSurface,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                key: const ValueKey('page-size-dropdown'),
                                value: _selectedPageSize,
                                isDense: true,
                                focusColor: Colors.transparent,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'a4',
                                    child: Text(
                                      'A4',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'letter',
                                    child: Text(
                                      'Letter',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedPageSize = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Margins:',
                            style: TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(4),
                              color: isDark
                                  ? AppTheme.darkBg
                                  : AppTheme.lightSurface,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                key: const ValueKey('margin-size-dropdown'),
                                value: _selectedMarginSize,
                                isDense: true,
                                focusColor: Colors.transparent,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'medium',
                                    child: Text(
                                      'Medium',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'thin',
                                    child: Text(
                                      'Thin',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'thick',
                                    child: Text(
                                      'Thick',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedMarginSize = val);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (showPreview) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Font Size:',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(
                            width: 115,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                              ),
                              child: Slider(
                                key: const ValueKey('font-scale-slider'),
                                value: _fontScale,
                                min: 0.7,
                                max: 1.5,
                                divisions: 16,
                                onChanged: (val) {
                                  setState(() => _fontScale = val);
                                },
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 38,
                            child: Text(
                              '${(_fontScale * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Advanced Options (Optional)
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => setState(
                  () => _showAdvancedOptions = !_showAdvancedOptions,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showAdvancedOptions
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 16,
                        color: mutedColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Advanced Options',
                        style: TextStyle(fontSize: 11, color: mutedColor),
                      ),
                    ],
                  ),
                ),
              ),

              if (_showAdvancedOptions) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: _customArgsController,
                  style: const TextStyle(
                    fontFamily: 'Consolas, monospace',
                    fontSize: 11.5,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Additional Arguments (Optional)',
                    labelStyle: const TextStyle(fontSize: 11),
                    hintText: 'e.g. --number-sections',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Execution / Status Log Area
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkBg : AppTheme.lightSidebar,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: _isExporting
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(strokeWidth: 2),
                              SizedBox(height: 12),
                              Text(
                                'Exporting document...',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      : _lastResult == null
                      ? Center(
                          child: Text(
                            'Ready to export ${_selectedFormat.name}. Click "Export Now" below.',
                            style: TextStyle(fontSize: 12, color: mutedColor),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _lastResult!.success
                                        ? Icons.check_circle
                                        : Icons.error_outline,
                                    size: 16,
                                    color: _lastResult!.success
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _lastResult!.success
                                        ? 'Export completed successfully in ${_lastResult!.duration.inMilliseconds}ms!'
                                        : 'Export failed with exit code ${_lastResult!.exitCode}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _lastResult!.success
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              if (_lastResult!.success) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(
                                        Icons.open_in_new,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'Open File',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => widget
                                          .controller
                                          .fileService
                                          .openFileWithSystemDefault(
                                            _lastResult!.targetFile,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.folder_open,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'Reveal in Explorer',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => widget
                                          .controller
                                          .fileService
                                          .revealInExplorer(
                                            _lastResult!.targetFile,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                              if (!_lastResult!.success &&
                                  _lastResult!.stderr.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _lastResult!.stderr,
                                  style: const TextStyle(
                                    fontFamily: 'Consolas, monospace',
                                    fontSize: 10.5,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                              if (_lastResult!.success &&
                                  _lastResult!.stderr.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _lastResult!.stderr,
                                  style: TextStyle(
                                    fontFamily: 'Consolas, monospace',
                                    fontSize: 10.5,
                                    color: mutedColor,
                                  ),
                                ),
                              ],
                              if (_lastResult!.stdout.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _lastResult!.stdout,
                                  style: TextStyle(
                                    fontFamily: 'Consolas, monospace',
                                    fontSize: 10.5,
                                    color: mutedColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
                        ],
                      ),
                    ),
                    if (showPreview) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildFirstPagePreview(
                          context: context,
                          isDark: isDark,
                          borderColor: borderColor,
                          mutedColor: mutedColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Export Now'),
                    onPressed: _isExporting ? null : _startExport,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Scaled first-page preview reflecting selected page size, margins, and font scale
  Widget _buildFirstPagePreview({
    required BuildContext context,
    required bool isDark,
    required Color borderColor,
    required Color mutedColor,
  }) {
    final isPdf = _selectedFormat.type == ExportFormatType.pdf;
    final isLetter = isPdf && _selectedPageSize.toLowerCase() == 'letter';
    final double pageWidth = isLetter ? 612.0 : 595.0;
    final double pageHeight = isLetter ? 792.0 : 842.0;

    final EdgeInsets pageMargins = !isPdf
        ? const EdgeInsets.all(56.0)
        : switch (_selectedMarginSize) {
            'thin' => const EdgeInsets.all(36.0),
            'thick' => const EdgeInsets.symmetric(vertical: 72.0, horizontal: 90.0),
            _ => const EdgeInsets.all(72.0),
          };

    final double baseFont = 11.0 * _fontScale;
    final bodyFont = widget.controller.renderBodyFont;
    final headerFont = widget.controller.effectiveRenderHeaderFont;
    final codeFont = widget.controller.editorFontFamily;
    const textColor = Color(0xFF0F172A);
    const codeGreen = Color(0xFF166534);
    const quoteTextColor = Color(0xFF475569);

    final lightTheme = AppTheme.lightTheme();
    final previewStyle = MarkdownStyleSheet.fromTheme(
      Theme.of(context),
    ).copyWith(
      p: TextStyle(
        fontFamily: bodyFont,
        fontSize: baseFont,
        height: 1.6,
        color: textColor,
      ),
      h1: TextStyle(
        fontFamily: headerFont,
        fontSize: baseFont * 2.1,
        fontWeight: FontWeight.bold,
        color: textColor,
        height: 1.35,
      ),
      h2: TextStyle(
        fontFamily: headerFont,
        fontSize: baseFont * 1.55,
        fontWeight: FontWeight.bold,
        color: textColor,
        height: 1.35,
      ),
      h3: TextStyle(
        fontFamily: headerFont,
        fontSize: baseFont * 1.25,
        fontWeight: FontWeight.bold,
        color: textColor,
        height: 1.35,
      ),
      h4: TextStyle(
        fontFamily: headerFont,
        fontSize: baseFont * 1.1,
        fontWeight: FontWeight.bold,
        color: textColor,
        height: 1.35,
      ),
      h5: TextStyle(
        fontFamily: headerFont,
        fontSize: baseFont,
        fontWeight: FontWeight.bold,
        color: textColor,
        height: 1.35,
      ),
      h6: TextStyle(
        fontFamily: headerFont,
        fontSize: baseFont * 0.9,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF64748B),
        height: 1.35,
      ),
      blockquote: TextStyle(
        fontFamily: bodyFont,
        fontSize: baseFont,
        fontStyle: FontStyle.italic,
        color: quoteTextColor,
      ),
      blockquoteDecoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          left: BorderSide(color: Color(0xFF2563EB), width: 3.5),
        ),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      code: TextStyle(
        fontFamily: codeFont,
        fontFamilyFallback: AppTheme.editorFontFamilyFallback,
        fontSize: baseFont * 0.92,
        backgroundColor: Colors.transparent,
        color: codeGreen,
      ),
      codeblockDecoration: const BoxDecoration(color: Colors.transparent),
      tableBody: TextStyle(
        fontFamily: bodyFont,
        fontSize: baseFont * 0.95,
        color: textColor,
      ),
      tableHead: TextStyle(
        fontFamily: headerFont,
        fontSize: baseFont * 0.95,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      tableBorder: TableBorder.all(color: const Color(0xFFCBD5E1), width: 1),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      tableColumnWidth: const FlexColumnWidth(),
    );

    final currentDoc = widget.controller.currentFilePath;
    final imgDir = (currentDoc != null && currentDoc.isNotEmpty)
        ? p.dirname(currentDoc)
        : Directory.current.path;

    final helper = CitationHelper(
      widget.controller,
      numericIndices: _previewRender.numericIndices,
    );

    final marginLabel = switch (_selectedMarginSize) {
      'thin' => 'Thin',
      'thick' => 'Thick',
      _ => 'Medium',
    };
    final summaryText = isPdf
        ? '${_selectedPageSize.toUpperCase()} • $marginLabel • ${(_fontScale * 100).round()}%'
        : 'HTML • ${(_fontScale * 100).round()}%';

    return Column(
      key: const ValueKey('export-first-page-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'First Page Preview',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summaryText,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: mutedColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Center(
              child: AspectRatio(
                aspectRatio: pageWidth / pageHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: pageWidth,
                      height: pageHeight,
                      child: Padding(
                        padding: pageMargins,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: pageWidth - pageMargins.horizontal,
                            maxWidth: pageWidth - pageMargins.horizontal,
                            minHeight: 0,
                            maxHeight: double.infinity,
                            child: Theme(
                              data: lightTheme,
                              child: DefaultTextStyle(
                                style: TextStyle(
                                  fontFamily: bodyFont,
                                  fontSize: baseFont,
                                  height: 1.6,
                                  color: textColor,
                                ),
                                child: MarkdownBody(
                                  data: _previewRender.processedMarkdown,
                                  extensionSet: md.ExtensionSet.gitHubFlavored,
                                  styleSheet: previewStyle,
                                  inlineSyntaxes: [
                                    DisplayMathSyntax(),
                                    InlineMathSyntax(),
                                    BracketedCitationSyntax(),
                                    InTextCitationSyntax(),
                                    SuperscriptSyntax(),
                                    SubscriptSyntax(),
                                  ],
                                  builders: {
                                    'displaymath': MathElementBuilder(
                                      isDisplay: true,
                                      textColor: textColor,
                                      codeFont: codeFont,
                                    ),
                                    'inlinemath': MathElementBuilder(
                                      isDisplay: false,
                                      textColor: textColor,
                                      codeFont: codeFont,
                                    ),
                                    'academiccitation': CitationElementBuilder(
                                      helper: helper,
                                      isDark: false,
                                    ),
                                    'code': MathCodeBlockBuilder(
                                      textColor: textColor,
                                      codeFont: codeFont,
                                    ),
                                    'img': MarkdownImageElementBuilder(
                                      controller: widget.controller,
                                      imageDirectory: imgDir,
                                      isDark: false,
                                      codeFont: codeFont,
                                      textColor: textColor,
                                      mutedColor: const Color(0xFF64748B),
                                    ),
                                    'input': InputElementBuilder(),
                                    'sup': SuperscriptElementBuilder(),
                                    'sub': SubscriptElementBuilder(),
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
