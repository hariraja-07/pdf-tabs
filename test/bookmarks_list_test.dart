import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_tabs/features/bookmarks/bookmarks_provider.dart';
import 'package:pdf_tabs/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  testWidgets('bookmark appears in list after toggling via provider',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(bookmarksProvider.future);

    await container
        .read(bookmarksProvider.notifier)
        .toggle('/docs/test.pdf', 4);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(
          Consumer(builder: (context, ref, _) {
            final entries = ref.watch(bookmarksProvider).valueOrNull?['/docs/test.pdf'] ?? [];
            return Text('count: ${entries.length}');
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('count: 1'), findsOneWidget);
  });

  testWidgets('bookmark appears in modal bottom sheet list', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(bookmarksProvider.future);

    await container
        .read(bookmarksProvider.notifier)
        .toggle('/docs/test.pdf', 4);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => _TestBookmarkSheet(filePath: '/docs/test.pdf'),
                  );
                },
                child: const Text('open sheet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Page 5'), findsOneWidget);
  });

  testWidgets(
      'bookmark added after sheet is open appears in list',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(bookmarksProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => Material(child: _TestBookmarkSheet(filePath: '/docs/test.pdf')),
                  );
                },
                child: const Text('open sheet'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();

    // Sheet should be open and show empty state
    expect(find.text('No bookmarks yet'), findsOneWidget);

    // Add a bookmark after the sheet is already open
    await container
        .read(bookmarksProvider.notifier)
        .toggle('/docs/test.pdf', 4);
    await tester.pumpAndSettle();

    // Sheet should rebuild and show the bookmark
    expect(find.text('No bookmarks yet'), findsNothing);
    expect(find.text('Page 5'), findsOneWidget);
  });
}

class _TestBookmarkSheet extends ConsumerWidget {
  final String filePath;
  const _TestBookmarkSheet({required this.filePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref.watch(bookmarksProvider).valueOrNull?[filePath] ?? const [];
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Text('No bookmarks yet'),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: entries.length,
      itemBuilder: (_, index) {
        final entry = entries[index];
        return ListTile(title: Text('Page ${entry.pageIndex + 1}'));
      },
    );
  }
}
