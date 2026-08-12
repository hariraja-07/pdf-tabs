// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Pdf Tabs';

  @override
  String get openPdfToStartReading => 'Open a PDF to start reading';

  @override
  String get pickPdf => 'Pick PDF';

  @override
  String get openPdfTooltip => 'Open PDF';

  @override
  String get search => 'Search';

  @override
  String get searchInPdf => 'Search in PDF...';

  @override
  String get previousMatch => 'Previous match';

  @override
  String get nextMatch => 'Next match';

  @override
  String get closeTab => 'Close tab';

  @override
  String get toggleTheme => 'Toggle theme';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get retry => 'Retry';

  @override
  String get couldNotOpenPdf => 'Could not open PDF';

  @override
  String tabClosed(String fileName) {
    return '$fileName closed';
  }

  @override
  String get undo => 'Undo';

  @override
  String get goToPage => 'Go to page';

  @override
  String pageRange(int min, int max) {
    return 'Pages: $min - $max';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get go => 'Go';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get recentFiles => 'Recent Files';

  @override
  String get clearAllRecents => 'Clear Recent Files';

  @override
  String get clear => 'Clear';

  @override
  String get fileNotFound => 'File not found on device';

  @override
  String get zoomIn => 'Zoom in';

  @override
  String get zoomOut => 'Zoom out';

  @override
  String get fitWidth => 'Fit width';

  @override
  String get fitPage => 'Fit page';

  @override
  String get toggleDarkMode => 'Toggle dark reader mode';

  @override
  String get continuousScroll => 'Continuous scroll';

  @override
  String get singlePage => 'Single page';

  @override
  String get matchCase => 'Match case';

  @override
  String get sharePdf => 'Share PDF';

  @override
  String get addBookmark => 'Add bookmark';

  @override
  String get removeBookmark => 'Remove bookmark';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get noBookmarks => 'No bookmarks yet';

  @override
  String get bookmarkAdded => 'Bookmark added';

  @override
  String get bookmarkRemoved => 'Bookmark removed';

  @override
  String bookmarkPage(int page) {
    return 'Page $page';
  }

  @override
  String get tableOfContents => 'Table of contents';

  @override
  String get noTableOfContents => 'No table of contents';

  @override
  String get historyBack => 'Go back';

  @override
  String get historyForward => 'Go forward';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get exitFullscreen => 'Exit fullscreen';
}
