import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../l10n/app_localizations.dart';
import '../../bookmarks/bookmarks_provider.dart';
import '../../settings/invert_mode_provider.dart';

final fullscreenModeProvider = StateProvider<bool>((ref) => false);

class PdfDocumentView extends ConsumerStatefulWidget {
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
  ConsumerState<PdfDocumentView> createState() => PdfDocumentViewState();
}

class PdfDocumentViewState extends ConsumerState<PdfDocumentView> {
  final _pdfController = PdfViewerController();
  PdfTextSearcher? _searcher;
  bool _isSearchOpen = false;
  bool _isCaseSensitive = false;
  final _searchController = TextEditingController();
  int _currentMatchIndex = 0;
  int _totalMatches = 0;
  int _reloadKey = 0;
  int? _currentPageNumber;
  int? _pageCount;
  List<PdfOutlineNode>? _outline;
  final List<int> _history = [];
  int _historyPos = -1;

  bool get isSearchOpen => _isSearchOpen;

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
    _searcher?.startTextSearch(
      query,
      caseInsensitive: !_isCaseSensitive,
    );
  }

  void _toggleCaseSensitive() {
    setState(() {
      _isCaseSensitive = !_isCaseSensitive;
    });
    if (_searchController.text.isNotEmpty) {
      _onSearchChanged(_searchController.text);
    }
  }

  void _nextMatch() {
    _searcher?.goToNextMatch();
  }

  void _previousMatch() {
    _searcher?.goToPrevMatch();
  }

  void _zoomIn() {
    _pdfController.zoomUp();
  }

  void _zoomOut() {
    _pdfController.zoomDown();
  }

  Future<void> _toggleBookmark() async {
    final pageNumber = _currentPageNumber ?? 1;
    final l10n = AppLocalizations.of(context);
    final nowBookmarked = await ref
        .read(bookmarksProvider.notifier)
        .toggle(widget.filePath, pageNumber - 1);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(nowBookmarked ? l10n.bookmarkAdded : l10n.bookmarkRemoved),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  Future<void> _loadOutline(PdfDocument document) async {
    try {
      final outline = await document.loadOutline();
      if (!mounted) return;
      setState(() => _outline = outline);
    } catch (_) {
      if (!mounted) return;
      setState(() => _outline = const []);
    }
  }

  void _openNavigation() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _NavigationSheet(
        filePath: widget.filePath,
        outline: _outline,
        currentPageNumber: _currentPageNumber ?? 1,
        onJumpToPage: (pageIndex) {
          Navigator.of(sheetContext).pop();
          _pushHistoryTo(pageIndex + 1);
          _pdfController.goToPage(pageNumber: pageIndex + 1);
        },
        onJumpToDest: (dest) {
          Navigator.of(sheetContext).pop();
          if (dest == null) return;
          _pushHistoryTo(dest.pageNumber);
          _pdfController.goToDest(dest);
        },
      ),
    );
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

  bool get canGoBack => _historyPos > 0;

  bool get canGoForward =>
      _historyPos >= 0 && _historyPos < _history.length - 1;

  void _pushHistoryTo(int target) {
    final current = _currentPageNumber;
    if (current == null || current == target) return;
    if (_historyPos < _history.length - 1) {
      _history.removeRange(_historyPos + 1, _history.length);
    }
    if (_history.isEmpty || _history[_historyPos] != current) {
      _history.add(current);
      _historyPos++;
    }
    _history.add(target);
    _historyPos++;
  }

  void _goBack() {
    if (!canGoBack) return;
    _historyPos--;
    _pdfController.goToPage(pageNumber: _history[_historyPos]);
  }

  void _goForward() {
    if (!canGoForward) return;
    _historyPos++;
    _pdfController.goToPage(pageNumber: _history[_historyPos]);
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
      _pushHistoryTo(result);
      await _pdfController.goToPage(pageNumber: result);
    }
  }

  Widget _buildPdfContent(BuildContext context) {
    final viewer = PdfViewer.file(
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
          if (_searcher != null) _searcher!.pageTextMatchPaintCallback,
        ],
        viewerOverlayBuilder: (context, size, handleLinkTap) => [
          PdfViewerScrollThumb(
            controller: _pdfController,
            orientation: ScrollbarOrientation.right,
            thumbBuilder: (context, thumbSize, pageNumber, controller) =>
                _ScrollThumb(size: thumbSize, pageNumber: pageNumber),
          ),
        ],
        onViewerReady: (document, controller) {
          _initSearcher();
          _loadOutline(document);
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
    );

    if (ref.watch(invertModeProvider).valueOrNull ?? false) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: viewer,
      );
    }

    return viewer;
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
            isCaseSensitive: _isCaseSensitive,
            onToggleCaseSensitive: _toggleCaseSensitive,
          ),
        Expanded(
          child: _buildPdfContent(context),
        ),
        if (_pageCount != null && !ref.watch(fullscreenModeProvider))
          _PageNavigationBar(
            currentPage: _currentPageNumber ?? 1,
            pageCount: _pageCount!,
            isBookmarked: _isCurrentPageBookmarked,
            onPrevious: _goToPreviousPage,
            onNext: _goToNextPage,
            onJump: _jumpToPage,
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onToggleBookmark: _toggleBookmark,
            onOpenBookmarks: _openNavigation,
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            onBack: _goBack,
            onForward: _goForward,
            onPageSliderChange: (targetPage) {
              _pushHistoryTo(targetPage);
              _pdfController.goToPage(pageNumber: targetPage);
            },
          ),
      ],
    );
  }

  bool get _isCurrentPageBookmarked {
    final bookmarks = ref.watch(bookmarksProvider).valueOrNull;
    if (bookmarks == null) return false;
    final fileBookmarks = bookmarks[widget.filePath];
    if (fileBookmarks == null) return false;
    final pageIndex = (_currentPageNumber ?? 1) - 1;
    return fileBookmarks.any((entry) => entry.pageIndex == pageIndex);
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final int currentMatch;
  final int totalMatches;
  final bool isCaseSensitive;
  final VoidCallback onToggleCaseSensitive;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onNext,
    required this.onPrevious,
    required this.currentMatch,
    required this.totalMatches,
    required this.isCaseSensitive,
    required this.onToggleCaseSensitive,
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
                suffixIcon: IconButton(
                  icon: Text(
                    'Aa',
                    style: TextStyle(
                      fontWeight:
                          isCaseSensitive ? FontWeight.bold : FontWeight.normal,
                      color: isCaseSensitive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onPressed: onToggleCaseSensitive,
                  tooltip: l10n.matchCase,
                ),
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
  final bool isBookmarked;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onJump;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onToggleBookmark;
  final VoidCallback onOpenBookmarks;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final ValueChanged<int> onPageSliderChange;

  const _PageNavigationBar({
    required this.currentPage,
    required this.pageCount,
    required this.isBookmarked,
    required this.onPrevious,
    required this.onNext,
    required this.onJump,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onToggleBookmark,
    required this.onOpenBookmarks,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onPageSliderChange,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1 ? onPrevious : null,
            tooltip: l10n.previousPage,
            visualDensity: VisualDensity.compact,
          ),
          InkWell(
            onTap: onJump,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '$currentPage / $pageCount',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < pageCount ? onNext : null,
            tooltip: l10n.nextPage,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: canGoBack ? onBack : null,
            tooltip: l10n.historyBack,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: canGoForward ? onForward : null,
            tooltip: l10n.historyForward,
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 20),
            onPressed: onZoomOut,
            tooltip: l10n.zoomOut,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 20),
            onPressed: onZoomIn,
            tooltip: l10n.zoomIn,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              size: 20,
              color: isBookmarked ? colorScheme.primary : null,
            ),
            onPressed: onToggleBookmark,
            tooltip: isBookmarked ? l10n.removeBookmark : l10n.addBookmark,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined, size: 20),
            onPressed: onOpenBookmarks,
            tooltip: l10n.bookmarks,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _NavigationSheet extends ConsumerStatefulWidget {
  final String filePath;
  final List<PdfOutlineNode>? outline;
  final int currentPageNumber;
  final ValueChanged<int> onJumpToPage;
  final ValueChanged<PdfDest?> onJumpToDest;

  const _NavigationSheet({
    required this.filePath,
    required this.outline,
    required this.currentPageNumber,
    required this.onJumpToPage,
    required this.onJumpToDest,
  });

  @override
  ConsumerState<_NavigationSheet> createState() => _NavigationSheetState();
}

class _NavigationSheetState extends ConsumerState<_NavigationSheet> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final hasOutline = (widget.outline?.isNotEmpty ?? false);
    final entries =
        ref.watch(bookmarksProvider).valueOrNull?[widget.filePath] ?? const [];

    if (!hasOutline) _tabIndex = 0;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  Text(
                    l10n.bookmarks,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${entries.length}',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (hasOutline)
              TabBar(
                tabAlignment: TabAlignment.start,
                isScrollable: true,
                dividerColor: Colors.transparent,
                indicatorColor: colorScheme.primary,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                onTap: (index) => setState(() => _tabIndex = index),
                tabs: [
                  Tab(text: l10n.bookmarks),
                  Tab(text: l10n.tableOfContents),
                ],
              ),
            Flexible(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _BookmarksList(
                    filePath: widget.filePath,
                    currentPageNumber: widget.currentPageNumber,
                    onJump: widget.onJumpToPage,
                  ),
                  if (hasOutline)
                    _OutlineList(
                      nodes: widget.outline!,
                      onJump: widget.onJumpToDest,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarksList extends ConsumerWidget {
  final String filePath;
  final int currentPageNumber;
  final ValueChanged<int> onJump;

  const _BookmarksList({
    required this.filePath,
    required this.currentPageNumber,
    required this.onJump,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final entries =
        ref.watch(bookmarksProvider).valueOrNull?[filePath] ?? const [];

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          l10n.noBookmarks,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final pageNumber = entry.pageIndex + 1;
        return ListTile(
          leading: Icon(
            Icons.bookmark,
            size: 20,
            color: colorScheme.primary,
          ),
          title: Text(l10n.bookmarkPage(pageNumber)),
          subtitle: Text(l10n.pageRange(pageNumber, pageNumber)),
          trailing: pageNumber == currentPageNumber
              ? const Icon(Icons.radio_button_checked, size: 16)
              : null,
          onTap: () => onJump(entry.pageIndex),
        );
      },
    );
  }
}

class _OutlineList extends StatelessWidget {
  final List<PdfOutlineNode> nodes;
  final ValueChanged<PdfDest?> onJump;

  const _OutlineList({required this.nodes, required this.onJump});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (nodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          l10n.noTableOfContents,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: nodes.length,
      itemBuilder: (context, index) => _OutlineTile(
        node: nodes[index],
        depth: 0,
        onJump: onJump,
      ),
    );
  }
}

class _OutlineTile extends StatefulWidget {
  final PdfOutlineNode node;
  final int depth;
  final ValueChanged<PdfDest?> onJump;

  const _OutlineTile({
    required this.node,
    required this.depth,
    required this.onJump,
  });

  @override
  State<_OutlineTile> createState() => _OutlineTileState();
}

class _OutlineTileState extends State<_OutlineTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final node = widget.node;
    final hasChildren = node.children.isNotEmpty;
    final pageNumber = node.dest?.pageNumber;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            if (node.dest != null) {
              widget.onJump(node.dest);
            } else if (hasChildren) {
              setState(() => _expanded = !_expanded);
            }
          },
          child: Padding(
            padding: EdgeInsets.only(
              left: 12.0 + widget.depth * 16,
              right: 16,
              top: 4,
              bottom: 4,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: hasChildren
                      ? IconButton(
                          icon: Icon(
                            _expanded
                                ? Icons.expand_more
                                : Icons.chevron_right,
                            size: 20,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                        )
                      : const Icon(Icons.menu_book, size: 18),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    node.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          hasChildren ? FontWeight.w600 : FontWeight.w400,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (pageNumber != null)
                  Text(
                    '$pageNumber',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_expanded)
          for (final child in node.children)
            _OutlineTile(
              node: child,
              depth: widget.depth + 1,
              onJump: widget.onJump,
            ),
      ],
    );
  }
}

class _ScrollThumb extends StatelessWidget {
  final Size size;
  final int? pageNumber;

  const _ScrollThumb({required this.size, required this.pageNumber});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${pageNumber ?? ''}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colorScheme.onInverseSurface,
          ),
        ),
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
