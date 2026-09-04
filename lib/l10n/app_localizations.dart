import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Title of the family home — what happened with my child today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get familyToday;

  /// Section heading grouping the last seven days.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get familyThisWeek;

  /// Heading above the observations staff wrote today.
  ///
  /// In en, this message translates to:
  /// **'Today\'s notes'**
  String get familyTodaysNotes;

  /// Link from the photo strip into the full folder.
  ///
  /// In en, this message translates to:
  /// **'See all photos'**
  String get familySeeAllPhotos;

  /// No description provided for @familyMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get familyMessages;

  /// No description provided for @familyIncidents.
  ///
  /// In en, this message translates to:
  /// **'Incidents'**
  String get familyIncidents;

  /// Label before the classroom name. UI-side wording for the engine's Group (docs/NAMING.md).
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get familyRoom;

  /// Label before the people authorised to collect this child.
  ///
  /// In en, this message translates to:
  /// **'Pickup by'**
  String get familyPickupBy;

  /// No description provided for @familyShareFromHome.
  ///
  /// In en, this message translates to:
  /// **'Share from home'**
  String get familyShareFromHome;

  /// No description provided for @familyShareSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send your child\'s teacher a moment from home'**
  String get familyShareSubtitle;

  /// No description provided for @familyShareSend.
  ///
  /// In en, this message translates to:
  /// **'Send to the teacher'**
  String get familyShareSend;

  /// Confirmation after a guardian sends a photo or note. Keep the warmth — this is a parent being told their moment arrived.
  ///
  /// In en, this message translates to:
  /// **'Sent to the teacher!'**
  String get familyShareSent;

  /// No description provided for @familyShareNotLinked.
  ///
  /// In en, this message translates to:
  /// **'Once your child is linked, you can share from home.'**
  String get familyShareNotLinked;

  /// No description provided for @familyShareGuardianOnly.
  ///
  /// In en, this message translates to:
  /// **'Sharing from home is for a child\'s parent or guardian.'**
  String get familyShareGuardianOnly;

  /// No description provided for @familyNoChildren.
  ///
  /// In en, this message translates to:
  /// **'No children linked yet'**
  String get familyNoChildren;

  /// No description provided for @familyNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get familyNoConversations;

  /// No description provided for @familyChildNotFound.
  ///
  /// In en, this message translates to:
  /// **'Child not found'**
  String get familyChildNotFound;

  /// No description provided for @familyChildStillLoading.
  ///
  /// In en, this message translates to:
  /// **'Still loading this child — try again.'**
  String get familyChildStillLoading;

  /// Error-state title. Never says 'error' — see the copy-tone skill.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load'**
  String get commonCouldNotLoad;

  /// No description provided for @commonCheckConnection.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get commonCheckConnection;

  /// No description provided for @commonCouldNotLoadChildren.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your children'**
  String get commonCouldNotLoadChildren;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @commonSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get commonSignOut;

  /// No description provided for @commonNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get commonNotAvailable;

  /// No description provided for @commonDisplayAndTextSize.
  ///
  /// In en, this message translates to:
  /// **'Display & text size'**
  String get commonDisplayAndTextSize;

  /// No description provided for @commonForFamilies.
  ///
  /// In en, this message translates to:
  /// **'For families'**
  String get commonForFamilies;

  /// Header of the printable welcome sheet for a newly enrolled child.
  ///
  /// In en, this message translates to:
  /// **'Welcome - {childName}'**
  String familyWelcomeTitle(String childName);

  /// A child's display name. Separate so a locale that orders family name first can reorder it without touching Dart.
  ///
  /// In en, this message translates to:
  /// **'{firstName} {lastName}'**
  String familyChildFullName(String firstName, String lastName);

  /// Plural — English has two forms, Spanish two, Polish four. Written as ICU plural so a translator supplies the forms their language needs instead of the app assuming two.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No photos yet} =1{1 photo} other{{count} photos}}'**
  String familyPhotoCount(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
