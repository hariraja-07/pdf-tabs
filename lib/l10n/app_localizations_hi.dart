// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'Pdf Tabs';

  @override
  String get openPdfToStartReading => 'पढ़ना शुरू करने के लिए एक PDF खोलें';

  @override
  String get pickPdf => 'PDF चुनें';

  @override
  String get openPdfTooltip => 'PDF खोलें';

  @override
  String get search => 'खोजें';

  @override
  String get searchInPdf => 'PDF में खोजें...';

  @override
  String get previousMatch => 'पिछला परिणाम';

  @override
  String get nextMatch => 'अगला परिणाम';

  @override
  String get closeTab => 'टैब बंद करें';

  @override
  String get toggleTheme => 'थीम बदलें';

  @override
  String get somethingWentWrong => 'कुछ गलत हो गया';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get couldNotOpenPdf => 'PDF नहीं खोल सके';

  @override
  String tabClosed(String fileName) {
    return '$fileName बंद हो गया';
  }

  @override
  String get undo => 'पूर्ववत करें';

  @override
  String get goToPage => 'पेज पर जाएं';

  @override
  String pageRange(int min, int max) {
    return 'पेज: $min - $max';
  }

  @override
  String get cancel => 'रद्द करें';

  @override
  String get go => 'जाएं';

  @override
  String get previousPage => 'पिछला पेज';

  @override
  String get nextPage => 'अगला पेज';

  @override
  String get recentFiles => 'हाल की फ़ाइलें';

  @override
  String get clearAllRecents => 'हाल की फ़ाइलें हटाएं';

  @override
  String get clear => 'साफ़ करें';

  @override
  String get fileNotFound => 'फ़ाइल डिवाइस पर नहीं मिली';

  @override
  String get renameTab => 'टैब का नाम बदलें';

  @override
  String get newTabName => 'नया टैब नाम';

  @override
  String get rename => 'नाम बदलें';

  @override
  String get zoomIn => 'ज़ूम इन';

  @override
  String get zoomOut => 'ज़ूम आउट';

  @override
  String get fitWidth => 'चौड़ाई के अनुसार';

  @override
  String get fitPage => 'पेज के अनुसार';

  @override
  String get toggleDarkMode => 'डार्क रीडर मोड बदलें';

  @override
  String get continuousScroll => 'निरंतर स्क्रॉल';

  @override
  String get singlePage => 'एकल पेज';

  @override
  String get matchCase => 'अक्षर मिलान';

  @override
  String get sharePdf => 'PDF शेयर करें';
}
