// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'WhatsApp';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get sectionBehavior => 'Comportamento';

  @override
  String get minimizeToTrayTitle =>
      'Minimizar para a bandeja do sistema ao fechar';

  @override
  String get minimizeToTraySubtitle =>
      'Pressionar × oculta a janela na bandeja em vez de sair.';

  @override
  String get sectionAppearance => 'Aparência';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get primaryColorTitle => 'Cor principal';

  @override
  String get sectionLayout => 'Layout';

  @override
  String get chatListWidthTitle => 'Largura da lista de conversas';

  @override
  String get chatListWidthDefault => 'Padrão';

  @override
  String get resetToDefault => 'Redefinir para o padrão do WhatsApp';

  @override
  String get trayRestore => 'Restaurar';

  @override
  String get trayReload => 'Recarregar WhatsApp';

  @override
  String get traySettings => 'Configurações';

  @override
  String get trayKofi => 'Pague-me um café ☕';

  @override
  String get trayQuit => 'Sair';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageSystem => 'Automático (sistema)';
}
