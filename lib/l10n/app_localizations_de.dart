// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'WhatsApp';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get sectionBehavior => 'Verhalten';

  @override
  String get minimizeToTrayTitle =>
      'Beim Schließen in die Taskleiste minimieren';

  @override
  String get minimizeToTraySubtitle =>
      'Ein Klick auf × versteckt das Fenster in der Taskleiste, anstatt das Programm zu beenden.';

  @override
  String get sectionAppearance => 'Darstellung';

  @override
  String get themeTitle => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get primaryColorTitle => 'Hauptfarbe';

  @override
  String get sectionLayout => 'Layout';

  @override
  String get chatListWidthTitle => 'Breite der Chat-Liste';

  @override
  String get chatListWidthDefault => 'Standard';

  @override
  String get resetToDefault => 'Auf WhatsApp-Standard zurücksetzen';

  @override
  String get trayRestore => 'Wiederherstellen';

  @override
  String get trayReload => 'WhatsApp neu laden';

  @override
  String get traySettings => 'Einstellungen';

  @override
  String get trayKofi => 'Kauf mir einen Kaffee ☕';

  @override
  String get trayQuit => 'Beenden';

  @override
  String get languageTitle => 'Sprache';

  @override
  String get languageSystem => 'Automatisch (System)';
}
