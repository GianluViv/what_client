import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_el.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('el'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('nl'),
    Locale('pl'),
    Locale('pt'),
    Locale('ro'),
  ];

  /// Titolo dell'applicazione
  ///
  /// In it, this message translates to:
  /// **'WhatsApp'**
  String get appTitle;

  /// Titolo della schermata Impostazioni
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settingsTitle;

  /// Intestazione sezione comportamento
  ///
  /// In it, this message translates to:
  /// **'Comportamento'**
  String get sectionBehavior;

  /// Titolo opzione minimizza nel tray
  ///
  /// In it, this message translates to:
  /// **'Riduci nel system tray alla chiusura'**
  String get minimizeToTrayTitle;

  /// Sottotitolo opzione minimizza nel tray
  ///
  /// In it, this message translates to:
  /// **'La pressione di × nasconde la finestra nel tray invece di uscire.'**
  String get minimizeToTraySubtitle;

  /// Intestazione sezione aspetto
  ///
  /// In it, this message translates to:
  /// **'Aspetto'**
  String get sectionAppearance;

  /// Etichetta selezione tema
  ///
  /// In it, this message translates to:
  /// **'Tema'**
  String get themeTitle;

  /// Tema automatico (segue il sistema)
  ///
  /// In it, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// Tema chiaro
  ///
  /// In it, this message translates to:
  /// **'Chiaro'**
  String get themeLight;

  /// Tema scuro
  ///
  /// In it, this message translates to:
  /// **'Scuro'**
  String get themeDark;

  /// Etichetta scelta colore principale
  ///
  /// In it, this message translates to:
  /// **'Colore principale'**
  String get primaryColorTitle;

  /// Intestazione sezione layout
  ///
  /// In it, this message translates to:
  /// **'Layout'**
  String get sectionLayout;

  /// Etichetta larghezza lista chat
  ///
  /// In it, this message translates to:
  /// **'Larghezza lista chat'**
  String get chatListWidthTitle;

  /// Etichetta valore predefinito larghezza chat
  ///
  /// In it, this message translates to:
  /// **'Default'**
  String get chatListWidthDefault;

  /// Pulsante per ripristinare la larghezza predefinita
  ///
  /// In it, this message translates to:
  /// **'Reimposta al default WhatsApp'**
  String get resetToDefault;

  /// Voce menu tray: ripristina finestra
  ///
  /// In it, this message translates to:
  /// **'Ripristina'**
  String get trayRestore;

  /// No description provided for @trayReload.
  ///
  /// In it, this message translates to:
  /// **'Ricarica WhatsApp'**
  String get trayReload;

  /// Voce menu tray: apri impostazioni
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get traySettings;

  /// Voce menu tray: link Ko-fi
  ///
  /// In it, this message translates to:
  /// **'Offrimi un caffè ☕'**
  String get trayKofi;

  /// Voce menu tray: chiudi applicazione
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get trayQuit;

  /// Etichetta selezione lingua
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get languageTitle;

  /// Opzione lingua automatica (segue il sistema)
  ///
  /// In it, this message translates to:
  /// **'Automatica (sistema)'**
  String get languageSystem;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'el',
    'en',
    'es',
    'fr',
    'it',
    'nl',
    'pl',
    'pt',
    'ro',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
