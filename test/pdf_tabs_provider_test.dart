import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_tabs/features/tabs/pdf_tabs_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    await container.read(pdfTabsProvider.future);
  });

  tearDown(() => container.dispose());

  Future<void> open(String path) =>
      container.read(pdfTabsProvider.notifier).open(path);

  Future<void> close(String id) =>
      container.read(pdfTabsProvider.notifier).close(id);

  Future<void> activate(String id) =>
      container.read(pdfTabsProvider.notifier).activate(id);

  test('starts empty', () {
    final state = container.read(pdfTabsProvider).requireValue;
    expect(state.tabs, isEmpty);
    expect(state.activeIndex, 0);
  });

  test('open adds tabs and activates the new one', () async {
    await open('/docs/a.pdf');
    await open('/docs/b.pdf');

    final state = container.read(pdfTabsProvider).requireValue;
    expect(state.tabs.length, 2);
    expect(state.tabs.first.fileName, 'a.pdf');
    expect(state.tabs.last.fileName, 'b.pdf');
    expect(state.activeIndex, 1);
  });

  test('open same file dedupes and activates existing tab', () async {
    await open('/docs/a.pdf');
    await open('/docs/b.pdf');
    await open('/docs/a.pdf');

    final state = container.read(pdfTabsProvider).requireValue;
    expect(state.tabs.length, 2);
    expect(state.activeIndex, 0);
  });

  test('activate switches active tab', () async {
    await open('/docs/a.pdf');
    await open('/docs/b.pdf');
    await activate(container.read(pdfTabsProvider).requireValue.tabs.first.id);

    expect(container.read(pdfTabsProvider).requireValue.activeIndex, 0);
  });

  test('close removes tab and reindexes active', () async {
    await open('/docs/a.pdf');
    await open('/docs/b.pdf');
    await open('/docs/c.pdf');

    final tabs = container.read(pdfTabsProvider).requireValue.tabs;

    await activate(tabs.last.id);
    await close(tabs.first.id);

    final state = container.read(pdfTabsProvider).requireValue;
    expect(state.tabs.length, 2);
    expect(state.tabs.first.fileName, 'b.pdf');
    expect(state.activeIndex, 1);
  });

  test('closing last tab returns to empty', () async {
    await open('/docs/a.pdf');
    final id = container.read(pdfTabsProvider).requireValue.tabs.first.id;
    await close(id);

    final state = container.read(pdfTabsProvider).requireValue;
    expect(state.tabs, isEmpty);
    expect(state.activeIndex, 0);
  });

  test('tabs survive a new container (persisted)', () async {
    final pdf = File(
      '${Directory.systemTemp.path}/pdf_tabs_restore_test.pdf',
    );
    await pdf.writeAsString('test');

    await open(pdf.path);
    await open('/docs/second.pdf');
    await activate(container.read(pdfTabsProvider).requireValue.tabs.first.id);

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    final restoredState = await restored.read(pdfTabsProvider.future);

    expect(restoredState.tabs.length, 1);
    expect(restoredState.tabs.first.filePath, pdf.path);
    expect(restoredState.activeIndex, 0);

    await pdf.delete();
  });

  test('missing files are skipped on restore', () async {
    await open('/docs/gone.pdf');

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    final restoredState = await restored.read(pdfTabsProvider.future);

    expect(restoredState.tabs, isEmpty);
  });

  test('setPosition updates the tab page index in memory', () async {
    await open('/docs/a.pdf');
    final id = container.read(pdfTabsProvider).requireValue.tabs.first.id;

    container.read(pdfTabsProvider.notifier).setPosition(id, 7);

    final tab = container.read(pdfTabsProvider).requireValue.tabs.first;
    expect(tab.pageIndex, 7);
  });

  test('page positions survive a new container (persisted)', () async {
    final pdf = File('${Directory.systemTemp.path}/pdf_tabs_pos_test.pdf');
    await pdf.writeAsString('test');

    await open(pdf.path);
    final id = container.read(pdfTabsProvider).requireValue.tabs.first.id;
    container.read(pdfTabsProvider.notifier).setPosition(id, 12);
    await container.read(pdfTabsProvider.notifier).persist();

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    final restoredState = await restored.read(pdfTabsProvider.future);

    expect(restoredState.tabs.single.pageIndex, 12);

    await pdf.delete();
  });
}
