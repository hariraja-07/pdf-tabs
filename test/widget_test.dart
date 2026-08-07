import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_tabs/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PdfTabs smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PdfTabsApp()));
    await tester.pumpAndSettle();

    expect(find.text('PdfTabs'), findsOneWidget);
    expect(find.text('Pick PDF'), findsOneWidget);
  });
}
