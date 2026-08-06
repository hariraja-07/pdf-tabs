import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pdf_tabs/main.dart';

void main() {
  testWidgets('PdfTabs smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PdfTabsApp()));

    expect(find.text('PdfTabs'), findsOneWidget);
    expect(find.text('Pick PDF'), findsOneWidget);
  });
}
