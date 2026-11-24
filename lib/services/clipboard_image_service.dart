import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as p;

/// Represents an image extracted from the system clipboard.
class ClipboardImageData {
  final Uint8List bytes;

  /// Lowercase file extension without leading dot (e.g. `png`, `jpg`).
  final String extension;

  const ClipboardImageData({
    required this.bytes,
    required this.extension,
  });
}

/// Service for reading raw images or copied image files from the system clipboard.
class ClipboardImageService {
  static const Set<String> _supportedExtensions = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
    'svg',
    'tiff',
    'tif',
    'avif',
  };

  /// Reads an image from the system clipboard, returning `null` if no image
  /// data or image file is present.
  Future<ClipboardImageData?> readImageFromClipboard() async {
    try {
      // 1. Prefer copied image files (preserves original format and bytes).
      final files = await Pasteboard.files();
      for (final filePath in files) {
        final ext = p.extension(filePath).toLowerCase().replaceFirst('.', '');
        if (_supportedExtensions.contains(ext)) {
          final file = File(filePath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) {
              return ClipboardImageData(bytes: bytes, extension: ext);
            }
          }
        }
      }

      // 2. Fall back to raw image data (e.g. screenshots or browser "Copy Image").
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        return ClipboardImageData(
          bytes: imageBytes,
          extension: detectExtension(imageBytes),
        );
      }
    } catch (e) {
      debugPrint('[ClipboardImageService] Failed to read clipboard image: $e');
    }
    return null;
  }

  /// Detects common image formats from magic bytes, defaulting to `'png'`.
  @visibleForTesting
  static String detectExtension(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 6 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return 'gif';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4D) {
      return 'bmp';
    }
    return 'png';
  }
}
