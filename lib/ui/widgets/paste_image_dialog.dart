import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../controllers/editor_controller.dart';
import '../theme/app_theme.dart';

/// Result returned by [PasteImageDialog] when the user confirms saving.
class PasteImageResult {
  final String filename;
  final String altText;

  const PasteImageResult({
    required this.filename,
    required this.altText,
  });
}

/// Modal dialog prompting the user to name a pasted clipboard image (and
/// optionally enter alt text) before saving it to the document's media folder.
class PasteImageDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final String defaultExtension;
  final String mediaDirectory;
  final String mediaFolderDisplay;
  final String? initialFilename;

  const PasteImageDialog({
    super.key,
    required this.imageBytes,
    required this.defaultExtension,
    required this.mediaDirectory,
    required this.mediaFolderDisplay,
    this.initialFilename,
  });

  /// Prompts the user to save an unsaved document if necessary, opens
  /// [PasteImageDialog] to name [imageBytes], and saves/inserts the image.
  static Future<void> promptAndSaveImage({
    required BuildContext context,
    required EditorController controller,
    required Uint8List imageBytes,
    required String defaultExtension,
    String? initialFilename,
  }) async {
    if (controller.currentFilePath == null) {
      final shouldSave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Save Document First'),
          content: const Text(
            'To save images into a media folder next to your document, please save this Markdown file first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save Document'),
            ),
          ],
        ),
      );
      if (shouldSave != true) return;
      await controller.saveFile();
      if (controller.currentFilePath == null || !context.mounted) return;
    }

    final mediaDir = controller.resolveMediaDirectoryPath();
    if (mediaDir == null || !context.mounted) return;
    final mediaDisplay = controller.resolveMediaFolderSetting();

    final result = await showDialog<PasteImageResult>(
      context: context,
      builder: (_) => PasteImageDialog(
        imageBytes: imageBytes,
        defaultExtension: defaultExtension,
        mediaDirectory: mediaDir,
        mediaFolderDisplay: mediaDisplay,
        initialFilename: initialFilename,
      ),
    );

    if (result == null || !context.mounted) return;

    try {
      await controller.savePastedImage(
        bytes: imageBytes,
        filename: result.filename,
        altText: result.altText,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save image: $e')),
      );
    }
  }

  /// Normalises a user-entered filename by trimming, replacing whitespace with
  /// hyphens, and appending [defaultExtension] if no extension is present.
  static String normaliseFilename(String raw, String defaultExtension) {
    var cleaned = raw.trim().replaceAll(RegExp(r'\s+'), '-');
    if (cleaned.isEmpty) return '';

    final ext = p.extension(cleaned);
    if (ext.isEmpty || ext == '.') {
      final base = cleaned.endsWith('.')
          ? cleaned.substring(0, cleaned.length - 1)
          : cleaned;
      if (base.isEmpty) return '';
      return '$base.$defaultExtension';
    }
    return cleaned;
  }

  /// Validates [normalisedFilename], returning an error message or `null` if valid.
  static String? validateFilename(String normalisedFilename) {
    if (normalisedFilename.isEmpty) {
      return 'Please enter a filename.';
    }
    if (normalisedFilename.contains('..') ||
        RegExp(r'[<>:"/\\|?*\x00-\x1F]').hasMatch(normalisedFilename)) {
      return 'Filename contains invalid characters.';
    }
    final base = p.basenameWithoutExtension(normalisedFilename);
    if (base.isEmpty || normalisedFilename.startsWith('.')) {
      return 'Please enter a filename before the extension.';
    }
    return null;
  }

  @override
  State<PasteImageDialog> createState() => _PasteImageDialogState();
}

class _PasteImageDialogState extends State<PasteImageDialog> {
  static final RegExp _spacesRegex = RegExp(r'\s+');

  late final TextEditingController _filenameController;
  late final TextEditingController _altTextController;
  late final FocusNode _filenameFocusNode;

  String _normalisedName = '';
  String? _validationError;
  bool _fileExists = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialFilename ?? _buildDefaultFilename();
    _filenameController = TextEditingController(text: initial);
    _altTextController = TextEditingController();
    _filenameFocusNode = FocusNode();

    _recomputeState();

    // Select only the base filename so the user can type immediately.
    final extLen = p.extension(initial).length;
    final baseEnd = (initial.length - extLen).clamp(0, initial.length);
    _filenameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: baseEnd,
    );

    _filenameController.addListener(_recomputeState);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _filenameFocusNode.requestFocus();
      }
    });
  }

  String _buildDefaultFilename() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}${two(now.second)}';
    return 'image-$stamp.${widget.defaultExtension}';
  }

  void _recomputeState() {
    final normalised = PasteImageDialog.normaliseFilename(
      _filenameController.text,
      widget.defaultExtension,
    );
    final error = PasteImageDialog.validateFilename(normalised);
    final exists = error == null &&
        File(p.join(widget.mediaDirectory, normalised)).existsSync();

    if (normalised != _normalisedName ||
        error != _validationError ||
        exists != _fileExists) {
      setState(() {
        _normalisedName = normalised;
        _validationError = error;
        _fileExists = exists;
      });
    }
  }

  @override
  void dispose() {
    _filenameController.removeListener(_recomputeState);
    _filenameController.dispose();
    _altTextController.dispose();
    _filenameFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_validationError != null || _normalisedName.isEmpty) return;
    Navigator.of(context).pop(
      PasteImageResult(
        filename: _normalisedName,
        altText: _altTextController.text.trim(),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final sidebarColor = isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final mutedColor =
        isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final hasSpacesToNormalise =
        _spacesRegex.hasMatch(_filenameController.text.trim());

    return Dialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Save Pasted Image',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: sidebarColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    '${widget.defaultExtension.toUpperCase()} · ${_formatBytes(widget.imageBytes.length)}',
                    style: TextStyle(fontSize: 11, color: mutedColor),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: sidebarColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: mutedColor,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Saving to: ${widget.mediaFolderDisplay}/',
              style: TextStyle(fontSize: 11.5, color: mutedColor),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _filenameController,
              focusNode: _filenameFocusNode,
              decoration: InputDecoration(
                labelText: 'Filename',
                isDense: true,
                errorText: _validationError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (hasSpacesToNormalise && _validationError == null) ...[
              const SizedBox(height: 6),
              Text(
                'Spaces will be saved as: $_normalisedName',
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
            ],
            if (_fileExists) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: isDark ? Colors.amber[300] : Colors.amber[800],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '"$_normalisedName" already exists. Rename it or click Overwrite.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.amber[200] : Colors.amber[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _altTextController,
              decoration: InputDecoration(
                labelText: 'Alt text (optional)',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _validationError == null ? _submit : null,
                  style: _fileExists
                      ? FilledButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.amber[700] : Colors.amber[800],
                          foregroundColor: Colors.white,
                        )
                      : null,
                  child: Text(_fileExists ? 'Overwrite' : 'Save & Insert'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
