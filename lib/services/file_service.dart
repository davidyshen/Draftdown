import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service managing file I/O, file picking, and OS file explorer interaction.
class FileService {
  /// Open file picker dialog for Markdown files
  Future<String?> pickMarkdownFile() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Select Markdown Document',
        type: FileType.custom,
        allowedExtensions: ['md', 'markdown', 'mdown', 'txt'],
      );

      return file?.path;
    } catch (e) {
      debugPrint('[FileService] Failed to pick markdown file: $e');
      return null;
    }
  }

  /// Open file picker dialog for saving a Markdown file
  Future<String?> pickSaveMarkdownLocation({
    String defaultName = 'Document.md',
  }) async {
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save Markdown Document',
        fileName: defaultName,
        bytes: Uint8List(0),
      );

      if (uri == null) return null;
      var path = uri.toFilePath();
      if (!path.toLowerCase().endsWith('.md')) {
        path = '$path.md';
      }
      return path;
    } catch (e) {
      debugPrint('[FileService] Failed to pick save location: $e');
      return null;
    }
  }

  /// Open file picker dialog for Bibliography databases (.bib, .json)
  Future<String?> pickBibliographyFile() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Select Bibliography File (BibTeX / CSL JSON)',
        type: FileType.custom,
        allowedExtensions: ['bib', 'bibtex', 'biblatex', 'json', 'yaml', 'yml'],
      );

      return file?.path;
    } catch (e) {
      debugPrint('[FileService] Failed to pick bibliography file: $e');
      return null;
    }
  }

  /// Open file picker dialog for Export destination
  Future<String?> pickExportLocation({
    required String defaultName,
    required String extension,
  }) async {
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Choose Export Destination',
        fileName: defaultName,
        bytes: Uint8List(0),
      );

      if (uri == null) return null;
      var path = uri.toFilePath();
      if (!path.toLowerCase().endsWith('.$extension')) {
        path = '$path.$extension';
      }
      return path;
    } catch (e) {
      debugPrint('[FileService] Failed to pick export location: $e');
      return null;
    }
  }

  /// Read file contents as UTF-8 string
  Future<String> readFile(String filePath) async {
    final file = File(filePath);
    return await file.readAsString();
  }

  /// Get file stat metadata (modified timestamp and size), or null if unavailable.
  Future<FileStat?> statFile(String filePath) async {
    try {
      final stat = await File(filePath).stat();
      if (stat.type == FileSystemEntityType.notFound) {
        return null;
      }
      return stat;
    } catch (_) {
      return null;
    }
  }

  /// Write string contents to file with UTF-8 encoding
  Future<void> writeFile(String filePath, String content) async {
    final file = File(filePath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(content);
  }

  /// Create a temporary file with contents for export
  Future<File> createTemporaryFile(
    String content, {
    String prefix = 'draftdown_export_',
    String extension = 'md',
  }) async {
    final tempDir = await getTemporaryDirectory();
    final cleanExt = extension.startsWith('.') ? extension : '.$extension';
    final fileName = '$prefix${DateTime.now().millisecondsSinceEpoch}$cleanExt';
    final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(content);
    return file;
  }

  /// Reveal file in native operating system file explorer
  Future<void> revealInExplorer(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        final parentDir = File(filePath).parent.path;
        await Process.run('xdg-open', [parentDir]);
      }
    } catch (e) {
      debugPrint('[FileService] Failed to reveal file in explorer: $e');
    }
  }

  /// Open exported file with the system default application
  Future<void> openFileWithSystemDefault(String filePath) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [filePath]);
      }
    } catch (e) {
      debugPrint('[FileService] Failed to open file: $e');
    }
  }
}
