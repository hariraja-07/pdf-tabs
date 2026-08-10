import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  Future<PdfTabsState> build() async {
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
        final pageIndex = i < pages.length && pages[i] > 0 ? pages[i] : 0;
        tabs.add(
          PdfTabData(
            id: _newId(),
            filePath: path,
            fileName: name,
            pageIndex: pageIndex,
          ),
        );
      }

      final savedIndex = decoded['activeIndex'] as int? ?? 0;
      final activeIndex = tabs.isEmpty ? 0 : savedIndex.clamp(0, tabs.length - 1);
      return PdfTabsState(tabs: tabs, activeIndex: activeIndex);
    } catch (_) {
      return const PdfTabsState(tabs: [], activeIndex: 0);
    }
  }

  Future<void> open(String filePath) async {
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
        fileName: _fileNameFromPath(filePath),
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
        'pages': next.tabs.map((tab) => tab.pageIndex).toList(),
        'activeIndex': next.activeIndex,
      }),
    );
  }

  String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'tab_${now}_${_nextId++}';
  }

  String _fileNameFromPath(String path) => path.split('/').last;
}
