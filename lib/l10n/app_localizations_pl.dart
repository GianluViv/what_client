// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'WhatsApp';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get sectionBehavior => 'Zachowanie';

  @override
  String get minimizeToTrayTitle =>
      'Minimalizuj do zasobnika systemowego przy zamykaniu';

  @override
  String get minimizeToTraySubtitle =>
      'Naciśnięcie × ukrywa okno w zasobniku zamiast zamykać program.';

  @override
  String get sectionAppearance => 'Wygląd';

  @override
  String get themeTitle => 'Motyw';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Jasny';

  @override
  String get themeDark => 'Ciemny';

  @override
  String get primaryColorTitle => 'Kolor główny';

  @override
  String get sectionLayout => 'Układ';

  @override
  String get chatListWidthTitle => 'Szerokość listy czatów';

  @override
  String get chatListWidthDefault => 'Domyślny';

  @override
  String get resetToDefault => 'Przywróć domyślne WhatsApp';

  @override
  String get trayRestore => 'Przywróć';

  @override
  String get trayReload => 'Odśwież WhatsApp';

  @override
  String get traySettings => 'Ustawienia';

  @override
  String get trayKofi => 'Postaw mi kawę ☕';

  @override
  String get trayQuit => 'Zamknij';

  @override
  String get languageTitle => 'Język';

  @override
  String get languageSystem => 'Automatyczny (system)';
}
