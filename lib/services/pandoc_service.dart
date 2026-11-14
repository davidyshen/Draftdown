import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/export_format.dart';

/// Result object describing the outcome of a Pandoc export execution.
class PandocResult {
  final bool success;
  final int exitCode;
  final String targetFile;
  final String stdout;
  final String stderr;
  final Duration duration;
  final String? errorMessage;

  PandocResult({
    required this.success,
    required this.exitCode,
    required this.targetFile,
    required this.stdout,
    required this.stderr,
    required this.duration,
    this.errorMessage,
  });
}

/// Service managing Pandoc discovery, version inspection, and document conversion.
/// Supports both bundled binaries and system-installed Pandoc.
class PandocService {
  static final RegExp _whitespaceSplitRegex = RegExp(r'\s+');

  String? _customExecutablePath;
  String? _resolvedExecutablePath;
  String? _cachedVersion;
  bool _isBundled = false;

  bool get isBundled => _isBundled;
  String? get resolvedExecutablePath => _resolvedExecutablePath;

  PandocService({String? customExecutablePath}) {
    _customExecutablePath = customExecutablePath;
  }

  void setCustomPath(String? path) {
    _customExecutablePath = path;
    _resolvedExecutablePath = null;
    _cachedVersion = null;
    _isBundled = false;
  }

  /// Locate the pandoc binary, checking user custom path, bundled assets,
  /// and system installations.
  Future<String?> findPandocExecutable() async {
    // 1. User custom path takes precedence if explicitly supplied
    if (_customExecutablePath != null &&
        _customExecutablePath!.trim().isNotEmpty) {
      final customFile = File(_customExecutablePath!.trim());
      if (await customFile.exists()) {
        _resolvedExecutablePath = customFile.path;
        _isBundled = false;
        return _resolvedExecutablePath;
      }
    }

    if (_resolvedExecutablePath != null) {
      if (await File(_resolvedExecutablePath!).exists()) {
        return _resolvedExecutablePath;
      }
    }

    final binaryName = Platform.isWindows ? 'pandoc.exe' : 'pandoc';

    // 2. Check bundled Pandoc binary in workspace assets/bin or executable folder
    final bundledCandidates = [
      // Direct relative to current working directory
      'assets${Platform.pathSeparator}bin${Platform.pathSeparator}$binaryName',
      // Runner / release app directory structures
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets${Platform.pathSeparator}assets${Platform.pathSeparator}bin${Platform.pathSeparator}$binaryName',
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}assets${Platform.pathSeparator}bin${Platform.pathSeparator}$binaryName',
      '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}$binaryName',
    ];

    for (final candidate in bundledCandidates) {
      final file = File(candidate);
      if (await file.exists()) {
        _resolvedExecutablePath = file.path;
        _isBundled = true;
        return _resolvedExecutablePath;
      }
    }

