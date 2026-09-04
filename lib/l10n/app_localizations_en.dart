// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get familyToday => 'Today';

  @override
  String get familyThisWeek => 'This week';

  @override
  String get familyTodaysNotes => 'Today\'s notes';

  @override
  String get familySeeAllPhotos => 'See all photos';

  @override
  String get familyMessages => 'Messages';

  @override
  String get familyIncidents => 'Incidents';

  @override
  String get familyRoom => 'Room';

  @override
  String get familyPickupBy => 'Pickup by';

  @override
  String get familyShareFromHome => 'Share from home';

  @override
  String get familyShareSubtitle =>
      'Send your child\'s teacher a moment from home';

  @override
  String get familyShareSend => 'Send to the teacher';

  @override
  String get familyShareSent => 'Sent to the teacher!';

  @override
  String get familyShareNotLinked =>
      'Once your child is linked, you can share from home.';

  @override
  String get familyShareGuardianOnly =>
      'Sharing from home is for a child\'s parent or guardian.';

  @override
  String get familyNoChildren => 'No children linked yet';

  @override
  String get familyNoConversations => 'No conversations yet';

  @override
  String get familyChildNotFound => 'Child not found';

  @override
  String get familyChildStillLoading => 'Still loading this child — try again.';

  @override
  String get commonCouldNotLoad => 'Couldn\'t load';

  @override
  String get commonCheckConnection => 'Check your connection and try again.';

  @override
  String get commonCouldNotLoadChildren => 'Couldn\'t load your children';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonSignOut => 'Sign out?';

  @override
  String get commonNotAvailable => 'Not available';

  @override
  String get commonDisplayAndTextSize => 'Display & text size';

  @override
  String get commonForFamilies => 'For families';

  @override
  String familyWelcomeTitle(String childName) {
    return 'Welcome - $childName';
  }

  @override
  String familyChildFullName(String firstName, String lastName) {
    return '$firstName $lastName';
  }

  @override
  String familyPhotoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
      zero: 'No photos yet',
    );
    return '$_temp0';
  }
}
