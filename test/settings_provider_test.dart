import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_tabs/features/settings/invert_mode_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    await container.read(invertModeProvider.future);
  });

  tearDown(() => container.dispose());

  test('defaults to off', () {
    expect(container.read(invertModeProvider).requireValue, isFalse);
  });

  test('set persists across a new container', () async {
    await container.read(invertModeProvider.notifier).set(true);

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    final value = await restored.read(invertModeProvider.future);

    expect(value, isTrue);
  });

  test('toggle flips the value', () async {
    await container.read(invertModeProvider.notifier).toggle();
    expect(container.read(invertModeProvider).requireValue, isTrue);

    await container.read(invertModeProvider.notifier).toggle();
    expect(container.read(invertModeProvider).requireValue, isFalse);
  });
}
