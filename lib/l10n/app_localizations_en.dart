// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WhatsApp';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionBehavior => 'Behavior';

  @override
  String get minimizeToTrayTitle => 'Minimize to system tray on close';

  @override
  String get minimizeToTraySubtitle =>
      'Pressing × hides the window to the tray instead of quitting.';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get primaryColorTitle => 'Primary color';

  @override
  String get sectionLayout => 'Layout';

  @override
  String get chatListWidthTitle => 'Chat list width';

  @override
  String get chatListWidthDefault => 'Default';

  @override
  String get resetToDefault => 'Reset to WhatsApp default';

  @override
  String get trayRestore => 'Restore';

  @override
  String get trayReload => 'Reload WhatsApp';

  @override
  String get traySettings => 'Settings';

  @override
  String get trayKofi => 'Buy me a coffee ☕';

  @override
  String get trayQuit => 'Quit';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'Automatic (system)';
}
