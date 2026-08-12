import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_tabs/features/home/recent_files_provider.dart';
import 'package:pdf_tabs/features/home/screens/history_screen.dart';
import 'package:pdf_tabs/features/tabs/pdf_tabs_provider.dart';
import 'package:pdf_tabs/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  testWidgets('shows empty state when there is no history', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(recentFilesProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(const HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No reading history yet'), findsOneWidget);
  });

  testWidgets('lists recent files and swipe removes an entry', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(recentFilesProvider.notifier)
        .addRecent('/docs/a.pdf', 'a.pdf');
    await container
        .read(recentFilesProvider.notifier)
        .addRecent('/docs/b.pdf', 'b.pdf');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(const HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reading history'), findsOneWidget);
    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('b.pdf'), findsOneWidget);

    await tester.drag(find.text('a.pdf'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('a.pdf'), findsNothing);
    expect(find.text('b.pdf'), findsOneWidget);
    final recents =
        await container.read(recentFilesProvider.future);
    expect(recents.length, 1);
  });

  testWidgets('tapping a recent pops history and resumes the file',
      (tester) async {
    final file = File('${Directory.systemTemp.path}/pdf_tabs_test.pdf');
    await tester.runAsync(() => file.writeAsString('stub'));
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(recentFilesProvider.notifier)
        .addRecent(file.path, 'pdf_tabs_test.pdf');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HistoryScreen(),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);

    await tester.tap(find.text('pdf_tabs_test.pdf'));
    await tester.pumpAndSettle();

    expect(find.byType(HistoryScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
    final tabs = await container.read(pdfTabsProvider.future);
    expect(tabs.tabs.length, 1);
    expect(tabs.tabs.first.filePath, file.path);
  });
}
