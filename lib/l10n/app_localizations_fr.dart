// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'WhatsApp';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get sectionBehavior => 'Comportement';

  @override
  String get minimizeToTrayTitle =>
      'Réduire dans la barre des tâches à la fermeture';

  @override
  String get minimizeToTraySubtitle =>
      'Appuyer sur × masque la fenêtre dans la barre des tâches au lieu de quitter.';

  @override
  String get sectionAppearance => 'Apparence';

  @override
  String get themeTitle => 'Thème';

  @override
  String get themeSystem => 'Système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get primaryColorTitle => 'Couleur principale';

  @override
  String get sectionLayout => 'Disposition';

  @override
  String get chatListWidthTitle => 'Largeur de la liste de discussions';

  @override
  String get chatListWidthDefault => 'Défaut';

  @override
  String get resetToDefault => 'Réinitialiser au défaut WhatsApp';

  @override
  String get trayRestore => 'Restaurer';

  @override
  String get trayReload => 'Recharger WhatsApp';

  @override
  String get traySettings => 'Paramètres';

  @override
  String get trayQuit => 'Quitter';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageSystem => 'Automatique (système)';
}
