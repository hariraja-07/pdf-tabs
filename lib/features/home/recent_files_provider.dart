import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentFileItem {
  const RecentFileItem({
    required this.filePath,
    required this.fileName,
    required this.lastOpened,
    this.pageIndex = 0,
  });

  final String filePath;
  final String fileName;
  final DateTime lastOpened;
  final int pageIndex;

  RecentFileItem copyWith({int? pageIndex}) {
    return RecentFileItem(
      filePath: filePath,
      fileName: fileName,
      lastOpened: lastOpened,
      pageIndex: pageIndex ?? this.pageIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'fileName': fileName,
        'lastOpened': lastOpened.toIso8601String(),
        'pageIndex': pageIndex,
      };

  factory RecentFileItem.fromJson(Map<String, dynamic> json) {
    return RecentFileItem(
      filePath: json['filePath'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      lastOpened: DateTime.tryParse(json['lastOpened'] as String? ?? '') ??
          DateTime.now(),
      pageIndex: json['pageIndex'] as int? ?? 0,
    );
  }
}

final recentFilesProvider =
    AsyncNotifierProvider<RecentFilesNotifier, List<RecentFileItem>>(
  RecentFilesNotifier.new,
);

class RecentFilesNotifier extends AsyncNotifier<List<RecentFileItem>> {
  static const _prefsKey = 'pdf_recent_files_v1';
  static const _maxItems = 20;

  @override
  Future<List<RecentFileItem>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .whereType<Map<String, dynamic>>()
          .map(RecentFileItem.fromJson)
          .where((item) => item.filePath.isNotEmpty)
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> addRecent(String filePath, String fileName) async {
    final current = await future;
    final updated = [
      RecentFileItem(
        filePath: filePath,
        fileName: fileName,
        lastOpened: DateTime.now(),
      ),
      ...current.where((item) => item.filePath != filePath),
    ];

    if (updated.length > _maxItems) {
      updated.removeRange(_maxItems, updated.length);
    }

    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> updateProgress(String filePath, int pageIndex) async {
    final current = await future;
    final index = current.indexWhere((item) => item.filePath == filePath);
    if (index < 0) return;
    final item = current[index];
    if (item.pageIndex == pageIndex) return;

    final updated = [...current];
    updated[index] = item.copyWith(pageIndex: pageIndex);
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> removeRecent(String filePath) async {
    final current = await future;
    final updated =
        current.where((item) => item.filePath != filePath).toList();
    state = AsyncData(updated);
    await _save(updated);
  }

  Future<void> clearAll() async {
    state = const AsyncData([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<void> _save(List<RecentFileItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }
}
