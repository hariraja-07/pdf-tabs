import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/screens/home_screen.dart';
import '../../pdf_viewer/widgets/pdf_document_view.dart';
import '../pdf_opener.dart';
import '../pdf_tab.dart';
import '../pdf_tabs_provider.dart';

class PdfTabsScreen extends ConsumerStatefulWidget {
  const PdfTabsScreen({super.key});

  @override
  ConsumerState<PdfTabsScreen> createState() => _PdfTabsScreenState();
}

class _PdfTabsScreenState extends ConsumerState<PdfTabsScreen> {
  final Map<String, GlobalKey<PdfDocumentViewState>> _docKeys = {};

  void _toggleSearch(PdfTabsState state) {
    final activeTab = state.tabs[state.activeIndex];
    _docKeys[activeTab.id]?.currentState?.toggleSearch();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pdf Tabs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _toggleSearch(state),
            tooltip: 'Search',
          ),
          const ThemeToggleButton(),
        ],
      ),
      body: Column(
        children: [
          _TabStrip(
            tabs: state.tabs,
            activeIndex: state.activeIndex,
            isPicking: isPicking,
            onActivate: (id) =>
                ref.read(pdfTabsProvider.notifier).activate(id),
            onClose: (id) {
              _docKeys.remove(id);
              ref.read(pdfTabsProvider.notifier).close(id);
            },
            onAdd: () => PdfOpener.pickAndOpen(ref),
          ),
          Expanded(
            child: IndexedStack(
              index: state.activeIndex,
              children: [
                for (final tab in state.tabs)
                  PdfDocumentView(
                    key: _docKeys.putIfAbsent(
                      tab.id,
                      () => GlobalKey<PdfDocumentViewState>(),
                    ),
                    filePath: tab.filePath,
                  ),
              ],
            ),
          ),
        ],
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
  final VoidCallback onAdd;

  const _TabStrip({
    required this.tabs,
    required this.activeIndex,
    required this.isPicking,
    required this.onActivate,
    required this.onClose,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 56,
      color: colorScheme.surfaceContainerHighest,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          for (var i = 0; i < tabs.length; i++)
            _TabChip(
              tab: tabs[i],
              active: i == activeIndex,
              onTap: () => onActivate(tabs[i].id),
              onClose: () => onClose(tabs[i].id),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: IconButton.filledTonal(
              onPressed: isPicking ? null : onAdd,
              tooltip: 'Open PDF',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pdf Tabs'),
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
                'Something went wrong',
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
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {  final PdfTabData tab;
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
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf, size: 16, color: foreground),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    tab.fileName,
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
                  tooltip: 'Close tab',
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
