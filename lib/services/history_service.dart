import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_entry.dart';

/// Service managing the persistence and retrieval of previously opened
/// Markdown files.
class HistoryService {
  static const String _storageKey = 'draftdown_file_history';
  static const int _maxHistoryCount = 30;

  List<HistoryEntry> _history = [];
  List<HistoryEntry>? _unmodifiableHistory;
  SharedPreferences? _prefs;

  List<HistoryEntry> get history =>
      _unmodifiableHistory ??= List.unmodifiable(_history);

  Future<SharedPreferences> _getPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Load persisted history from SharedPreferences
  Future<List<HistoryEntry>> loadHistory() async {
    try {
      final prefs = await _getPrefs();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _history = decoded
            .map((item) => HistoryEntry.fromJson(item as Map<String, dynamic>))
            .toList();

        // Sort descending by lastOpened timestamp
        _history.sort((a, b) => b.lastOpened.compareTo(a.lastOpened));
        _unmodifiableHistory = null;
      }
    } catch (e) {
      debugPrint('[HistoryService] Failed to load history: $e');
    }
    return history;
  }

  /// Add or update a file in history
  Future<void> recordFileOpen(String filePath) async {
    try {
      final file = File(filePath);
      final fileName = file.uri.pathSegments.lastWhere(
        (s) => s.isNotEmpty,
        orElse: () => 'Untitled.md',
      );

      int? fileSize;
      try {
        if (file.existsSync()) {
          fileSize = file.lengthSync();
        }
      } catch (_) {}

      // Remove existing entry for the same path if present
      _history.removeWhere((entry) => entry.path == filePath);

      // Insert fresh entry at top
      _history.insert(
        0,
        HistoryEntry(
          path: filePath,
          fileName: fileName,
          lastOpened: DateTime.now(),
          fileSize: fileSize,
        ),
      );

      // Trim history if it exceeds maximum capacity
      if (_history.length > _maxHistoryCount) {
        _history = _history.sublist(0, _maxHistoryCount);
      }
      _unmodifiableHistory = null;

      await _persist();
    } catch (e) {
      debugPrint('[HistoryService] Failed to record file: $e');
    }
  }

  /// Remove an entry from history by file path
  Future<void> removeEntry(String filePath) async {
    _history.removeWhere((entry) => entry.path == filePath);
    _unmodifiableHistory = null;
    await _persist();
  }

  /// Clear the entire file history
  Future<void> clearHistory() async {
    _history.clear();
    _unmodifiableHistory = null;
    await _persist();
  }

  /// Persist current history list into SharedPreferences
  Future<void> _persist() async {
    try {
      final prefs = await _getPrefs();
      final jsonList = _history.map((e) => e.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[HistoryService] Failed to persist history: $e');
    }
  }
}
