// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'WhatsApp';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get sectionBehavior => 'Comportamiento';

  @override
  String get minimizeToTrayTitle =>
      'Minimizar en la bandeja del sistema al cerrar';

  @override
  String get minimizeToTraySubtitle =>
      'Pulsar × oculta la ventana en la bandeja en lugar de salir.';

  @override
  String get sectionAppearance => 'Apariencia';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get primaryColorTitle => 'Color principal';

  @override
  String get sectionLayout => 'Diseño';

  @override
  String get chatListWidthTitle => 'Ancho de la lista de chats';

  @override
  String get chatListWidthDefault => 'Predeterminado';

  @override
  String get resetToDefault =>
      'Restablecer al valor predeterminado de WhatsApp';

  @override
  String get trayRestore => 'Restaurar';

  @override
  String get trayReload => 'Recargar WhatsApp';

  @override
  String get traySettings => 'Configuración';

  @override
  String get trayKofi => 'Invítame un café ☕';

  @override
  String get trayQuit => 'Salir';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageSystem => 'Automático (sistema)';
}
