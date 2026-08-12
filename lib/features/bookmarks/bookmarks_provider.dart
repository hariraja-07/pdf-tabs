import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkEntry {
  const BookmarkEntry({
    required this.filePath,
    required this.pageIndex,
    required this.createdAt,
  });

  final String filePath;
  final int pageIndex;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'pageIndex': pageIndex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BookmarkEntry.fromJson(Map<String, dynamic> json) {
    return BookmarkEntry(
      filePath: json['filePath'] as String? ?? '',
      pageIndex: json['pageIndex'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

final bookmarksProvider =
    AsyncNotifierProvider<BookmarksNotifier, Map<String, List<BookmarkEntry>>>(
  BookmarksNotifier.new,
);

class BookmarksNotifier extends AsyncNotifier<Map<String, List<BookmarkEntry>>> {
  static const _prefsKey = 'pdf_bookmarks_v1';

  @override
  Future<Map<String, List<BookmarkEntry>>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final entries = decoded
          .whereType<Map<String, dynamic>>()
          .map(BookmarkEntry.fromJson)
          .where((entry) => entry.filePath.isNotEmpty && entry.pageIndex >= 0)
          .toList();
      return _groupByFile(entries);
    } catch (_) {
      return {};
    }
  }

  Map<String, List<BookmarkEntry>> _groupByFile(List<BookmarkEntry> entries) {
    final result = <String, List<BookmarkEntry>>{};
    for (final entry in entries) {
      result.putIfAbsent(entry.filePath, () => []).add(entry);
    }
    for (final list in result.values) {
      list.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    }
    return result;
  }

  Future<bool> toggle(String filePath, int pageIndex) async {
    final current = await future;
    final existing = current[filePath] ?? const <BookmarkEntry>[];
    final isBookmarked =
        existing.any((entry) => entry.pageIndex == pageIndex);

    final updated = Map<String, List<BookmarkEntry>>.from(current);
    if (isBookmarked) {
      updated[filePath] = existing
          .where((entry) => entry.pageIndex != pageIndex)
          .toList();
      if (updated[filePath]!.isEmpty) updated.remove(filePath);
    } else {
      final added = [
        ...existing,
        BookmarkEntry(
          filePath: filePath,
          pageIndex: pageIndex,
          createdAt: DateTime.now(),
        ),
      ]..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
      updated[filePath] = added;
    }

    state = AsyncData(updated);
    await _save(updated);
    return !isBookmarked;
  }

  Future<void> remove(String filePath, int pageIndex) async {
    final current = await future;
    final existing = current[filePath] ?? const <BookmarkEntry>[];
    final updated = Map<String, List<BookmarkEntry>>.from(current);
    updated[filePath] = existing
        .where((entry) => entry.pageIndex != pageIndex)
        .toList();
    if (updated[filePath]!.isEmpty) updated.remove(filePath);

    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> removeFile(String filePath) async {
    final current = await future;
    if (!current.containsKey(filePath)) return;

    final updated = Map<String, List<BookmarkEntry>>.from(current)
      ..remove(filePath);
    state = AsyncData(updated);
    await _save(updated);
  }

  bool isBookmarked(String filePath, int pageIndex) {
    final bookmarks = state.valueOrNull?[filePath] ?? const <BookmarkEntry>[];
    return bookmarks.any((entry) => entry.pageIndex == pageIndex);
  }

  Future<void> _save(Map<String, List<BookmarkEntry>> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    final flattened = bookmarks.values
        .expand((entries) => entries)
        .map((entry) => entry.toJson())
        .toList();
    final raw = jsonEncode(flattened);
    await prefs.setString(_prefsKey, raw);
  }
}
