import 'dart:io';
import 'package:flutter/material.dart';
import '../../controllers/editor_controller.dart';
import '../../models/export_format.dart';
import '../../services/pandoc_service.dart';
import '../theme/app_theme.dart';

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
  bool _showAdvancedOptions = false;

  bool _isExporting = false;
  PandocResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _initialiseDefaultTargetPath();
  }

  void _initialiseDefaultTargetPath() {
    final currentPath = widget.controller.currentFilePath;
    final baseName = widget.controller.currentFileName.replaceAll(RegExp(r'\.md$'), '');

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
      customArguments: _customArgsController.text.trim(),
      pageSize: _selectedPageSize,
      marginSize: _selectedMarginSize,
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
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surfaceColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final mutedColor =
        isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: surfaceColor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 820,
          maxHeight: 700,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.output,
                      color: theme.colorScheme.primary, size: 22),
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
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
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
                              ? theme.colorScheme.primary.withValues(alpha: 0.12)
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
                            horizontal: 12, vertical: 8),
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
                    label: const Text('Browse...',
                        style: TextStyle(fontSize: 12)),
                    onPressed: _browseDestination,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Options: Citeproc, Standalone, TOC
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                  color: isDark
                      ? AppTheme.darkSidebar
                      : AppTheme.lightBg,
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
                        const Text('Include Citations & References',
                            style: TextStyle(fontSize: 12)),
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
                        const Text('Standalone Document',
                            style: TextStyle(fontSize: 12)),
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
                        const Text('Table of Contents',
                            style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    if (_selectedFormat.type == ExportFormatType.pdf) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Page Size:',
                              style: TextStyle(fontSize: 12)),
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
                                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'a4',
                                    child: Text('A4', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: 'letter',
                                    child: Text('Letter', style: TextStyle(fontSize: 12)),
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
                          const Text('Margins:',
                              style: TextStyle(fontSize: 12)),
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
                                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'medium',
                                    child: Text('Medium', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: 'thin',
                                    child: Text('Thin', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: 'thick',
                                    child: Text('Thick', style: TextStyle(fontSize: 12)),
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
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Advanced Options (Optional)
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => setState(
                    () => _showAdvancedOptions = !_showAdvancedOptions),
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
                      fontFamily: 'Consolas, monospace', fontSize: 11.5),
                  decoration: InputDecoration(
                    labelText: 'Additional Arguments (Optional)',
                    labelStyle: const TextStyle(fontSize: 11),
                    hintText: 'e.g. --number-sections',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
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
                    color: isDark
                        ? AppTheme.darkBg
                        : AppTheme.lightSidebar,
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
                                style:
                                    TextStyle(fontSize: 12, color: mutedColor),
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
                                          icon: const Icon(Icons.open_in_new,
                                              size: 14),
                                          label: const Text('Open File',
                                              style: TextStyle(fontSize: 11)),
                                          style: ElevatedButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          onPressed: () => widget
                                              .controller.fileService
                                              .openFileWithSystemDefault(
                                                  _lastResult!.targetFile),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.folder_open,
                                              size: 14),
                                          label: const Text(
                                              'Reveal in Explorer',
                                              style: TextStyle(fontSize: 11)),
                                          style: OutlinedButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          onPressed: () => widget
                                              .controller.fileService
                                              .revealInExplorer(
                                                  _lastResult!.targetFile),
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
}
