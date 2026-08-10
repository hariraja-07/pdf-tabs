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
}
