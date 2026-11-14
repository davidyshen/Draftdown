/// Represents an entry in the file history (previously opened files).
class HistoryEntry {
  final String path;
  final String fileName;
  final DateTime lastOpened;
  final int? fileSize;

  HistoryEntry({
    required this.path,
    required this.fileName,
    required this.lastOpened,
    this.fileSize,
  });

  /// Human-friendly relative timestamp in British English
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(lastOpened);

    if (difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return mins == 1 ? '1 minute ago' : '$mins minutes ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else {
      return '${lastOpened.day.toString().padLeft(2, '0')}/${lastOpened.month.toString().padLeft(2, '0')}/${lastOpened.year}';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'fileName': fileName,
      'lastOpened': lastOpened.toIso8601String(),
      'fileSize': fileSize,
    };
  }

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      path: json['path'] as String,
      fileName: json['fileName'] as String? ?? 'Untitled.md',
      lastOpened:
          DateTime.tryParse(json['lastOpened'] as String? ?? '') ??
          DateTime.now(),
      fileSize: json['fileSize'] as int?,
    );
  }

  HistoryEntry copyWith({
    String? path,
    String? fileName,
    DateTime? lastOpened,
    int? fileSize,
  }) {
    return HistoryEntry(
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      lastOpened: lastOpened ?? this.lastOpened,
      fileSize: fileSize ?? this.fileSize,
    );
  }
}
