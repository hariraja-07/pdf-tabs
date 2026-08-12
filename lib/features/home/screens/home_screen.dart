import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/screens/settings_screen.dart';
import '../../tabs/pdf_opener.dart';
import '../../tabs/pdf_tabs_provider.dart';
import '../recent_files_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPicking = ref.watch(isPickingProvider);
    final l10n = AppLocalizations.of(context);
    final recentAsync = ref.watch(recentFilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
          const ThemeToggleButton(),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf,
                      size: 72,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.openPdfToStartReading,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed:
                        isPicking ? null : () => PdfOpener.pickAndOpen(ref),
                    icon: isPicking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.file_open),
                    label: Text(l10n.pickPdf),
                  ),
                ],
              ),
            ),
          ),

          // Recent Files Header & List
          recentAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
            error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (recentFiles) {
              if (recentFiles.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }

              return SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.recentFiles,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                          ),
                          TextButton(
                            onPressed: () {
                              ref.read(recentFilesProvider.notifier).clearAll();
                            },
                            child: Text(l10n.clear),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: recentFiles.length,
                      itemBuilder: (context, index) {
                        final item = recentFiles[index];
                        final exists = File(item.filePath).existsSync();

                        return Dismissible(
                          key: Key('recent_${item.filePath}'),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) {
                            ref
                                .read(recentFilesProvider.notifier)
                                .removeRecent(item.filePath);
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
                                  exists
                                      ? Icons.description_outlined
                                      : Icons.error_outline,
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
                                      : colorScheme.onSurface
                                          .withValues(alpha: 0.5),
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
                              trailing: exists
                                  ? const Icon(Icons.chevron_right, size: 20)
                                  : null,
                              onTap: exists
                                  ? () async {
                                      await ref
                                          .read(pdfTabsProvider.notifier)
                                          .open(
                                            item.filePath,
                                            initialPageIndex: item.pageIndex,
                                          );
                                    }
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
