import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/recent_files_provider.dart';
import '../../home/screens/home_screen.dart';
import '../../pdf_viewer/widgets/pdf_document_view.dart';
import '../../settings/invert_mode_provider.dart';
import '../pdf_opener.dart';
import '../pdf_tab.dart';
import '../pdf_tabs_provider.dart';

class PdfTabsScreen extends ConsumerStatefulWidget {
  const PdfTabsScreen({super.key, this.documentBuilder});

  final Widget Function(BuildContext context, PdfTabData tab)? documentBuilder;

  @override
  ConsumerState<PdfTabsScreen> createState() => _PdfTabsScreenState();
}

class _PdfTabsScreenState extends ConsumerState<PdfTabsScreen> {
  final Map<String, GlobalKey<PdfDocumentViewState>> _docKeys = {};

  void _toggleSearch(PdfTabsState state) {
    final activeTab = state.tabs[state.activeIndex];
    _docKeys[activeTab.id]?.currentState?.toggleSearch();
  }

  Future<void> _shareCurrentTab(PdfTabsState state) async {
    if (state.tabs.isEmpty) return;
    final activeTab = state.tabs[state.activeIndex];
    final box = context.findRenderObject() as RenderBox?;
    await Share.shareXFiles(
      [XFile(activeTab.filePath)],
      text: activeTab.displayName,
      sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  Future<void> _closeTab(PdfTabsState state, String id) async {
    final tab = state.tabs.firstWhere((element) => element.id == id);
    _docKeys.remove(id);
    await ref.read(pdfTabsProvider.notifier).close(id);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).tabClosed(tab.displayName),
          ),
          action: SnackBarAction(
            label: AppLocalizations.of(context).undo,
            onPressed: () {
              ref.read(pdfTabsProvider.notifier).open(tab.filePath);
            },
          ),
        ),
      );
  }

  Widget _buildDocument(BuildContext context, PdfTabData tab) {
    final builder = widget.documentBuilder;
    if (builder != null) return builder(context, tab);

    return PdfDocumentView(
      key: _docKeys.putIfAbsent(
        tab.id,
        () => GlobalKey<PdfDocumentViewState>(),
      ),
      filePath: tab.filePath,
      initialPageIndex: tab.pageIndex,
      onPageChanged: (pageIndex) {
        ref.read(pdfTabsProvider.notifier).setPosition(tab.id, pageIndex);
        ref
            .read(recentFilesProvider.notifier)
            .updateProgress(tab.filePath, pageIndex);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabsAsync = ref.watch(pdfTabsProvider);

    return tabsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => _ErrorScreen(
        message: '$error',
        onRetry: () => ref.invalidate(pdfTabsProvider),
      ),
      data: (state) {
        if (state.tabs.isEmpty) return const HomeScreen();
        return _buildTabbed(context, state);
      },
    );
  }

  Widget _buildTabbed(BuildContext context, PdfTabsState state) {
    final isPicking = ref.watch(isPickingProvider);
    final isFullscreen = ref.watch(fullscreenModeProvider);
    final activeTab = state.tabs[state.activeIndex];
    final activeDocState = _docKeys[activeTab.id]?.currentState;
    final isSearchOpen = activeDocState?.isSearchOpen ?? false;

    return PopScope(
      canPop: !isSearchOpen && !isFullscreen,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isFullscreen) {
          ref.read(fullscreenModeProvider.notifier).state = false;
        } else if (isSearchOpen) {
          activeDocState?.toggleSearch();
        }
      },
      child: Scaffold(
        appBar: isFullscreen
            ? null
            : AppBar(
                title: Text(
                  activeTab.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _toggleSearch(state),
                    tooltip: AppLocalizations.of(context).search,
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => _shareCurrentTab(state),
                    tooltip: AppLocalizations.of(context).sharePdf,
                  ),
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () => ref
                        .read(fullscreenModeProvider.notifier)
                        .state = true,
                    tooltip: AppLocalizations.of(context).fullscreen,
                  ),
                  IconButton(
                    icon: Icon(
                      ref.watch(invertModeProvider).valueOrNull ?? false
                          ? Icons.invert_colors
                          : Icons.invert_colors_off,
                    ),
                    onPressed: () => ref
                        .read(invertModeProvider.notifier)
                        .toggle(),
                    tooltip: AppLocalizations.of(context).toggleDarkMode,
                  ),
                  const ThemeToggleButton(),
                ],
              ),
        body: isFullscreen
            ? Stack(
                children: [
                  Positioned.fill(
                    child: IndexedStack(
                      index: state.activeIndex,
                      children: [
                        for (final tab in state.tabs)
                          _buildDocument(context, tab),
                      ],
                    ),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Material(
                          color: Colors.black54,
                          shape: const CircleBorder(),
                          child: IconButton(
                            icon: const Icon(
                              Icons.fullscreen_exit,
                              color: Colors.white,
                            ),
                            tooltip: AppLocalizations.of(context).exitFullscreen,
                            onPressed: () => ref
                                .read(fullscreenModeProvider.notifier)
                                .state = false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _TabStrip(
                    tabs: state.tabs,
                    activeIndex: state.activeIndex,
                    isPicking: isPicking,
                    onActivate: (id) =>
                        ref.read(pdfTabsProvider.notifier).activate(id),
                    onClose: (id) => _closeTab(state, id),
                    onReorder: (oldIndex, newIndex) => ref
                        .read(pdfTabsProvider.notifier)
                        .reorder(oldIndex, newIndex),
                    onAdd: () => PdfOpener.pickAndOpen(ref),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: state.activeIndex,
                      children: [
                        for (final tab in state.tabs)
                          _buildDocument(context, tab),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  final List<PdfTabData> tabs;
  final int activeIndex;
  final bool isPicking;
  final ValueChanged<String> onActivate;
  final ValueChanged<String> onClose;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onAdd;

  const _TabStrip({
    required this.tabs,
    required this.activeIndex,
    required this.isPicking,
    required this.onActivate,
    required this.onClose,
    required this.onReorder,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 52,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: tabs.length,
              onReorder: onReorder,
              itemBuilder: (context, i) {
                final tab = tabs[i];
                return Container(
                  key: ValueKey(tab.id),
                  child: _TabChip(
                    tab: tab,
                    active: i == activeIndex,
                    onTap: () => onActivate(tab.id),
                    onClose: () => onClose(tab.id),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton.filledTonal(
              onPressed: isPicking ? null : onAdd,
              tooltip: AppLocalizations.of(context).openPdfTooltip,
              visualDensity: VisualDensity.compact,
              icon: isPicking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorScreen({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [ThemeToggleButton()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.somethingWentWrong,
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final PdfTabData tab;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabChip({
    required this.tab,
    required this.active,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = active
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: active ? colorScheme.primaryContainer : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        elevation: active ? 1 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.picture_as_pdf,
                  size: 16,
                  color: active ? colorScheme.primary : foreground,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    tab.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: foreground,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: foreground,
                  onPressed: onClose,
                  tooltip: AppLocalizations.of(context).closeTab,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
