import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../l10n/app_localizations.dart';

class PdfDocumentView extends StatefulWidget {
  const PdfDocumentView({
    super.key,
    required this.filePath,
    this.initialPageIndex = 0,
    this.onPageChanged,
  });

  final String filePath;
  final int initialPageIndex;
  final ValueChanged<int>? onPageChanged;

  @override
  State<PdfDocumentView> createState() => PdfDocumentViewState();
}

class PdfDocumentViewState extends State<PdfDocumentView> {
  final _pdfController = PdfViewerController();
  PdfTextSearcher? _searcher;
  bool _isSearchOpen = false;
  final _searchController = TextEditingController();
  int _currentMatchIndex = 0;
  int _totalMatches = 0;
  int _reloadKey = 0;
  int? _currentPageNumber;
  int? _pageCount;

  @override
  void dispose() {
    _searcher?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void toggleSearch() {
    setState(() {
      _isSearchOpen = !_isSearchOpen;
      if (!_isSearchOpen) {
        _searchController.clear();
        _searcher?.resetTextSearch();
        _currentMatchIndex = 0;
        _totalMatches = 0;
      }
    });
  }

  void _initSearcher() {
    if (_searcher != null) return;
    _searcher = PdfTextSearcher(_pdfController);
    _searcher!.addListener(() {
      if (mounted) {
        setState(() {
          _totalMatches = _searcher!.matches.length;
          _currentMatchIndex = _searcher!.currentIndex ?? 0;
        });
      }
    });
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      _searcher?.resetTextSearch();
      setState(() {
        _currentMatchIndex = 0;
        _totalMatches = 0;
      });
      return;
    }
    _searcher?.startTextSearch(query);
  }

  void _nextMatch() {
    _searcher?.goToNextMatch();
  }

  void _previousMatch() {
    _searcher?.goToPrevMatch();
  }

  void _goToPreviousPage() {
    final pageNumber = _currentPageNumber;
    if (pageNumber == null || pageNumber <= 1) return;
    _pdfController.goToPage(pageNumber: pageNumber - 1);
  }

  void _goToNextPage() {
    final pageNumber = _currentPageNumber;
    final pageCount = _pageCount;
    if (pageNumber == null || pageCount == null || pageNumber >= pageCount) {
      return;
    }
    _pdfController.goToPage(pageNumber: pageNumber + 1);
  }

  Future<void> _jumpToPage() async {
    final pageCount = _pageCount;
    final current = _currentPageNumber ?? 1;
    if (pageCount == null) return;

    final controller = TextEditingController(text: '$current');
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.goToPage),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              helperText: l10n.pageRange(1, pageCount),
            ),
            onSubmitted: (value) {
              final page = int.tryParse(value);
              if (page != null && page >= 1 && page <= pageCount) {
                Navigator.of(dialogContext).pop(page);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final page = int.tryParse(controller.text);
                if (page != null && page >= 1 && page <= pageCount) {
                  Navigator.of(dialogContext).pop(page);
                }
              },
              child: Text(l10n.go),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      await _pdfController.goToPage(pageNumber: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isSearchOpen)
          _SearchBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onNext: _nextMatch,
            onPrevious: _previousMatch,
            currentMatch: _currentMatchIndex,
            totalMatches: _totalMatches,
          ),
        Expanded(
          child: PdfViewer.file(
            widget.filePath,
            key: ValueKey(_reloadKey),
            controller: _pdfController,
            params: PdfViewerParams(
              margin: 8.0,
              textSelectionParams: const PdfTextSelectionParams(
                enabled: true,
              ),
              matchTextColor: Colors.yellow.withAlpha(127),
              activeMatchTextColor: Colors.orange.withAlpha(127),
              errorBannerBuilder: (context, error, _, _) => _LoadErrorView(
                message: '$error',
                onRetry: () => setState(() => _reloadKey++),
              ),
              onPageChanged: (pageNumber) {
                if (!mounted) return;
                setState(() => _currentPageNumber = pageNumber);
                if (pageNumber != null) {
                  widget.onPageChanged?.call(pageNumber - 1);
                }
              },
              pagePaintCallbacks: [
                if (_searcher != null)
                  _searcher!.pageTextMatchPaintCallback,
              ],
              onViewerReady: (document, controller) {
                _initSearcher();
                setState(() {
                  _pageCount = controller.pageCount;
                  _currentPageNumber = controller.pageNumber;
                });
                final initial = widget.initialPageIndex;
                if (initial > 0 &&
                    controller.isReady &&
                    initial < controller.pageCount) {
                  controller.goToPage(
                    pageNumber: initial + 1,
                    duration: Duration.zero,
                  );
                }
              },
            ),
          ),
        ),
        if (_pageCount != null)
          _PageNavigationBar(
            currentPage: _currentPageNumber ?? 1,
            pageCount: _pageCount!,
            onPrevious: _goToPreviousPage,
            onNext: _goToNextPage,
            onJump: _jumpToPage,
          ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final int currentMatch;
  final int totalMatches;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onNext,
    required this.onPrevious,
    required this.currentMatch,
    required this.totalMatches,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.searchInPdf,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
            ),
          ),
          if (totalMatches > 0) ...[
            const SizedBox(width: 8),
            Text(
              '$currentMatch/$totalMatches',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            onPressed: totalMatches > 0 ? onPrevious : null,
            tooltip: l10n.previousMatch,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            onPressed: totalMatches > 0 ? onNext : null,
            tooltip: l10n.nextMatch,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _PageNavigationBar extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onJump;

  const _PageNavigationBar({
    required this.currentPage,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      height: 48,
      color: colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1 ? onPrevious : null,
            tooltip: l10n.previousPage,
          ),
          Expanded(
            child: InkWell(
              onTap: onJump,
              borderRadius: BorderRadius.circular(8),
              child: Center(
                child: Text(
                  '$currentPage / $pageCount',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < pageCount ? onNext : null,
            tooltip: l10n.nextPage,
          ),
        ],
      ),
    );
  }
}

class _LoadErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              l10n.couldNotOpenPdf,
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
    );
  }
}
