import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../recent_files_provider.dart';
import '../widgets/recent_file_tile.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final recentAsync = ref.watch(recentFilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.readingHistory),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_recents') {
                ref.read(recentFilesProvider.notifier).clearAll();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear_recents',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, size: 20),
                    const SizedBox(width: 12),
                    Text(l10n.clearAllRecents),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: recentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const SizedBox.shrink(),
        data: (recentFiles) {
          if (recentFiles.isEmpty) {
            return Center(
              child: Text(
                l10n.noHistory,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: recentFiles.length,
            itemBuilder: (context, index) =>
                RecentFileTile(item: recentFiles[index]),
          );
        },
      ),
    );
  }
}
