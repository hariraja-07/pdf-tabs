import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_tabs/core/theme/app_theme.dart';
import 'package:pdf_tabs/features/tabs/pdf_tab.dart';
import 'package:pdf_tabs/features/tabs/pdf_tabs_provider.dart';
import 'package:pdf_tabs/features/tabs/screens/pdf_tabs_screen.dart';
import 'package:pdf_tabs/l10n/app_localizations.dart';

class _FailingTabsNotifier extends PdfTabsNotifier {
  @override
  Future<PdfTabsState> build() async {
    throw StateError('boom');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  testWidgets('shows home screen when no tabs are open', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(pdfTabsProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(const PdfTabsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open a PDF to start reading'), findsOneWidget);
    expect(find.text('Pick PDF'), findsOneWidget);
  });

  testWidgets('renders error state with retry when provider fails',
      (tester) async {
    final container = ProviderContainer(
      overrides: [pdfTabsProvider.overrideWith(_FailingTabsNotifier.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(const PdfTabsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('activates tabs and closing shows undo snackbar',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(pdfTabsProvider.future);
    await container.read(pdfTabsProvider.notifier).open('/docs/a.pdf');
    await container.read(pdfTabsProvider.notifier).open('/docs/b.pdf');

    Widget documentBuilder(BuildContext context, PdfTabData tab) {
      return Center(child: Text('VIEW:${tab.fileName}'));
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(PdfTabsScreen(documentBuilder: documentBuilder)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VIEW:b.pdf'), findsOneWidget);
    expect(find.text('VIEW:a.pdf'), findsNothing);

    await tester.tap(find.text('a.pdf'));
    await tester.pumpAndSettle();
    expect(find.text('VIEW:a.pdf'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.text('a.pdf closed'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('VIEW:a.pdf'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('VIEW:a.pdf'), findsOneWidget);
    final state = container.read(pdfTabsProvider).requireValue;
    expect(state.tabs.length, 2);
    expect(state.activeIndex, 1);
  });

  testWidgets('overflow menu exposes chrome actions', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(pdfTabsProvider.future);
    await container.read(pdfTabsProvider.notifier).open('/docs/a.pdf');

    Widget documentBuilder(BuildContext context, PdfTabData tab) {
      return Center(child: Text('VIEW:${tab.fileName}'));
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(PdfTabsScreen(documentBuilder: documentBuilder)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Share PDF'), findsOneWidget);
    expect(find.text('Fullscreen'), findsOneWidget);
    expect(find.text('Dark reader'), findsOneWidget);
    expect(find.text('Reading history'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('dark reader toggle shows check in overflow menu', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(pdfTabsProvider.future);
    await container.read(pdfTabsProvider.notifier).open('/docs/a.pdf');

    Widget documentBuilder(BuildContext context, PdfTabData tab) {
      return Center(child: Text('VIEW:${tab.fileName}'));
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(PdfTabsScreen(documentBuilder: documentBuilder)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsNothing);

    await tester.tap(find.text('Dark reader'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('reading history opens from overflow menu', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(pdfTabsProvider.future);
    await container.read(pdfTabsProvider.notifier).open('/docs/a.pdf');

    Widget documentBuilder(BuildContext context, PdfTabData tab) {
      return Center(child: Text('VIEW:${tab.fileName}'));
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(PdfTabsScreen(documentBuilder: documentBuilder)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reading history'));
    await tester.pumpAndSettle();

    expect(find.text('Reading history'), findsOneWidget);
    expect(find.text('a.pdf'), findsOneWidget);
  });

  testWidgets('settings opens from overflow menu', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(pdfTabsProvider.future);
    await container.read(pdfTabsProvider.notifier).open('/docs/a.pdf');

    Widget documentBuilder(BuildContext context, PdfTabData tab) {
      return Center(child: Text('VIEW:${tab.fileName}'));
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(PdfTabsScreen(documentBuilder: documentBuilder)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('theme toggle cycles and persists', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(actions: const [ThemeToggleButton()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.brightness_auto), findsOneWidget);

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode), findsOneWidget);

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.dark_mode), findsOneWidget);

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    expect(await restored.read(themeModeProvider.future), ThemeMode.dark);
  });
}