    // 3. Extract from packaged Flutter assets to application support directory
    try {
      final assetKey = 'assets/bin/$binaryName';
      final byteData = await rootBundle.load(assetKey);
      final appSupportDir = await getApplicationSupportDirectory();
      final binDir = Directory(
        '${appSupportDir.path}${Platform.pathSeparator}bin',
      );
      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }
      final extractedFile = File(
        '${binDir.path}${Platform.pathSeparator}$binaryName',
      );
      if (!await extractedFile.exists() ||
          await extractedFile.length() != byteData.lengthInBytes) {
        await extractedFile.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
          flush: true,
        );
        if (!Platform.isWindows) {
          await Process.run('chmod', ['+x', extractedFile.path]);
        }
      }
      if (await extractedFile.exists()) {
        _resolvedExecutablePath = extractedFile.path;
        _isBundled = true;
        return _resolvedExecutablePath;
      }
    } catch (_) {
      // In test or non-bundled environment, proceed to check system path
    }

    // 4. Try running 'pandoc --version' directly from system PATH
    try {
      final res = await Process.run('pandoc', ['--version']);
      if (res.exitCode == 0) {
        _resolvedExecutablePath = 'pandoc';
        _cachedVersion = (res.stdout as String).split('\n').firstOrNull?.trim();
        _isBundled = false;
        return _resolvedExecutablePath;
      }
    } catch (_) {}

    // 5. Platform-specific common paths
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      final programFiles =
          Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
      final programFilesX86 =
          Platform.environment['ProgramFiles(x86)'] ??
          r'C:\Program Files (x86)';

      final candidatePaths = [
        '$programFiles\\Pandoc\\pandoc.exe',
        '$programFilesX86\\Pandoc\\pandoc.exe',
        '$localAppData\\Pandoc\\pandoc.exe',
        r'C:\ProgramData\chocolatey\bin\pandoc.exe',
        '$userProfile\\scoop\\shims\\pandoc.exe',
      ];

      for (final p in candidatePaths) {
        if (await File(p).exists()) {
          _resolvedExecutablePath = p;
          _isBundled = false;
          return _resolvedExecutablePath;
        }
      }
    } else {
      // macOS / Linux common paths
      final candidatePaths = [
        '/usr/local/bin/pandoc',
        '/usr/bin/pandoc',
        '/opt/homebrew/bin/pandoc',
        '/home/linuxbrew/.linuxbrew/bin/pandoc',
      ];

      for (final p in candidatePaths) {
        if (await File(p).exists()) {
          _resolvedExecutablePath = p;
          _isBundled = false;
          return _resolvedExecutablePath;
        }
      }
    }

    return null;
  }

  /// Retrieve the version of the active Pandoc executable
  Future<String?> getVersion() async {
    if (_cachedVersion != null) return _cachedVersion;
    final exe = await findPandocExecutable();
    if (exe == null) return null;

    try {
      final result = await Process.run(exe, ['--version']);
      if (result.exitCode == 0) {
        final firstLine = (result.stdout as String)
            .split('\n')
            .firstOrNull
            ?.trim();
        _cachedVersion = firstLine ?? 'Pandoc';
        return _cachedVersion;
      }
    } catch (e) {
      debugPrint('Error getting pandoc version: $e');
    }
    return null;
  }

  /// Check whether Pandoc is accessible on this machine
  Future<bool> isAvailable() async {
    final path = await findPandocExecutable();
    return path != null;
  }

  /// Execute Pandoc conversion for the specified Markdown file
  Future<PandocResult> exportDocument({
    required String sourceMarkdownPath,
    required ExportOptions options,
    String? workingDirectory,
  }) async {
    final stopwatch = Stopwatch()..start();
    final exe = await findPandocExecutable();

    if (exe == null) {
      stopwatch.stop();
      return PandocResult(
        success: false,
        exitCode: -1,
        targetFile: options.targetPath,
        stdout: '',
        stderr: 'Pandoc executable was not found on your system.',
        duration: stopwatch.elapsed,
        errorMessage: 'Pandoc was not detected. Please ensure the bundled binary is intact or configure a custom binary path in Settings.',
      );
    }

    final args = <String>[];

    // Input format
    args.addAll(['-f', 'markdown']);

    // Output format/writer
    if (options.format.type == ExportFormatType.pdf) {
      args.addAll(['-o', options.targetPath]);
      final paper = options.pageSize.toLowerCase() == 'letter'
          ? 'letter'
          : 'a4';
      args.addAll(['-V', 'papersize=$paper']);

      switch (options.marginSize.toLowerCase()) {
        case 'thin':
          args.addAll(['-V', 'geometry:margin=0.5in']);
          break;
        case 'thick':
          args.addAll([
            '-V',
            'geometry:top=1in,bottom=1in,left=1.25in,right=1.25in',
          ]);
          break;
        case 'medium':
        default:
          args.addAll(['-V', 'geometry:margin=1in']);
          break;
      }
    } else {
      args.addAll(['-t', options.format.pandocWriter]);
      args.addAll(['-o', options.targetPath]);
    }

    // Standalone
    if (options.standalone) {
      args.add('-s');
    }

    // Table of contents
    if (options.tableOfContents) {
      args.add('--toc');
    }

    // Citeproc & Bibliography
    if (options.useCiteproc) {
      args.add('--citeproc');
      if (options.bibliographyPath != null &&
          options.bibliographyPath!.isNotEmpty &&
          File(options.bibliographyPath!).existsSync()) {
        args.add('--bibliography=${options.bibliographyPath}');
      }
      if (options.cslStylePath != null &&
          options.cslStylePath!.isNotEmpty &&
          File(options.cslStylePath!).existsSync()) {
        args.add('--csl=${options.cslStylePath}');
      }
    }

    // Custom user arguments
    if (options.customArguments.trim().isNotEmpty) {
      final customArgs = options.customArguments.trim().split(
        _whitespaceSplitRegex,
      );
      args.addAll(customArgs);
    }

    // Add source file as last argument
    args.add(sourceMarkdownPath);

    final cwd = workingDirectory ?? File(sourceMarkdownPath).parent.path;

    try {
      debugPrint(
        '[PandocService] Running $exe (${_isBundled ? "bundled" : "system"}) with args: ${args.join(" ")} in $cwd',
      );
      final processResult = await Process.run(exe, args, workingDirectory: cwd);

      stopwatch.stop();
      final isSuccess = processResult.exitCode == 0;

      return PandocResult(
        success: isSuccess,
        exitCode: processResult.exitCode,
        targetFile: options.targetPath,
        stdout: processResult.stdout.toString(),
        stderr: processResult.stderr.toString(),
        duration: stopwatch.elapsed,
        errorMessage: isSuccess
            ? null
            : 'Pandoc exited with code ${processResult.exitCode}: ${processResult.stderr}',
      );
    } catch (e) {
      stopwatch.stop();
      return PandocResult(
        success: false,
        exitCode: -2,
        targetFile: options.targetPath,
        stdout: '',
        stderr: e.toString(),
        duration: stopwatch.elapsed,
        errorMessage: 'Failed to run Pandoc process: $e',
      );
    }
  }

  /// Built-in fallback HTML exporter
  Future<PandocResult> fallbackExportHtml({
    required String markdownContent,
    required String targetPath,
    String title = 'Document',
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final targetFile = File(targetPath);
      final html =
          '''<!DOCTYPE html>
<html lang="en-GB">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      line-height: 1.6;
      color: #1e293b;
      max-width: 800px;
      margin: 40px auto;
      padding: 0 20px;
      background: #f8fafc;
    }
    article {
      background: #ffffff;
      padding: 48px;
      border-radius: 8px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    }
    h1, h2, h3, h4 { color: #0f172a; margin-top: 1.5em; margin-bottom: 0.5em; }
    h1 { border-bottom: 2px solid #e2e8f0; padding-bottom: 0.3em; }
    code { background: #f1f5f9; padding: 2px 6px; border-radius: 4px; font-family: monospace; font-size: 0.9em; }
    pre { background: #0f172a; color: #f8fafc; padding: 16px; border-radius: 6px; overflow-x: auto; }
    pre code { background: none; color: inherit; padding: 0; }
    blockquote { border-left: 4px solid #3b82f6; margin: 0; padding-left: 16px; color: #475569; }
    table { border-collapse: collapse; width: 100%; margin: 16px 0; }
    th, td { border: 1px solid #cbd5e1; padding: 8px 12px; text-align: left; }
    th { background: #f1f5f9; }
  </style>
</head>
<body>
  <article>
    <pre style="white-space: pre-wrap; font-family: inherit; background: none; color: inherit; padding: 0;">${_escapeHtml(markdownContent)}</pre>
  </article>
</body>
</html>''';

      await targetFile.writeAsString(html);
      stopwatch.stop();

      return PandocResult(
        success: true,
        exitCode: 0,
        targetFile: targetPath,
        stdout: 'Fallback HTML exported successfully',
        stderr: '',
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      stopwatch.stop();
      return PandocResult(
        success: false,
        exitCode: -1,
        targetFile: targetPath,
        stdout: '',
        stderr: e.toString(),
        duration: stopwatch.elapsed,
        errorMessage: 'Fallback HTML export failed: $e',
      );
    }
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
