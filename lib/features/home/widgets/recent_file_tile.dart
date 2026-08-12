import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../tabs/pdf_tabs_provider.dart';
import '../recent_files_provider.dart';

class RecentFileTile extends ConsumerWidget {
  const RecentFileTile({super.key, required this.item, this.onOpened});

  final RecentFileItem item;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final exists = File(item.filePath).existsSync();

    return Dismissible(
      key: Key('recent_${item.filePath}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref.read(recentFilesProvider.notifier).removeRecent(item.filePath);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: colorScheme.errorContainer,
        child: Icon(
          Icons.delete,
          color: colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: exists
                ? colorScheme.secondaryContainer
                : colorScheme.errorContainer,
            child: Icon(
              exists ? Icons.description_outlined : Icons.error_outline,
              size: 20,
              color: exists
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.error,
            ),
          ),
          title: Text(
            item.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: exists
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          subtitle: Text(
            exists
                ? '${l10n.pageN(item.pageIndex + 1)} · ${item.filePath}'
                : l10n.fileNotFound,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: exists
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.error,
            ),
          ),
          trailing: exists ? const Icon(Icons.chevron_right, size: 20) : null,
          onTap: exists
              ? () async {
                  await ref
                      .read(pdfTabsProvider.notifier)
                      .open(item.filePath, initialPageIndex: item.pageIndex);
                  onOpened?.call();
                }
              : null,
        ),
      ),
    );
  }
}
