// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'WhatsApp';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get sectionBehavior => 'Comportamento';

  @override
  String get minimizeToTrayTitle => 'Riduci nel system tray alla chiusura';

  @override
  String get minimizeToTraySubtitle =>
      'La pressione di × nasconde la finestra nel tray invece di uscire.';

  @override
  String get sectionAppearance => 'Aspetto';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get primaryColorTitle => 'Colore principale';

  @override
  String get sectionLayout => 'Layout';

  @override
  String get chatListWidthTitle => 'Larghezza lista chat';

  @override
  String get chatListWidthDefault => 'Default';

  @override
  String get resetToDefault => 'Reimposta al default WhatsApp';

  @override
  String get trayRestore => 'Ripristina';

  @override
  String get traySettings => 'Impostazioni';

  @override
  String get trayQuit => 'Chiudi';

  @override
  String get languageTitle => 'Lingua';

  @override
  String get languageSystem => 'Automatica (sistema)';
}
