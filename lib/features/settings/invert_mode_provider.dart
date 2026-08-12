import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final invertModeProvider =
    AsyncNotifierProvider<InvertModeNotifier, bool>(InvertModeNotifier.new);

class InvertModeNotifier extends AsyncNotifier<bool> {
  static const _prefsKey = 'dark_reader_mode';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? false;
  }

  Future<void> set(bool value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }

  Future<void> toggle() async {
    await set(!(state.valueOrNull ?? false));
  }
}
