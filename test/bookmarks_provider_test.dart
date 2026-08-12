import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_tabs/features/bookmarks/bookmarks_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    await container.read(bookmarksProvider.future);
  });

  tearDown(() => container.dispose());

  Future<bool> toggle(String path, int page) =>
      container.read(bookmarksProvider.notifier).toggle(path, page);

  Future<void> remove(String path, int page) =>
      container.read(bookmarksProvider.notifier).remove(path, page);

  Future<void> removeFile(String path) =>
      container.read(bookmarksProvider.notifier).removeFile(path);

  Map<String, List<BookmarkEntry>> state() =>
      container.read(bookmarksProvider).requireValue;

  test('starts empty', () {
    expect(state(), isEmpty);
  });

  test('toggle adds a bookmark and returns true', () async {
    final added = await toggle('/docs/a.pdf', 2);

    expect(added, isTrue);
    final entries = state()['/docs/a.pdf'];
    expect(entries, hasLength(1));
    expect(entries!.first.pageIndex, 2);
    expect(container.read(bookmarksProvider.notifier).isBookmarked('/docs/a.pdf', 2), isTrue);
  });

  test('toggle same page removes the bookmark and returns false', () async {
    await toggle('/docs/a.pdf', 2);
    final added = await toggle('/docs/a.pdf', 2);

    expect(added, isFalse);
    expect(state(), isEmpty);
  });

  test('bookmarks are kept sorted by page index', () async {
    await toggle('/docs/a.pdf', 5);
    await toggle('/docs/a.pdf', 1);
    await toggle('/docs/a.pdf', 3);

    final pages = state()['/docs/a.pdf']!.map((e) => e.pageIndex).toList();
    expect(pages, [1, 3, 5]);
  });

  test('bookmarks from different files are kept separate', () async {
    await toggle('/docs/a.pdf', 1);
    await toggle('/docs/b.pdf', 7);

    expect(state()['/docs/a.pdf'], hasLength(1));
    expect(state()['/docs/b.pdf'], hasLength(1));
    expect(container.read(bookmarksProvider.notifier).isBookmarked('/docs/b.pdf', 7), isTrue);
    expect(container.read(bookmarksProvider.notifier).isBookmarked('/docs/a.pdf', 7), isFalse);
  });

  test('remove deletes a single bookmark', () async {
    await toggle('/docs/a.pdf', 1);
    await toggle('/docs/a.pdf', 3);
    await remove('/docs/a.pdf', 1);

    final pages = state()['/docs/a.pdf']!.map((e) => e.pageIndex).toList();
    expect(pages, [3]);
  });

  test('removeFile clears all bookmarks for a file', () async {
    await toggle('/docs/a.pdf', 1);
    await toggle('/docs/a.pdf', 2);
    await toggle('/docs/b.pdf', 1);
    await removeFile('/docs/a.pdf');

    expect(state()['/docs/a.pdf'], isNull);
    expect(state()['/docs/b.pdf'], hasLength(1));
  });

  test('bookmarks survive a new container (persisted)', () async {
    await toggle('/docs/a.pdf', 2);
    await toggle('/docs/a.pdf', 9);
    await toggle('/docs/b.pdf', 4);

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    final restoredState = await restored.read(bookmarksProvider.future);

    expect(restoredState['/docs/a.pdf']!.map((e) => e.pageIndex), [2, 9]);
    expect(restoredState['/docs/b.pdf']!.single.pageIndex, 4);
  });

  test('corrupt persisted data loads as empty', () async {
    SharedPreferences.setMockInitialValues({
      'pdf_bookmarks_v1': 'not json',
    });
    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    final restoredState = await restored.read(bookmarksProvider.future);

    expect(restoredState, isEmpty);
  });
}
