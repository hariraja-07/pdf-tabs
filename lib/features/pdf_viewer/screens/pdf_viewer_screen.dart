import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final _pdfController = PdfViewerController();
  PdfTextSearcher? _searcher;
  bool _isSearchOpen = false;
  final _searchController = TextEditingController();
  int _currentMatchIndex = 0;
  int _totalMatches = 0;

  @override
  void dispose() {
    _searcher?.dispose();
    _searchController.dispose();
    super.dispose();
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

  void _toggleSearch() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearchOpen ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
            tooltip: 'Search',
          ),
        ],
      ),
      body: Column(
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
              controller: _pdfController,
              params: PdfViewerParams(
                margin: 8.0,
                textSelectionParams: const PdfTextSelectionParams(
                  enabled: true,
                ),
                matchTextColor: Colors.yellow.withAlpha(127),
                activeMatchTextColor: Colors.orange.withAlpha(127),
                pagePaintCallbacks: [
                  if (_searcher != null)
                    _searcher!.pageTextMatchPaintCallback,
                ],
                onViewerReady: (document, controller) {
                  _initSearcher();
                },
              ),
            ),
          ),
        ],
      ),
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
                hintText: 'Search in PDF...',
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
            tooltip: 'Previous match',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            onPressed: totalMatches > 0 ? onNext : null,
            tooltip: 'Next match',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
