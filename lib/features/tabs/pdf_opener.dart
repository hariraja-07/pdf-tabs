import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pdf_tabs_provider.dart';

final isPickingProvider = StateProvider<bool>((ref) => false);

class PdfOpener {
  PdfOpener._();

  static Future<void> pickAndOpen(WidgetRef ref) async {
    if (ref.read(isPickingProvider)) return;
    ref.read(isPickingProvider.notifier).state = true;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      final path = result?.files.single.path;
      if (path == null || path.isEmpty) return;
      await ref.read(pdfTabsProvider.notifier).open(path);
    } finally {
      ref.read(isPickingProvider.notifier).state = false;
    }
  }
}
