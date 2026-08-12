import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home/recent_files_provider.dart';
import 'pdf_tab.dart';

final pdfTabsProvider = AsyncNotifierProvider<PdfTabsNotifier, PdfTabsState>(
  PdfTabsNotifier.new,
);

class PdfTabsState {
  const PdfTabsState({required this.tabs, required this.activeIndex});

  final List<PdfTabData> tabs;
  final int activeIndex;

  PdfTabsState copyWith({List<PdfTabData>? tabs, int? activeIndex}) {
    return PdfTabsState(
      tabs: tabs ?? this.tabs,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

class PdfTabsNotifier extends AsyncNotifier<PdfTabsState> {
  static const _prefsKey = 'pdf_tabs_state_v1';

  int _nextId = 0;
  Timer? _debounceTimer;

  @override
  Future<PdfTabsState> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return const PdfTabsState(tabs: [], activeIndex: 0);

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final paths = (decoded['paths'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
      final names = (decoded['names'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList();
      final displayNames =
          (decoded['displayNames'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList();
      final pages = (decoded['pages'] as List<dynamic>? ?? const [])
          .whereType<int>()
          .toList();

      final tabs = <PdfTabData>[];
      for (var i = 0; i < paths.length; i++) {
        final path = paths[i];
        if (!await File(path).exists()) continue;
        final name = i < names.length && names[i].isNotEmpty
            ? names[i]
            : _fileNameFromPath(path);
        final displayName = i < displayNames.length && displayNames[i].isNotEmpty
            ? displayNames[i]
            : name;
        final pageIndex = i < pages.length && pages[i] > 0 ? pages[i] : 0;
        tabs.add(
          PdfTabData(
            id: _newId(),
            filePath: path,
            fileName: name,
            displayName: displayName,
            pageIndex: pageIndex,
          ),
        );
      }

      final savedIndex = decoded['activeIndex'] as int? ?? 0;
      final activeIndex =
          tabs.isEmpty ? 0 : savedIndex.clamp(0, tabs.length - 1);
      return PdfTabsState(tabs: tabs, activeIndex: activeIndex);
    } catch (_) {
      return const PdfTabsState(tabs: [], activeIndex: 0);
    }
  }

  Future<void> open(String filePath, {int initialPageIndex = 0}) async {
    final fileName = _fileNameFromPath(filePath);

    // Register in recent files
    unawaited(
      ref.read(recentFilesProvider.notifier).addRecent(filePath, fileName),
    );

    final current = await future;
    final existingIndex =
        current.tabs.indexWhere((tab) => tab.filePath == filePath);
    if (existingIndex >= 0) {
      await _set(current.copyWith(activeIndex: existingIndex));
      return;
    }

    final tabs = [...current.tabs];
    tabs.add(
      PdfTabData(
        id: _newId(),
        filePath: filePath,
        fileName: fileName,
        pageIndex: initialPageIndex,
      ),
    );
    await _set(PdfTabsState(tabs: tabs, activeIndex: tabs.length - 1));
  }

  Future<void> close(String id) async {
    final current = await future;
    final index = current.tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;

    final tabs = [...current.tabs]..removeAt(index);
    var activeIndex = current.activeIndex;
    if (tabs.isEmpty) {
      activeIndex = 0;
    } else if (index < activeIndex) {
      activeIndex -= 1;
    } else if (index == activeIndex && activeIndex >= tabs.length) {
      activeIndex = tabs.length - 1;
    }
    await _set(PdfTabsState(tabs: tabs, activeIndex: activeIndex));
  }

  Future<void> activate(String id) async {
    final current = await future;
    final index = current.tabs.indexWhere((tab) => tab.id == id);
    if (index < 0 || index == current.activeIndex) return;
    await _set(current.copyWith(activeIndex: index));
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = await future;
    if (oldIndex < 0 ||
        oldIndex >= current.tabs.length ||
        newIndex < 0 ||
        newIndex > current.tabs.length) {
      return;
    }

    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }

    final tabs = [...current.tabs];
    final activeTabId = tabs[current.activeIndex].id;
    final movedTab = tabs.removeAt(oldIndex);
    tabs.insert(targetIndex, movedTab);

    final newActiveIndex = tabs.indexWhere((tab) => tab.id == activeTabId);
    await _set(
      PdfTabsState(
        tabs: tabs,
        activeIndex: newActiveIndex >= 0 ? newActiveIndex : 0,
      ),
    );
  }

  void setPosition(String id, int pageIndex) {
    final current = state.valueOrNull;
    if (current == null) return;
    final index = current.tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;

    final tab = current.tabs[index];
    if (tab.pageIndex == pageIndex) return;

    final tabs = [...current.tabs];
    tabs[index] = tab.copyWith(pageIndex: pageIndex);
    state = AsyncData(current.copyWith(tabs: tabs));

    // Debounce SharedPreferences write to avoid heavy disk IO while scrolling
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      persist();
    });
  }

  Future<void> persist() async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _writePrefs(current);
  }

  Future<void> _set(PdfTabsState next) async {
    state = AsyncData(next);
    await _writePrefs(next);
  }

  Future<void> _writePrefs(PdfTabsState next) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'paths': next.tabs.map((tab) => tab.filePath).toList(),
        'names': next.tabs.map((tab) => tab.fileName).toList(),
        'displayNames': next.tabs.map((tab) => tab.displayName).toList(),
        'pages': next.tabs.map((tab) => tab.pageIndex).toList(),
        'activeIndex': next.activeIndex,
      }),
    );
  }

  String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'tab_${now}_${_nextId++}';
  }

  String _fileNameFromPath(String path) {
    final rawName = path.split('/').last;
    try {
      return Uri.decodeFull(rawName);
    } catch (_) {
      return rawName;
    }
  }
}
