import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_tabs/features/home/recent_files_provider.dart';
import 'package:pdf_tabs/features/home/screens/history_screen.dart';
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
}
